#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

REQUIRED_SAMPLE = "沧海嘀鸣师门决斗清风剑阁重选招式确认出招伤害格挡势力消耗范围详情"


def read_font_magic(path: Path) -> bytes:
    with path.open("rb") as fh:
        return fh.read(4)


def require_supported_font_container(path: Path) -> None:
    magic = read_font_magic(path)
    supported = {
        b"\x00\x01\x00\x00": "TrueType",
        b"OTTO": "OpenType CFF",
        b"true": "Apple TrueType",
    }
    if magic in supported:
        print(f"[font-check] container: {supported[magic]}")
        return
    if magic == b"ttcf":
        raise SystemExit(
            "[font-check] ERROR: font is a TTC collection. Do not rename .ttc to .ttf for Web builds. "
            "Use a real .ttf/.otf such as NotoSansSC-Regular.ttf."
        )
    raise SystemExit(f"[font-check] ERROR: unsupported font container magic={magic!r}")


def require_glyph_coverage(path: Path, sample: str) -> None:
    try:
        from fontTools.ttLib import TTFont
    except Exception as exc:
        raise SystemExit(
            "[font-check] ERROR: fontTools is required for strict glyph validation.\n"
            "Run: python3 -m pip install fonttools\n"
            f"Original error: {exc}"
        )

    font = TTFont(str(path), fontNumber=0)
    cmap: set[int] = set()
    for table in font["cmap"].tables:
        cmap.update(table.cmap.keys())
    missing = sorted({ch for ch in sample if ord(ch) not in cmap})
    if missing:
        missing_text = "".join(missing)
        raise SystemExit(
            "[font-check] ERROR: font file exists but does not contain required CJK glyphs.\n"
            f"[font-check] Missing glyphs: {missing_text}\n"
            "[font-check] Use a real Simplified Chinese font such as NotoSansSC-Regular.ttf or SourceHanSansSC-Regular.otf."
        )
    print(f"[font-check] glyph coverage OK for {len(set(sample))} required chars")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("font", nargs="?", default="assets/fonts/cjk_font_runtime.ttf")
    parser.add_argument("--sample", default=REQUIRED_SAMPLE)
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    path = (root / args.font).resolve()
    if not path.exists() or not path.is_file():
        raise SystemExit(f"[font-check] ERROR: missing font file: {path}")
    if path.stat().st_size < 1024 * 64:
        raise SystemExit(f"[font-check] ERROR: font file is suspiciously small: {path.stat().st_size} bytes")

    print(f"[font-check] checking: {path}")
    require_supported_font_container(path)
    require_glyph_coverage(path, args.sample)
    print("[font-check] CJK font validation passed")


if __name__ == "__main__":
    main()
