#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOTS = [ROOT / "art_reference" / "generated", ROOT / "art_reference" / "final"]
RUNTIME_ROOTS = [ROOT / "assets"]
REFERENCE_SCAN_ROOTS = [
    ROOT / "assets",
    ROOT / "data",
    ROOT / "docs",
    ROOT / "scripts",
    ROOT / "tables",
    ROOT / "tools",
]
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".psd", ".kra"}
TEXT_EXTENSIONS = {".gd", ".json", ".tsv", ".csv", ".md", ".txt", ".cfg"}
SOURCE_NAME_PATTERNS = [
    re.compile(r"(^|[_-])source($|[_-])", re.IGNORECASE),
    re.compile(r"(^|[_-])raw($|[_-])", re.IGNORECASE),
    re.compile(r"(^|/)ref[_-]", re.IGNORECASE),
]


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT))


def iter_files(roots: list[Path], extensions: set[str] | None = None):
    for root in roots:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            if extensions is None or path.suffix.lower() in extensions:
                yield path


def load_reference_text() -> str:
    chunks: list[str] = []
    for path in iter_files(REFERENCE_SCAN_ROOTS, TEXT_EXTENSIONS):
        try:
            chunks.append(path.read_text(encoding="utf-8", errors="ignore"))
        except OSError:
            pass
    return "\n".join(chunks)


def is_runtime_referenced(path: Path, reference_text: str) -> bool:
    relative = rel(path)
    res_path = f"res://{relative}"
    if res_path in reference_text or relative in reference_text:
        return True
    if "/sheets/" in relative:
        leaf = Path(relative).name
        return leaf in reference_text
    return False


def has_source_name(path: Path) -> bool:
    normalized = rel(path).replace("\\", "/")
    stem_path = str(Path(normalized).with_suffix(""))
    return any(pattern.search(stem_path) for pattern in SOURCE_NAME_PATTERNS)


def print_section(title: str, rows: list[str], limit: int = 80) -> None:
    print(f"\n## {title} ({len(rows)})")
    if not rows:
        print("- OK")
        return
    for row in rows[:limit]:
        print(f"- {row}")
    if len(rows) > limit:
        print(f"- ... {len(rows) - limit} more")


def main() -> int:
    source_images = sorted(rel(path) for path in iter_files(SOURCE_ROOTS, IMAGE_EXTENSIONS))
    runtime_images = sorted(path for path in iter_files(RUNTIME_ROOTS, IMAGE_EXTENSIONS))
    reference_text = load_reference_text()

    suspicious_runtime_sources = sorted(rel(path) for path in runtime_images if has_source_name(path))
    unreferenced_runtime = sorted(rel(path) for path in runtime_images if not is_runtime_referenced(path, reference_text))
    art_reference_imports = sorted(
        rel(path)
        for path in iter_files([ROOT / "art_reference"], None)
        if path.suffix.lower() in {".import", ".ctex", ".md5"}
    )
    pixel_battle_sources = [path for path in source_images if path.startswith("art_reference/final/pixel_battle/")]
    master_runtime = [
        rel(path)
        for path in runtime_images
        if "master_veteran" in rel(path) or "mentor" in rel(path)
    ]

    print("# Art Asset Structure Audit")
    print(f"source_images={len(source_images)} runtime_images={len(runtime_images)}")
    print_section("Pixel Battle Sources", pixel_battle_sources)
    print_section("Master Runtime Assets", master_runtime)
    print_section("Suspicious Source-Like Files Under assets", suspicious_runtime_sources)
    print_section("art_reference Godot Import Artifacts", art_reference_imports)
    print_section("Runtime Images Not Referenced By Text Scan", unreferenced_runtime, limit=120)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
