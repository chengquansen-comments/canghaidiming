#!/usr/bin/env python3
"""Audit repository file sizes against code-organization thresholds.

Outputs:
- Console summary sorted by descending file size.
- reports/file_size_audit.md
- reports/file_size_audit.csv

Run from repository root:
    python3 tools/audit_file_sizes.py
"""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

WARN_KB = 20.0
SPLIT_REQUIRED_KB = 25.0
HIGH_RISK_KB = 35.0

DEFAULT_EXCLUDE_DIRS = {
    ".git",
    ".godot",
    ".import",
    "build",
    "export",
    "exports",
    "__pycache__",
    ".pytest_cache",
    ".mypy_cache",
    ".ruff_cache",
    "node_modules",
}

DEFAULT_INCLUDE_SUFFIXES = {
    ".gd",
    ".py",
    ".tscn",
    ".tres",
    ".md",
    ".json",
    ".tsv",
    ".csv",
    ".cfg",
    ".godot",
    ".shader",
}

GENERATED_OR_DATA_DIRS = {
    "data",
    "reports",
}


@dataclass(frozen=True)
class FileSizeRecord:
    path: str
    size_bytes: int
    size_kb: float
    level: str
    category: str


def repo_root_from_script() -> Path:
    return Path(__file__).resolve().parents[1]


def should_skip_dir(path: Path) -> bool:
    return any(part in DEFAULT_EXCLUDE_DIRS for part in path.parts)


def should_include_file(path: Path, include_all: bool) -> bool:
    if include_all:
        return True
    if path.suffix in DEFAULT_INCLUDE_SUFFIXES:
        return True
    return path.name in {"README", "LICENSE"}


def classify_size(size_kb: float) -> str:
    if size_kb >= HIGH_RISK_KB:
        return "HIGH_RISK"
    if size_kb >= SPLIT_REQUIRED_KB:
        return "SPLIT_REQUIRED"
    if size_kb >= WARN_KB:
        return "WARN"
    return "OK"


def category_for(path: Path) -> str:
    parts = path.parts
    if not parts:
        return "other"
    first = parts[0]
    if first == "scripts" and path.suffix == ".gd":
        return "gd_script"
    if first == "tools" and path.suffix == ".py":
        return "tool_script"
    if first == "docs" or path.suffix == ".md":
        return "docs"
    if first == "scenes" or path.suffix == ".tscn":
        return "scene"
    if first in GENERATED_OR_DATA_DIRS:
        return first
    if path.suffix in {".json", ".tsv", ".csv"}:
        return "data_like"
    return "other"


def iter_files(root: Path, include_all: bool) -> Iterable[Path]:
    for path in root.rglob("*"):
        rel = path.relative_to(root)
        if path.is_dir():
            continue
        if should_skip_dir(rel):
            continue
        if not should_include_file(rel, include_all):
            continue
        yield path


def collect_records(root: Path, include_all: bool) -> list[FileSizeRecord]:
    records: list[FileSizeRecord] = []
    for path in iter_files(root, include_all):
        rel = path.relative_to(root)
        size_bytes = path.stat().st_size
        size_kb = size_bytes / 1024.0
        records.append(
            FileSizeRecord(
                path=rel.as_posix(),
                size_bytes=size_bytes,
                size_kb=size_kb,
                level=classify_size(size_kb),
                category=category_for(rel),
            )
        )
    records.sort(key=lambda item: item.size_bytes, reverse=True)
    return records


def records_by_level(records: list[FileSizeRecord]) -> dict[str, list[FileSizeRecord]]:
    result = {
        "HIGH_RISK": [],
        "SPLIT_REQUIRED": [],
        "WARN": [],
        "OK": [],
    }
    for record in records:
        result.setdefault(record.level, []).append(record)
    return result


def write_csv(records: list[FileSizeRecord], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["path", "size_bytes", "size_kb", "level", "category"])
        for record in records:
            writer.writerow([
                record.path,
                record.size_bytes,
                f"{record.size_kb:.2f}",
                record.level,
                record.category,
            ])


def markdown_table(records: list[FileSizeRecord], limit: int | None = None) -> str:
    visible = records if limit is None else records[:limit]
    lines = ["| Size | Level | Category | File |", "|---:|---|---|---|"]
    for record in visible:
        lines.append(
            "| %.1f KB | %s | %s | `%s` |"
            % (record.size_kb, record.level, record.category, record.path)
        )
    if not visible:
        lines.append("| - | - | - | - |")
    return "\n".join(lines)


def write_markdown(records: list[FileSizeRecord], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    by_level = records_by_level(records)
    non_ok = by_level["HIGH_RISK"] + by_level["SPLIT_REQUIRED"] + by_level["WARN"]
    gd_scripts = [record for record in records if record.category == "gd_script"]
    high_or_split = by_level["HIGH_RISK"] + by_level["SPLIT_REQUIRED"]

    lines: list[str] = []
    lines.append("# File Size Audit")
    lines.append("")
    lines.append("This report is generated by `python3 tools/audit_file_sizes.py`.")
    lines.append("")
    lines.append("## Thresholds")
    lines.append("")
    lines.append("| Level | Range | Action |")
    lines.append("|---|---|---|")
    lines.append("| OK | `< 20KB` | Healthy range. |")
    lines.append("| WARN | `20KB - 25KB` | Start evaluating split opportunities. |")
    lines.append("| SPLIT_REQUIRED | `25KB - 35KB` | Do not keep adding features; split or extract helpers. |")
    lines.append("| HIGH_RISK | `>= 35KB` | High-maintenance file; prioritize refactor plan. |")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append("| Level | Count |")
    lines.append("|---|---:|")
    for level in ["HIGH_RISK", "SPLIT_REQUIRED", "WARN", "OK"]:
        lines.append("| %s | %d |" % (level, len(by_level[level])))
    lines.append("| Total | %d |" % len(records))
    lines.append("")
    lines.append("## Action Required")
    lines.append("")
    lines.append(markdown_table(high_or_split, None))
    lines.append("")
    lines.append("## Watch List")
    lines.append("")
    lines.append(markdown_table(by_level["WARN"], None))
    lines.append("")
    lines.append("## Largest Files")
    lines.append("")
    lines.append(markdown_table(records, 40))
    lines.append("")
    lines.append("## GDScript Files")
    lines.append("")
    lines.append(markdown_table(gd_scripts, None))
    lines.append("")
    output_path.write_text("\n".join(lines), encoding="utf-8")


def print_summary(records: list[FileSizeRecord], top: int) -> None:
    by_level = records_by_level(records)
    print("File size audit")
    print("---------------")
    for level in ["HIGH_RISK", "SPLIT_REQUIRED", "WARN", "OK"]:
        print(f"{level:15s} {len(by_level[level]):4d}")
    print(f"{'TOTAL':15s} {len(records):4d}")
    print("")
    print(f"Top {top} largest files:")
    for record in records[:top]:
        print(f"{record.size_kb:8.1f} KB  {record.level:14s}  {record.path}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Audit repository file sizes.")
    parser.add_argument(
        "--root",
        default=None,
        help="Repository root. Defaults to parent of this script's directory.",
    )
    parser.add_argument(
        "--include-all",
        action="store_true",
        help="Include all file suffixes, not only common source/data/doc files.",
    )
    parser.add_argument(
        "--top",
        type=int,
        default=30,
        help="Number of largest files to print to console.",
    )
    parser.add_argument(
        "--fail-on-split-required",
        action="store_true",
        help="Exit non-zero if any file is >= 25KB.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = Path(args.root).resolve() if args.root else repo_root_from_script()
    records = collect_records(root, args.include_all)
    reports_dir = root / "reports"
    write_csv(records, reports_dir / "file_size_audit.csv")
    write_markdown(records, reports_dir / "file_size_audit.md")
    print_summary(records, args.top)
    if args.fail_on_split_required:
        risky = [record for record in records if record.level in {"HIGH_RISK", "SPLIT_REQUIRED"}]
        if risky:
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
