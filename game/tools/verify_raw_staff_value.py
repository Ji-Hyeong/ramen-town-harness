#!/usr/bin/env python3
"""Read-only independent checks of v1 raw staff audit saves and order traces.

The writer's successful API calls are not trusted as arithmetic evidence here.
Recompute wallets, wages, experience, training eligibility and sales from the
actual daily files. Checks remain enabled under python -O.
"""
import hashlib
import json
from pathlib import Path
import sys


class AuditError(ValueError):
    """An audit artifact does not conserve the expected public transactions."""


def canonical(value):
    # Recipe/setup signatures have only integer/string/list/dictionary values;
    # their sorted compact UTF-8 encoding matches Godot's signature encoding.
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()


def verify(root):
    checks = 0

    def check(condition, message):
        nonlocal checks
        checks += 1
        if not condition:
            raise AuditError(message)

    def read(path):
        check(path.is_file() and not path.is_symlink(), f"regular artifact required: {path}")
        return json.loads(path.read_text())

    def digest(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()

    check(root.is_dir() and not root.is_symlink(), "audit root must be a real directory")
    report = read(root / "report.json")
    check(report["format"] == 1 and report["kind"] == "raw_staff_value", "supported report format")
    check(report["failures"] == [] and report["settlements"] == 84, "six completed scenarios without writer failures")
    policies = {"none": ("", 0, 0), "kitchen_policy": ("prep_assistant", 8000, 600), "hall_policy": ("floor_assistant", 7000, 500)}
    expected = {}
    for name, ingredients, cut, tare, oil, cook, price in [
        ("light", ["ginger", "kelp"], "thin", "tare_shio", "oil_scallion", "cook_firm", 9000),
        ("rich", ["garlic", "pork_bone"], "thick", "tare_shoyu", "oil_garlic", "cook_normal", 9500),
    ]:
        expected[name] = {"broth": "broth_dashi" if name == "light" else "broth_tonkotsu",
            "broth_recipe": {"ingredients": ingredients, "method": "standard"}, "noodle": "noodle_" + cut,
            "noodle_recipe": {"flour": "wheat", "water": "clear", "cut": cut, "method": "standard"},
            "tare": tare, "oil": oil, "cook": cook, "price": price, "toppings": ["topping_nori"]}
    scenarios = report["scenarios"]
    check(len(scenarios) == 6 and {s["id"] for s in scenarios} == {m + "_" + p for m in expected for p in policies}, "exact six policy identities")
    derived = {}
    for scenario in scenarios:
        sid, menu, policy = scenario["id"], scenario["menu"], scenario["policy"]
        helper, hire_price, wage = policies[policy]
        config = expected[menu]
        sold_id = 1 if menu == "light" else 2
        other_id = 3 - sold_id
        check(scenario["complete"] and len(scenario["days"]) == 14, sid + ": all14days")
        setup = scenario["setup"]
        cursor = 30000
        for event in setup["events"]:
            check(event["wallet_before"] == cursor and event["day"] == 1 and event["rank"] == 1, sid + ": setup chronology")
            cursor += event["delta"]
            check(event["wallet_after"] == cursor, sid + ": setup wallet")
        check(cursor == setup["wallet_after"] and setup["records"] == {"light": 1, "rich": 2}, sid + ": real two-menu setup")
        check(hashlib.sha256(canonical(setup["events"])).hexdigest() == setup["setup_signature"], sid + ": independent setup signature")
        check(hashlib.sha256(canonical(config)).hexdigest() == setup["config_signature"] and scenario["sold_config"] == config, sid + ": exact fixed raw recipe")
        totals = {k: 0 for k in ["units", "revenue", "ingredient_cost", "overhead", "service_net", "preparation_spend", "turned_away"]}
        xp = workdays = wait_sum = stars_sum = 0
        trained = False
        action_days = {"promotion": 0, "staff_1": 0, "hire": 0, "train_basic": 0}
        action_costs = {"staff_1": 0, "hire": 0, "train_basic": 0}
        previous_state_hash = None
        for day, row in enumerate(scenario["days"], 1):
            check(row["day"] == day and row["wallet_before_preparation"] == cursor, sid + ": daily wallet starts from prior actual day")
            expected_actions = []
            if day == 4:
                expected_actions.append(("promotion", 0))
                action_days["promotion"] = day
                if helper:
                    expected_actions += [("facility", -15000), ("hire", -hire_price)]
                    action_days.update(staff_1=day, hire=day)
                    action_costs.update(staff_1=15000, hire=hire_price)
            # Basic training occurs at the first real eligible preparation, not
            # after today's bowls have been credited, and never consumes XP.
            if helper and day >= 4 and not trained and xp >= 40 and workdays >= 2:
                expected_actions.append(("training", -4000))
                trained = True
                action_days["train_basic"] = day
                action_costs["train_basic"] = 4000
            check([(e["kind"], e["delta"]) for e in row["actions"]] == expected_actions, sid + ": earliest eligible policy actions")
            for event in row["actions"]:
                check(event["day"] == day and event["wallet_before"] == cursor, sid + ": action day/wallet")
                cursor += event["delta"]
                check(event["wallet_after"] == cursor, sid + ": exact action expense")
            spend = -sum(delta for _, delta in expected_actions)
            check(row["preparation_spend"] == spend and row["wallet_before_service"] == cursor, sid + ": service starts after actual expenses")
            witness = row["selling_witness"]
            check(witness["record_id"] == sold_id and witness["pinned_menu_ids"] == [sold_id] and witness["selected_record_id"] == other_id and witness["last_feedback_record_id"] == other_id, sid + ": pin overrides the other displayed recipe")
            check(witness["config_signature"] == setup["config_signature"] and witness["price"] == config["price"], sid + ": pinned recipe and price")
            folder = root / sid / ("day-%02d" % day)
            check(row["save"]["folder"] == folder.name and row["save"]["file"] == "ramen_lab_save.json", sid + ": bounded save references")
            state_path = folder / "ramen_lab_save.json"
            state = read(state_path)
            check(digest(state_path) == row["save"]["sha256"] and state_path.stat().st_size == row["save"]["bytes"], sid + ": original saved bytes")
            check(state["schema_version"] == 18 and state["day"] == day + 1, sid + ": supported production saved day")
            check(not state["broth_workshop"]["legacy"] and not state["noodle_workshop"]["legacy"], sid + ": neither raw gate bypassed")
            check(len(state["records"]) == 2 and [r["config"] for r in state["records"]] == [expected["light"], expected["rich"]], sid + ": actual paid raw records unchanged")
            check(state["selected_record_id"] == other_id and state["last_feedback_record_id"] == other_id and state["shop"]["menu_ids"] == [sold_id], sid + ": saved pin and displayed record")
            rank = 1 if day < 4 else 2
            check(state["growth"]["rank"] == row["rank_before_service"] == row["rank_after"] == rank, sid + ": earned promotion chronology")
            hired = [helper] if helper and day >= 4 else []
            staffing = {"hired": hired, "prep_percent": 100, "serve_percent": 100, "wage": 0}
            if hired:
                staffing["prep_percent" if policy == "kitchen_policy" else "serve_percent"] = (80 if policy == "kitchen_policy" else 70) - (10 if trained else 0)
                staffing["wage"] = wage + (150 if trained else 0)
                if trained:
                    staffing["training"] = [{"id": helper, "level": 1, "style": "basic"}]
            check(row["staffing_snapshot"] == staffing == row["helper_state"]["current_staffing"], sid + ": actual qualification-derived wage and time")
            observation = row["runtime_observation_not_saved"]
            check(observation["saved_game_field"] is False and observation["orders_file"] == "runtime-orders.json", sid + ": separately marked runtime trace")
            orders_path = folder / "runtime-orders.json"
            orders = read(orders_path)
            check(digest(orders_path) == observation["orders_sha256"] and orders_path.stat().st_size == observation["orders_bytes"], sid + ": original order-trace bytes")
            check(len(orders) == observation["completed_orders"] == row["service"]["units"], sid + ": only completed orders counted")
            source_counts = {source: 0 for source in ["dohyun", "hayoung", "maru", "walkin"]}
            last_done = -1
            for ordinal, order in enumerate(orders, 1):
                # Single-menu sessions do not attach record_id to each order.
                # Tie their price to the pin and saved named receipt instead;
                # when an identity is present it must agree, never be invented.
                check(order["order_id"] == ordinal and order["price"] == config["price"], sid + ": actual completed order identity/price")
                if "record_id" in order:
                    check(order["record_id"] == sold_id, sid + ": explicit order record identity")
                check(order["unit_cost"] >= 0 and 1 <= order["stars"] <= 5 and order["wait"] >= 0 and 0 <= order["seat"] < 8, sid + ": bounded unexpanded order")
                check(last_done <= order["done_t"] <= row["service"]["finished_at"], sid + ": completion chronology")
                last_done = order["done_t"]
                check(order["source"] in source_counts, sid + ": known actual buyer")
                source_counts[order["source"]] += 1
            sales = row["service"]
            revenue, cost = sum(o["price"] for o in orders), sum(o["unit_cost"] for o in orders)
            overhead = 3000 + staffing["wage"]
            net = revenue - cost - overhead
            check((sales["revenue"], sales["ingredient_cost"], sales["overhead"], sales["net"]) == (revenue, cost, overhead, net), sid + ": independent order and wage ledger")
            check(sales["by_source"] == source_counts and abs(sales["avg_stars"] - sum(o["stars"] for o in orders) / max(1, len(orders))) < 1e-9, sid + ": actual buyers and response")
            check(observation["wait_total"] == sum(o["wait"] for o in orders), sid + ": actual-order waits")
            cursor += net
            check(state["wallet"] == row["wallet_after"] == cursor and state["last_report"] == row["settlement_report"], sid + ": entire saved settlement receipt")
            receipt = state["last_report"]
            check(receipt["recipe_name"] == state["records"][sold_id - 1]["name"] and receipt["price"] == config["price"] and receipt["version"] == 1, sid + ": saved named receipt identifies the pinned recipe")
            check((receipt["units"], receipt["revenue"], receipt["ingredient_cost"], receipt["overhead"], receipt["net"], receipt["wallet_after"]) == (len(orders), revenue, cost, overhead, net, cursor), sid + ": raw orders match saved restaurant totals")
            check(state["growth"]["staff"] == hired and row["helper_state"]["hired"] == hired, sid + ": only intended helper hired")
            check(state["growth"]["facilities"] == (["staff_1"] if hired else []), sid + ": only intended staffing room")
            if hired:
                training = state["training"][helper]
                if trained:
                    lesson = training["lessons"][0]
                    check(len(training["lessons"]) == 1 and lesson["style"] == "basic" and lesson["rank"] == 2 and lesson["day"] == action_days["train_basic"], sid + ": real basic lesson")
                    check(lesson["bowls"] >= 40 and lesson["work_days"] >= 2, sid + ": lesson prerequisites")
                    if day == action_days["train_basic"]:
                        check(lesson["bowls"] == xp and lesson["work_days"] == workdays, sid + ": lesson uses previous completed experience")
                else:
                    check(training["lessons"] == [], sid + ": no fabricated early training")
                xp += len(orders)
                workdays += int(bool(orders))
                check((training["bowls"], training["work_days"], training["last_work_day"]) == (xp, workdays, day), sid + ": completed-only experience")
            check(row["helper_state"]["training"] == state["training"], sid + ": exact saved qualification projection")
            check(row["save"]["roundtrip_equal"] is True, sid + ": runtime disk equality recorded")
            if previous_state_hash is not None:
                check(row["previous_day_state_sha256"] == previous_state_hash, sid + ": daily state continuity")
            previous_state_hash = row["save"]["state_sha256"]
            for key, value in {"units": len(orders), "revenue": revenue, "ingredient_cost": cost, "overhead": overhead, "service_net": net, "preparation_spend": spend, "turned_away": sales["turned_away"]}.items():
                totals[key] += value
            wait_sum += sum(o["wait"] for o in orders)
            stars_sum += sum(o["stars"] for o in orders)
        check(totals == scenario["totals"] and cursor == scenario["final"]["wallet"], sid + ": independently aggregated totals")
        check(action_days == scenario["action_days"] and action_costs == scenario["action_costs"], sid + ": real action dates and capital costs")
        summary = report["summary"]["menus"][menu][policy]
        check(summary["totals"] == totals and summary["final_wallet"] == cursor, sid + ": summary conservation")
        derived[sid] = {"menu": menu, "policy": policy, "wallet": cursor, "units": totals["units"], "wait_total": wait_sum, "star_sum": stars_sum,
            "mean_wait": wait_sum / max(1, totals["units"]), "mean_stars": stars_sum / max(1, totals["units"]), "training_day": action_days["train_basic"]}
    for scenario in scenarios:
        if scenario["policy"] == "none":
            continue
        base = next(s for s in scenarios if s["id"] == scenario["menu"] + "_none")
        summary = report["summary"]["menus"][scenario["menu"]][scenario["policy"]]
        check(scenario["setup"] == base["setup"] and scenario["sold_config"] == base["sold_config"], "paired setup and menu identical")
        difference = {key: scenario["totals"][key] - base["totals"][key] for key in scenario["totals"]}
        difference["final_wallet"] = scenario["final"]["wallet"] - base["final"]["wallet"]
        check(summary["difference_vs_none"] == difference, "paired policy difference uses same-menu control")
    return {"checks": checks, "failures": 0, "scenarios": 6, "settlements": 84, "derived": derived}


if __name__ == "__main__":
    try:
        if len(sys.argv) != 2:
            raise AuditError("usage: verify_raw_staff_value.py ABSOLUTE_AUDIT_ROOT")
        print(json.dumps(verify(Path(sys.argv[1])), ensure_ascii=False, indent=2))
    except (AuditError, OSError, json.JSONDecodeError, KeyError, TypeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
