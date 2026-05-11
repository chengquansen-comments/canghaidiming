#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
SEQUENCE_TEMPLATE_DIR = ROOT / "data" / "aigc_battle" / "sequence_templates"
DEFAULT_SEQUENCE_TEMPLATE_ID = "formal_sequence_15_v1"


def sequence_template_path(sequence_template_id: str) -> Path:
    return SEQUENCE_TEMPLATE_DIR / f"{sequence_template_id}.json"


def load_sequence_template(sequence_template_id: str | None) -> dict[str, Any]:
    template_id = (sequence_template_id or DEFAULT_SEQUENCE_TEMPLATE_ID).strip()
    path = sequence_template_path(template_id)
    if not path.exists():
        raise SystemExit(f"sequence template not found: {template_id}")
    payload = json.loads(path.read_text(encoding="utf-8"))
    if str(payload.get("sequence_template_id", "")) != template_id:
        raise SystemExit(f"sequence template id mismatch: {template_id}")
    return payload


def infer_build_variant(profile_id: str, content_pack_id: str, fallback_variant: str = "baseline_001") -> str:
    prefix = f"{profile_id}__"
    if content_pack_id.startswith(prefix):
        tail = content_pack_id[len(prefix):]
        if "__" in tail:
            maybe_variant = tail.rsplit("__", 1)[-1].strip()
            if maybe_variant:
                return maybe_variant
    if content_pack_id.startswith(f"{profile_id}_balance_release_"):
        return content_pack_id[len(f"{profile_id}_"):]
    if content_pack_id.startswith(f"{profile_id}_eval_rebuild_"):
        return content_pack_id[len(f"{profile_id}_"):]
    if content_pack_id.startswith(f"{profile_id}_real_rebuild_"):
        return content_pack_id[len(f"{profile_id}_"):]
    for marker in ["_balance_release_", "_eval_rebuild_", "_real_rebuild_"]:
        if marker in content_pack_id:
            return marker[1:] + content_pack_id.split(marker, 1)[1]
    if content_pack_id.endswith("_formal_sequence_pack_001"):
        return "baseline_001"
    return fallback_variant


def resolve_build_variant(explicit_variant: Any, profile_id: str, content_pack_id: str, fallback_variant: str = "baseline_001") -> str:
    explicit = str(explicit_variant or "").strip()
    inferred = infer_build_variant(profile_id, content_pack_id, fallback_variant=fallback_variant)
    if not explicit:
        return inferred
    if explicit == "baseline_001" and inferred != "baseline_001":
        return inferred
    return explicit


def infer_sequence_template_id(content_pack_summary: dict[str, Any], runtime_manifest: dict[str, Any] | None = None) -> str:
    template_id = str(content_pack_summary.get("sequence_template_id", "")).strip()
    if not template_id and runtime_manifest:
        template_id = str(runtime_manifest.get("sequence_template_id", "")).strip()
    if template_id:
        return template_id
    total_count = int(
        content_pack_summary.get("formal_encounter_total_count")
        or content_pack_summary.get("generated_battle_slot_count")
        or (runtime_manifest or {}).get("total_encounter_count", 0)
        or 0
    )
    if total_count == 12:
        return "formal_sequence_12_fast_v1"
    return DEFAULT_SEQUENCE_TEMPLATE_ID


def build_pack_identity(
    sequence_template_id: str,
    mechanic_profile_id: str,
    build_variant: str,
    content_pack_id: str,
) -> dict[str, Any]:
    return {
        "sequence_template_id": sequence_template_id,
        "mechanic_profile_id": mechanic_profile_id,
        "build_variant": build_variant,
        "content_pack_id": content_pack_id,
    }
