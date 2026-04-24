#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def fail(message: str) -> None:
    print(f"[actor-sheet] ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def warn(message: str) -> None:
    print(f"[actor-sheet] WARN: {message}")


def ok(message: str) -> None:
    print(f"[actor-sheet] OK: {message}")


def require_pillow():
    try:
        from PIL import Image
        return Image
    except Exception as exc:
        raise SystemExit(
            "[actor-sheet] ERROR: Pillow is required for image validation.\n"
            "Run: python3 -m pip install pillow\n"
            f"Original error: {exc}"
        )


def load_meta(meta_path: Path) -> dict[str, Any]:
    try:
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"failed to read JSON {meta_path}: {exc}")
    if not isinstance(meta, dict):
        fail(f"meta root must be an object: {meta_path}")
    return meta


def validate_png_signature(path: Path) -> None:
    with path.open("rb") as fh:
        signature = fh.read(8)
    if signature != PNG_SIGNATURE:
        fail(f"not a PNG file: {path}")


def alpha_coverage(image) -> tuple[int, int, float]:
    if image.mode not in ("RGBA", "LA"):
        return 0, image.width * image.height, 0.0
    alpha = image.getchannel("A")
    values = alpha.getdata()
    non_zero = sum(1 for value in values if value > 0)
    total = image.width * image.height
    return non_zero, total, non_zero / float(total) if total else 0.0


def validate_sheet(meta_path: Path, animation_name: str, anim: dict[str, Any], frame_size: list[int]) -> None:
    Image = require_pillow()

    file_name = anim.get("file")
    frames = anim.get("frames")
    if not isinstance(file_name, str) or not file_name:
        fail(f"{animation_name}.file must be a non-empty string")
    if not isinstance(frames, int) or frames <= 0:
        fail(f"{animation_name}.frames must be a positive integer")

    image_path = meta_path.parent / file_name
    if not image_path.exists():
        fail(f"sheet not found for {animation_name}: {image_path}")
    if image_path.suffix.lower() != ".png":
        fail(f"sheet must be PNG for {animation_name}: {image_path}")
    validate_png_signature(image_path)

    with Image.open(image_path) as image:
        width, height = image.size
        expected_width = frame_size[0] * frames
        expected_height = frame_size[1]
        if width != expected_width or height != expected_height:
            fail(
                f"{animation_name} size mismatch: got {width}x{height}, "
                f"expected {expected_width}x{expected_height} "
                f"({frames} frames of {frame_size[0]}x{frame_size[1]})"
            )
        if image.mode != "RGBA":
            fail(f"{animation_name} must be RGBA PNG, got mode={image.mode}: {image_path}")
        non_zero, total, ratio = alpha_coverage(image)
        if non_zero <= 0:
            fail(f"{animation_name} appears fully transparent: {image_path}")
        if ratio < 0.01:
            warn(f"{animation_name} alpha coverage is very low ({ratio:.2%}); check if sprite is too small")
        if ratio > 0.72:
            warn(f"{animation_name} alpha coverage is very high ({ratio:.2%}); check if background is not transparent")

    ok(f"{animation_name}: {image_path.name} {expected_width}x{expected_height}, frames={frames}")


def validate_meta_sheets(meta_path: Path) -> None:
    meta = load_meta(meta_path)
    frame_size = meta.get("frame_size")
    if not isinstance(frame_size, list) or len(frame_size) != 2 or not all(isinstance(v, int) for v in frame_size):
        fail(f"frame_size must be [width, height] in {meta_path}")
    animations = meta.get("animations")
    if not isinstance(animations, dict) or not animations:
        fail(f"animations must be a non-empty object in {meta_path}")
    for animation_name, anim in animations.items():
        if not isinstance(anim, dict):
            fail(f"animations.{animation_name} must be object")
        validate_sheet(meta_path, animation_name, anim, frame_size)
    ok(f"all sheets validated for {meta_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate actor animation PNG sheets against meta.json.")
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
        validate_meta_sheets(meta_path)


if __name__ == "__main__":
    main()
