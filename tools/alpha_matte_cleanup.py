#!/usr/bin/env python3
from __future__ import annotations

import argparse
import math
import statistics
import sys
from pathlib import Path
from typing import Iterable


def fail(message: str) -> None:
    print(f"[alpha-cleanup] ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def require_pillow():
    try:
        from PIL import Image, ImageChops, ImageFilter

        return Image, ImageChops, ImageFilter
    except Exception as exc:
        raise SystemExit(
            "[alpha-cleanup] ERROR: Pillow is required.\n"
            "Run: python3 -m pip install pillow\n"
            f"Original error: {exc}"
        )


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _parse_color(value: str) -> tuple[int, int, int] | None:
    raw = value.strip().lower()
    if raw in ("auto", ""):
        return None
    if raw in ("light", "white", "checker"):
        return (245, 245, 245)
    parts = [part.strip() for part in raw.split(",")]
    if len(parts) != 3:
        fail(f"invalid --background value: {value}; use auto, light, or R,G,B")
    try:
        color = tuple(int(part) for part in parts)
    except ValueError:
        fail(f"invalid --background value: {value}; use auto, light, or R,G,B")
    if any(channel < 0 or channel > 255 for channel in color):
        fail(f"background color channel outside 0..255: {value}")
    return color  # type: ignore[return-value]


def _edge_pixels(image, sample_width: int) -> Iterable[tuple[int, int, int]]:
    width, height = image.size
    px = image.convert("RGB").load()
    border = max(1, min(sample_width, width // 2, height // 2))
    for y in range(height):
        for x in range(border):
            yield px[x, y]
            yield px[width - 1 - x, y]
    for x in range(width):
        for y in range(border):
            yield px[x, y]
            yield px[x, height - 1 - y]


def estimate_background_color(image, sample_width: int = 8) -> tuple[int, int, int]:
    samples = list(_edge_pixels(image, sample_width))
    if not samples:
        return (245, 245, 245)
    channels = list(zip(*samples))
    return tuple(int(round(statistics.median(channel))) for channel in channels)  # type: ignore[return-value]


def _color_distance(rgb: tuple[int, int, int], bg: tuple[int, int, int]) -> float:
    return math.sqrt(sum((float(rgb[i]) - float(bg[i])) ** 2 for i in range(3)))


def _matte_alpha(distance: float, transparent_distance: float, opaque_distance: float) -> int:
    if distance <= transparent_distance:
        return 0
    if distance >= opaque_distance:
        return 255
    value = (distance - transparent_distance) / max(1.0, opaque_distance - transparent_distance)
    value = value * value * (3.0 - 2.0 * value)
    return int(round(_clamp(value, 0.0, 1.0) * 255.0))


def _decontaminate_channel(channel: int, bg_channel: int, alpha: int, strength: float) -> int:
    if alpha <= 0:
        return 0
    if strength <= 0:
        return channel
    a = _clamp(alpha / 255.0, 0.01, 1.0)
    unmatte = (float(channel) - float(bg_channel) * (1.0 - a)) / a
    mixed = float(channel) * (1.0 - strength) + unmatte * strength
    return int(round(_clamp(mixed, 0.0, 255.0)))


def clean_alpha_matte(
    image,
    background: str | tuple[int, int, int] | None = "auto",
    transparent_distance: float = 28.0,
    opaque_distance: float = 84.0,
    choke: int = 1,
    feather: float = 0.45,
    despill: float = 0.85,
    sample_width: int = 8,
    edge_dehalo: bool = True,
    edge_light_threshold: int = 190,
    edge_alpha_threshold: int = 245,
    fill_alpha_holes: bool = False,
    max_hole_area: int = 700,
    hole_alpha_threshold: int = 8,
):
    Image, ImageChops, ImageFilter = require_pillow()
    source = image.convert("RGBA")
    if isinstance(background, tuple):
        bg_color = background
    else:
        parsed = _parse_color("auto" if background is None else str(background))
        bg_color = parsed if parsed is not None else estimate_background_color(source, sample_width)

    width, height = source.size
    source_px = source.load()
    alpha_mask = Image.new("L", (width, height), 0)
    alpha_px = alpha_mask.load()
    for y in range(height):
        for x in range(width):
            r, g, b, a = source_px[x, y]
            if a == 0:
                alpha_px[x, y] = 0
                continue
            distance = _color_distance((r, g, b), bg_color)
            matte_a = _matte_alpha(distance, transparent_distance, opaque_distance)
            alpha_px[x, y] = min(a, matte_a)

    if choke > 0:
        for _ in range(choke):
            alpha_mask = alpha_mask.filter(ImageFilter.MinFilter(3))
    if feather > 0:
        alpha_mask = alpha_mask.filter(ImageFilter.GaussianBlur(radius=feather))

    result = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    result_px = result.load()
    alpha_px = alpha_mask.load()
    for y in range(height):
        for x in range(width):
            r, g, b, _ = source_px[x, y]
            out_a = int(alpha_px[x, y])
            if out_a <= 0:
                result_px[x, y] = (0, 0, 0, 0)
                continue
            out_r = _decontaminate_channel(r, bg_color[0], out_a, despill)
            out_g = _decontaminate_channel(g, bg_color[1], out_a, despill)
            out_b = _decontaminate_channel(b, bg_color[2], out_a, despill)
            result_px[x, y] = (out_r, out_g, out_b, out_a)
    if edge_dehalo:
        result = remove_one_pixel_light_halo(result, edge_light_threshold, edge_alpha_threshold)
    if fill_alpha_holes:
        result = fill_internal_alpha_holes(result, max_hole_area, hole_alpha_threshold)
    return result


def remove_one_pixel_light_halo(image, light_threshold: int = 190, alpha_threshold: int = 245):
    """Drop light neutral fringe pixels that touch fully transparent space."""
    source = image.convert("RGBA")
    width, height = source.size
    src = source.load()
    out = source.copy()
    dst = out.load()
    for y in range(height):
        for x in range(width):
            r, g, b, a = src[x, y]
            if a <= 0 or a > alpha_threshold:
                continue
            if min(r, g, b) < light_threshold or max(r, g, b) - min(r, g, b) > 48:
                continue
            touches_transparent = False
            for yy in range(max(0, y - 1), min(height, y + 2)):
                for xx in range(max(0, x - 1), min(width, x + 2)):
                    if xx == x and yy == y:
                        continue
                    if src[xx, yy][3] == 0:
                        touches_transparent = True
                        break
                if touches_transparent:
                    break
            if touches_transparent:
                dst[x, y] = (0, 0, 0, 0)
    return out


def fill_internal_alpha_holes(image, max_hole_area: int = 700, alpha_threshold: int = 8):
    """Repair small transparent pinholes inside a subject without filling the outside background."""
    source = image.convert("RGBA")
    width, height = source.size
    px = source.load()
    transparent = bytearray(width * height)
    for y in range(height):
        row = y * width
        for x in range(width):
            if px[x, y][3] <= alpha_threshold:
                transparent[row + x] = 1

    outside = bytearray(width * height)
    stack: list[int] = []

    def push_if_transparent(index: int) -> None:
        if transparent[index] and not outside[index]:
            outside[index] = 1
            stack.append(index)

    for x in range(width):
        push_if_transparent(x)
        push_if_transparent((height - 1) * width + x)
    for y in range(height):
        push_if_transparent(y * width)
        push_if_transparent(y * width + width - 1)

    while stack:
        index = stack.pop()
        x = index % width
        y = index // width
        if x > 0:
            push_if_transparent(index - 1)
        if x + 1 < width:
            push_if_transparent(index + 1)
        if y > 0:
            push_if_transparent(index - width)
        if y + 1 < height:
            push_if_transparent(index + width)

    visited = bytearray(width * height)
    hole_indices: list[int] = []
    for start in range(width * height):
        if not transparent[start] or outside[start] or visited[start]:
            continue
        component: list[int] = []
        visited[start] = 1
        stack = [start]
        while stack:
            index = stack.pop()
            component.append(index)
            x = index % width
            y = index // width
            neighbors = []
            if x > 0:
                neighbors.append(index - 1)
            if x + 1 < width:
                neighbors.append(index + 1)
            if y > 0:
                neighbors.append(index - width)
            if y + 1 < height:
                neighbors.append(index + width)
            for neighbor in neighbors:
                if transparent[neighbor] and not outside[neighbor] and not visited[neighbor]:
                    visited[neighbor] = 1
                    stack.append(neighbor)
        if max_hole_area <= 0 or len(component) <= max_hole_area:
            hole_indices.extend(component)

    if not hole_indices:
        return source

    remaining = set(hole_indices)
    out = source.copy()
    out_px = out.load()
    while remaining:
        changed: list[tuple[int, tuple[int, int, int, int]]] = []
        for index in list(remaining):
            x = index % width
            y = index // width
            samples: list[tuple[int, int, int, int]] = []
            for yy in range(max(0, y - 1), min(height, y + 2)):
                for xx in range(max(0, x - 1), min(width, x + 2)):
                    neighbor = yy * width + xx
                    if neighbor == index or neighbor in remaining:
                        continue
                    nr, ng, nb, na = out_px[xx, yy]
                    if na > alpha_threshold:
                        samples.append((nr, ng, nb, na))
            if not samples:
                continue
            count = len(samples)
            r = round(sum(sample[0] for sample in samples) / count)
            g = round(sum(sample[1] for sample in samples) / count)
            b = round(sum(sample[2] for sample in samples) / count)
            a = max(sample[3] for sample in samples)
            changed.append((index, (r, g, b, a)))
        if not changed:
            break
        for index, value in changed:
            x = index % width
            y = index // width
            out_px[x, y] = value
            remaining.remove(index)
    return out


def repair_dark_pinholes(image, max_area: int = 36, black_threshold: int = 10, alpha_threshold: int = 180):
    """Replace tiny pure-black artifacts inside painted figures with nearby colors."""
    source = image.convert("RGBA")
    width, height = source.size
    px = source.load()
    mask = bytearray(width * height)
    for y in range(height):
        row = y * width
        for x in range(width):
            r, g, b, a = px[x, y]
            if a >= alpha_threshold and max(r, g, b) <= black_threshold:
                mask[row + x] = 1

    visited = bytearray(width * height)
    target_indices: list[int] = []
    for start in range(width * height):
        if not mask[start] or visited[start]:
            continue
        component: list[int] = []
        stack = [start]
        visited[start] = 1
        touches_border = False
        while stack:
            index = stack.pop()
            component.append(index)
            x = index % width
            y = index // width
            if x == 0 or y == 0 or x == width - 1 or y == height - 1:
                touches_border = True
            neighbors = []
            if x > 0:
                neighbors.append(index - 1)
            if x + 1 < width:
                neighbors.append(index + 1)
            if y > 0:
                neighbors.append(index - width)
            if y + 1 < height:
                neighbors.append(index + width)
            for neighbor in neighbors:
                if mask[neighbor] and not visited[neighbor]:
                    visited[neighbor] = 1
                    stack.append(neighbor)
        if not touches_border and len(component) <= max_area:
            target_indices.extend(component)

    if not target_indices:
        return source

    remaining = set(target_indices)
    out = source.copy()
    out_px = out.load()
    while remaining:
        changed: list[tuple[int, tuple[int, int, int, int]]] = []
        for index in list(remaining):
            x = index % width
            y = index // width
            samples: list[tuple[int, int, int, int]] = []
            for yy in range(max(0, y - 1), min(height, y + 2)):
                for xx in range(max(0, x - 1), min(width, x + 2)):
                    neighbor = yy * width + xx
                    if neighbor == index or neighbor in remaining:
                        continue
                    nr, ng, nb, na = out_px[xx, yy]
                    if na >= alpha_threshold and max(nr, ng, nb) > black_threshold:
                        samples.append((nr, ng, nb, na))
            if not samples:
                continue
            count = len(samples)
            r = round(sum(sample[0] for sample in samples) / count)
            g = round(sum(sample[1] for sample in samples) / count)
            b = round(sum(sample[2] for sample in samples) / count)
            a = round(sum(sample[3] for sample in samples) / count)
            changed.append((index, (r, g, b, a)))
        if not changed:
            break
        for index, value in changed:
            x = index % width
            y = index // width
            out_px[x, y] = value
            remaining.remove(index)
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description="Remove light/non-transparent matte backgrounds and clean alpha fringes.")
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--background", default="auto", help="auto, light, or R,G,B")
    parser.add_argument("--transparent-distance", type=float, default=28.0)
    parser.add_argument("--opaque-distance", type=float, default=84.0)
    parser.add_argument("--choke", type=int, default=1, help="Shrink alpha edge by N pixels before feathering.")
    parser.add_argument("--feather", type=float, default=0.45)
    parser.add_argument("--despill", type=float, default=0.85)
    parser.add_argument("--sample-width", type=int, default=8)
    parser.add_argument("--no-edge-dehalo", action="store_true", help="Disable one-pixel light halo removal.")
    parser.add_argument("--edge-light-threshold", type=int, default=190)
    parser.add_argument("--edge-alpha-threshold", type=int, default=245)
    parser.add_argument("--fill-alpha-holes", action="store_true", help="Fill small fully transparent pinholes inside the subject.")
    parser.add_argument("--max-hole-area", type=int, default=700, help="Maximum transparent component area to repair; 0 repairs all enclosed holes.")
    parser.add_argument("--hole-alpha-threshold", type=int, default=8)
    parser.add_argument("--repair-alpha-holes-only", action="store_true", help="Skip matte cleanup and only repair internal alpha pinholes.")
    parser.add_argument("--repair-dark-pinholes", action="store_true", help="Repair tiny pure-black speck artifacts after alpha cleanup.")
    parser.add_argument("--repair-dark-pinholes-only", action="store_true", help="Skip matte cleanup and only repair tiny pure-black specks.")
    parser.add_argument("--max-dark-pinhole-area", type=int, default=36)
    parser.add_argument("--dark-pinhole-threshold", type=int, default=10)
    args = parser.parse_args()

    Image, _, _ = require_pillow()
    image = Image.open(args.source)
    if args.repair_alpha_holes_only:
        cleaned = fill_internal_alpha_holes(
            image,
            max_hole_area=max(0, args.max_hole_area),
            alpha_threshold=max(0, min(255, args.hole_alpha_threshold)),
        )
    elif args.repair_dark_pinholes_only:
        cleaned = repair_dark_pinholes(
            image,
            max_area=max(0, args.max_dark_pinhole_area),
            black_threshold=max(0, min(255, args.dark_pinhole_threshold)),
        )
    else:
        cleaned = clean_alpha_matte(
            image,
            background=args.background,
            transparent_distance=args.transparent_distance,
            opaque_distance=args.opaque_distance,
            choke=max(0, args.choke),
            feather=max(0.0, args.feather),
            despill=_clamp(args.despill, 0.0, 1.0),
            sample_width=max(1, args.sample_width),
            edge_dehalo=not args.no_edge_dehalo,
            edge_light_threshold=max(0, min(255, args.edge_light_threshold)),
            edge_alpha_threshold=max(0, min(255, args.edge_alpha_threshold)),
            fill_alpha_holes=args.fill_alpha_holes,
            max_hole_area=max(0, args.max_hole_area),
            hole_alpha_threshold=max(0, min(255, args.hole_alpha_threshold)),
        )
        if args.repair_dark_pinholes:
            cleaned = repair_dark_pinholes(
                cleaned,
                max_area=max(0, args.max_dark_pinhole_area),
                black_threshold=max(0, min(255, args.dark_pinhole_threshold)),
            )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    cleaned.save(args.output)
    print(f"[alpha-cleanup] OK: {args.source} -> {args.output} size={cleaned.width}x{cleaned.height}")


if __name__ == "__main__":
    main()
