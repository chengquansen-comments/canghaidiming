#!/usr/bin/env python3
from __future__ import annotations

import shutil
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
TARGET = PROJECT_ROOT / "assets" / "fonts" / "cjk_font.ttf"

# Keep this list to real .ttf files. Do not rename .ttc font collections to .ttf:
# Godot may see a file at the expected path but fail to embed/use the glyphs correctly on Web.
CANDIDATES = [
    Path("/System/Library/Fonts/Supplemental/Arial Unicode.ttf"),
    Path("/Library/Fonts/Arial Unicode.ttf"),
    Path.home() / "Library/Fonts/Arial Unicode.ttf",
    Path("/Library/Fonts/NotoSansSC-Regular.ttf"),
    Path.home() / "Library/Fonts/NotoSansSC-Regular.ttf",
    Path("/Library/Fonts/NotoSansCJKsc-Regular.ttf"),
    Path.home() / "Library/Fonts/NotoSansCJKsc-Regular.ttf",
    Path("/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttf"),
    Path("/usr/share/fonts/truetype/noto/NotoSansSC-Regular.ttf"),
]


def looks_like_ttf(path: Path) -> bool:
    with path.open("rb") as fh:
        magic = fh.read(4)
    return magic in (b"\x00\x01\x00\x00", b"true")


def main() -> None:
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    for source in CANDIDATES:
        if not source.exists() or not source.is_file():
            continue
        if not looks_like_ttf(source):
            print(f"[font] skip non-TTF candidate: {source}")
            continue
        shutil.copyfile(source, TARGET)
        print(f"[font] copied {source} -> {TARGET}")
        print("[font] rebuild the Web bundle after this step")
        return
    print("[font] ERROR: no real .ttf CJK font candidate found")
    print("[font] Please copy a Chinese-capable TRUE .ttf font to:")
    print(f"[font] {TARGET}")
    print("[font] Do not copy/rename .ttc collections such as PingFang.ttc to cjk_font.ttf.")
    print("[font] On macOS, try: /System/Library/Fonts/Supplemental/Arial Unicode.ttf")
    raise SystemExit(1)


if __name__ == "__main__":
    main()
