#!/usr/bin/env python3
"""验证 v1.1 runtime export dry-run 报告。"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate runtime export dry-run outputs.")
    parser.add_argument("--design-dir", default="data/design")
    return parser.parse_args()


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def fail(msg: str) -> int:
    print(f"FAIL: {msg}")
    return 1


def main() -> int:
    args = parse_args()
    design_dir = Path(args.design_dir)
    tsv_path = design_dir / "generated_runtime_export_dry_run.tsv"
    md_path = design_dir / "generated_runtime_export_dry_run.md"
    schema_path = design_dir / "generated_runtime_schema_proposal.tsv"

    if not tsv_path.exists() or tsv_path.stat().st_size == 0:
        return fail(f"missing/empty TSV: {tsv_path}")
    if not md_path.exists() or md_path.stat().st_size == 0:
        return fail(f"missing/empty MD: {md_path}")

    rows = read_tsv(tsv_path)
    schema_rows = read_tsv(schema_path)

    expected_domains = sorted({r.get("runtime_domain", "") for r in schema_rows if r.get("runtime_domain", "")})
    actual_domains = sorted({r.get("runtime_domain", "") for r in rows if r.get("runtime_domain", "")})
    if actual_domains != expected_domains or len(actual_domains) != 7:
        return fail(f"runtime_domain coverage mismatch: expected={expected_domains} actual={actual_domains}")

    if any(r.get("would_export") != "false" for r in rows):
        return fail("expected all would_export=false")
    if any(r.get("blocked") != "true" for r in rows):
        return fail("expected all blocked=true")
    if any(not r.get("block_reasons", "").strip() or r.get("block_reasons") == "none" for r in rows):
        return fail("block_reasons must be non-empty for all rows")

    # dry-run 必须不写 runtime 文件
    if any("runtime_files_written=0" not in r.get("notes", "") for r in rows):
        return fail("notes must declare runtime_files_written=0")

    md = md_path.read_text(encoding="utf-8", errors="ignore").lower()
    forbidden_claims = [
        "已写 runtime",
        "已实现 runtime export",
        "runtime export 已实现",
        "wrote runtime",
    ]
    for token in forbidden_claims:
        if token in md:
            return fail(f"md contains forbidden claim: {token}")

    print("PASS: dry-run TSV exists and non-empty")
    print("PASS: dry-run MD exists and non-empty")
    print("PASS: covers all 7 runtime domains")
    print("PASS: would_export all false")
    print("PASS: blocked all true")
    print("PASS: block_reasons all non-empty")
    print("PASS: runtime write markers are zero")
    print("PASS: MD does not claim runtime export implemented/written")
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
