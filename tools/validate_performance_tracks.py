#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    print(f"[performance-tracks] ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def ok(message: str) -> None:
    print(f"[performance-tracks] OK: {message}")


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"failed to read JSON {path}: {exc}")


def validate_res_path(raw_path: str, context: str) -> Path | None:
    path = raw_path.strip()
    if path == "":
        return None
    if not path.startswith("res://"):
        fail(f"{context} must use res:// path, got: {path}")
    local_path = ROOT / path.replace("res://", "", 1)
    if not local_path.exists():
        fail(f"{context} points to missing asset: {path}")
    if local_path.suffix.lower() == ".svg":
        validate_svg(local_path, context)
    return local_path


def validate_svg(path: Path, context: str) -> None:
    text = path.read_text(encoding="utf-8")
    try:
        ET.fromstring(text)
    except ET.ParseError as exc:
        fail(f"{context} is not valid SVG XML: {path}: {exc}")
    lowered = text.lower()
    if "<image" in lowered:
        fail(f"{context} SVG must not embed image tags: {path}")
    if "@font-face" in lowered:
        fail(f"{context} SVG must not embed font declarations: {path}")
    if re.search(r"(?:href|xlink:href)\s*=\s*['\"](?:https?:)?//", text, re.IGNORECASE):
        fail(f"{context} SVG must not reference remote resources: {path}")


def validate_performance_tracks(path: Path) -> int:
    payload = load_json(path)
    if not isinstance(payload, dict):
        fail("performance_tracks root must be a dictionary")
    timeline = payload.get("timeline")
    if not isinstance(timeline, dict):
        fail("performance_tracks.timeline must be a dictionary")

    checked = 0
    for track_id, track in timeline.items():
        if not isinstance(track, dict):
            fail(f"timeline.{track_id} must be a dictionary")
        for prefix in ("prop", "prop2", "prop3"):
            asset_path = validate_res_path(str(track.get(f"{prefix}_path", "")), f"timeline.{track_id}.{prefix}_path")
            if asset_path is not None:
                checked += 1
        for prefix in ("prop", "prop2", "prop3"):
            has_path = str(track.get(f"{prefix}_path", "")).strip() != ""
            layout_keys = [f"{prefix}_{key}" for key in ("left", "top", "right", "bottom", "alpha", "push_x", "push_y")]
            layout_values = [key for key in layout_keys if str(track.get(key, "")).strip() != ""]
            if layout_values and not has_path:
                fail(f"timeline.{track_id} defines {prefix} layout without {prefix}_path")
    return checked


def validate_narrative_visuals(path: Path) -> int:
    payload = load_json(path)
    if not isinstance(payload, dict):
        fail("narrative_mvp_nodes root must be a dictionary")
    checked = 0
    for node in payload.get("nodes", []):
        if not isinstance(node, dict):
            continue
        asset_path = validate_res_path(str(node.get("visual_path", "")), f"nodes.{node.get('id', 'unknown')}.visual_path")
        if asset_path is not None:
            checked += 1
    return checked


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate narrative performance track runtime assets.")
    parser.add_argument("--performance-tracks", default="data/performance_tracks.json")
    parser.add_argument("--narrative-nodes", default="data/narrative_mvp_nodes.json")
    args = parser.parse_args()

    performance_count = validate_performance_tracks(ROOT / args.performance_tracks)
    visual_count = validate_narrative_visuals(ROOT / args.narrative_nodes)
    ok(f"validated {performance_count} performance prop path(s) and {visual_count} narrative visual path(s)")


if __name__ == "__main__":
    main()
