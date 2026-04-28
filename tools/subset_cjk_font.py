#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_FONT = PROJECT_ROOT / "assets" / "fonts" / "cjk_font.ttf"
TARGET_FONT = PROJECT_ROOT / "assets" / "fonts" / "cjk_font_runtime.ttf"
TEXT_SOURCES = ["scripts", "scenes", "data", "tables", "themes"]
TEXT_SUFFIXES = {".gd", ".tscn", ".json", ".tsv", ".tres", ".cfg"}
EXTRA_TEXT = (
    "大明之沧海嘀鸣军功清望旧案线索剧情战斗接敌继续返回胜利失败同归于尽"
    "长枪腰刀武官师父倭寇海边伏击渔村残火明制火器涂改军报押运官夜半磨刀"
    "破船军门压案海商宴欠饷营雨中信使报告掩盖私查借势潮声"
    "●◎○◆▶━━◇▣⚔☠♨？！，。；：“”‘’（）《》【】｜"
)


def collect_text() -> str:
    chunks: list[str] = [EXTRA_TEXT]
    for folder in TEXT_SOURCES:
        root = PROJECT_ROOT / folder
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if path.is_file() and path.suffix.lower() in TEXT_SUFFIXES:
                chunks.append(path.read_text(encoding="utf-8", errors="ignore"))
    return "\n".join(chunks)


def main() -> int:
    if not SOURCE_FONT.exists():
        print(f"[font-subset] ERROR: missing source font: {SOURCE_FONT}", file=sys.stderr)
        return 1
    text_path = PROJECT_ROOT / ".godot" / "cjk_runtime_subset_chars.txt"
    text_path.parent.mkdir(parents=True, exist_ok=True)
    text_path.write_text(collect_text(), encoding="utf-8")
    cmd = [
        sys.executable,
        "-m",
        "fontTools.subset",
        str(SOURCE_FONT),
        f"--output-file={TARGET_FONT}",
        f"--text-file={text_path}",
        "--unicodes=U+0020-007E,U+00A0,U+3000-303F,U+FF00-FFEF,U+2500-25FF,U+2600-26FF",
        "--layout-features=*",
        "--name-IDs=*",
        "--name-legacy",
        "--name-languages=*",
        "--recommended-glyphs",
        "--notdef-glyph",
        "--notdef-outline",
    ]
    subprocess.run(cmd, check=True)
    print(f"[font-subset] wrote {TARGET_FONT} ({TARGET_FONT.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
