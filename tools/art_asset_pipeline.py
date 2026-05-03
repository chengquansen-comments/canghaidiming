#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import re
import sys
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
TABLES_DIR = ROOT / "tables"
MANIFEST_PATH = TABLES_DIR / "art_asset_manifest.tsv"
STATUS_ORDER = [
    "PROMPT_READY",
    "SOURCE_READY",
    "EXPORTED",
    "WIRED",
    "COMPILED",
    "GODOT_IMPORTED",
    "IN_GAME_CHECKED",
]


@dataclass(frozen=True)
class ExportProfile:
    asset_type: str
    size: tuple[int, int]
    mode: str


@dataclass(frozen=True)
class AssetTypeSpec:
    asset_type: str
    size: tuple[int, int]
    mode: str
    hook_table: str
    hook_key_field: str
    hook_field: str
    prompt_renderer: str | None


@dataclass(frozen=True)
class HookSpec:
    table_path: str
    compiled_json: str
    compiled_root_key: str | None
    scan_fields: tuple[str, ...]


ASSET_TYPE_SPECS = {
    "battle_background": AssetTypeSpec(
        "battle_background",
        (1280, 720),
        "cover",
        "tables/battle_scene_manifest.tsv",
        "id",
        "background",
        "battle_background",
    ),
    "narrative_background": AssetTypeSpec(
        "narrative_background",
        (1280, 720),
        "cover",
        "tables/narrative_mvp_node_status.tsv",
        "id",
        "visual_path",
        "narrative_background",
    ),
    "narrative_prop": AssetTypeSpec(
        "narrative_prop",
        (1024, 1024),
        "fit",
        "tables/performance_timeline.tsv",
        "track_id",
        "prop_path",
        "narrative_prop",
    ),
    "battle_portrait": AssetTypeSpec(
        "battle_portrait",
        (1024, 1024),
        "cover",
        "",
        "",
        "",
        "battle_portrait",
    ),
    "battle_action_sheet": AssetTypeSpec(
        "battle_action_sheet",
        (1536, 1536),
        "fit",
        "",
        "",
        "",
        "battle_action_sheet",
    ),
    "performance_portrait": AssetTypeSpec(
        "performance_portrait",
        (360, 520),
        "cover",
        "tables/performance_timeline.tsv",
        "track_id",
        "prop_path",
        None,
    ),
}

HOOK_SPECS = {
    "tables/battle_scene_manifest.tsv": HookSpec(
        "tables/battle_scene_manifest.tsv",
        "data/battle_scene_manifest.json",
        None,
        ("background",),
    ),
    "tables/narrative_mvp_node_status.tsv": HookSpec(
        "tables/narrative_mvp_node_status.tsv",
        "data/narrative_mvp_nodes.json",
        "node_status",
        ("visual_path",),
    ),
    "tables/performance_timeline.tsv": HookSpec(
        "tables/performance_timeline.tsv",
        "data/performance_tracks.json",
        "timeline",
        ("prop_path", "prop2_path", "prop3_path"),
    ),
}


def require_pillow():
    try:
        from PIL import Image

        return Image
    except Exception as exc:
        raise SystemExit(
            "[art-asset-pipeline] ERROR: Pillow is required.\n"
            "Run: python3 -m pip install pillow\n"
            f"Original error: {exc}"
        )


Image = require_pillow()
try:
    from alpha_matte_cleanup import clean_alpha_matte
except ModuleNotFoundError:
    from tools.alpha_matte_cleanup import clean_alpha_matte


CHROMA_KEY_ASSET_TYPES = {"battle_action_sheet", "battle_portrait"}
CHROMA_KEY_COLOR = (0, 255, 0)


def fail(message: str) -> None:
    print(f"[art-asset-pipeline] ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def ok(message: str) -> None:
    print(f"[art-asset-pipeline] OK: {message}")


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT))


def normalize_repo_path(raw_path: str) -> Path:
    path = Path(raw_path.strip())
    if str(path) == "":
        fail("encountered empty repo path")
    return path if path.is_absolute() else ROOT / path


def to_res_path(path: Path) -> str:
    return f"res://{path.relative_to(ROOT).as_posix()}"


def detect_delimiter(path: Path) -> str:
    return "\t" if path.suffix.lower() == ".tsv" else ","


def read_delimited(path: Path) -> tuple[list[str], list[dict[str, str]], str]:
    delimiter = detect_delimiter(path)
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle, delimiter=delimiter)
        fieldnames = [str(name).strip() for name in (reader.fieldnames or [])]
        rows: list[dict[str, str]] = []
        for row in reader:
            cleaned = {str(key).strip(): (value or "").strip() for key, value in row.items() if key is not None}
            if any(value != "" for value in cleaned.values()):
                rows.append(cleaned)
        return fieldnames, rows, delimiter


def write_delimited(path: Path, fieldnames: list[str], rows: list[dict[str, str]], delimiter: str) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter=delimiter, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in fieldnames})


def load_manifest() -> tuple[list[str], list[dict[str, str]], str]:
    if not MANIFEST_PATH.exists():
        fail(f"missing manifest: {rel(MANIFEST_PATH)}")
    return read_delimited(MANIFEST_PATH)


def get_manifest_entry(asset_id: str) -> tuple[list[str], list[dict[str, str]], int, dict[str, str], str]:
    fieldnames, rows, delimiter = load_manifest()
    for index, row in enumerate(rows):
        if row.get("asset_id", "") == asset_id:
            return fieldnames, rows, index, row, delimiter
    fail(f"asset_id not found in {rel(MANIFEST_PATH)}: {asset_id}")


def save_manifest(fieldnames: list[str], rows: list[dict[str, str]], delimiter: str) -> None:
    write_delimited(MANIFEST_PATH, fieldnames, rows, delimiter)


def status_rank(status: str) -> int:
    return STATUS_ORDER.index(status) if status in STATUS_ORDER else -1


def advance_status(current: str, target: str) -> str:
    if status_rank(target) > status_rank(current):
        return target
    return current


def update_manifest_status(asset_id: str, target_status: str) -> tuple[str, str]:
    fieldnames, rows, index, row, delimiter = get_manifest_entry(asset_id)
    current = row.get("status", "").strip()
    updated = advance_status(current, target_status)
    rows[index]["status"] = updated
    save_manifest(fieldnames, rows, delimiter)
    return current, updated


def get_asset_type_spec(asset_type: str) -> AssetTypeSpec:
    spec = ASSET_TYPE_SPECS.get(asset_type)
    if spec is None:
        supported = ", ".join(sorted(ASSET_TYPE_SPECS))
        fail(f"unsupported asset type '{asset_type}'. Supported: {supported}")
    return spec


def get_export_profile(asset_type: str) -> ExportProfile:
    spec = get_asset_type_spec(asset_type)
    return ExportProfile(spec.asset_type, spec.size, spec.mode)


def get_hook_spec(table_path: str) -> HookSpec:
    spec = HOOK_SPECS.get(table_path)
    if spec is None:
        supported = ", ".join(sorted(HOOK_SPECS))
        fail(f"unsupported hook table for compiled validation: {table_path}. Supported: {supported}")
    return spec


def resize_cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_w, target_h = size
    scale = max(target_w / image.width, target_h / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    left = max(0, (resized.width - target_w) // 2)
    top = max(0, (resized.height - target_h) // 2)
    return resized.crop((left, top, left + target_w, top + target_h))


def resize_fit(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_w, target_h = size
    scale = min(target_w / image.width, target_h / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    left = (target_w - resized.width) // 2
    top = (target_h - resized.height) // 2
    canvas.alpha_composite(resized, (left, top))
    return canvas


def is_greenish_pixel(rgb: tuple[int, int, int], green_floor: int = 120, gap: int = 28) -> bool:
    r, g, b = rgb
    return g >= green_floor and (g - r) >= gap and (g - b) >= gap


def normalize_battle_portrait_chroma_background(source: Image.Image) -> Image.Image:
    """Stabilize model variance by snapping border-connected greenish background to pure #00FF00."""
    image = source.convert("RGBA")
    width, height = image.size
    px = image.load()
    visited = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def enqueue_if_bg(x: int, y: int) -> None:
        idx = y * width + x
        if visited[idx]:
            return
        visited[idx] = 1
        r, g, b, a = px[x, y]
        if a > 0 and is_greenish_pixel((r, g, b)):
            queue.append((x, y))

    for x in range(width):
        enqueue_if_bg(x, 0)
        enqueue_if_bg(x, height - 1)
    for y in range(height):
        enqueue_if_bg(0, y)
        enqueue_if_bg(width - 1, y)

    while queue:
        x, y = queue.popleft()
        px[x, y] = (CHROMA_KEY_COLOR[0], CHROMA_KEY_COLOR[1], CHROMA_KEY_COLOR[2], 255)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if nx < 0 or ny < 0 or nx >= width or ny >= height:
                continue
            idx = ny * width + nx
            if visited[idx]:
                continue
            visited[idx] = 1
            r, g, b, a = px[nx, ny]
            if a > 0 and is_greenish_pixel((r, g, b), green_floor=105, gap=20):
                queue.append((nx, ny))
    return image


def scrub_green_spill(result: Image.Image) -> Image.Image:
    """Remove green residue anywhere in portrait output, including interior matte specks."""
    image = result.convert("RGBA")
    px = image.load()
    width, height = image.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if not is_greenish_pixel((r, g, b), green_floor=25, gap=8):
                continue
            if a <= 96 or is_greenish_pixel((r, g, b), green_floor=80, gap=40):
                px[x, y] = (0, 0, 0, 0)
                continue
            clamp = max(r, b)
            if g > clamp:
                px[x, y] = (r, clamp, b, a)
    return image


def scrub_green_spill_strict(result: Image.Image) -> Image.Image:
    """Aggressively remove chroma-green residue for strict sheet/portrait runtime output."""
    image = result.convert("RGBA")
    px = image.load()
    width, height = image.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if not is_greenish_pixel((r, g, b), green_floor=20, gap=6):
                continue
            # Any soft-edge green fringe becomes transparent; interior residue gets de-greened.
            if a <= 220 or is_greenish_pixel((r, g, b), green_floor=80, gap=35):
                px[x, y] = (0, 0, 0, 0)
                continue
            clamp = max(r, b)
            if g > clamp:
                px[x, y] = (r, clamp, b, a)
    return image


def apply_chroma_key_if_needed(source: Image.Image, profile: ExportProfile) -> Image.Image:
    if profile.asset_type not in CHROMA_KEY_ASSET_TYPES:
        return source
    if profile.asset_type == "battle_portrait":
        source = normalize_battle_portrait_chroma_background(source)
    # Standard chroma-key cleanup for sheet/portrait sources using bright green #00FF00.
    output = clean_alpha_matte(
        source,
        background=CHROMA_KEY_COLOR,
        transparent_distance=40.0 if profile.asset_type == "battle_portrait" else 24.0,
        opaque_distance=112.0 if profile.asset_type == "battle_portrait" else 78.0,
        choke=2 if profile.asset_type == "battle_portrait" else 1,
        feather=0.30 if profile.asset_type == "battle_portrait" else 0.35,
        despill=1.0 if profile.asset_type == "battle_portrait" else 0.9,
        edge_dehalo=True,
        fill_alpha_holes=False,
    )
    if profile.asset_type in CHROMA_KEY_ASSET_TYPES:
        output = scrub_green_spill_strict(output)
    return output


def validate_chroma_key_runtime_image(runtime_path: Path) -> None:
    with Image.open(runtime_path) as image:
        if image.mode not in {"RGBA", "LA"}:
            fail(f"chroma-key asset must be RGBA or LA: {rel(runtime_path)} mode={image.mode}")
        alpha = image.getchannel("A")
        pixels = image.convert("RGBA").load()
        non_zero = sum(1 for value in alpha.getdata() if value > 0)
        total = image.width * image.height
        if total <= 0:
            fail(f"invalid runtime image size for chroma-key validation: {rel(runtime_path)}")
        if non_zero <= 0:
            fail(f"chroma-key asset appears fully transparent: {rel(runtime_path)}")
        if non_zero >= total:
            fail(f"chroma-key asset appears fully opaque; expected cleanup to produce transparency: {rel(runtime_path)}")
        sample_step_x = max(1, image.width // 16)
        sample_step_y = max(1, image.height // 16)
        border_points: set[tuple[int, int]] = set()
        for x in range(0, image.width, sample_step_x):
            border_points.add((x, 0))
            border_points.add((x, image.height - 1))
        for y in range(0, image.height, sample_step_y):
            border_points.add((0, y))
            border_points.add((image.width - 1, y))
        for x, y in border_points:
            r, g, b, a = pixels[x, y]
            if a > 8 and abs(r - CHROMA_KEY_COLOR[0]) <= 24 and abs(g - CHROMA_KEY_COLOR[1]) <= 24 and abs(b - CHROMA_KEY_COLOR[2]) <= 24:
                fail(f"chroma-key border still contains green matte pixels: {rel(runtime_path)}")


def validate_no_battle_portrait_green_residue(runtime_path: Path) -> None:
    with Image.open(runtime_path) as image:
        pixels = image.convert("RGBA").getdata()
        for r, g, b, a in pixels:
            if a > 0 and is_greenish_pixel((r, g, b), green_floor=25, gap=8):
                fail(f"battle portrait still contains green residue pixels: {rel(runtime_path)}")


def validate_no_chroma_green_residue(runtime_path: Path) -> None:
    with Image.open(runtime_path) as image:
        pixels = image.convert("RGBA").getdata()
        for r, g, b, a in pixels:
            if a > 0 and is_greenish_pixel((r, g, b), green_floor=20, gap=6):
                fail(f"chroma-key asset still contains green residue pixels: {rel(runtime_path)}")


def export_runtime_image(source_path: Path, runtime_path: Path, profile: ExportProfile) -> Image.Image:
    source = Image.open(source_path).convert("RGBA")
    source.load()
    source = apply_chroma_key_if_needed(source, profile)
    output = resize_cover(source, profile.size) if profile.mode == "cover" else resize_fit(source, profile.size)
    if profile.asset_type in CHROMA_KEY_ASSET_TYPES:
        output = scrub_green_spill_strict(output)
    runtime_path.parent.mkdir(parents=True, exist_ok=True)
    output.save(runtime_path)
    return output


def update_hook_table(row: dict[str, str], runtime_path: Path) -> None:
    hook_table = row.get("hook_table", "").strip()
    if hook_table == "":
        return
    hook_key_field = row.get("hook_key_field", "").strip()
    hook_id = row.get("hook_id", "").strip()
    hook_field = row.get("hook_field", "").strip()
    if hook_key_field == "" or hook_id == "" or hook_field == "":
        fail(f"asset {row.get('asset_id', '')} has incomplete hook fields")

    table_path = normalize_repo_path(hook_table)
    if not table_path.exists():
        fail(f"hook table missing: {rel(table_path)}")
    fieldnames, rows, delimiter = read_delimited(table_path)
    if hook_key_field not in fieldnames:
        fail(f"hook key field '{hook_key_field}' missing in {hook_table}")
    if hook_field not in fieldnames:
        fail(f"hook field '{hook_field}' missing in {hook_table}")

    target_value = to_res_path(runtime_path)
    for hook_row in rows:
        if hook_row.get(hook_key_field, "") == hook_id:
            hook_row[hook_field] = target_value
            write_delimited(table_path, fieldnames, rows, delimiter)
            return
    fail(f"hook row not found in {hook_table}: {hook_key_field}={hook_id}")


def validate_hook_table_value(row: dict[str, str], runtime_path: Path) -> None:
    hook_table = row.get("hook_table", "").strip()
    if hook_table == "":
        return
    hook_key_field = row.get("hook_key_field", "").strip()
    hook_id = row.get("hook_id", "").strip()
    hook_field = row.get("hook_field", "").strip()
    table_path = normalize_repo_path(hook_table)
    if not table_path.exists():
        fail(f"hook table missing: {rel(table_path)}")
    _, rows, _ = read_delimited(table_path)
    expected = to_res_path(runtime_path)
    for hook_row in rows:
        if hook_row.get(hook_key_field, "") == hook_id:
            actual = hook_row.get(hook_field, "").strip()
            if actual != expected:
                fail(f"{hook_table}:{hook_key_field}={hook_id}.{hook_field} expected {expected}, got {actual or '<empty>'}")
            return
    fail(f"hook row not found in {hook_table}: {hook_key_field}={hook_id}")


def validate_compiled_value(row: dict[str, str], runtime_path: Path) -> Path:
    hook_table = row.get("hook_table", "").strip()
    if hook_table == "":
        fail(f"asset {row.get('asset_id', '')} has no hook_table; compiled validation is not available")
    hook_spec = get_hook_spec(hook_table)
    compiled_path = normalize_repo_path(hook_spec.compiled_json)
    if not compiled_path.exists():
        fail(f"compiled json missing: {rel(compiled_path)}")
    payload = json.loads(compiled_path.read_text(encoding="utf-8"))
    node: Any = payload[hook_spec.compiled_root_key] if hook_spec.compiled_root_key else payload
    hook_id = row.get("hook_id", "").strip()
    hook_field = row.get("hook_field", "").strip()
    expected = to_res_path(runtime_path)
    if hook_id not in node:
        fail(f"{rel(compiled_path)} missing compiled entry: {hook_id}")
    entry = node[hook_id]
    if not isinstance(entry, dict):
        fail(f"{rel(compiled_path)} entry {hook_id} is not an object")
    actual = str(entry.get(hook_field, "")).strip()
    if actual != expected:
        fail(f"{rel(compiled_path)} entry {hook_id}.{hook_field} expected {expected}, got {actual or '<empty>'}")
    return compiled_path


def validate_runtime_image(row: dict[str, str], runtime_path: Path) -> tuple[int, int, str]:
    if not runtime_path.exists():
        fail(f"missing runtime asset: {rel(runtime_path)}")
    profile = get_export_profile(row.get("type", "").strip())
    with Image.open(runtime_path) as image:
        width, height = image.size
        mode = image.mode
    if (width, height) != profile.size:
        fail(f"runtime asset has wrong size: {rel(runtime_path)} expected {profile.size[0]}x{profile.size[1]}, got {width}x{height}")
    if profile.asset_type in CHROMA_KEY_ASSET_TYPES:
        validate_chroma_key_runtime_image(runtime_path)
        validate_no_chroma_green_residue(runtime_path)
    return width, height, mode


def detect_godot_import(runtime_path: Path) -> tuple[bool, Path, list[Path]]:
    import_path = runtime_path.with_name(f"{runtime_path.name}.import")
    ctex_matches = sorted((ROOT / ".godot" / "imported").glob(f"{runtime_path.name}-*.ctex"))
    return import_path.exists() and bool(ctex_matches), import_path, ctex_matches


def godot_import_is_stale(runtime_path: Path, ctex_matches: list[Path]) -> bool:
    if not ctex_matches:
        return False
    runtime_mtime = runtime_path.stat().st_mtime_ns
    newest_ctex_mtime = max(path.stat().st_mtime_ns for path in ctex_matches)
    return newest_ctex_mtime < runtime_mtime


def summarize_status(asset_id: str, previous: str, current: str) -> str:
    return f"{asset_id}: {previous or '<empty>'} -> {current}"


def describe_runtime(row: dict[str, str]) -> tuple[Path, ExportProfile]:
    source_path = normalize_repo_path(row.get("source_path", ""))
    runtime_path = normalize_repo_path(row.get("runtime_path", ""))
    profile = get_export_profile(row.get("type", "").strip())
    return source_path, runtime_path, profile


def validate_source_exists(source_path: Path) -> None:
    if not source_path.exists():
        fail(f"missing source asset: {rel(source_path)}")


def note(message: str) -> None:
    print(f"[art-asset-pipeline] {message}")


def parse_import_destinations(import_path: Path) -> list[str]:
    if not import_path.exists():
        return []
    text = import_path.read_text(encoding="utf-8")
    match = re.search(r"dest_files=\[(.*?)\]", text)
    if not match:
        return []
    return re.findall(r"\"([^\"]+)\"", match.group(1))
