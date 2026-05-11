#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import build_aigc_detail_views as detail_lib
from tools.aigc_battle import switch_active_profile as switch_lib

OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "mechanic_expansion"
OUT_JSON = OUT_DIR / "mechanic_compare_matrix.json"
OUT_MD = OUT_DIR / "mechanic_compare_matrix.md"


def main() -> int:
    detail_lib.main()
    rows: list[dict[str, Any]] = []
    for profile_id in switch_lib.list_profile_ids():
        generated_dir = switch_lib.resolve_generated_dir(profile_id)
        runtime_manifest_path = generated_dir / "runtime_manifest.json"
        validation_path = generated_dir / "validation_report.json"
        if not runtime_manifest_path.exists() or not validation_path.exists():
            continue
        runtime_manifest = read_json(runtime_manifest_path)
        validation = read_json(validation_path)
        summary = read_json(generated_dir / "content_pack_summary.json") if (generated_dir / "content_pack_summary.json").exists() else {}
        runtime_primitives = [str(item) for item in runtime_manifest.get("runtime_primitives", [])]
        row = {
            "mechanic_profile_id": profile_id,
            "content_pack_id": str(runtime_manifest.get("content_pack_id", "")),
            "runtime_primitive_types": runtime_primitives,
            "mechanic_runtime_observable": bool(validation.get("ready_for_runtime_export", False)),
            "max_wujing": int(validation.get("max_wujing", 0) or 0),
            "dual_weapon_enabled": bool(validation.get("dual_weapon_declared", False)),
            "clue_pressure_enabled": bool(validation.get("clue_pressure_declared", False)),
            "mechanic_density": len(runtime_primitives),
            "weapon_loadout_counts": summary.get("weapon_loadout_counts", {}),
            "clue_pressure_density_by_tier": summary.get("clue_pressure_density_by_tier", {}),
        }
        rows.append(row)
    payload = build_matrix(rows)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    write_json(OUT_JSON, payload)
    OUT_MD.write_text(build_markdown(payload), encoding="utf-8")
    print("built mechanic compare matrix")
    return 0


def build_matrix(rows: list[dict[str, Any]]) -> dict[str, Any]:
    primitive_sets = {tuple(row["runtime_primitive_types"]) for row in rows}
    max_wujing_by_pack = {
        f"{row['mechanic_profile_id']}::{row['content_pack_id']}": row["max_wujing"]
        for row in rows
    }
    dual_weapon_enabled_by_pack = {
        f"{row['mechanic_profile_id']}::{row['content_pack_id']}": row["dual_weapon_enabled"]
        for row in rows
    }
    clue_pressure_enabled_by_pack = {
        f"{row['mechanic_profile_id']}::{row['content_pack_id']}": row["clue_pressure_enabled"]
        for row in rows
    }
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "real_mechanic_profile_count": len(rows),
        "runtime_primitive_types": sorted({primitive for row in rows for primitive in row["runtime_primitive_types"]}),
        "distinct_mechanic_count": len(primitive_sets),
        "mechanic_density_by_pack": {
            f"{row['mechanic_profile_id']}::{row['content_pack_id']}": row["mechanic_density"]
            for row in rows
        },
        "mechanic_runtime_observable": {
            f"{row['mechanic_profile_id']}::{row['content_pack_id']}": row["mechanic_runtime_observable"]
            for row in rows
        },
        "max_wujing_by_pack": max_wujing_by_pack,
        "dual_weapon_enabled_by_pack": dual_weapon_enabled_by_pack,
        "clue_pressure_enabled_by_pack": clue_pressure_enabled_by_pack,
        "mechanism_overlap_warning": len(primitive_sets) != len(rows),
        "packs": rows,
    }


def build_markdown(payload: dict[str, Any]) -> str:
    lines = [
        "# Mechanic Compare Matrix",
        "",
        f"- real_mechanic_profile_count: `{payload['real_mechanic_profile_count']}`",
        f"- runtime_primitive_types: `{', '.join(payload['runtime_primitive_types'])}`",
        f"- distinct_mechanic_count: `{payload['distinct_mechanic_count']}`",
        f"- mechanism_overlap_warning: `{str(payload['mechanism_overlap_warning']).lower()}`",
        "",
        "| profile | pack | primitives | max_wujing | dual_weapon | clue_pressure | observable |",
        "| --- | --- | --- | ---: | --- | --- | --- |",
    ]
    for row in payload.get("packs", []):
        lines.append(
            "| `{}` | `{}` | `{}` | {} | {} | {} | {} |".format(
                row["mechanic_profile_id"],
                row["content_pack_id"],
                ",".join(row["runtime_primitive_types"]) or "-",
                row["max_wujing"],
                "true" if row["dual_weapon_enabled"] else "false",
                "true" if row["clue_pressure_enabled"] else "false",
                "true" if row["mechanic_runtime_observable"] else "false",
            )
        )
    return "\n".join(lines) + "\n"


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
