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
MATRIX_BUILD_PATH = ROOT / "data" / "aigc_battle" / "generated" / "mechanic_template_matrix" / "matrix_build_report.json"
MATRIX_EVAL_PATH = ROOT / "data" / "aigc_battle" / "generated" / "mechanic_template_matrix" / "matrix_evaluation_report.json"
MATRIX_STRATEGY_PATH = ROOT / "data" / "aigc_battle" / "generated" / "mechanic_template_matrix" / "matrix_release_strategy.json"
PLAYABLE_HARDENING_DIR = ROOT / "data" / "aigc_battle" / "generated" / "playable_hardening"
AI_STUDIO_DIR = ROOT / "data" / "aigc_battle" / "generated" / "ai_studio"
PREVIEW_DIR = ROOT / "data" / "aigc_battle" / "preview"
PREVIEW_GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated" / "preview_runtime"
ACCEPTANCE_DIR = ROOT / "data" / "aigc_battle" / "acceptance"
PROMOTION_DIR = ROOT / "data" / "aigc_battle" / "promotion"
PROMOTION_REVIEW_DIR = PROMOTION_DIR / "human_review_notes"
RELEASE_SWITCH_DIR = ROOT / "data" / "aigc_battle" / "release_switch"
PRODUCTION_CONTRACT_DIR = ROOT / "data" / "aigc_battle" / "production_contract"
PRODUCTION_CLOSEOUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "production_closeout"
RELEASE_LANDING_DIR = ROOT / "data" / "aigc_battle" / "generated" / "release_landing"
PREVIOUS_CURRENT_PROFILE_ID = "weapon_followup_v0_1"
PREVIOUS_CURRENT_PACK_ID = "weapon_followup_balance_release_007"


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
    matrix_build = index_lib.try_read_json(MATRIX_BUILD_PATH) or {}
    matrix_eval = index_lib.try_read_json(MATRIX_EVAL_PATH) or {}
    matrix_strategy = index_lib.try_read_json(MATRIX_STRATEGY_PATH) or {}
    hardening_plan = index_lib.try_read_json(PLAYABLE_HARDENING_DIR / "playable_hardening_plan.json") or {}
    hardening_eval = index_lib.try_read_json(PLAYABLE_HARDENING_DIR / "hardened_candidates_evaluation_report.json") or {}
    hardening_strategy = index_lib.try_read_json(PLAYABLE_HARDENING_DIR / "playable_hardening_strategy.json") or {}
    ai_studio_build = index_lib.try_read_json(AI_STUDIO_DIR / "r9_candidate_pack_build_report.json") or {}
    ai_studio_compare = index_lib.try_read_json(AI_STUDIO_DIR / "r9_candidate_pack_compare_report.json") or {}
    ai_studio_prompts = index_lib.try_read_json(ROOT / "data" / "aigc_battle" / "ai_studio" / "prompts" / "r9_prompt_manifest.json") or {}
    preview_profile = index_lib.try_read_json(PREVIEW_DIR / "preview_profile.json") or {}
    preview_smoke = index_lib.try_read_json(PREVIEW_GENERATED_DIR / "preview_smoke_report.json") or {}
    latest_release_switch = index_lib.try_read_json(RELEASE_SWITCH_DIR / "latest_release_switch_report.json") or {}
    closeout_verification = index_lib.try_read_json(PRODUCTION_CLOSEOUT_DIR / "production_closeout_verification_report.json") or {}
    release_landing = index_lib.try_read_json(RELEASE_LANDING_DIR / "r16_release_landing_gameplay_verification_probe_report.json") or {}
    hardening_smokes = {}
    for name in ["fast_hardened_smoke_report.json", "bossrush_hardened_smoke_report.json"]:
        payload = index_lib.try_read_json(PLAYABLE_HARDENING_DIR / name) or {}
        if payload:
            hardening_smokes[str(payload.get("content_pack_id", ""))] = payload
    matrix_slots = {str(item.get("content_pack_id", "")): item for item in matrix_build.get("matrix_slots", [])}
    matrix_eval_map = {str(item.get("content_pack_id", "")): item for item in matrix_eval.get("slots", [])}

    entries: list[dict[str, Any]] = []
    for profile in index_payload.get("profiles", []):
        profile_id = str(profile.get("mechanic_profile_id", ""))
        for pack in profile.get("content_packs", []):
            pack_id = str(pack.get("content_pack_id", ""))
            runtime_manifest = index_lib.try_read_json(ROOT / str(pack.get("runtime_manifest_path", ""))) or {}
            content_pack_summary = index_lib.try_read_json(ROOT / str(pack.get("generated_dir", "")) / "content_pack_summary.json") or {}
            channel = "review"
            if profile_id == str(current.get("mechanic_profile_id", "")) and pack_id == str(current.get("content_pack_id", "")):
                channel = "current"
            elif profile_id == str(candidate.get("mechanic_profile_id", "")) and pack_id == str(candidate.get("content_pack_id", "")):
                channel = "candidate"
            elif profile_id == str(fallback.get("mechanic_profile_id", "")) and pack_id == str(fallback.get("content_pack_id", "")):
                channel = "fallback"
            release_status = safe_release_status(profile_id, pack_id)
            previous_current_marker = profile_id == PREVIOUS_CURRENT_PROFILE_ID and pack_id == PREVIOUS_CURRENT_PACK_ID
            if bool(release_status.get("playable_hardening", False)):
                channel = "release_candidate" if str(release_status.get("release_status", "")) == "release_candidate" else "review"
            if bool(content_pack_summary.get("ai_studio_candidate_pack", False)):
                channel = "ai_studio_review"
            previewable = (
                channel in {"review", "matrix_review", "ai_studio_review", "release_candidate", "fallback", "current", "candidate"}
                and bool(pack.get("runtime_manifest_path"))
                and bool(pack.get("validation_report_path"))
                and str(release_status.get("release_status", "")) != "archived"
                and bool(index_lib.try_read_json(ROOT / str(pack.get("validation_report_path", ""))) or {})
                and bool((index_lib.try_read_json(ROOT / str(pack.get("validation_report_path", ""))) or {}).get("ready_for_runtime_export", False))
            )
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
                "release_status": "current" if channel == "current" else "fallback" if channel == "fallback" else str(release_status.get("release_status", "")),
                "active": profile_id == str(active_runtime.get("active_profile_id", "")) and pack_id == str(active_runtime.get("active_content_pack_id", "")),
                "fallback": channel == "fallback",
                "source_pack_id": str(content_pack_summary.get("source_pack_id", "")),
                "resolver_entry_valid": bool(sequence_template_id and build_variant and pack_id),
                "pack_identity": template_lib.build_pack_identity(sequence_template_id, profile_id, build_variant, pack_id),
                "template_usage_recommendation": usage_map.get(sequence_template_id, ""),
                "template_release_strategy": portfolio_strategy if portfolio_strategy else {},
                "evaluation_metrics": eval_map.get(pack_id, {}),
                "matrix_slot": pack_id in matrix_slots,
                "matrix_channel": str(matrix_slots.get(pack_id, {}).get("channel", "")),
                "matrix_build_variant": str(matrix_slots.get(pack_id, {}).get("build_variant", "")),
                "matrix_strategy_tag": infer_matrix_strategy_tag(pack_id, matrix_strategy),
                "matrix_evaluation_summary": matrix_eval_map.get(pack_id, {}),
                "needs_balance_before_release": bool(matrix_eval_map.get(pack_id, {}).get("needs_balance_before_release", False)),
                "ready_for_candidate_review": bool(matrix_eval_map.get(pack_id, {}).get("ready_for_candidate_review", False)),
                "playable_hardening": bool(content_pack_summary.get("playable_hardening", False)),
                "hardening_target": str(content_pack_summary.get("hardening_target", "")),
                "source_matrix_pack_id": str(content_pack_summary.get("source_matrix_pack_id", "")),
                "target_gate_pass": hardening_target_gate(pack_id, hardening_eval),
                "smoke_pass": bool(hardening_smokes.get(pack_id, {}).get("smoke_pass", False)),
                "recommended_release_mode": str(content_pack_summary.get("recommended_release_mode", "")),
                "playable_hardening_strategy": hardening_strategy if hardening_strategy else {},
                "ai_studio_candidate_pack": bool(content_pack_summary.get("ai_studio_candidate_pack", False)),
                "candidate_batch_id": str(content_pack_summary.get("candidate_batch_id", "")),
                "candidate_source_trace": content_pack_summary.get("candidate_source_trace", []),
                "candidate_quality_summary": content_pack_summary.get("candidate_quality_summary", {}),
                "deterministic_fill_used": bool(content_pack_summary.get("deterministic_fill_used", False)),
                "ai_studio_variant_type": str(content_pack_summary.get("ai_studio_variant_type", "")),
                "candidate_pack_compare_summary": next(
                    (row for row in ai_studio_compare.get("rows", []) if str(row.get("content_pack_id", "")) == pack_id),
                    {},
                ),
                "online_llm_adapter_supported": bool(ai_studio_prompts.get("online_llm_adapter_supported", False)),
                "previewable": previewable,
                "preview_source_channel": channel,
                "preview_status": "active" if (
                    bool(preview_profile.get("preview_enabled", False))
                    and str(preview_profile.get("preview_mechanic_profile_id", "")) == profile_id
                    and str(preview_profile.get("preview_content_pack_id", "")) == pack_id
                    and str(preview_profile.get("preview_status", "")) == "active"
                ) else "idle",
                "last_preview_smoke_pass": bool(
                    str(preview_smoke.get("preview_content_pack_id", "")) == pack_id
                    and str(preview_smoke.get("preview_mechanic_profile_id", "")) == profile_id
                    and preview_smoke.get("smoke_pass", False)
                ),
                "preview_smoke_report_path": "data/aigc_battle/generated/preview_runtime/preview_smoke_report.json" if preview_smoke else "",
                "latest_acceptance_report_path": acceptance_report_path(profile_id, pack_id),
                "latest_acceptance_pass": acceptance_field(profile_id, pack_id, "acceptance_pass"),
                "latest_acceptance_risk_level": acceptance_field(profile_id, pack_id, "risk_level", ""),
                "latest_acceptance_recommendation": acceptance_field(profile_id, pack_id, "acceptance_recommendation", ""),
                "acceptance_required_before_candidate": True,
                "latest_promotion_report_path": promotion_report_path(profile_id, pack_id),
                "human_review_status": human_review_field(profile_id, pack_id, "status", ""),
                "human_review_note_path": human_review_note_path(profile_id, pack_id),
                "promotion_allowed": promotion_field(profile_id, pack_id, "promotion_allowed"),
                "release_candidate_status": str(release_status.get("release_status", "")) == "release_candidate",
                "acceptance_required_before_promotion": True,
                "human_review_required_before_promotion": True,
                "release_candidate_valid": release_candidate_valid(profile_id, pack_id, release_status, entry=None),
                "release_switch_allowed": release_candidate_valid(profile_id, pack_id, release_status, entry=None),
                "latest_release_switch_report_path": latest_release_switch_path(profile_id, pack_id, latest_release_switch),
                "can_set_current": release_candidate_valid(profile_id, pack_id, release_status, entry=None),
                "can_rollback": channel in {"current", "fallback"},
                "current_release_marker": channel == "current",
                "previous_current_marker": previous_current_marker and channel != "current",
                "fallback_release_marker": channel == "fallback",
                "release_landing_current": channel == "current" and bool(closeout_verification or current),
                "gameplay_entry_verified": bool(
                    channel == "current"
                    and str(current.get("content_pack_id", "")) == pack_id
                    and str(current.get("sequence_template_id", "")) == str(sequence_template_id)
                    and bool(
                        closeout_verification.get("final_current_smoke_pass", False)
                        or closeout_verification.get("probe_pass", False)
                        or (
                            str(release_landing.get("content_pack_id", "")) == pack_id
                            and bool(release_landing.get("gameplay_entry_verification_ready", False))
                            and bool(release_landing.get("probe_pass", False))
                        )
                    )
                ),
                "resolver_channel_consistency_valid": (
                    (channel != "current" or (profile_id == str(current.get("mechanic_profile_id", "")) and pack_id == str(current.get("content_pack_id", ""))))
                    and (channel != "fallback" or (profile_id == str(fallback.get("mechanic_profile_id", "")) and pack_id == str(fallback.get("content_pack_id", ""))))
                    and not (channel == "current" and previous_current_marker)
                ),
                "production_contract_ready": bool((PRODUCTION_CONTRACT_DIR / "schema_manifest.json").exists()),
                "schema_manifest_path": "data/aigc_battle/production_contract/schema_manifest.json",
                "generated_file_policy_path": "data/aigc_battle/production_contract/generated_file_policy.json",
                "minimal_acceptance_command_path": "data/aigc_battle/production_contract/minimal_acceptance_command.json",
                "deprecated_probe_inventory_path": "data/aigc_battle/production_contract/deprecated_probe_inventory.json",
                "production_contract_doc_path": "docs/AIGC_BATTLE_PRODUCTION_CONTRACT.md",
                "production_closeout_ready": bool(closeout_verification.get("production_closeout_ready", False)),
                "closeout_report_path": "data/aigc_battle/generated/production_closeout/r17_production_closeout_probe_report.json" if closeout_verification else "",
                "cleanup_report_path": "data/aigc_battle/generated/production_closeout/production_closeout_cleanup_report.json" if closeout_verification else "",
                "final_acceptance_status": str(closeout_verification.get("final_current_acceptance_pass", False)).lower() if closeout_verification else "",
            }
            entries.append(entry)
    if matrix_build:
        for slot in matrix_build.get("matrix_slots", []):
            pack_id = str(slot.get("content_pack_id", ""))
            profile_id = str(slot.get("mechanic_profile_id", ""))
            if not pack_id or not profile_id:
                continue
            if any(entry.get("content_pack_id") == pack_id and entry.get("mechanic_profile_id") == profile_id and entry.get("channel") == "matrix_review" for entry in entries):
                continue
            entries.append(
                {
                    "sequence_template_id": str(slot.get("sequence_template_id", "")),
                    "template_display_name": str(slot.get("sequence_template_id", "")),
                    "mechanic_profile_id": profile_id,
                    "build_variant": str(slot.get("build_variant", "")),
                    "content_pack_id": pack_id,
                    "channel": "matrix_review",
                    "runtime_manifest_path": "",
                    "validation_report_path": "",
                    "release_status": "reviewing",
                    "active": False,
                    "fallback": False,
                    "source_pack_id": str(slot.get("source_pack_id", "")),
                    "resolver_entry_valid": True,
                    "pack_identity": template_lib.build_pack_identity(str(slot.get("sequence_template_id", "")), profile_id, str(slot.get("build_variant", "")), pack_id),
                    "template_usage_recommendation": "",
                    "template_release_strategy": matrix_strategy if matrix_strategy else {},
                    "evaluation_metrics": matrix_eval_map.get(pack_id, {}),
                    "matrix_slot": True,
                    "matrix_channel": "matrix_review",
                    "matrix_build_variant": str(slot.get("build_variant", "")),
                    "matrix_strategy_tag": infer_matrix_strategy_tag(pack_id, matrix_strategy),
                    "matrix_evaluation_summary": matrix_eval_map.get(pack_id, {}),
                    "needs_balance_before_release": bool(matrix_eval_map.get(pack_id, {}).get("needs_balance_before_release", False)),
                    "ready_for_candidate_review": bool(matrix_eval_map.get(pack_id, {}).get("ready_for_candidate_review", False)),
                    "previewable": True,
                    "preview_source_channel": "matrix_review",
                    "preview_status": "active" if (
                        bool(preview_profile.get("preview_enabled", False))
                        and str(preview_profile.get("preview_mechanic_profile_id", "")) == profile_id
                        and str(preview_profile.get("preview_content_pack_id", "")) == pack_id
                        and str(preview_profile.get("preview_status", "")) == "active"
                    ) else "idle",
                    "last_preview_smoke_pass": bool(
                        str(preview_smoke.get("preview_content_pack_id", "")) == pack_id
                        and str(preview_smoke.get("preview_mechanic_profile_id", "")) == profile_id
                        and preview_smoke.get("smoke_pass", False)
                    ),
                    "preview_smoke_report_path": "data/aigc_battle/generated/preview_runtime/preview_smoke_report.json" if preview_smoke else "",
                    "latest_acceptance_report_path": acceptance_report_path(profile_id, pack_id),
                    "latest_acceptance_pass": acceptance_field(profile_id, pack_id, "acceptance_pass"),
                    "latest_acceptance_risk_level": acceptance_field(profile_id, pack_id, "risk_level", ""),
                    "latest_acceptance_recommendation": acceptance_field(profile_id, pack_id, "acceptance_recommendation", ""),
                    "acceptance_required_before_candidate": True,
                    "latest_promotion_report_path": promotion_report_path(profile_id, pack_id),
                    "human_review_status": human_review_field(profile_id, pack_id, "status", ""),
                    "human_review_note_path": human_review_note_path(profile_id, pack_id),
                    "promotion_allowed": promotion_field(profile_id, pack_id, "promotion_allowed"),
                    "release_candidate_status": str(safe_release_status(profile_id, pack_id).get("release_status", "")) == "release_candidate",
                    "acceptance_required_before_promotion": True,
                    "human_review_required_before_promotion": True,
                    "release_candidate_valid": release_candidate_valid(profile_id, pack_id, safe_release_status(profile_id, pack_id), entry=None),
                    "release_switch_allowed": release_candidate_valid(profile_id, pack_id, safe_release_status(profile_id, pack_id), entry=None),
                    "latest_release_switch_report_path": latest_release_switch_path(profile_id, pack_id, latest_release_switch),
                    "can_set_current": release_candidate_valid(profile_id, pack_id, safe_release_status(profile_id, pack_id), entry=None),
                    "can_rollback": False,
                    "current_release_marker": False,
                    "previous_current_marker": profile_id == PREVIOUS_CURRENT_PROFILE_ID and pack_id == PREVIOUS_CURRENT_PACK_ID,
                    "fallback_release_marker": False,
                    "release_landing_current": False,
                    "gameplay_entry_verified": False,
                    "resolver_channel_consistency_valid": True,
                    "production_contract_ready": bool((PRODUCTION_CONTRACT_DIR / "schema_manifest.json").exists()),
                    "schema_manifest_path": "data/aigc_battle/production_contract/schema_manifest.json",
                    "generated_file_policy_path": "data/aigc_battle/production_contract/generated_file_policy.json",
                    "minimal_acceptance_command_path": "data/aigc_battle/production_contract/minimal_acceptance_command.json",
                    "deprecated_probe_inventory_path": "data/aigc_battle/production_contract/deprecated_probe_inventory.json",
                    "production_contract_doc_path": "docs/AIGC_BATTLE_PRODUCTION_CONTRACT.md",
                    "production_closeout_ready": bool(closeout_verification.get("production_closeout_ready", False)),
                    "closeout_report_path": "data/aigc_battle/generated/production_closeout/r17_production_closeout_probe_report.json" if closeout_verification else "",
                    "cleanup_report_path": "data/aigc_battle/generated/production_closeout/production_closeout_cleanup_report.json" if closeout_verification else "",
                    "final_acceptance_status": str(closeout_verification.get("final_current_acceptance_pass", False)).lower() if closeout_verification else "",
                }
            )
    return {
        "resolver_id": "pack_resolver_v1",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "production_contract_ready": bool((PRODUCTION_CONTRACT_DIR / "schema_manifest.json").exists()),
        "schema_manifest_path": "data/aigc_battle/production_contract/schema_manifest.json",
        "generated_file_policy_path": "data/aigc_battle/production_contract/generated_file_policy.json",
        "minimal_acceptance_command_path": "data/aigc_battle/production_contract/minimal_acceptance_command.json",
        "deprecated_probe_inventory_path": "data/aigc_battle/production_contract/deprecated_probe_inventory.json",
        "production_contract_doc_path": "docs/AIGC_BATTLE_PRODUCTION_CONTRACT.md",
        "production_closeout_ready": bool(closeout_verification.get("production_closeout_ready", False)),
        "closeout_report_path": "data/aigc_battle/generated/production_closeout/r17_production_closeout_probe_report.json" if closeout_verification else "",
        "cleanup_report_path": "data/aigc_battle/generated/production_closeout/production_closeout_cleanup_report.json" if closeout_verification else "",
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


def infer_matrix_strategy_tag(content_pack_id: str, strategy: dict[str, Any]) -> str:
    mapping = {
        "recommended_standard_candidate": "standard_candidate",
        "recommended_fast_candidate": "fast_candidate",
        "recommended_bossrush_candidate": "bossrush_candidate",
        "recommended_mechanic_showcase_candidate": "mechanic_showcase",
    }
    for key, label in mapping.items():
        value = strategy.get(key, {})
        if isinstance(value, dict) and str(value.get("content_pack_id", "")) == content_pack_id:
            return label
    return ""


def hardening_target_gate(content_pack_id: str, report: dict[str, Any]) -> bool:
    if str(report.get("fast_hardened_pack_id", "")) == content_pack_id:
        return bool(report.get("fast_target_gate_pass", False))
    if str(report.get("bossrush_hardened_pack_id", "")) == content_pack_id:
        return bool(report.get("bossrush_target_gate_pass", False))
    return False


def acceptance_report_path(profile_id: str, content_pack_id: str) -> str:
    path = ACCEPTANCE_DIR / f"{profile_id}__{content_pack_id}__acceptance_report.json"
    return path.relative_to(ROOT).as_posix() if path.exists() else ""


def acceptance_field(profile_id: str, content_pack_id: str, key: str, default: Any = False) -> Any:
    path = ACCEPTANCE_DIR / f"{profile_id}__{content_pack_id}__acceptance_report.json"
    payload = index_lib.try_read_json(path) or {}
    return payload.get(key, default)


def promotion_report_path(profile_id: str, content_pack_id: str) -> str:
    path = PROMOTION_DIR / f"{profile_id}__{content_pack_id}__promotion_report.json"
    return path.relative_to(ROOT).as_posix() if path.exists() else ""


def promotion_field(profile_id: str, content_pack_id: str, key: str, default: Any = False) -> Any:
    path = PROMOTION_DIR / f"{profile_id}__{content_pack_id}__promotion_report.json"
    payload = index_lib.try_read_json(path) or {}
    return payload.get(key, default)


def human_review_note_path(profile_id: str, content_pack_id: str) -> str:
    path = PROMOTION_REVIEW_DIR / f"{profile_id}__{content_pack_id}.json"
    return path.relative_to(ROOT).as_posix() if path.exists() else ""


def human_review_field(profile_id: str, content_pack_id: str, key: str, default: Any = "") -> Any:
    path = PROMOTION_REVIEW_DIR / f"{profile_id}__{content_pack_id}.json"
    payload = index_lib.try_read_json(path) or {}
    return payload.get(key, default)


def latest_release_switch_path(profile_id: str, content_pack_id: str, payload: dict[str, Any]) -> str:
    if (
        str(payload.get("target_profile_id", "")) == profile_id
        and str(payload.get("target_content_pack_id", "")) == content_pack_id
    ):
        path = RELEASE_SWITCH_DIR / "latest_release_switch_report.json"
        return path.relative_to(ROOT).as_posix()
    return ""


def release_candidate_valid(profile_id: str, content_pack_id: str, release_status: dict[str, Any], entry: dict[str, Any] | None) -> bool:
    promotion_allowed = bool(promotion_field(profile_id, content_pack_id, "promotion_allowed"))
    promoted = bool(promotion_field(profile_id, content_pack_id, "promoted_to_release_candidate"))
    acceptance_pass = bool(acceptance_field(profile_id, content_pack_id, "acceptance_pass"))
    acceptance_risk = str(acceptance_field(profile_id, content_pack_id, "risk_level", ""))
    acceptance_recommendation = str(acceptance_field(profile_id, content_pack_id, "acceptance_recommendation", ""))
    human_review_status = str(human_review_field(profile_id, content_pack_id, "status", ""))
    return (
        promotion_allowed
        and promoted
        and acceptance_pass
        and acceptance_risk != "fail"
        and acceptance_recommendation != "reject"
        and human_review_status == "accepted"
        and str(release_status.get("release_status", "")) == "release_candidate"
    )


def safe_release_status(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    try:
        return release_lib.get_release_status(profile_id, content_pack_id)
    except SystemExit:
        return {
            "mechanic_profile_id": profile_id,
            "content_pack_id": content_pack_id,
            "release_status": "reviewing",
            "playable_hardening": False,
        }


if __name__ == "__main__":
    raise SystemExit(main())
