#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from art_asset_pipeline import read_delimited


ROOT = Path(__file__).resolve().parents[1]
BACKLOG_PATH = ROOT / "tables" / "art_backlog.tsv"
PRIORITY_ORDER = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}
STATUS_ORDER = {
    "NEEDS_SOURCE": 0,
    "NEEDS_PROMPT": 1,
    "EXISTING_RUNTIME_ONLY": 2,
    "SOURCE_READY": 3,
    "PROMPT_READY": 4,
    "WIRED_FINAL": 5,
    "GODOT_IMPORTED": 6,
    "IN_GAME_ACCEPTED": 7,
}
PROXY_CLASSES = {"portrait_proxy", "prop_proxy", "relic_proxy"}
SCENE_TYPES = {"battle_background", "narrative_background"}
PROP_TYPES = {"narrative_prop"}
PORTRAIT_CLASSES = {"portrait_proxy"}


def fail(message: str) -> None:
    raise SystemExit(f"[list-art-backlog] ERROR: {message}")


def load_rows() -> list[dict[str, str]]:
    if not BACKLOG_PATH.exists():
        fail(f"missing backlog: {BACKLOG_PATH}")
    _, rows, _ = read_delimited(BACKLOG_PATH)
    return rows


def row_sort_key(row: dict[str, str]) -> tuple[int, str]:
    return (PRIORITY_ORDER.get(row.get("priority", "").strip(), 99), row.get("asset_id", "").strip())


def row_pick_key(row: dict[str, str]) -> tuple[int, int, str]:
    return (
        PRIORITY_ORDER.get(row.get("priority", "").strip(), 99),
        STATUS_ORDER.get(row.get("overall_status", "").strip(), 99),
        row.get("asset_id", "").strip(),
    )


def matches_todo(row: dict[str, str], todo: str) -> bool:
    overall_status = row.get("overall_status", "").strip()
    current_asset_class = row.get("current_asset_class", "").strip()
    asset_type = row.get("asset_type", "").strip()
    if todo == "proxy":
        return current_asset_class in PROXY_CLASSES
    if todo == "next":
        return overall_status in {"NEEDS_PROMPT", "NEEDS_SOURCE", "EXISTING_RUNTIME_ONLY"}
    if todo == "scene":
        return overall_status in {"NEEDS_PROMPT", "NEEDS_SOURCE", "EXISTING_RUNTIME_ONLY"} and asset_type in SCENE_TYPES
    if todo == "prop":
        return overall_status in {"NEEDS_PROMPT", "NEEDS_SOURCE", "EXISTING_RUNTIME_ONLY"} and asset_type in PROP_TYPES
    if todo == "portrait":
        return overall_status in {"NEEDS_PROMPT", "NEEDS_SOURCE", "EXISTING_RUNTIME_ONLY"} and current_asset_class in PORTRAIT_CLASSES
    fail(f"unsupported --todo value: {todo}")
    return False


def print_ids(rows: list[dict[str, str]]) -> None:
    for row in rows:
        print(row.get("asset_id", "").strip())


def print_short(rows: list[dict[str, str]]) -> None:
    print("priority\toverall_status\tasset_id\tcurrent_asset_class\tsubject_label")
    for row in rows:
        print(
            "\t".join(
                [
                    row.get("priority", "").strip(),
                    row.get("overall_status", "").strip(),
                    row.get("asset_id", "").strip(),
                    row.get("current_asset_class", "").strip(),
                    row.get("subject_label", "").strip(),
                ]
            )
        )


def print_wide(rows: list[dict[str, str]]) -> None:
    print(
        "priority\toverall_status\tasset_id\tasset_type\tsubject_label\tcurrent_asset_class\tplanned_asset_class\truntime_role\tcurrent_runtime_path\tplanned_runtime_path"
    )
    for row in rows:
        print(
            "\t".join(
                [
                    row.get("priority", "").strip(),
                    row.get("overall_status", "").strip(),
                    row.get("asset_id", "").strip(),
                    row.get("asset_type", "").strip(),
                    row.get("subject_label", "").strip(),
                    row.get("current_asset_class", "").strip(),
                    row.get("planned_asset_class", "").strip(),
                    row.get("runtime_role", "").strip(),
                    row.get("current_runtime_path", "").strip(),
                    row.get("planned_runtime_path", "").strip(),
                ]
            )
        )


def main() -> int:
    parser = argparse.ArgumentParser(description="List art backlog entries.")
    parser.add_argument("--status", help="Filter by overall_status")
    parser.add_argument("--priority", help="Filter by priority")
    parser.add_argument("--type", dest="asset_type", help="Filter by asset_type")
    parser.add_argument(
        "--class",
        dest="asset_class",
        help="Filter by current_asset_class",
    )
    parser.add_argument("--todo", choices=["proxy", "next", "scene", "prop", "portrait"], help="Common backlog shortcuts")
    parser.add_argument("--format", choices=["wide", "short", "ids"], default="wide", help="Output format")
    parser.add_argument("--limit", type=int, help="Maximum number of rows to print")
    parser.add_argument("--pick-next", action="store_true", help="Print only one best candidate asset_id after filters")
    args = parser.parse_args()

    rows = sorted(load_rows(), key=row_sort_key)
    if args.todo:
        rows = [row for row in rows if matches_todo(row, args.todo)]
    if args.status:
        rows = [row for row in rows if row.get("overall_status", "").strip() == args.status]
    if args.priority:
        rows = [row for row in rows if row.get("priority", "").strip() == args.priority]
    if args.asset_type:
        rows = [row for row in rows if row.get("asset_type", "").strip() == args.asset_type]
    if args.asset_class:
        rows = [
            row
            for row in rows
            if row.get("current_asset_class", "").strip() == args.asset_class
        ]
    if args.limit is not None:
        rows = rows[: max(args.limit, 0)]

    if args.pick_next:
        if not rows:
            return 0
        print(min(rows, key=row_pick_key).get("asset_id", "").strip())
        return 0

    if args.format == "ids":
        print_ids(rows)
    elif args.format == "short":
        print_short(rows)
    else:
        print_wide(rows)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
