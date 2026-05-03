#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

from art_asset_pipeline import HOOK_SPECS, detect_godot_import, read_delimited, write_delimited


ROOT = Path(__file__).resolve().parents[1]
BACKLOG_PATH = ROOT / "tables" / "art_backlog.tsv"
PROMPT_MANIFEST_PATH = ROOT / "tables" / "art_prompt_manifest.tsv"
ASSET_MANIFEST_PATH = ROOT / "tables" / "art_asset_manifest.tsv"

REQUIRED_FIELDS = [
    "current_asset_class",
    "planned_asset_class",
    "runtime_role",
]

HOOKLESS_ASSET_TYPES = {"battle_action_sheet", "battle_portrait"}


def fail(message: str) -> None:
    raise SystemExit(f"[refresh-art-backlog] ERROR: {message}")


def ok(message: str) -> None:
    print(f"[refresh-art-backlog] OK: {message}")


def normalize_local_path(raw_path: str) -> Path:
    path = Path(raw_path.strip())
    return path if path.is_absolute() else ROOT / path


def normalize_res_to_local(raw_path: str) -> str:
    text = raw_path.strip()
    if text.startswith("res://"):
        return text.replace("res://", "", 1)
    return text


def load_rows(path: Path) -> tuple[list[str], list[dict[str, str]], str]:
    if not path.exists():
        fail(f"missing table: {path}")
    return read_delimited(path)


def load_index(path: Path, key: str) -> dict[str, dict[str, str]]:
    _, rows, _ = load_rows(path)
    return {row.get(key, "").strip(): row for row in rows if row.get(key, "").strip()}


def ensure_required_fields(fieldnames: list[str], rows: list[dict[str, str]]) -> list[str]:
    updated = list(fieldnames)
    for field in REQUIRED_FIELDS:
        if field not in updated:
            updated.append(field)
    for row in rows:
        for field in REQUIRED_FIELDS:
            row.setdefault(field, "")
    return updated


def build_usage_index() -> set[str]:
    used_paths: set[str] = set()
    for relative_path, hook_spec in HOOK_SPECS.items():
        _, rows, _ = load_rows(ROOT / relative_path)
        for row in rows:
            for field in hook_spec.scan_fields:
                raw_path = row.get(field, "").strip()
                if raw_path.startswith("res://"):
                    used_paths.add(normalize_res_to_local(raw_path))
    return used_paths


def lookup_current_runtime(row: dict[str, str]) -> str:
    table_rel = row.get("hook_table", "").strip()
    key_field = row.get("hook_key_field", "").strip()
    hook_field = row.get("hook_field", "").strip()
    target_id = row.get("target_id", "").strip()
    if table_rel == "" or key_field == "" or hook_field == "" or target_id == "":
        return row.get("current_runtime_path", "").strip()
    table_path = ROOT / table_rel
    if not table_path.exists():
        return row.get("current_runtime_path", "").strip()
    _, rows, _ = load_rows(table_path)
    for candidate in rows:
        if candidate.get(key_field, "").strip() == target_id:
            return candidate.get(hook_field, "").strip()
    return row.get("current_runtime_path", "").strip()


def derive_overall_status(
    prompt_ready: bool,
    source_ready: bool,
    runtime_ready: bool,
    hook_final: bool,
    import_ready: bool,
    accepted: bool,
    current_runtime_exists: bool,
    hook_temp: bool,
) -> str:
    if accepted:
        return "IN_GAME_ACCEPTED"
    if import_ready and source_ready and prompt_ready:
        return "GODOT_IMPORTED"
    if hook_final and source_ready:
        return "WIRED_FINAL"
    if runtime_ready and source_ready:
        return "EXPORTED"
    if source_ready:
        return "SOURCE_READY"
    if prompt_ready:
        return "NEEDS_SOURCE"
    if current_runtime_exists or hook_temp:
        return "EXISTING_RUNTIME_ONLY"
    return "NEEDS_PROMPT"


def classify_planned_asset(planned_runtime_rel: str, asset_type: str) -> str:
    if planned_runtime_rel == "":
        return "missing"
    suffix = Path(planned_runtime_rel).suffix.lower()
    if suffix == ".svg":
        return "svg_placeholder"
    if suffix != ".png":
        return "other"
    if asset_type in {"battle_background", "narrative_background", "narrative_prop", "battle_portrait", "performance_portrait"}:
        return "png_formal"
    return "png_formal"


def classify_current_asset(
    current_runtime_rel: str,
    planned_runtime_rel: str,
    asset_type: str,
    source_ready: bool,
    runtime_ready: bool,
    hook_final: bool,
) -> str:
    if current_runtime_rel == "":
        return "missing"
    current_path = Path(current_runtime_rel)
    suffix = current_path.suffix.lower()
    if suffix == ".svg":
        return "svg_placeholder"
    if suffix != ".png":
        return "other"
    if current_runtime_rel == planned_runtime_rel:
        if source_ready and runtime_ready and (hook_final or asset_type in HOOKLESS_ASSET_TYPES):
            return "png_formal"
        return "png_temp"
    normalized = current_runtime_rel.replace("\\", "/")
    if "/portraits/" in normalized:
        return "portrait_proxy"
    if "/props/" in normalized:
        return "prop_proxy"
    if "/relics/" in normalized:
        return "relic_proxy"
    return "shared_runtime"


def classify_runtime_role(current_asset_class: str, current_runtime_rel: str, planned_runtime_rel: str) -> str:
    if current_runtime_rel == "":
        return "missing"
    if current_asset_class == "svg_placeholder":
        return "placeholder"
    if current_asset_class in {"portrait_proxy", "prop_proxy", "relic_proxy"}:
        return "proxy"
    if current_runtime_rel == planned_runtime_rel:
        if current_asset_class == "png_formal":
            return "final_target"
        return "legacy_target"
    return "shared_existing"


def refresh() -> int:
    fieldnames, rows, delimiter = load_rows(BACKLOG_PATH)
    fieldnames = ensure_required_fields(fieldnames, rows)
    prompt_index = load_index(PROMPT_MANIFEST_PATH, "asset_id") if PROMPT_MANIFEST_PATH.exists() else {}
    asset_index = load_index(ASSET_MANIFEST_PATH, "asset_id") if ASSET_MANIFEST_PATH.exists() else {}
    used_paths = build_usage_index()

    for row in rows:
        asset_id = row.get("asset_id", "").strip()
        prompt_row = prompt_index.get(asset_id)
        asset_row = asset_index.get(asset_id)

        current_runtime_res = lookup_current_runtime(row)
        row["current_runtime_path"] = current_runtime_res

        planned_runtime_rel = normalize_res_to_local(row.get("planned_runtime_path", ""))
        planned_source_rel = row.get("planned_source_path", "").strip()
        current_runtime_rel = normalize_res_to_local(current_runtime_res)

        planned_runtime_path = normalize_local_path(planned_runtime_rel) if planned_runtime_rel else None
        planned_source_path = normalize_local_path(planned_source_rel) if planned_source_rel else None
        current_runtime_path = normalize_local_path(current_runtime_rel) if current_runtime_rel else None

        prompt_ready = prompt_row is not None
        source_ready = planned_source_path is not None and planned_source_path.exists()
        runtime_ready = planned_runtime_path is not None and planned_runtime_path.exists()
        hook_final = planned_runtime_rel in used_paths if planned_runtime_rel else False
        hook_temp = current_runtime_rel in used_paths if current_runtime_rel else False
        import_ready = False
        if runtime_ready and planned_runtime_path is not None:
            import_ready = detect_godot_import(planned_runtime_path)[0]
        current_runtime_exists = current_runtime_path is not None and current_runtime_path.exists()
        accepted = row.get("acceptance_status", "").strip() == "ACCEPTED"

        row["prompt_status"] = "READY" if prompt_ready else "MISSING"
        row["source_status"] = "READY" if source_ready else "MISSING"
        row["runtime_status"] = "READY" if runtime_ready else "MISSING"
        row["hook_status"] = "WIRED_FINAL" if hook_final else ("WIRED_TEMP" if hook_temp else "UNWIRED")
        row["import_status"] = "IMPORTED" if import_ready else "MISSING"
        row["acceptance_status"] = "ACCEPTED" if accepted else "UNCHECKED"
        row["planned_asset_class"] = classify_planned_asset(planned_runtime_rel, row.get("asset_type", "").strip())
        row["current_asset_class"] = classify_current_asset(
            current_runtime_rel,
            planned_runtime_rel,
            row.get("asset_type", "").strip(),
            source_ready,
            runtime_ready,
            hook_final,
        )
        row["runtime_role"] = classify_runtime_role(
            row["current_asset_class"],
            current_runtime_rel,
            planned_runtime_rel,
        )
        row["overall_status"] = derive_overall_status(
            prompt_ready,
            source_ready,
            runtime_ready,
            hook_final,
            import_ready,
            accepted,
            current_runtime_exists,
            hook_temp,
        )

        if asset_row is not None:
            row["planned_runtime_path"] = asset_row.get("runtime_path", row["planned_runtime_path"])
            row["planned_source_path"] = asset_row.get("source_path", row["planned_source_path"])

    write_delimited(BACKLOG_PATH, fieldnames, rows, delimiter)
    summary = {
        status: sum(1 for row in rows if row.get("overall_status", "") == status)
        for status in sorted({row.get("overall_status", "") for row in rows})
    }
    ok(json.dumps(summary, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(refresh())
