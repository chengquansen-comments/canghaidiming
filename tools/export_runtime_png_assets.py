#!/usr/bin/env python3
from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path
from typing import Iterable

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SIPS = Path("/usr/bin/sips")

RUNTIME_PATH_FILES = [
    Path("tables/narrative_mvp_node_status.tsv"),
    Path("tables/performance_timeline.tsv"),
    Path("tables/battle_scene_manifest.tsv"),
    Path("scripts/battle_controller_visual_scene_manifest.gd"),
    Path("scripts/narrative_demo_art_controller.gd"),
    Path("scripts/narrative_demo_canonical_controller.gd"),
    Path("scripts/narrative_demo_cinematic_controller.gd"),
    Path("scripts/narrative_demo_fragmented_controller.gd"),
    Path("scripts/narrative_demo_safe_controller.gd"),
    Path("scripts/narrative_demo_ui_focus_controller.gd"),
]

REFERENCE_EXPORTS = {
    "art_reference/generated/ref_night_knife_camp.png": ("assets/pixel_battle/backgrounds/narrative_night_knife_camp.png", (1280, 720), "cover"),
    "art_reference/generated/ref_old_master_saber.png": ("assets/narrative/props/prop_old_master_saber.png", (1024, 1024), "fit"),
    "art_reference/generated/ref_firearm_seal_mark.png": ("assets/narrative/props/prop_firearm_seal_mark.png", (1024, 1024), "fit"),
    "art_reference/generated/ref_half_roster_wet.png": ("assets/narrative/props/prop_half_roster_wet.png", (1024, 1024), "fit"),
    "art_reference/generated/ref_empty_wooden_case.png": ("assets/narrative/props/prop_empty_wooden_case.png", (1024, 1024), "fit"),
}


def main() -> int:
    if not SIPS.exists():
        raise SystemExit("Missing /usr/bin/sips; cannot export SVG runtime assets to PNG")

    svg_paths = sorted(_collect_runtime_svg_paths())
    for res_path in svg_paths:
        _export_svg_res_path(res_path)
    for source, export in REFERENCE_EXPORTS.items():
        _export_reference_png(ROOT / source, ROOT / export[0], export[1], export[2])
    _rewrite_runtime_paths()

    print(f"exported_png_from_svg={len(svg_paths)}")
    print(f"exported_png_from_reference={len(REFERENCE_EXPORTS)}")
    print(f"rewritten_files={len(RUNTIME_PATH_FILES)}")
    return 0


def _collect_runtime_svg_paths() -> set[str]:
    paths: set[str] = set()
    for relative_path in RUNTIME_PATH_FILES:
        path = ROOT / relative_path
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        for match in re.finditer(r"res://[^\s\"'\t]+?\.svg", text):
            paths.add(match.group(0))
    return paths


def _export_svg_res_path(res_path: str) -> None:
    source = ROOT / res_path.replace("res://", "", 1)
    if not source.exists():
        raise FileNotFoundError(f"Missing SVG source for runtime PNG export: {res_path}")
    target = source.with_suffix(".png")
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([str(SIPS), "-s", "format", "png", str(source), "--out", str(target)], check=True, stdout=subprocess.DEVNULL)
    print(f"{source.relative_to(ROOT)} -> {target.relative_to(ROOT)}")


def _export_reference_png(source: Path, target: Path, size: tuple[int, int], mode: str) -> None:
    if not source.exists():
        raise FileNotFoundError(f"Missing reference PNG: {source.relative_to(ROOT)}")
    target.parent.mkdir(parents=True, exist_ok=True)
    if mode == "copy":
        shutil.copyfile(source, target)
    else:
        image = Image.open(source).convert("RGBA")
        image = _resize_cover(image, size) if mode == "cover" else _resize_fit(image, size)
        image.save(target)
    print(f"{source.relative_to(ROOT)} -> {target.relative_to(ROOT)}")


def _resize_cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    width, height = size
    src_ratio = image.width / image.height
    dst_ratio = width / height
    if src_ratio > dst_ratio:
        new_height = height
        new_width = round(height * src_ratio)
    else:
        new_width = width
        new_height = round(width / src_ratio)
    resized = image.resize((new_width, new_height), Image.Resampling.LANCZOS)
    left = max(0, (new_width - width) // 2)
    top = max(0, (new_height - height) // 2)
    return resized.crop((left, top, left + width, top + height))


def _resize_fit(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    width, height = size
    copy = image.copy()
    copy.thumbnail(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    left = (width - copy.width) // 2
    top = (height - copy.height) // 2
    canvas.alpha_composite(copy, (left, top))
    return canvas


def _rewrite_runtime_paths() -> None:
    for relative_path in RUNTIME_PATH_FILES:
        path = ROOT / relative_path
        if not path.exists():
            continue
        original = path.read_text(encoding="utf-8")
        rewritten = re.sub(r"(res://[^\s\"'\t]+?)\.svg", r"\1.png", original)
        if rewritten != original:
            path.write_text(rewritten, encoding="utf-8")
            print(f"rewrote {relative_path}")


if __name__ == "__main__":
    raise SystemExit(main())
