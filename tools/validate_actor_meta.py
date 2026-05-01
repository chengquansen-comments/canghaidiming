#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

REQUIRED_TOP_LEVEL = [
    "schema_version",
    "role_id",
    "display_name",
    "frame_size",
    "foot_anchor",
    "body_center",
    "default_facing",
    "animations",
]

REQUIRED_ANIMATION_FIELDS = ["frames", "fps", "loop"]
REQUIRED_ATTACK_FIELDS = ["hit_frame", "phase_frames", "fx", "impact_offset", "recovery_to"]
ATTACK_ANIMATION_PREFIXES = ("attack",)
MIN_REQUIRED_ANIMATIONS = ["idle", "move_forward", "attack_light", "guard", "hit", "break"]


def fail(message: str) -> None:
    print(f"[actor-meta] ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def warn(message: str) -> None:
    print(f"[actor-meta] WARN: {message}")


def ok(message: str) -> None:
    print(f"[actor-meta] OK: {message}")


def require_pair(name: str, value: Any) -> list[int]:
    if not isinstance(value, list) or len(value) != 2:
        fail(f"{name} must be a two-number array")
    result: list[int] = []
    for item in value:
        if not isinstance(item, int):
            fail(f"{name} values must be integers: {value!r}")
        result.append(item)
    return result


def validate_phase_frames(animation_name: str, anim: dict[str, Any], frames: int) -> None:
    phase_frames = anim.get("phase_frames")
    if not isinstance(phase_frames, dict):
        fail(f"{animation_name}.phase_frames must be an object")
    for phase in ["anticipation", "strike", "impact", "recovery"]:
        if phase not in phase_frames:
            fail(f"{animation_name}.phase_frames missing phase: {phase}")
        span = phase_frames[phase]
        if not isinstance(span, list) or len(span) != 2 or not all(isinstance(v, int) for v in span):
            fail(f"{animation_name}.phase_frames.{phase} must be [start, end]")
        start, end = span
        if start < 0 or end < start or end >= frames:
            fail(f"{animation_name}.phase_frames.{phase} out of range for {frames} frames: {span}")


def validate_animation(meta_path: Path, animation_name: str, anim: Any, frame_size: list[int]) -> None:
    if not isinstance(anim, dict):
        fail(f"animations.{animation_name} must be an object")
    for field in REQUIRED_ANIMATION_FIELDS:
        if field not in anim:
            fail(f"animations.{animation_name} missing required field: {field}")

    frames = anim["frames"]
    fps = anim["fps"]
    loop = anim["loop"]
    if not isinstance(frames, int) or frames <= 0:
        fail(f"animations.{animation_name}.frames must be a positive integer")
    if not isinstance(fps, (int, float)) or fps <= 0:
        fail(f"animations.{animation_name}.fps must be a positive number")
    if not isinstance(loop, bool):
        fail(f"animations.{animation_name}.loop must be boolean")

    file_name = anim.get("file")
    files = anim.get("files")
    if isinstance(files, list):
        if len(files) != frames:
            fail(f"animations.{animation_name}.files length must equal frames={frames}")
        for index, item in enumerate(files):
            if not isinstance(item, str) or item.strip() == "":
                fail(f"animations.{animation_name}.files[{index}] must be a non-empty string")
            asset_path = meta_path.parent / item
            if not asset_path.exists():
                fail(f"animations.{animation_name}.files[{index}] not found: {asset_path}")
    elif isinstance(file_name, str) and file_name.strip() != "":
        asset_path = meta_path.parent / file_name
        if not asset_path.exists():
            fail(f"animations.{animation_name}.file not found: {asset_path}")
    else:
        fail(f"animations.{animation_name} must define either file or files")

    if animation_name.startswith(ATTACK_ANIMATION_PREFIXES):
        for field in REQUIRED_ATTACK_FIELDS:
            if field not in anim:
                fail(f"attack animation {animation_name} missing required field: {field}")
        hit_frame = anim["hit_frame"]
        if not isinstance(hit_frame, int) or hit_frame < 0 or hit_frame >= frames:
            fail(f"{animation_name}.hit_frame must be in [0, {frames - 1}]")
        require_pair(f"{animation_name}.impact_offset", anim["impact_offset"])
        validate_phase_frames(animation_name, anim, frames)


def validate_meta(meta_path: Path) -> None:
    try:
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"failed to read JSON {meta_path}: {exc}")

    if not isinstance(meta, dict):
        fail("meta root must be an object")

    for field in REQUIRED_TOP_LEVEL:
        if field not in meta:
            fail(f"missing required top-level field: {field}")

    role_id = meta["role_id"]
    if not isinstance(role_id, str) or not role_id:
        fail("role_id must be a non-empty string")

    frame_size = require_pair("frame_size", meta["frame_size"])
    foot_anchor = require_pair("foot_anchor", meta["foot_anchor"])
    body_center = require_pair("body_center", meta["body_center"])

    if frame_size[0] <= 0 or frame_size[1] <= 0:
        fail("frame_size values must be positive")
    if not (0 <= foot_anchor[0] <= frame_size[0] and 0 <= foot_anchor[1] <= frame_size[1]):
        fail(f"foot_anchor {foot_anchor} outside frame_size {frame_size}")
    if not (0 <= body_center[0] <= frame_size[0] and 0 <= body_center[1] <= frame_size[1]):
        fail(f"body_center {body_center} outside frame_size {frame_size}")

    expected_foot_y_min = frame_size[1] - 24
    expected_foot_y_max = frame_size[1] - 8
    if not (expected_foot_y_min <= foot_anchor[1] <= expected_foot_y_max):
        warn(f"foot_anchor.y usually should be {expected_foot_y_min}..{expected_foot_y_max}, got {foot_anchor[1]}")

    facing = meta["default_facing"]
    if facing not in ["left", "right"]:
        fail("default_facing must be 'left' or 'right'")

    animations = meta["animations"]
    if not isinstance(animations, dict) or not animations:
        fail("animations must be a non-empty object")

    for animation_name in MIN_REQUIRED_ANIMATIONS:
        if animation_name not in animations:
            fail(f"missing minimum required animation: {animation_name}")

    for animation_name, anim in animations.items():
        validate_animation(meta_path, animation_name, anim, frame_size)

    ok(f"{meta_path} validated for role_id={role_id}, animations={len(animations)}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate actor animation meta.json files.")
    parser.add_argument("paths", nargs="+", help="meta.json paths or actor directories")
    args = parser.parse_args()

    meta_paths: list[Path] = []
    for raw in args.paths:
        path = Path(raw)
        if path.is_dir():
            meta_paths.extend(sorted(path.glob("*.meta.json")))
        else:
            meta_paths.append(path)

    if not meta_paths:
        fail("no meta files found")

    for meta_path in meta_paths:
        if not meta_path.exists():
            fail(f"meta file not found: {meta_path}")
        validate_meta(meta_path)


if __name__ == "__main__":
    main()
