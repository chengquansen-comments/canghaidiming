#!/usr/bin/env python3
from __future__ import annotations

import argparse
import statistics
import sys
from pathlib import Path

from alpha_matte_cleanup import clean_alpha_matte


def fail(message: str) -> None:
    print(f"[normalize-actor-sheet] ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def require_pillow():
    try:
        from PIL import Image

        return Image
    except Exception as exc:
        raise SystemExit(
            "[normalize-actor-sheet] ERROR: Pillow is required.\n"
            "Run: python3 -m pip install pillow\n"
            f"Original error: {exc}"
        )


def alpha_bbox(image, threshold: int):
    alpha = image.getchannel("A")
    return alpha.point(lambda value: 255 if value > threshold else 0).getbbox()


def estimate_foot_anchor(image, threshold: int) -> tuple[float, float]:
    bbox = alpha_bbox(image, threshold)
    if bbox is None:
        fail("source frame appears fully transparent")
    left, top, right, bottom = bbox
    alpha = image.getchannel("A")
    sample_top = max(top, bottom - max(8, int((bottom - top) * 0.18)))
    xs: list[int] = []
    ys: list[int] = []
    for y in range(sample_top, bottom):
        for x in range(left, right):
            if alpha.getpixel((x, y)) > threshold:
                xs.append(x)
                ys.append(y)
    if not xs:
        return ((left + right) * 0.5, float(bottom))
    return (float(statistics.median(xs)), float(max(ys)))


def normalize_sheet(
    source: Path,
    output: Path,
    frames: int,
    output_frame_width: int,
    output_frame_height: int,
    target_foot_x: float,
    target_foot_y: float,
    alpha_threshold: int,
    source_frame_width: int | None,
    source_frame_height: int | None,
    cleanup_alpha: bool,
    cleanup_background: str,
) -> None:
    Image = require_pillow()
    image = Image.open(source).convert("RGBA")
    image.load()
    if cleanup_alpha:
        image = clean_alpha_matte(image, background=cleanup_background)
    if image.width <= 0 or image.height <= 0:
        fail(f"invalid source size: {image.size}")
    if source_frame_width is None:
        if image.width % frames != 0:
            fail(f"source width {image.width} is not divisible by frames={frames}; pass --source-frame-width")
        source_frame_width = image.width // frames
    if source_frame_height is None:
        source_frame_height = image.height
    if source_frame_width <= 0 or source_frame_height <= 0:
        fail("source frame size must be positive")

    sheet = Image.new("RGBA", (output_frame_width * frames, output_frame_height), (0, 0, 0, 0))
    for index in range(frames):
        source_left = index * source_frame_width
        frame = image.crop((source_left, 0, source_left + source_frame_width, source_frame_height))
        bbox = alpha_bbox(frame, alpha_threshold)
        if bbox is None:
            print(f"[normalize-actor-sheet] WARN: frame {index} is transparent; keeping empty frame")
            continue
        foot_x, foot_y = estimate_foot_anchor(frame, alpha_threshold)
        scale = min(
            output_frame_width / float(source_frame_width),
            output_frame_height / float(source_frame_height),
            1.0,
        )
        if scale != 1.0:
            new_size = (max(1, int(round(frame.width * scale))), max(1, int(round(frame.height * scale))))
            frame = frame.resize(new_size, Image.Resampling.LANCZOS)
            foot_x *= scale
            foot_y *= scale
        paste_x = int(round(index * output_frame_width + target_foot_x - foot_x))
        paste_y = int(round(target_foot_y - foot_y))
        sheet.alpha_composite(frame, (paste_x, paste_y))

    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)
    print(
        "[normalize-actor-sheet] OK: "
        f"{source} -> {output} frames={frames} frame={output_frame_width}x{output_frame_height} "
        f"foot=({target_foot_x:.1f},{target_foot_y:.1f})"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Normalize horizontal actor sheets to fixed frame size and foot anchor.")
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--frames", type=int, default=3)
    parser.add_argument("--frame-width", type=int, default=1536)
    parser.add_argument("--frame-height", type=int, default=512)
    parser.add_argument("--foot-x", type=float, default=560.0)
    parser.add_argument("--foot-y", type=float, default=492.0)
    parser.add_argument("--alpha-threshold", type=int, default=8)
    parser.add_argument("--source-frame-width", type=int)
    parser.add_argument("--source-frame-height", type=int)
    parser.add_argument("--cleanup-alpha", action="store_true", help="Remove a non-transparent matte background and clean fringes.")
    parser.add_argument("--cleanup-background", default="auto", help="auto, light, or R,G,B; used with --cleanup-alpha.")
    parser.add_argument("--remove-light-background", action="store_true", help="Deprecated alias for --cleanup-alpha --cleanup-background light.")
    args = parser.parse_args()
    cleanup_alpha = args.cleanup_alpha or args.remove_light_background
    cleanup_background = "light" if args.remove_light_background and not args.cleanup_alpha else args.cleanup_background

    normalize_sheet(
        args.source,
        args.output,
        args.frames,
        args.frame_width,
        args.frame_height,
        args.foot_x,
        args.foot_y,
        args.alpha_threshold,
        args.source_frame_width,
        args.source_frame_height,
        cleanup_alpha,
        cleanup_background,
    )


if __name__ == "__main__":
    main()
