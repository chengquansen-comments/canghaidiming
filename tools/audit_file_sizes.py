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

CODE_CATEGORIES = {
    "gd_script",
    "tool_script",
    "python_script",
    "shader",
}

CONTENT_CATEGORIES = {
    "data",
    "data_like",
    "docs",
    "scene",
    "resource",
    "project_config",
}


@dataclass(frozen=True)
class FileSizeRecord:
    path: str
    size_bytes: int
    size_kb: float
    level: str
    category: str
    risk_scope: str


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
    if path.suffix == ".gd":
        return "gd_script"
    if path.suffix == ".py":
        if first == "tools":
            return "tool_script"
        return "python_script"
    if path.suffix == ".shader":
        return "shader"
    if first == "docs" or first == "archive" or path.suffix == ".md":
        return "docs"
    if first == "scenes" or path.suffix == ".tscn":
        return "scene"
    if path.suffix in {".tres", ".res"}:
        return "resource"
    if path.name == "project.godot" or path.suffix in {".cfg", ".godot"}:
        return "project_config"
    if first in GENERATED_OR_DATA_DIRS:
        return first
    if path.suffix in {".json", ".tsv", ".csv"}:
        return "data_like"
    return "other"


def risk_scope_for(category: str) -> str:
    if category in CODE_CATEGORIES:
        return "code"
    if category in CONTENT_CATEGORIES:
        return "content"
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
        category = category_for(rel)
        records.append(
            FileSizeRecord(
                path=rel.as_posix(),
                size_bytes=size_bytes,
                size_kb=size_kb,
                level=classify_size(size_kb),
                category=category,
                risk_scope=risk_scope_for(category),
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


def records_by_scope(records: list[FileSizeRecord], scope: str) -> list[FileSizeRecord]:
    return [record for record in records if record.risk_scope == scope]


def non_ok_records(records: list[FileSizeRecord]) -> list[FileSizeRecord]:
    return [record for record in records if record.level != "OK"]


def high_or_split_records(records: list[FileSizeRecord]) -> list[FileSizeRecord]:
    return [record for record in records if record.level in {"HIGH_RISK", "SPLIT_REQUIRED"}]


def write_csv(records: list[FileSizeRecord], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["path", "size_bytes", "size_kb", "level", "category", "risk_scope"])
        for record in records:
            writer.writerow([
                record.path,
                record.size_bytes,
                f"{record.size_kb:.2f}",
                record.level,
                record.category,
                record.risk_scope,
            ])


def markdown_table(records: list[FileSizeRecord], limit: int | None = None) -> str:
    visible = records if limit is None else records[:limit]
    lines = ["| Size | Level | Scope | Category | File |", "|---:|---|---|---|---|"]
    for record in visible:
        lines.append(
            "| %.1f KB | %s | %s | %s | `%s` |"
            % (record.size_kb, record.level, record.risk_scope, record.category, record.path)
        )
    if not visible:
        lines.append("| - | - | - | - | - |")
    return "\n".join(lines)


def summary_table(title: str, records: list[FileSizeRecord]) -> list[str]:
    by_level = records_by_level(records)
    lines: list[str] = []
    lines.append(f"### {title}")
    lines.append("")
    lines.append("| Level | Count |")
    lines.append("|---|---:|")
    for level in ["HIGH_RISK", "SPLIT_REQUIRED", "WARN", "OK"]:
        lines.append("| %s | %d |" % (level, len(by_level[level])))
    lines.append("| Total | %d |" % len(records))
    lines.append("")
    return lines


def write_markdown(records: list[FileSizeRecord], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    code_records = records_by_scope(records, "code")
    content_records = records_by_scope(records, "content")
    other_records = records_by_scope(records, "other")
    gd_scripts = [record for record in records if record.category == "gd_script"]

    lines: list[str] = []
    lines.append("# File Size Audit")
    lines.append("")
    lines.append("This report is generated by `python3 tools/audit_file_sizes.py`.")
    lines.append("")
    lines.append("## Scope Model")
    lines.append("")
    lines.append("This audit separates file-size risk into two primary scopes:")
    lines.append("")
    lines.append("- **Code risk**: `.gd`, `.py`, and shader files. These should follow the 25KB code-organization rule strictly.")
    lines.append("- **Data / document risk**: TSV, JSON, Markdown, scene, resource, and config files. Large files here are not automatically code refactor blockers, but may need data-source or documentation cleanup.")
    lines.append("")
    lines.append("## Thresholds")
    lines.append("")
    lines.append("| Level | Range | Code Action | Data / Document Action |")
    lines.append("|---|---|---|---|")
    lines.append("| OK | `< 20KB` | Healthy range. | Healthy range. |")
    lines.append("| WARN | `20KB - 25KB` | Start evaluating split opportunities. | Watch for maintainability. |")
    lines.append("| SPLIT_REQUIRED | `25KB - 35KB` | Do not keep adding features; split or extract helpers. | Consider splitting source tables/docs if editing becomes hard. |")
    lines.append("| HIGH_RISK | `>= 35KB` | High-maintenance file; prioritize refactor plan. | Large content/data file; review source ownership and generation path. |")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.extend(summary_table("All Files", records))
    lines.extend(summary_table("Code Files", code_records))
    lines.extend(summary_table("Data / Document Files", content_records))
    if other_records:
        lines.extend(summary_table("Other Files", other_records))
    lines.append("## Code Action Required")
    lines.append("")
    lines.append("These files are the highest priority for code organization work.")
    lines.append("")
    lines.append(markdown_table(high_or_split_records(code_records), None))
    lines.append("")
    lines.append("## Code Watch List")
    lines.append("")
    lines.append(markdown_table([record for record in code_records if record.level == "WARN"], None))
    lines.append("")
    lines.append("## Data / Document Large Files")
    lines.append("")
    lines.append("These files are large, but should not be treated the same as oversized controller code. `data/*.json` files are usually generated artifacts and should not be edited directly.")
    lines.append("")
    lines.append(markdown_table(non_ok_records(content_records), None))
    lines.append("")
    lines.append("## Largest Files")
    lines.append("")
    lines.append(markdown_table(records, 50))
    lines.append("")
    lines.append("## GDScript Files")
    lines.append("")
    lines.append(markdown_table(gd_scripts, None))
    lines.append("")
    output_path.write_text("\n".join(lines), encoding="utf-8")


def print_scope_summary(scope_name: str, records: list[FileSizeRecord]) -> None:
    by_level = records_by_level(records)
    print(f"{scope_name}:")
    for level in ["HIGH_RISK", "SPLIT_REQUIRED", "WARN", "OK"]:
        print(f"  {level:15s} {len(by_level[level]):4d}")
    print(f"  {'TOTAL':15s} {len(records):4d}")


def print_summary(records: list[FileSizeRecord], top: int) -> None:
    code_records = records_by_scope(records, "code")
    content_records = records_by_scope(records, "content")
    other_records = records_by_scope(records, "other")
    print("File size audit")
    print("---------------")
    print_scope_summary("Code risk", code_records)
    print("")
    print_scope_summary("Data / document risk", content_records)
    if other_records:
        print("")
        print_scope_summary("Other", other_records)
    print("")
    print(f"Top {top} largest code files:")
    for record in code_records[:top]:
        print(f"{record.size_kb:8.1f} KB  {record.level:14s}  {record.path}")
    print("")
    print(f"Top {top} largest data/document files:")
    for record in content_records[:top]:
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
        help="Number of largest files to print to console per scope.",
    )
    parser.add_argument(
        "--fail-on-split-required",
        action="store_true",
        help="Exit non-zero if any code file is >= 25KB.",
    )
    parser.add_argument(
        "--fail-on-content-split-required",
        action="store_true",
        help="Exit non-zero if any data/document file is >= 25KB. Off by default because large generated/content files are expected.",
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
        risky_code = [
            record
            for record in records_by_scope(records, "code")
            if record.level in {"HIGH_RISK", "SPLIT_REQUIRED"}
        ]
        if risky_code:
            return 1

    if args.fail_on_content_split_required:
        risky_content = [
            record
            for record in records_by_scope(records, "content")
            if record.level in {"HIGH_RISK", "SPLIT_REQUIRED"}
        ]
        if risky_content:
            return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
