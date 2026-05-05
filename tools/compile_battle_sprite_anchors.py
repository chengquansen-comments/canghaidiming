#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

REQUIRED_COLUMNS = [
    "asset_id",
    "sheet",
    "frame_index",
    "frame_width",
    "frame_height",
    "layout",
    "foot_anchor_x",
    "foot_anchor_y",
    "target_anchor_x",
    "target_anchor_y",
]

OPTIONAL_BBOX_COLUMNS = ["bbox_x", "bbox_y", "bbox_w", "bbox_h"]


def fail(message: str) -> None:
    print(f"[battle-sprite-anchors] ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_int(row: dict[str, str], key: str, default: int | None = None) -> int:
    value = str(row.get(key, "")).strip()
    if value == "":
        if default is None:
            fail(f"missing required integer field '{key}' in row: {row}")
        return default
    try:
        return int(value)
    except ValueError:
        fail(f"invalid integer field '{key}'={value!r} in row: {row}")


def parse_optional_int(row: dict[str, str], key: str) -> int | None:
    value = str(row.get(key, "")).strip()
    if value == "":
        return None
    try:
        return int(value)
    except ValueError:
        fail(f"invalid optional integer field '{key}'={value!r} in row: {row}")


def validate_header(fieldnames: list[str] | None) -> None:
    if not fieldnames:
        fail("TSV has no header")
    missing = [name for name in REQUIRED_COLUMNS if name not in fieldnames]
    if missing:
        fail(f"TSV missing required columns: {', '.join(missing)}")


def read_tsv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        fail(f"TSV not found: {path}")
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        validate_header(reader.fieldnames)
        return [dict(row) for row in reader]


def bbox_from_row(row: dict[str, str]) -> list[int] | None:
    values = [parse_optional_int(row, key) for key in OPTIONAL_BBOX_COLUMNS]
    if all(value is None for value in values):
        return None
    if any(value is None for value in values):
        fail(f"bbox fields must be all filled or all empty: {row}")
    return [int(value) for value in values if value is not None]


def compile_rows(rows: list[dict[str, str]]) -> dict:
    output: dict = {"version": 1, "assets": {}}
    seen: set[tuple[str, int]] = set()
    for row in rows:
        asset_id = str(row.get("asset_id", "")).strip()
        if asset_id == "":
            fail(f"empty asset_id in row: {row}")
        sheet = str(row.get("sheet", "")).strip()
        if sheet == "":
            fail(f"empty sheet in row: {row}")
        frame_index = parse_int(row, "frame_index")
        if frame_index < 0:
            fail(f"frame_index must be >= 0: {row}")
        key = (asset_id, frame_index)
        if key in seen:
            fail(f"duplicate asset_id/frame_index: {asset_id}/{frame_index}")
        seen.add(key)
        frame_width = parse_int(row, "frame_width")
        frame_height = parse_int(row, "frame_height")
        if frame_width <= 0 or frame_height <= 0:
            fail(f"frame size must be positive: {row}")
        layout = str(row.get("layout", "vertical")).strip() or "vertical"
        if layout not in ["vertical", "horizontal"]:
            fail(f"layout must be vertical or horizontal: {row}")
        foot_anchor = [parse_int(row, "foot_anchor_x"), parse_int(row, "foot_anchor_y")]
        target_anchor = [parse_int(row, "target_anchor_x"), parse_int(row, "target_anchor_y")]
        shift = [target_anchor[0] - foot_anchor[0], target_anchor[1] - foot_anchor[1]]
        assets: dict = output["assets"]
        if asset_id not in assets:
            assets[asset_id] = {
                "sheet": sheet,
                "frame_size": [frame_width, frame_height],
                "layout": layout,
                "default_anchor": target_anchor,
                "frames": {},
            }
        else:
            asset = assets[asset_id]
            if asset["sheet"] != sheet:
                fail(f"asset {asset_id} has inconsistent sheet: {asset['sheet']} vs {sheet}")
            if asset["frame_size"] != [frame_width, frame_height]:
                fail(f"asset {asset_id} has inconsistent frame_size")
            if asset["layout"] != layout:
                fail(f"asset {asset_id} has inconsistent layout")
        assets[asset_id]["frames"][str(frame_index)] = {
            "foot_anchor": foot_anchor,
            "target_anchor": target_anchor,
            "shift": shift,
            "bbox": bbox_from_row(row),
        }
    return output


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Compile battle sprite anchor TSV into Godot runtime JSON.")
    parser.add_argument("--tsv", type=Path, default=Path("tables/battle_sprite_anchors.tsv"))
    parser.add_argument("--output", type=Path, default=Path("data/battle_sprite_anchors.json"))
    args = parser.parse_args()
    rows = read_tsv(args.tsv)
    data = compile_rows(rows)
    write_json(args.output, data)
    print(f"[battle-sprite-anchors] compiled {len(rows)} rows into {args.output}")
    print(f"[battle-sprite-anchors] assets={len(data.get('assets', {}))}")


if __name__ == "__main__":
    main()
