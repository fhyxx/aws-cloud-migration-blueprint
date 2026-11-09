#!/usr/bin/env python3
"""Validate the portfolio's saved cost baseline and migration-cost guardrails."""

from __future__ import annotations

import csv
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "cost" / "pricing-assumptions.csv"
EXPECTED_BASELINE = Decimal("1930.76")
EXPECTED_ANNUAL = Decimal("23169.12")


def money(value: str, label: str) -> Decimal:
    try:
        return Decimal(value)
    except Exception as exc:
        raise AssertionError(f"{label} must be a numeric USD amount, got {value!r}") from exc


def main() -> None:
    with CSV_PATH.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    assert rows, "Pricing assumptions CSV is empty"
    by_service: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        by_service.setdefault(row["service"], []).append(row)

    # Only parent/component rows explicitly verified in the Calculator may
    # contribute. The TOTAL row is a control total and is excluded from sum.
    verified = [
        row for row in rows
        if row["confidence"] == "calculator-verified"
        and row["service"] != "TOTAL"
        and row["monthly_low_usd"].strip()
    ]
    verified_sum = sum((money(row["monthly_low_usd"], row["service"]) for row in verified), Decimal("0"))
    assert verified_sum == EXPECTED_BASELINE, (
        f"Calculator-verified component sum {verified_sum} != {EXPECTED_BASELINE}"
    )

    total = by_service["TOTAL"][0]
    assert money(total["monthly_low_usd"], "TOTAL monthly") == EXPECTED_BASELINE
    assert money(total["monthly_high_usd"], "TOTAL monthly high") == EXPECTED_BASELINE
    assert "23169.12" in total["notes"], "Annualised subtotal must remain documented"

    # Migration group is intentionally unpriced. A numeric zero would be
    # misleading because the service/resource quantities are not known.
    migration_group = by_service["MIGRATION GROUP"][0]
    assert migration_group["monthly_low_usd"].strip() == ""
    assert migration_group["monthly_high_usd"].strip() == ""
    for service in ("MGN staging infrastructure (migration period)", "DMS (migration period)", "DataSync", "Temporary network", "Parallel running"):
        row = by_service[service][0]
        assert row["confidence"] == "pending", f"{service} must remain pending"
        assert row["monthly_low_usd"].strip() in ("", "UNPRICED")
        assert row["monthly_high_usd"].strip() in ("", "UNPRICED")

    # Independently recompute the published/reference sensitivities.
    mgn = by_service["MGN service fee (migration period)"][0]
    assert money(mgn["monthly_low_usd"], "MGN low") == Decimal("0.00")
    assert money(mgn["monthly_high_usd"], "MGN high") == Decimal("2.52")
    assert Decimal("2") * max(Decimal("0"), Decimal("2190") - Decimal("2160")) * Decimal("0.042") == Decimal("2.520")

    datasync = by_service["DataSync NFS-only conditional sensitivity"][0]
    assert money(datasync["monthly_low_usd"], "DataSync low") == Decimal("12.50")
    assert money(datasync["monthly_high_usd"], "DataSync high") == Decimal("12.80")
    assert Decimal("1000") * Decimal("0.0125") == Decimal("12.5000")
    assert Decimal("1024") * Decimal("0.0125") == Decimal("12.8000")

    endpoint = by_service["Interface endpoint fixed price"][0]
    assert money(endpoint["monthly_low_usd"], "endpoint low") == Decimal("7.30")
    assert Decimal("730") * Decimal("0.01") == Decimal("7.300")

    print("Cost model validation passed.")
    print(f"Calculator-verified baseline: USD {verified_sum:.2f}/month")
    print(f"Annualised control total: USD {EXPECTED_ANNUAL:.2f}")
    print("Migration-period costs remain explicitly unpriced; conditional sensitivities reconcile.")


if __name__ == "__main__":
    main()
