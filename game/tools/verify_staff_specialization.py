#!/usr/bin/env python3
"""Verify the35-day specialization treatment independently of the game engine.

Shared ledger/disk/qualification oracles also verify the older14-day diagnostic.
This driver additionally checks treatment identity and pre-specialization parity.
All paths are read-only and the result goes to stdout.
"""
import argparse
from copy import deepcopy
import json
from pathlib import Path

from verify_campaign_audit import Verifier, digest

MODES = ("untrained", "basic", "speed", "economy")
DAYS = 35


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("audit_dir", type=Path)
    args = parser.parse_args()
    report = json.loads((args.audit_dir / "report.json").read_text())
    v = Verifier(days=DAYS)
    v.check(report["format"] == 2 and report["kind"] == "staff_specialization" and report["days_per_campaign"] == DAYS and report["failures"] == [], "successful specialization schema with observed orders")
    expected = {(mode, f"{menu}_{role}") for mode in MODES for menu in ("fast", "slow") for role in ("prep", "floor")}
    expected |= {("untrained", "fast_none"), ("untrained", "slow_none")}
    cases = report["cases"]
    v.check(len(cases) == 18 and {(c["training_mode"], c["campaign"]["id"]) for c in cases} == expected, "all eighteen unique treatments")
    indexed = {(c["training_mode"], c["campaign"]["id"]): c["campaign"] for c in cases}
    summaries = []
    for wrapper in cases:
        mode, campaign = wrapper["training_mode"], wrapper["campaign"]
        # Only verified constant mode names select a child directory; campaign
        # identifiers and each day file are bounded by the shared verifier.
        summary = v.campaign(args.audit_dir / mode, campaign)
        summary["training_mode"] = mode
        hires = campaign["final_state"]["growth"]["staff"]
        events = [a for row in campaign["days"] for a in row["actions"] if a["kind"] == "training"]
        expected_styles = [] if mode == "untrained" else (["basic"] if mode == "basic" else ["basic", mode])
        receipts = []
        for staff in hires:
            entry = campaign["final_state"]["training"][staff]
            v.check([e["style"] for e in entry["lessons"]] == expected_styles, "exact chosen qualification level/path")
            v.check(len(events) == len(expected_styles), "no repeated or unrecorded training transaction")
            receipts.extend(deepcopy(entry["lessons"]))
        v.check(campaign["policy"] == "none" or len(hires) == 1, "single helper isolates role")
        summary["training_receipts"] = receipts
        summary["final_training"] = deepcopy(campaign["final_state"]["training"])
        total_wait, total_stars = 0, 0
        observed_days = []
        for row in campaign["days"]:
            metrics, service = row["runtime_metrics"], row["service"]
            orders = metrics["orders"]
            v.check(type(metrics["finished_at"]) is int and metrics["finished_at"] >= 0, "whole runtime finish time")
            v.check(len(orders) == service["units"], "one witness for each completed order")
            counts = {key: 0 for key in service["by_source"]}
            previous_done = 0
            for number, order in enumerate(orders, 1):
                v.check(order["order_id"] == number and order["source"] in counts, "valid ordered customer witness")
                v.check(all(type(order[key]) is int for key in ("wait", "stars", "done_t", "price", "unit_cost")), "whole observed metrics")
                v.check(order["wait"] >= 0 and 1 <= order["stars"] <= 5 and previous_done <= order["done_t"] <= metrics["finished_at"], "valid wait/stars/chronology")
                v.check(order["price"] == campaign["sale_config"]["price"] and order["unit_cost"] >= 0, "actual fixed menu order price/cost")
                counts[order["source"]] += 1
                previous_done = order["done_t"]
            v.check(counts == service["by_source"], "observed customer totals match actual report")
            v.check(sum(order["price"] for order in orders) == service["revenue"] and sum(order["unit_cost"] for order in orders) == service["ingredient_cost"], "order financial witnesses reconcile")
            v.check(sum(order["wait"] for order in orders) == metrics["wait_total"] and sum(order["stars"] for order in orders) == metrics["stars_total"], "observed wait/stars aggregates reconcile")
            total_wait += metrics["wait_total"]
            total_stars += metrics["stars_total"]
            observed_days.append({"day": row["day"], "units": len(orders), "wait_total": metrics["wait_total"], "stars_total": metrics["stars_total"], "finished_at": metrics["finished_at"]})
        summary["wait_total"] = total_wait
        summary["stars_total"] = total_stars
        summary["average_wait_game_seconds"] = round(total_wait / summary["units"], 3) if summary["units"] else None
        summary["average_stars"] = round(total_stars / summary["units"], 3) if summary["units"] else None
        summary["observed_days"] = observed_days
        control = indexed[("untrained", f"{campaign['menu']}_none")]
        baseline = indexed[("basic", campaign["id"])] if campaign["policy"] != "none" else control
        summary["wallet_delta_vs_no_helper"] = summary["final_wallet"] - control["final_state"]["wallet"]
        summary["units_delta_vs_no_helper"] = summary["units"] - sum(row["service"]["units"] for row in control["days"])
        summary["wallet_delta_vs_basic"] = summary["final_wallet"] - baseline["final_state"]["wallet"]
        summary["units_delta_vs_basic"] = summary["units"] - sum(row["service"]["units"] for row in baseline["days"])
        summaries.append(summary)

    for menu in ("fast", "slow"):
        control = indexed[("untrained", f"{menu}_none")]
        for role in ("prep", "floor"):
            identity = f"{menu}_{role}"
            basic = indexed[("basic", identity)]
            for mode in MODES:
                campaign = indexed[(mode, identity)]
                v.check(campaign["sale_config"] == control["sale_config"] and campaign["final_state"]["records"] == control["final_state"]["records"], "same immutable menus/identifiers in every treatment")
                hires = [a for row in campaign["days"] for a in row["actions"] if a["kind"] == "hire"]
                v.check(len(hires) == 1 and hires[0]["day"] == 4, "same actual hire date")
                for left, right in zip(control["days"], campaign["days"]):
                    for kind in ("research", "trial"):
                        a = [(e["action"], e["delta"], e["day"]) for e in left["actions"] if e["kind"] == kind]
                        b = [(e["action"], e["delta"], e["day"]) for e in right["actions"] if e["kind"] == kind]
                        v.check(a == b, "same research/trial schedule")
                if mode in ("speed", "economy"):
                    staff = "prep_assistant" if role == "prep" else "floor_assistant"
                    specialization_day = campaign["final_state"]["training"][staff]["lessons"][1]["day"]
                    # All days before the second qualification must match the
                    # basic-only control exactly, including completed orders,
                    # experience, cash, snapshots and qualification receipts.
                    for day in range(1, specialization_day):
                        v.check(campaign["days"][day - 1] == basic["days"][day - 1], "identical pre-specialization history")
            speed = indexed[("speed", identity)]
            economy = indexed[("economy", identity)]
            staff = "prep_assistant" if role == "prep" else "floor_assistant"
            s = speed["final_state"]["training"][staff]["lessons"][1]
            e = economy["final_state"]["training"][staff]["lessons"][1]
            v.check({k: value for k, value in s.items() if k != "style"} == {k: value for k, value in e.items() if k != "style"}, "both specializations unlock from identical experience/date/rank")

    print(json.dumps({"independent_checks": v.checks, "failures": 0, "runtime_days": 18 * DAYS,
                      "report_sha256": digest(args.audit_dir / "report.json"), "campaigns": summaries}, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
