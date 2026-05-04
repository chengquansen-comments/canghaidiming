#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


def fail(message: str) -> None:
    print(f"[sprite-anchor] ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def require_pillow():
    try:
        from PIL import Image, ImageDraw

        return Image, ImageDraw
    except Exception as exc:
        raise SystemExit(
            "[sprite-anchor] ERROR: Pillow is required.\n"
            "Run: python3 -m pip install pillow\n"
            f"Original error: {exc}"
        )


@dataclass(frozen=True)
class FrameSpec:
    index: int
    left: int
    top: int
    width: int
    height: int


@dataclass(frozen=True)
class AnchorResult:
    frame_index: int
    bbox: tuple[int, int, int, int] | None
    detected_anchor: tuple[int, int] | None
    target_anchor: tuple[int, int]
    shift: tuple[int, int]
    opaque_pixels: int


def parse_pair(value: str, name: str) -> tuple[int, int]:
    parts = [part.strip() for part in value.split(",")]
    if len(parts) != 2:
        fail(f"invalid {name}: {value}; expected X,Y")
    try:
        x = int(parts[0])
        y = int(parts[1])
    except ValueError:
        fail(f"invalid {name}: {value}; expected integer X,Y")
    return x, y


def parse_color(value: str) -> tuple[int, int, int] | None:
    raw = value.strip().lower()
    if raw in ("none", "alpha", "transparent", ""):
        return None
    if raw in ("green", "chroma", "chroma-green"):
        return (0, 255, 0)
    parts = [part.strip() for part in raw.split(",")]
    if len(parts) != 3:
        fail(f"invalid --background-color: {value}; use none, green, or R,G,B")
    try:
        color = tuple(int(part) for part in parts)
    except ValueError:
        fail(f"invalid --background-color: {value}; use none, green, or R,G,B")
    if any(channel < 0 or channel > 255 for channel in color):
        fail(f"background color channel outside 0..255: {value}")
    return color  # type: ignore[return-value]


def frame_specs(image_width: int, image_height: int, frame_width: int, frame_height: int, layout: str, frame_count: int) -> list[FrameSpec]:
    specs: list[FrameSpec] = []
    for index in range(frame_count):
        if layout == "vertical":
            left = 0
            top = index * frame_height
        elif layout == "horizontal":
            left = index * frame_width
            top = 0
        else:
            fail(f"invalid layout: {layout}; use vertical or horizontal")
        if left + frame_width > image_width or top + frame_height > image_height:
            fail(
                f"frame {index} is outside source image: frame={frame_width}x{frame_height}, "
                f"layout={layout}, source={image_width}x{image_height}"
            )
        specs.append(FrameSpec(index, left, top, frame_width, frame_height))
    return specs


def is_subject_pixel(rgba: tuple[int, int, int, int], background_color: tuple[int, int, int] | None, alpha_threshold: int, color_tolerance: int) -> bool:
    r, g, b, a = rgba
    if a <= alpha_threshold:
        return False
    if background_color is None:
        return True
    br, bg, bb = background_color
    return max(abs(r - br), abs(g - bg), abs(b - bb)) > color_tolerance


def iter_subject_pixels(frame, background_color: tuple[int, int, int] | None, alpha_threshold: int, color_tolerance: int) -> Iterable[tuple[int, int]]:
    px = frame.convert("RGBA").load()
    width, height = frame.size
    for y in range(height):
        for x in range(width):
            if is_subject_pixel(px[x, y], background_color, alpha_threshold, color_tolerance):
                yield x, y


def detect_subject_bbox(frame, background_color: tuple[int, int, int] | None, alpha_threshold: int, color_tolerance: int) -> tuple[tuple[int, int, int, int] | None, int]:
    min_x = frame.width
    min_y = frame.height
    max_x = -1
    max_y = -1
    count = 0
    for x, y in iter_subject_pixels(frame, background_color, alpha_threshold, color_tolerance):
        min_x = min(min_x, x)
        min_y = min(min_y, y)
        max_x = max(max_x, x)
        max_y = max(max_y, y)
        count += 1
    if count <= 0:
        return None, 0
    return (min_x, min_y, max_x, max_y), count


def detect_foot_anchor(frame, bbox: tuple[int, int, int, int], background_color: tuple[int, int, int] | None, alpha_threshold: int, color_tolerance: int, bottom_band: int) -> tuple[int, int]:
    min_x, _min_y, max_x, max_y = bbox
    band_top = max(0, max_y - max(1, bottom_band) + 1)
    xs: list[int] = []
    ys: list[int] = []
    px = frame.convert("RGBA").load()
    for y in range(band_top, max_y + 1):
        for x in range(min_x, max_x + 1):
            if is_subject_pixel(px[x, y], background_color, alpha_threshold, color_tolerance):
                xs.append(x)
                ys.append(y)
    if not xs:
        return ((min_x + max_x) // 2, max_y)
    xs.sort()
    anchor_x = xs[len(xs) // 2]
    anchor_y = max(ys) if ys else max_y
    return anchor_x, anchor_y


def paste_shifted_frame(Image, source_frame, frame_width: int, frame_height: int, shift: tuple[int, int], transparent_output: bool, background_color: tuple[int, int, int] | None):
    if transparent_output:
        output_frame = Image.new("RGBA", (frame_width, frame_height), (0, 0, 0, 0))
    else:
        bg = background_color if background_color is not None else (0, 0, 0)
        output_frame = Image.new("RGBA", (frame_width, frame_height), (bg[0], bg[1], bg[2], 255))
    output_frame.alpha_composite(source_frame.convert("RGBA"), shift)
    return output_frame


def normalize_sheet(
    source_path: Path,
    output_path: Path,
    frame_width: int,
    frame_height: int,
    frame_count: int,
    layout: str,
    target_anchor: tuple[int, int],
    background_color: tuple[int, int, int] | None,
    alpha_threshold: int,
    color_tolerance: int,
    bottom_band: int,
    transparent_output: bool,
):
    Image, _ImageDraw = require_pillow()
    image = Image.open(source_path).convert("RGBA")
    specs = frame_specs(image.width, image.height, frame_width, frame_height, layout, frame_count)
    output = Image.new("RGBA", image.size, (0, 0, 0, 0)) if transparent_output else Image.new("RGBA", image.size, (0, 255, 0, 255) if background_color is None else (*background_color, 255))
    results: list[AnchorResult] = []
    for spec in specs:
        frame = image.crop((spec.left, spec.top, spec.left + spec.width, spec.top + spec.height))
        bbox, count = detect_subject_bbox(frame, background_color, alpha_threshold, color_tolerance)
        if bbox is None:
            shifted = frame
            detected = None
            shift = (0, 0)
        else:
            detected = detect_foot_anchor(frame, bbox, background_color, alpha_threshold, color_tolerance, bottom_band)
            shift = (target_anchor[0] - detected[0], target_anchor[1] - detected[1])
            shifted = paste_shifted_frame(Image, frame, spec.width, spec.height, shift, transparent_output, background_color)
        output.alpha_composite(shifted, (spec.left, spec.top))
        results.append(AnchorResult(spec.index, bbox, detected, target_anchor, shift, count))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output.save(output_path)
    return output, specs, results


def draw_cross(draw, x: int, y: int, color: tuple[int, int, int, int], radius: int = 12) -> None:
    draw.line((x - radius, y, x + radius, y), fill=color, width=3)
    draw.line((x, y - radius, x, y + radius), fill=color, width=3)


def make_debug_preview(source_path: Path, output_image, specs: list[FrameSpec], results: list[AnchorResult], debug_path: Path) -> None:
    Image, ImageDraw = require_pillow()
    source = Image.open(source_path).convert("RGBA")
    gap = 24
    width = source.width + output_image.width + gap
    height = max(source.height, output_image.height)
    preview = Image.new("RGBA", (width, height), (26, 28, 32, 255))
    preview.alpha_composite(source, (0, 0))
    preview.alpha_composite(output_image.convert("RGBA"), (source.width + gap, 0))
    draw = ImageDraw.Draw(preview)
    draw.text((8, 8), "source: red=detected foot, yellow=bbox", fill=(255, 240, 180, 255))
    draw.text((source.width + gap + 8, 8), "normalized: blue=target foot", fill=(180, 220, 255, 255))
    result_by_index = {result.frame_index: result for result in results}
    for spec in specs:
        result = result_by_index.get(spec.index)
        draw.rectangle((spec.left, spec.top, spec.left + spec.width - 1, spec.top + spec.height - 1), outline=(100, 110, 120, 255), width=2)
        out_left = source.width + gap + spec.left
        draw.rectangle((out_left, spec.top, out_left + spec.width - 1, spec.top + spec.height - 1), outline=(100, 110, 120, 255), width=2)
        if result == None:
            continue
        if result.bbox != None:
            min_x, min_y, max_x, max_y = result.bbox
            draw.rectangle((spec.left + min_x, spec.top + min_y, spec.left + max_x, spec.top + max_y), outline=(255, 210, 80, 255), width=2)
        if result.detected_anchor != None:
            ax, ay = result.detected_anchor
            draw_cross(draw, spec.left + ax, spec.top + ay, (255, 70, 70, 255))
        tx, ty = result.target_anchor
        draw_cross(draw, out_left + tx, spec.top + ty, (80, 160, 255, 255))
        draw.text((spec.left + 8, spec.top + 28), f"#{spec.index} shift={result.shift}", fill=(255, 255, 255, 255))
        draw.text((out_left + 8, spec.top + 28), f"#{spec.index} target={result.target_anchor}", fill=(255, 255, 255, 255))
    debug_path.parent.mkdir(parents=True, exist_ok=True)
    preview.save(debug_path)


def write_manifest(manifest_path: Path, source_path: Path, output_path: Path, frame_width: int, frame_height: int, layout: str, results: list[AnchorResult]) -> None:
    manifest = {
        "source": str(source_path),
        "output": str(output_path),
        "frame_size": [frame_width, frame_height],
        "layout": layout,
        "frames": [
            {
                "index": result.frame_index,
                "detected_anchor": list(result.detected_anchor) if result.detected_anchor is not None else None,
                "target_anchor": list(result.target_anchor),
                "shift": list(result.shift),
                "bbox": list(result.bbox) if result.bbox is not None else None,
                "opaque_pixels": result.opaque_pixels,
            }
            for result in results
        ],
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def default_output_path(source_path: Path) -> Path:
    return source_path.with_name(f"{source_path.stem}_anchored{source_path.suffix}")


def default_debug_path(output_path: Path) -> Path:
    return Path("reports/sprite_anchor_preview") / f"{output_path.stem}_debug.png"


def default_manifest_path(output_path: Path) -> Path:
    return Path("reports/sprite_anchor_preview") / f"{output_path.stem}_anchors.json"


def main() -> None:
    parser = argparse.ArgumentParser(description="Normalize battle sprite sheets by aligning each frame to a shared detected foot anchor.")
    parser.add_argument("--source", required=True, type=Path, help="Input sprite sheet PNG.")
    parser.add_argument("--output", type=Path, help="Output normalized sheet PNG. Defaults to *_anchored.png beside source.")
    parser.add_argument("--frame-width", type=int, default=1536)
    parser.add_argument("--frame-height", type=int, default=512)
    parser.add_argument("--frame-count", type=int, default=3)
    parser.add_argument("--layout", choices=["vertical", "horizontal"], default="vertical")
    parser.add_argument("--target-anchor", default="768,492", help="Target foot anchor inside each frame, X,Y.")
    parser.add_argument("--background-color", default="none", help="none for alpha, green/chroma, or R,G,B.")
    parser.add_argument("--alpha-threshold", type=int, default=8)
    parser.add_argument("--color-tolerance", type=int, default=16)
    parser.add_argument("--bottom-band", type=int, default=24, help="Bottom pixel band used to estimate foot center from subject bbox.")
    parser.add_argument("--keep-background", action="store_true", help="Keep an opaque background in output instead of transparent canvas.")
    parser.add_argument("--debug-preview", type=Path, help="Debug preview image path. Defaults to reports/sprite_anchor_preview/*_debug.png")
    parser.add_argument("--manifest", type=Path, help="Anchor report JSON path. Defaults to reports/sprite_anchor_preview/*_anchors.json")
    args = parser.parse_args()

    if not args.source.exists():
        fail(f"source does not exist: {args.source}")
    output_path = args.output if args.output is not None else default_output_path(args.source)
    target_anchor = parse_pair(args.target_anchor, "--target-anchor")
    background_color = parse_color(args.background_color)
    output_image, specs, results = normalize_sheet(
        args.source,
        output_path,
        max(1, args.frame_width),
        max(1, args.frame_height),
        max(1, args.frame_count),
        args.layout,
        target_anchor,
        background_color,
        max(0, min(255, args.alpha_threshold)),
        max(0, args.color_tolerance),
        max(1, args.bottom_band),
        not args.keep_background,
    )
    debug_path = args.debug_preview if args.debug_preview is not None else default_debug_path(output_path)
    manifest_path = args.manifest if args.manifest is not None else default_manifest_path(output_path)
    make_debug_preview(args.source, output_image, specs, results, debug_path)
    write_manifest(manifest_path, args.source, output_path, max(1, args.frame_width), max(1, args.frame_height), args.layout, results)
    print(f"[sprite-anchor] OK: {args.source} -> {output_path}")
    print(f"[sprite-anchor] debug: {debug_path}")
    print(f"[sprite-anchor] manifest: {manifest_path}")
    for result in results:
        print(
            f"[sprite-anchor] frame={result.frame_index} detected={result.detected_anchor} "
            f"target={result.target_anchor} shift={result.shift} pixels={result.opaque_pixels}"
        )


if __name__ == "__main__":
    main()
