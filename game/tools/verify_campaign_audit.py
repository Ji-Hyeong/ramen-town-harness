#!/usr/bin/env python3
"""Independently check a campaign audit without importing or running Godot.

The few numeric rules below are deliberate external oracles for this diagnostic,
not replacement gameplay calculations. A later balance change must review them.
All input is read-only; only the caller chooses where stdout is persisted.
"""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path

POLICIES = ("none", "bench", "seats", "prep", "floor", "all")
PRICES = {"bench_1": 12000, "bench_2": 30000, "staff_1": 15000, "staff_2": 36000}
HIRES = {"prep_assistant": 8000, "floor_assistant": 7000}
WAGES = {"prep_assistant": 600, "floor_assistant": 500}
RESEARCH = ("dohyun_basic", "hayoung_basic", "maru_basic", "dohyun_advanced", "hayoung_advanced", "maru_advanced")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class Verifier:
    def __init__(self, days=14):
        if type(days) is not int or not 1 <= days <= 60:
            raise ValueError("Campaign verification requires 1..60 whole days")
        self.days = days
        self.checks = 0

    def check(self, condition, message):
        # Do not use assert: python -O must not silently disable acceptance.
        self.checks += 1
        if not condition:
            raise ValueError(message)

    def campaign(self, root, campaign):
        label = campaign["id"]
        menu, policy = campaign["menu"], campaign["policy"]
        self.check(label == f"{menu}_{policy}", "case identity")
        self.check(len(campaign["days"]) == self.days, f"{label}: expected campaign length")
        wallet, rank = 30000, 1
        facilities, hired, promotions, seen_research = [], [], [], []
        totals = {"trial": 0, "research": 0, "facility": 0, "hire": 0, "training": 0, "service_net": 0}
        units, lost, wage_total = 0, 0, 0
        timeline, purchases, snapshots = [], [], {}
        prior_training = {}
        prior_snapshot = None
        for day, row in enumerate(campaign["days"], 1):
            context = f"{label}: day {day}"
            self.check(row["day"] == day and row["wallet_before_preparation"] == wallet, context + ": start ledger")
            # Rebuild the qualification transition from recorded public actions,
            # not from the ready snapshot whose honesty we are checking.
            expected_training = deepcopy(prior_training)
            for action in row["actions"]:
                label_action, kind, delta = action["action"], action["kind"], action["delta"]
                self.check(action["day"] == day and action["wallet_before"] == wallet, context + ": transaction starts here")
                parts = label_action.split(":")
                if kind == "trial":
                    self.check(delta < 0 and delta > -10000, context + ": trial is a bounded cost")
                elif kind == "research":
                    request = parts[1]
                    self.check(day <= 6 and request == RESEARCH[day - 1] and request not in seen_research, context + ": unique scheduled research")
                    self.check(delta == (2000 if day <= 3 else 5000), context + ": catalog reward")
                    seen_research.append(request)
                elif kind == "promotion":
                    next_rank = int(parts[1])
                    self.check(delta == 0 and next_rank == rank + 1 and day >= (4 if next_rank == 2 else 11), context + ": rank days")
                    self.check(len(seen_research) >= (1 if next_rank == 2 else 4), context + ": rank research")
                    rank = next_rank
                    promotions.append({"day": day, "rank": rank})
                elif kind == "facility":
                    if label_action == "expand":
                        self.check(policy in ("seats", "all") and delta == -60000 and rank >= 2 and "expand" not in facilities, context + ": expansion gate")
                        facilities.append("expand")
                    else:
                        facility = parts[1]
                        permitted = policy == "all" or (policy == "bench" and facility.startswith("bench")) or (policy in ("prep", "floor") and facility == "staff_1")
                        self.check(permitted and facility not in facilities and delta == -PRICES[facility], context + ": facility policy/price")
                        self.check(rank >= (3 if facility.endswith("2") else 2), context + ": facility rank")
                        self.check(not facility.endswith("2") or facility.replace("2", "1") in facilities, context + ": prerequisite")
                        facilities.append(facility)
                    purchases.append({"day": day, "action": label_action, "cost": -delta})
                elif kind == "hire":
                    staff = parts[1]
                    self.check(staff not in hired and delta == -HIRES[staff] and "staff_1" in facilities, context + ": hire price/prerequisite")
                    self.check(len(hired) < (2 if "staff_2" in facilities else 1), context + ": staff capacity")
                    self.check(policy == "all" or policy == ("prep" if staff == "prep_assistant" else "floor"), context + ": hire policy")
                    hired.append(staff)
                    expected_training[staff] = {"bowls": 0, "work_days": 0, "last_work_day": 0, "lessons": []}
                    purchases.append({"day": day, "action": label_action, "cost": -delta})
                elif kind == "training":
                    staff, style = parts[1:]
                    entry = expected_training[staff]
                    level = len(entry["lessons"])
                    valid_style = style == "basic" if level == 0 else style in ("speed", "economy")
                    self.check(staff in hired and valid_style and level < 2, context + ": training stage")
                    self.check(entry["bowls"] >= (40 if level == 0 else 160) and entry["work_days"] >= (2 if level == 0 else 5) and rank >= (2 if level == 0 else 3), context + ": actual experience gate")
                    self.check(delta == (-4000 if level == 0 else -12000), context + ": training price")
                    self.check(entry["last_work_day"] < day and (not entry["lessons"] or entry["lessons"][-1]["day"] < day), context + ": training calendar")
                    entry["lessons"].append({"day": day, "rank": rank, "bowls": entry["bowls"], "work_days": entry["work_days"], "style": style})
                    purchases.append({"day": day, "action": label_action, "cost": -delta})
                else:
                    raise ValueError(context + ": unknown transaction kind " + kind)
                self.check(action["rank"] == rank and wallet + delta >= 0 and action["wallet_after"] == wallet + delta, context + ": transaction balances")
                wallet += delta
                if kind != "promotion":
                    totals[kind] += delta
            ready = row["ready"]
            self.check(ready["wallet"] == wallet and ready["rank"] == rank, context + ": prepared wallet/rank")
            self.check(ready["training"] == expected_training, context + ": exact training receipts and prior experience")
            self.check(ready["facilities"] == [f for f in facilities if f != "expand"] and ready["hired"] == hired, context + ": ownership")
            self.check(ready["expanded"] == ("expand" in facilities) and ready["seats"] == (12 if "expand" in facilities else 8), context + ": seats")
            service = row["service"]
            wage = 0
            for staff in hired:
                lessons = ready["training"][staff]["lessons"]
                wage_delta = 0 if not lessons else (150 if len(lessons) == 1 else (-100 if lessons[-1]["style"] == "economy" else 400))
                wage += WAGES[staff] + wage_delta
                after = row["training_after"][staff]
                self.check(after["lessons"] == lessons, context + ": service does not train")
                self.check(after["bowls"] == ready["training"][staff]["bowls"] + service["units"], context + ": real bowls experience")
                self.check(after["work_days"] == ready["training"][staff]["work_days"] + (service["units"] > 0), context + ": work days")
                self.check(after["last_work_day"] == day, context + ": last working day")
            self.check(service["day"] == day and service["overhead"] == 3000 + wage, context + ": operating cost")
            self.check(service["revenue"] == service["units"] * campaign["sale_config"]["price"], context + ": actual sales")
            self.check(sum(service["by_source"].values()) == service["units"], context + ": source counts")
            self.check(service["net"] == service["revenue"] - service["ingredient_cost"] - service["overhead"], context + ": profit equation")
            totals["service_net"] += service["net"]
            wallet += service["net"]
            units += service["units"]
            lost += row["turned_away"]
            wage_total += wage
            self.check(wallet == row["wallet_after"] == service["wallet_after"], context + ": final wallet")
            filename = f"day-{day:02}.json"
            self.check(row["snapshot"] == filename, context + ": bounded snapshot path")
            path = root / campaign["id"] / filename
            raw = path.read_bytes()
            snapshot = json.loads(raw)
            self.check(digest(path) == row["save_sha256"], context + ": disk hash")
            self.check(snapshot["day"] == day + 1 and snapshot["wallet"] == wallet and snapshot["schema_version"] == 10, context + ": saved calendar/wallet")
            self.check(snapshot["training"] == row["training_after"] and snapshot["last_report"] == service, context + ": saved service/experience")
            self.check(snapshot["growth"]["rank"] == rank and snapshot["growth"]["staff"] == hired, context + ": saved growth")
            self.check(snapshot["shop"]["menu_ids"] == [1] and snapshot["records"][0]["config"] == campaign["sale_config"], context + ": unchanged sale menu")
            if day == self.days:
                self.check((root / campaign["id"] / "ramen_lab_save.json").read_bytes() == raw, context + ": main is final snapshot")
                self.check((root / campaign["id"] / "ramen_lab_save.json.bak").read_bytes() == prior_snapshot, context + ": backup is exact prior day")
                self.check(snapshot == campaign["final_state"], context + ": complete final state")
            prior_snapshot = raw
            prior_training = row["training_after"]
            snapshots[filename] = row["save_sha256"]
            timeline.append({"day": day, "wallet": wallet, "service_net": service["net"], "units": service["units"], "turned_away": row["turned_away"]})
        self.check(wallet == 30000 + sum(totals.values()), label + ": whole-campaign ledger")
        self.check(seen_research == list(RESEARCH) and totals["research"] == 21000, label + ": all six one-time rewards")
        self.check(promotions == [{"day": 4, "rank": 2}, {"day": 11, "rank": 3}], label + ": legal unlock dates")
        return {"id": label, "menu": menu, "policy": policy, "final_wallet": wallet, "units": units, "turned_away": lost,
                "helper_wages": wage_total, "totals": totals, "promotions": promotions, "purchases": purchases,
                "daily": timeline, "snapshot_sha256": snapshots}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("audit_dir", type=Path)
    args = parser.parse_args()
    report = json.loads((args.audit_dir / "report.json").read_text())
    verifier = Verifier()
    verifier.check(report["format"] == 1 and report["days_per_campaign"] == 14 and report["failures"] == [], "successful audit schema")
    cases = report["campaigns"]
    verifier.check(len(cases) == 12 and {c["id"] for c in cases} == {f"{m}_{p}" for m in ("fast", "slow") for p in POLICIES}, "complete unique case set")
    summaries = [verifier.campaign(args.audit_dir, c) for c in cases]
    # Record identifiers/configs must match across policies, otherwise arrival
    # determinism could confound an apparent benefit from the investment.
    for menu in ("fast", "slow"):
        group = [c for c in cases if c["menu"] == menu]
        baseline = group[0]
        for case in group[1:]:
            for left, right in zip(baseline["days"], case["days"]):
                for key in ("trial", "research"):
                    left_actions = [(a["action"], a["delta"], a["day"]) for a in left["actions"] if a["kind"] == key]
                    right_actions = [(a["action"], a["delta"], a["day"]) for a in right["actions"] if a["kind"] == key]
                    verifier.check(left_actions == right_actions, "same research/trial schedule")
            verifier.check(case["sale_config"] == baseline["sale_config"] and case["final_state"]["records"] == baseline["final_state"]["records"], "same immutable recipes and identifiers")
        baseline_summary = next(s for s in summaries if s["id"] == f"{menu}_none")
        for summary in [s for s in summaries if s["menu"] == menu]:
            summary["wallet_delta_vs_none"] = summary["final_wallet"] - baseline_summary["final_wallet"]
            summary["units_delta_vs_none"] = summary["units"] - baseline_summary["units"]
    print(json.dumps({"independent_checks": verifier.checks, "failures": 0, "runtime_days": 168,
                      "report_sha256": digest(args.audit_dir / "report.json"), "campaigns": summaries}, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
