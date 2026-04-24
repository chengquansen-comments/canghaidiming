#!/usr/bin/env python3
from __future__ import annotations

import shutil
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
TARGET = PROJECT_ROOT / "assets" / "fonts" / "cjk_font.ttf"

CANDIDATES = [
    Path("/System/Library/Fonts/PingFang.ttc"),
    Path("/System/Library/Fonts/STHeiti Light.ttc"),
    Path("/System/Library/Fonts/STHeiti Medium.ttc"),
    Path("/Library/Fonts/Arial Unicode.ttf"),
    Path("/Library/Fonts/NotoSansCJKsc-Regular.otf"),
    Path("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"),
    Path("/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc"),
]


def main() -> None:
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    for source in CANDIDATES:
        if source.exists() and source.is_file():
            shutil.copyfile(source, TARGET)
            print(f"[font] copied {source} -> {TARGET}")
            print("[font] rebuild the Web bundle after this step")
            return
    print("[font] ERROR: no local CJK font candidate found")
    print("[font] Please copy a Chinese-capable .ttf/.otf/.ttc font to:")
    print(f"[font] {TARGET}")
    raise SystemExit(1)


if __name__ == "__main__":
    main()
