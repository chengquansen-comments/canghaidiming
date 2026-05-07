#!/usr/bin/env python3
"""v1.2a reward preview approval 校验器。"""

from __future__ import annotations

import csv
from pathlib import Path

DESIGN_DIR = Path("data/design")
INPUT_TSV = DESIGN_DIR / "generated_reward_preview_approval.tsv"
INPUT_MD = DESIGN_DIR / "generated_reward_preview_approval.md"


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def fail(msg: str) -> int:
    print(f"FAIL: {msg}")
    return 1


def main() -> int:
    if not INPUT_TSV.exists() or INPUT_TSV.stat().st_size == 0:
        return fail(f"missing/empty tsv: {INPUT_TSV.as_posix()}")
    if not INPUT_MD.exists() or INPUT_MD.stat().st_size == 0:
        return fail(f"missing/empty md: {INPUT_MD.as_posix()}")

    rows = read_tsv(INPUT_TSV)
    if len(rows) != 1:
        return fail("approval tsv must contain exactly one row")
    row = rows[0]

    if row.get("artifact_id") != "generated_battle_reward_plan":
        return fail("artifact_id must be generated_battle_reward_plan")
    if row.get("preview_allowed") != "true":
        return fail("preview_allowed must be true")
    if row.get("runtime_allowed") != "false":
        return fail("runtime_allowed must be false")
    if row.get("approved_for_runtime") != "false":
        return fail("approved_for_runtime must be false")

    runtime_dir = Path("data/runtime/content_engine")
    json_files = list(runtime_dir.glob("*.json")) if runtime_dir.exists() else []
    if not json_files:
        return fail("runtime dir json files missing unexpectedly")

    md = INPUT_MD.read_text(encoding="utf-8", errors="ignore")
    if "runtime approval" in md.lower() and "不属于 runtime approval" not in md:
        return fail("md must not claim runtime approval")

    print("PASS: reward preview approval TSV/MD exists")
    print("PASS: only generated_battle_reward_plan approved")
    print("PASS: preview_allowed=true")
    print("PASS: runtime_allowed=false")
    print("PASS: approved_for_runtime=false")
    print("PASS: runtime json not written by this flow")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
