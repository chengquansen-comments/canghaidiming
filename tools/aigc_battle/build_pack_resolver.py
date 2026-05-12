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

from tools.aigc_battle import build_aigc_content_index as index_lib
from tools.aigc_battle import load_sequence_template as template_lib
from tools.aigc_battle import aigc_release_gate as release_lib


RESOLVER_PATH = ROOT / "data" / "aigc_battle" / "pack_resolver.json"
OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "pack_resolver"
TEMPLATE_PORTFOLIO_EVAL_PATH = ROOT / "data" / "aigc_battle" / "generated" / "template_portfolio" / "template_portfolio_evaluation_report.json"
TEMPLATE_RELEASE_STRATEGY_PATH = ROOT / "data" / "aigc_battle" / "generated" / "template_portfolio" / "template_release_strategy.json"


def main() -> int:
    payload = build_pack_resolver()
    RESOLVER_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "pack_resolver.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"built pack resolver: entries={len(payload['entries'])}")
    return 0


def build_pack_resolver() -> dict[str, Any]:
    index_payload = index_lib.build_index()
    channels = release_lib.show_channels()
    current = channels.get("current_release", {})
    candidate = channels.get("candidate_release", {})
    fallback = channels.get("fallback_release", {})
    active_runtime = channels.get("active_runtime", {})
    portfolio_eval = index_lib.try_read_json(TEMPLATE_PORTFOLIO_EVAL_PATH) or {}
    portfolio_strategy = index_lib.try_read_json(TEMPLATE_RELEASE_STRATEGY_PATH) or {}
    usage_map = build_usage_map(portfolio_strategy)
    eval_map = {str(item.get("content_pack_id", "")): item for item in portfolio_eval.get("template_metrics", [])}

    entries: list[dict[str, Any]] = []
    for profile in index_payload.get("profiles", []):
        profile_id = str(profile.get("mechanic_profile_id", ""))
        for pack in profile.get("content_packs", []):
            pack_id = str(pack.get("content_pack_id", ""))
            channel = "review"
            if profile_id == str(current.get("mechanic_profile_id", "")) and pack_id == str(current.get("content_pack_id", "")):
                channel = "current"
            elif profile_id == str(candidate.get("mechanic_profile_id", "")) and pack_id == str(candidate.get("content_pack_id", "")):
                channel = "candidate"
            elif profile_id == str(fallback.get("mechanic_profile_id", "")) and pack_id == str(fallback.get("content_pack_id", "")):
                channel = "fallback"
            release_status = release_lib.get_release_status(profile_id, pack_id)
            runtime_manifest = index_lib.try_read_json(ROOT / str(pack.get("runtime_manifest_path", ""))) or {}
            content_pack_summary = index_lib.try_read_json(ROOT / str(pack.get("generated_dir", "")) / "content_pack_summary.json") or {}
            sequence_template_id = template_lib.infer_sequence_template_id(content_pack_summary, runtime_manifest)
            build_variant = str(content_pack_summary.get("build_variant", "")).strip() or template_lib.infer_build_variant(profile_id, pack_id)
            entry = {
                "sequence_template_id": sequence_template_id,
                "template_display_name": str(sequence_template_id),
                "mechanic_profile_id": profile_id,
                "build_variant": build_variant,
                "content_pack_id": pack_id,
                "channel": channel,
                "runtime_manifest_path": str(pack.get("runtime_manifest_path", "")),
                "validation_report_path": str(pack.get("validation_report_path", "")),
                "release_status": str(release_status.get("release_status", "")),
                "active": profile_id == str(active_runtime.get("active_profile_id", "")) and pack_id == str(active_runtime.get("active_content_pack_id", "")),
                "fallback": channel == "fallback",
                "source_pack_id": str(content_pack_summary.get("source_pack_id", "")),
                "resolver_entry_valid": bool(sequence_template_id and build_variant and pack_id),
                "pack_identity": template_lib.build_pack_identity(sequence_template_id, profile_id, build_variant, pack_id),
                "template_usage_recommendation": usage_map.get(sequence_template_id, ""),
                "template_release_strategy": portfolio_strategy if portfolio_strategy else {},
                "evaluation_metrics": eval_map.get(pack_id, {}),
            }
            entries.append(entry)
    return {
        "resolver_id": "pack_resolver_v1",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "entries": entries,
    }


def build_usage_map(strategy: dict[str, Any]) -> dict[str, str]:
    mapping: dict[str, str] = {}
    if not strategy:
        return mapping
    labels = {
        "recommended_standard_template": "standard_run",
        "recommended_fast_template": "fast_run",
        "recommended_bossrush_template": "boss_rush",
        "recommended_elite_template": "elite_pressure",
    }
    for key, label in labels.items():
        template_id = str(strategy.get(key, "")).strip()
        if template_id:
            mapping[template_id] = label
    return mapping


if __name__ == "__main__":
    raise SystemExit(main())
