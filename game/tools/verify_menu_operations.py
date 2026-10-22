#!/usr/bin/env python3
"""Read-only external ledger/order/disk verifier; never imports the game runtime.

Known dish costs and existing catalog constants are explicit external oracles.
This does not independently reimplement taste scoring or customer menu choice.
All acceptance uses explicit checks, including under Python's optimized mode.
"""
import argparse
from collections import Counter, defaultdict
from copy import deepcopy
from itertools import combinations
import json
from pathlib import Path

from verify_campaign_audit import Verifier, PRICES, HIRES, WAGES, digest

DISH_COSTS = {"citrus_clear": 1490, "sesame_depth": 2540, "harbor_sea": 1670}
POLICIES = ("small_none", "small_prep", "expanded_none", "expanded_prep", "expanded_floor", "expanded_both")
TRAVEL_COSTS = {"trip:harbor": 6000, "trip:market": 3000, "trip:market_sample": 1000,
                "trip:harbor_sample": 1200, "choice:h_boat": 0, "choice:m_ask": 0,
                "choice:h_share_soup": 0, "choice:h_rent_tools": 400,
                "choice:m_hear_recipe": 0, "choice:m_buy_pickle": 300,
                "choice:sesame_stall": 0, "choice:citrus_cart": 0,
                "choice:sardine_boat": 0, "choice:scallop_diver": 0,
                "choice:take_three": 300, "choice:clean_three": 600}


class OperationsVerifier(Verifier):
    def actions(self, row, prior):
        """Reconstruct money, ownership and earned training from prior disk state."""
        day = row["day"]
        wallet = prior["wallet"]
        self.check(row["wallet_before"] == wallet and prior["day"] == day, "calendar/start wallet")
        growth, training = deepcopy(prior["growth"]), deepcopy(prior["training"])
        for action in row["actions"]:
            label, kind, delta = action["action"], action["kind"], action["delta"]
            self.check(type(delta) is int and action["wallet_before"] == wallet and action["day"] == day, "transaction input")
            if kind == "trial":
                self.check(label.startswith("taste:") and -10000 < delta < 0, "bounded actual trial cost")
            elif kind == "research":
                self.check(delta == (2000 if label.endswith("_basic") else 5000), "research cash oracle")
            elif kind == "travel":
                self.check(delta == -TRAVEL_COSTS.get(label, 0) and (label in TRAVEL_COSTS or label.startswith("claim:")), "travel fee/quantity oracle")
            elif kind == "promotion":
                target = int(label.split(":")[1])
                self.check(target == growth["rank"] + 1 and day >= (4 if target == 2 else 11) and delta == 0, "earned rank calendar")
                growth["rank"] = target
            elif kind == "facility":
                if label == "expand":
                    self.check(not prior["shop"]["expanded"] and delta == -60000 and growth["rank"] >= 2, "expansion gate/price")
                else:
                    facility = label.split(":")[1]
                    self.check(facility not in growth["facilities"] and delta == -PRICES[facility], "facility price/once")
                    self.check(growth["rank"] >= (3 if facility.endswith("2") else 2), "facility rank")
                    self.check(not facility.endswith("2") or facility.replace("2", "1") in growth["facilities"], "facility prerequisite")
                    growth["facilities"].append(facility)
            elif kind == "hire":
                staff = label.split(":")[1]
                self.check(staff not in growth["staff"] and delta == -HIRES[staff], "hire cost/once")
                self.check(len(growth["staff"]) < sum(f.startswith("staff_") for f in growth["facilities"]), "real staff capacity")
                growth["staff"].append(staff)
                training[staff] = {"bowls": 0, "work_days": 0, "last_work_day": 0, "lessons": []}
            elif kind == "training":
                _, staff, style = label.split(":")
                entry = training[staff]
                level = len(entry["lessons"])
                self.check(level < 2 and style == ("basic" if level == 0 else "speed"), "bounded chosen training path")
                self.check(entry["bowls"] >= (40 if level == 0 else 160) and entry["work_days"] >= (2 if level == 0 else 5), "actual experience")
                self.check(growth["rank"] >= (2 if level == 0 else 3) and entry["last_work_day"] < day, "training rank/calendar")
                self.check(delta == (-4000 if level == 0 else -12000), "training price")
                entry["lessons"].append(dict(day=day, rank=growth["rank"], bowls=entry["bowls"], work_days=entry["work_days"], style=style))
            else:
                self.check(False, "unknown transaction kind")
            self.check(action["rank"] == growth["rank"] and wallet + delta >= 0 and action["wallet_after"] == wallet + delta, "transaction output")
            wallet += delta
        ready = row["ready"]
        self.check(ready["wallet"] == wallet and ready["day"] == day, "ready money/calendar")
        self.check(ready["growth"] == growth and ready["training"] == training, "derived ownership/qualification receipts")

    def day(self, folder, row, prior, dish_by_record=None):
        self.actions(row, prior)
        ready, service, orders = row["ready"], row["service"], row["orders"]
        metrics = row["runtime_metrics"]
        day, menus = row["day"], ready["shop"]["menu_ids"]
        self.check(service["day"] == day and len(orders) == service["units"], "actual completion count/date")
        self.check(1 <= len(menus) <= (2 if ready["shop"]["expanded"] else 1), "legal menu capacity")
        sources = Counter({source: 0 for source in service["by_source"]})
        by_menu, previous_done = defaultdict(list), 0
        for index, order in enumerate(orders, 1):
            self.check(all(type(order[k]) is int for k in ("order_id", "price", "unit_cost", "wait", "stars", "done_t")), "whole order metrics")
            self.check(order["order_id"] == index and order["source"] in sources and 0 <= order["wait"] <= 4800, "order identity/source/wait")
            self.check(1 <= order["stars"] <= 5 and previous_done <= order["done_t"] <= metrics["finished_at"], "reaction/chronology")
            record = order.get("record_id", menus[0])
            self.check(record in menus and ("menu_index" not in order or menus[order["menu_index"]] == record), "actual ordered menu")
            if dish_by_record is not None:
                self.check(order["price"] == 9500 and order["unit_cost"] == DISH_COSTS[dish_by_record[record]], "fixed price/independent dish cost")
            sources[order["source"]] += 1
            by_menu[record].append(order)
            previous_done = order["done_t"]
        self.check(dict(sources) == service["by_source"], "order customer totals")
        self.check(sum(o["wait"] for o in orders) == metrics["wait_total"] and sum(o["stars"] for o in orders) == metrics["stars_total"], "observed wait/reaction aggregates")
        self.check(sum(o["price"] for o in orders) == service["revenue"] and sum(o["unit_cost"] for o in orders) == service["ingredient_cost"], "order financial totals")
        wage = 0
        for staff, entry in ready["training"].items():
            level = len(entry["lessons"])
            wage += WAGES[staff] + (0 if level == 0 else 150 if level == 1 else 400)
        self.check(service["overhead"] == 3000 + wage, "independent wages")
        self.check(service["net"] == service["revenue"] - service["ingredient_cost"] - service["overhead"], "net equation")
        if "menus" in service:
            self.check([m["record_id"] for m in service["menus"]] == menus, "menu report identity/order")
            for menu in service["menus"]:
                items = by_menu[menu["record_id"]]
                self.check(menu["units"] == len(items) and menu["wait_total"] == sum(o["wait"] for o in items), "per-menu wait/units")
                self.check(menu["revenue"] == sum(o["price"] for o in items) and menu["ingredient_cost"] == sum(o["unit_cost"] for o in items), "per-menu money")
        filename = f"day-{day:02d}.json"
        self.check(row["snapshot"] == filename, "bounded disk filename")
        path = folder / filename
        self.check(not path.is_symlink() and digest(path) == row["save_sha256"], "real snapshot hash")
        saved = json.loads(path.read_text())
        self.check(saved["schema_version"] == 13 and saved["day"] == day + 1, "saved schema/calendar")
        self.check(saved["wallet"] == ready["wallet"] + service["net"] == service["wallet_after"], "saved wallet")
        self.check(saved["last_report"] == service and saved["growth"] == ready["growth"], "saved report/ownership")
        self.check(saved["foraging"] == ready["foraging"] and saved["harbor_foraging"] == ready["harbor_foraging"], "service consumes no research stocks")
        for staff, entry in ready["training"].items():
            expected = deepcopy(entry)
            expected["bowls"] += len(orders)
            expected["work_days"] += bool(orders)
            expected["last_work_day"] = day
            self.check(saved["training"][staff] == expected, "actual-order experience, unchanged training receipt")
        return saved

    def verify(self, root):
        report = json.loads((root / "report.json").read_text())
        self.check(report["format"] == 1 and report["kind"] == "menu_operations" and report["failures"] == [] and report["days_per_case"] == 21, "successful bounded report")
        prep = report["preparation"]
        self.check(len(prep["days"]) == 12, "twelve legitimate preparation days")
        prior = dict(wallet=30000, day=1, growth=dict(rank=1, facilities=[], staff=[]), training={}, shop=dict(expanded=False))
        for row in prep["days"]:
            prior = self.day(root / "preparation", row, prior)
        self.check(prep["before_dishes"] == prior["wallet"], "pre-dish wallet")
        expected_wallet = prior["wallet"]
        for dish, action in zip(DISH_COSTS, prep["dish_actions"], strict=True):
            self.check(action["action"] == "taste:" + dish and action["delta"] == -DISH_COSTS[dish], "actual paid witness cost")
            self.check(action["wallet_before"] == expected_wallet and action["wallet_after"] == expected_wallet + action["delta"], "dish wallet")
            expected_wallet += action["delta"]
        baseline = json.loads((root / "baseline.json").read_text())
        self.check(digest(root / "baseline.json") == prep["baseline_sha256"] and baseline == prep["state"], "exact legitimate shared baseline")
        self.check(baseline["wallet"] == expected_wallet and baseline["day"] == 13 and baseline["growth"]["rank"] == 3, "earned prepared state")
        self.check(set(prep["dish_ids"]) == set(DISH_COSTS), "three real dish ids")
        dish_by_record = {record: dish for dish, record in prep["dish_ids"].items()}
        for field in ("foraging", "harbor_foraging"):
            self.check(set(baseline[field]["stock"].values()) == {2}, "three samples minus one real paid witness")
        expected_cases = {("+".join(menus) + "__" + policy) for size in (1, 2) for menus in combinations(DISH_COSTS, size) for policy in POLICIES if size == 1 or policy.startswith("expanded_")}
        self.check(len(report["cases"]) == 30 and {c["id"] for c in report["cases"]} == expected_cases, "exact thirty compatible cases")
        summaries = []
        for case in report["cases"]:
            label, policy = case["id"], case["policy"]
            self.check(label == "+".join(case["menu_set"]) + "__" + policy and len(case["days"]) == 21, "bounded case identity/duration")
            prior = deepcopy(baseline)
            folder = root / label
            for row in case["days"]:
                saved = self.day(folder, row, prior, dish_by_record)
                ready = row["ready"]
                self.check(ready["shop"]["menu_ids"] == [prep["dish_ids"][d] for d in case["menu_set"]], "chosen single/pair, no fallback")
                self.check(ready["shop"]["expanded"] == policy.startswith("expanded_"), "actual expansion policy")
                expected_staff = [s for s in HIRES if policy.endswith("both") or policy.endswith("prep" if s == "prep_assistant" else "floor")]
                self.check(ready["growth"]["staff"] == expected_staff, "actual helper policy")
                for field in ("records", "research", "exploration", "foraging", "harbor_foraging", "contests", "stories", "taste_achievements"):
                    self.check(ready[field] == baseline[field] and saved[field] == baseline[field], "unchanged baseline facts/stock: " + field)
                prior = saved
            self.check(prior == case["final_state"] == json.loads((folder / "ramen_lab_save.json").read_text()), "entire final disk state")
            penultimate = folder / f'day-{case["days"][-2]["day"]:02d}.json'
            self.check((folder / "ramen_lab_save.json.bak").read_bytes() == penultimate.read_bytes(), "exact previous-day backup")
            orders = [order for row in case["days"] for order in row["orders"]]
            spending = -sum(a["delta"] for row in case["days"] for a in row["actions"])
            net = sum(row["service"]["net"] for row in case["days"])
            self.check(prior["wallet"] == baseline["wallet"] - spending + net, "whole-branch ledger")
            summaries.append(dict(id=label, menu_set=case["menu_set"], policy=policy,
                                  units=len(orders), final_wallet=prior["wallet"], investment_and_training=spending,
                                  service_net=net, wait_total=sum(o["wait"] for o in orders),
                                  stars_total=sum(o["stars"] for o in orders),
                                  turned_away=sum(row["turned_away"] for row in case["days"]),
                                  menu_units=dict(Counter(dish_by_record[o.get("record_id", prep["dish_ids"][case["menu_set"][0]])] for o in orders)),
                                  training=prior["training"]))
        return dict(status="passed", checks=self.checks, preparation_days=12, service_days=630,
                    baseline_wallet=baseline["wallet"], cases=summaries)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("audit_dir", type=Path)
    args = parser.parse_args()
    try:
        result = OperationsVerifier(days=21).verify(args.audit_dir)
    except (OSError, ValueError, KeyError, TypeError, IndexError) as error:
        print(json.dumps(dict(status="failed", error=str(error))))
        return 1
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
