#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

CONTRACT_DIR = ROOT / "data" / "aigc_battle" / "production_contract"
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated" / "production_freeze"
DOC_PATH = ROOT / "docs" / "AIGC_BATTLE_PRODUCTION_CONTRACT.md"
SCHEMA_MANIFEST_PATH = CONTRACT_DIR / "schema_manifest.json"
GENERATED_FILE_POLICY_PATH = CONTRACT_DIR / "generated_file_policy.json"
MINIMAL_ACCEPTANCE_COMMAND_PATH = CONTRACT_DIR / "minimal_acceptance_command.json"
DEPRECATED_PROBE_INVENTORY_PATH = CONTRACT_DIR / "deprecated_probe_inventory.json"
REPORT_JSON_PATH = GENERATED_DIR / "production_contract_freeze_report.json"
REPORT_MD_PATH = GENERATED_DIR / "production_contract_freeze_report.md"

CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
FALLBACK_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"
PACK_RESOLVER_PATH = ROOT / "data" / "aigc_battle" / "pack_resolver.json"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="freeze production contract artifacts")
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args(argv[1:])
    report = freeze_production_contract(write=args.write)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report.get("production_contract_frozen", False) else 1


def freeze_production_contract(write: bool = True) -> dict[str, Any]:
    before = read_state()
    schema_manifest = build_schema_manifest()
    generated_file_policy = build_generated_file_policy()
    minimal_acceptance_command = build_minimal_acceptance_command()
    deprecated_probe_inventory = build_deprecated_probe_inventory()
    doc_text = build_contract_doc(schema_manifest, generated_file_policy, minimal_acceptance_command, deprecated_probe_inventory)

    report = {
        "generated_at": now_iso(),
        "schema_manifest_ready": bool(schema_manifest.get("schema_manifest_ready", False)),
        "generated_file_policy_ready": bool(generated_file_policy.get("generated_file_policy_ready", False)),
        "minimal_acceptance_command_ready": bool(minimal_acceptance_command.get("minimal_acceptance_command_ready", False)),
        "deprecated_probe_inventory_ready": bool(deprecated_probe_inventory.get("deprecated_probe_inventory_ready", False)),
        "production_contract_doc_ready": True,
        "current_release_unchanged": False,
        "active_profile_matches_current_release": False,
        "fallback_release_unchanged": False,
        "production_contract_frozen": False,
    }

    if write:
        CONTRACT_DIR.mkdir(parents=True, exist_ok=True)
        GENERATED_DIR.mkdir(parents=True, exist_ok=True)
        write_json(SCHEMA_MANIFEST_PATH, schema_manifest)
        write_json(GENERATED_FILE_POLICY_PATH, generated_file_policy)
        write_json(MINIMAL_ACCEPTANCE_COMMAND_PATH, minimal_acceptance_command)
        write_json(DEPRECATED_PROBE_INVENTORY_PATH, deprecated_probe_inventory)
        DOC_PATH.write_text(doc_text, encoding="utf-8")

    after = read_state()
    report["current_release_unchanged"] = before["current"] == after["current"]
    report["fallback_release_unchanged"] = before["fallback"] == after["fallback"]
    report["active_profile_matches_current_release"] = active_matches_current(after["active"], after["current"])
    report["production_contract_frozen"] = all(
        [
            report["schema_manifest_ready"],
            report["generated_file_policy_ready"],
            report["minimal_acceptance_command_ready"],
            report["deprecated_probe_inventory_ready"],
            report["production_contract_doc_ready"],
            report["current_release_unchanged"],
            report["fallback_release_unchanged"],
            report["active_profile_matches_current_release"],
        ]
    )

    if write:
        write_json(REPORT_JSON_PATH, report)
        REPORT_MD_PATH.write_text(build_report_markdown(report), encoding="utf-8")
    return report


def build_schema_manifest() -> dict[str, Any]:
    prohibited_fields = [
        "arbitrary_runtime_manifest_path",
        "arbitrary_current_release_path",
        "arbitrary_active_profile_path",
        "shell_command",
        "external_url",
        "unsafe_file_path",
    ]
    schemas = {
        "pack_resolver_entry": {
            "required_fields": [
                "sequence_template_id",
                "mechanic_profile_id",
                "content_pack_id",
                "build_variant",
                "channel",
                "runtime_manifest_path",
                "validation_report_path",
                "resolver_entry_valid",
            ],
            "optional_fields": [
                "release_status",
                "active",
                "fallback",
                "source_pack_id",
                "pack_identity",
                "previewable",
                "release_candidate_valid",
                "release_switch_allowed",
            ],
            "prohibited_fields": prohibited_fields,
        },
        "current_release": {
            "required_fields": [
                "mechanic_profile_id",
                "content_pack_id",
                "sequence_template_id",
                "build_variant",
                "runtime_manifest_path",
            ],
            "compatibility_aliases": {
                "active_mechanic_profile_id": "mechanic_profile_id",
                "active_content_pack_id": "content_pack_id",
            },
            "optional_fields": [
                "channel",
                "pack_identity",
                "release_status",
                "release_manifest_path",
                "activated_at",
                "fallback_profile_id",
                "fallback_content_pack_id",
            ],
            "prohibited_fields": prohibited_fields,
        },
        "fallback_release": {
            "required_fields": [
                "mechanic_profile_id",
                "content_pack_id",
                "runtime_manifest_path",
            ],
            "compatibility_aliases": {
                "fallback_mechanic_profile_id": "mechanic_profile_id",
                "fallback_content_pack_id": "content_pack_id",
                "active_mechanic_profile_id": "mechanic_profile_id",
                "active_content_pack_id": "content_pack_id",
            },
            "optional_fields": [
                "channel",
                "sequence_template_id",
                "build_variant",
                "pack_identity",
                "release_status",
                "reason",
            ],
            "prohibited_fields": prohibited_fields,
        },
        "active_profile": {
            "required_fields": [
                "active_mechanic_profile_id",
                "active_content_pack_id",
                "runtime_manifest_path",
            ],
            "optional_fields": [
                "target_sequence_id",
                "replacement_mode",
                "fallback_story_battle_loader",
            ],
            "prohibited_fields": prohibited_fields,
        },
        "preview_profile": {
            "required_fields": [
                "preview_enabled",
                "preview_channel",
                "preview_content_pack_id",
                "preview_status",
                "restore_target_profile_id",
                "restore_target_content_pack_id",
            ],
            "optional_fields": [
                "preview_mechanic_profile_id",
                "preview_sequence_template_id",
                "preview_build_variant",
                "preview_runtime_manifest_path",
                "preview_validation_report_path",
                "preview_source_channel",
                "preview_started_at",
                "preview_started_by",
                "current_release_snapshot_path",
                "active_profile_snapshot",
                "preview_reason",
            ],
            "prohibited_fields": prohibited_fields,
        },
        "acceptance_report": {
            "required_fields": [
                "pack_resolved",
                "validate_pass",
                "export_pass",
                "preview_formal_entry_smoke_pass",
                "fallback_loadout_count",
                "reward_coverage_complete",
                "evaluation_ready",
                "risk_level",
                "acceptance_recommendation",
                "current_release_unchanged",
                "active_profile_matches_current_release",
                "acceptance_pass",
            ],
            "optional_fields": [
                "pack_resolved_by_pack_resolver",
                "runtime_manifest_path",
                "validation_report_path",
                "mechanic_trigger_rate",
                "acceptance_error",
            ],
            "prohibited_fields": prohibited_fields,
        },
        "human_review_note": {
            "required_fields": [
                "mechanic_profile_id",
                "content_pack_id",
                "reviewer",
                "status",
                "note",
                "review_note_valid",
            ],
            "optional_fields": [
                "sequence_template_id",
                "build_variant",
                "created_at",
                "source_acceptance_report_path",
            ],
            "prohibited_fields": prohibited_fields,
        },
        "promotion_report": {
            "required_fields": [
                "acceptance_report_found",
                "acceptance_pass",
                "human_review_note_found",
                "human_review_status",
                "human_review_accepted",
                "promotion_allowed",
                "promoted_to_release_candidate",
                "current_release_unchanged",
            ],
            "optional_fields": [
                "release_gate_policy_pass",
                "release_candidate_manifest_path",
                "active_profile_matches_current_release",
                "promotion_error",
            ],
            "prohibited_fields": prohibited_fields,
        },
        "release_switch_report": {
            "required_fields": [
                "release_candidate_valid",
                "current_release_written",
                "formal_entry_smoke_pass",
                "fallback_loadout_count",
                "reward_coverage_complete",
                "rollback_available",
                "current_release_matches_active_profile",
            ],
            "compatibility_aliases": {
                "set_current_ready": "current_release_written",
            },
            "optional_fields": [
                "action",
                "target_profile_id",
                "target_content_pack_id",
                "active_profile_written",
                "rollback_performed",
                "switch_allowed",
                "switch_error",
            ],
            "prohibited_fields": prohibited_fields,
        },
    }
    return {
        "schema_manifest_version": "r14_v1",
        "frozen_at": now_iso(),
        "schemas": schemas,
        "prohibited_fields": prohibited_fields,
        "compatibility_policy": {
            "allow_additive_optional_fields": True,
            "forbid_required_field_removal_without_version_bump": True,
            "forbid_unsafe_path_fields": True,
        },
        "schema_manifest_ready": True,
    }


def build_generated_file_policy() -> dict[str, Any]:
    return {
        "generated_file_policy_ready": True,
        "must_commit": [
            "data/aigc_battle/sequence_templates/*.json",
            "data/aigc_battle/mechanics/*/mechanic_profile.json",
            "data/aigc_battle/mechanics/*/content_recipe.json",
            "data/aigc_battle/generated/{profile}/packs/{pack}/runtime_manifest.json",
            "data/aigc_battle/generated/{profile}/packs/{pack}/validation_report.json",
            "data/aigc_battle/release_channels/current_release.json",
            "data/aigc_battle/release_channels/fallback_release.json",
            "data/aigc_battle/runtime/active_profile.json",
            "data/aigc_battle/pack_resolver.json",
            "data/aigc_battle/production_contract/*.json",
            "docs/AIGC_BATTLE_PRODUCTION_CONTRACT.md",
        ],
        "commit_when_stage_delivered": [
            "data/aigc_battle/generated/preview_runtime/*_report.json",
            "data/aigc_battle/generated/preview_runtime/*_report.md",
            "data/aigc_battle/generated/acceptance/*_report.json",
            "data/aigc_battle/generated/acceptance/*_report.md",
            "data/aigc_battle/generated/promotion/*_report.json",
            "data/aigc_battle/generated/promotion/*_report.md",
            "data/aigc_battle/generated/release_switch/*_report.json",
            "data/aigc_battle/generated/release_switch/*_report.md",
            "data/aigc_battle/generated/ai_studio/*_report.json",
            "data/aigc_battle/generated/ai_studio/*_report.md",
            "data/aigc_battle/generated/template_portfolio/*_report.json",
            "data/aigc_battle/generated/template_portfolio/*_report.md",
            "data/aigc_battle/generated/mechanic_template_matrix/*_report.json",
            "data/aigc_battle/generated/mechanic_template_matrix/*_report.md",
        ],
        "local_or_cleanable": [
            "data/aigc_battle/generated/**/latest_*_report.json",
            "data/aigc_battle/generated/**/latest_*_report.md",
            "data/aigc_battle/generated/**/tmp_*.json",
            "data/aigc_battle/generated/**/debug_*.json",
            "/tmp/aigc_*_check.json",
        ],
        "never_overwrite_without_gate": [
            "data/aigc_battle/release_channels/current_release.json",
            "data/aigc_battle/release_channels/fallback_release.json",
            "data/aigc_battle/runtime/active_profile.json",
            "data/aigc_battle/release/release_manifest_*.json",
            "data/aigc_battle/generated/**/packs/**/archived/**",
            "data/aigc_battle/promotion/human_review_notes/*.json",
        ],
        "policy_notes": [
            "runtime_manifest 只能由 export_runtime_manifest.py 生成",
            "current_release / active_profile 只能由 release switch / safe switch 写入",
            "本轮只冻结规则，不做大规模清理",
        ],
    }


def build_minimal_acceptance_command() -> dict[str, Any]:
    return {
        "minimal_acceptance_command_ready": True,
        "command_list": [
            "python3 tools/aigc_battle/build_pack_resolver.py",
            "python3 tools/aigc_battle/aigc_acceptance_run.py --profile weapon_followup_v0_1 --pack weapon_followup_balance_release_007 --samples 1",
            "python3 tools/aigc_battle/aigc_preview_restore_probe.py",
            "python3 tools/aigc_battle/aigc_candidate_promotion_probe.py",
            "python3 tools/aigc_battle/aigc_r13_release_switch_console_probe.py",
            "git diff --check",
        ],
        "must_run_serially": True,
        "forbids_parallel": True,
        "expected_reports": [
            "data/aigc_battle/generated/acceptance/latest_acceptance_report.json",
            "data/aigc_battle/generated/promotion/candidate_promotion_probe_report.json",
            "data/aigc_battle/generated/release_switch/r13_release_switch_console_probe_report.json",
        ],
        "pass_conditions": [
            "current release acceptance pass",
            "preview restore pass",
            "promotion negative cases pass",
            "release switch negative cases pass",
            "git diff --check pass",
        ],
    }


def build_deprecated_probe_inventory() -> dict[str, Any]:
    generated_root = ROOT / "data" / "aigc_battle" / "generated"
    active_required = [
        "generated/acceptance/r11_one_click_acceptance_run_probe_report.json",
        "generated/promotion/r12_candidate_promotion_gate_probe_report.json",
        "generated/release_switch/r13_release_switch_console_probe_report.json",
        "generated/preview_runtime/preview_restore_probe_report.json",
    ]
    active_stage_specific = [
        "generated/template_portfolio/r6_template_portfolio_release_strategy_probe_report.json",
        "generated/mechanic_template_matrix/r7_mechanic_template_matrix_probe_report.json",
        "generated/playable_hardening/r8_playable_content_hardening_probe_report.json",
        "generated/ai_studio/r9_ai_content_studio_probe_report.json",
    ]
    deprecated_candidate: list[str] = []
    historical_report: list[str] = []
    local_cleanable: list[str] = []
    for path in sorted(generated_root.rglob("*")):
        rel = path.relative_to(generated_root).as_posix()
        if path.is_dir():
            continue
        if rel.startswith("details/") or rel.startswith("review/"):
            continue
        if rel.endswith("latest_acceptance_report.json") or rel.endswith("latest_acceptance_report.md"):
            local_cleanable.append(f"generated/{rel}")
        elif "dashboard_server_probe" in rel or rel.endswith("_probe_report.md") or rel.endswith("_probe_report.json"):
            if f"generated/{rel}" not in active_required and f"generated/{rel}" not in active_stage_specific:
                historical_report.append(f"generated/{rel}")
        elif rel.endswith(".log") or "tmp_" in rel or "debug_" in rel:
            local_cleanable.append(f"generated/{rel}")
        elif "report" in rel and ("template_portfolio" in rel or "mechanic_template_matrix" in rel or "ai_studio" in rel):
            deprecated_candidate.append(f"generated/{rel}")
    deprecated_candidate = sorted(set(deprecated_candidate))
    historical_report = sorted(set(historical_report))
    local_cleanable = sorted(set(local_cleanable))
    return {
        "deprecated_probe_inventory_ready": True,
        "active_required": active_required,
        "active_stage_specific": active_stage_specific,
        "deprecated_candidate": deprecated_candidate,
        "historical_report": historical_report,
        "local_cleanable": local_cleanable,
        "active_required_count": len(active_required),
        "deprecated_candidate_count": len(deprecated_candidate),
        "historical_report_count": len(historical_report),
        "local_cleanable_count": len(local_cleanable),
        "safe_to_delete_now": local_cleanable,
        "delete_later_requires_manual_review": deprecated_candidate + historical_report,
    }


def build_contract_doc(
    schema_manifest: dict[str, Any],
    generated_file_policy: dict[str, Any],
    minimal_acceptance_command: dict[str, Any],
    deprecated_probe_inventory: dict[str, Any],
) -> str:
    current = read_json(CURRENT_RELEASE_PATH)
    lines = [
        "# AIGC Battle Production Contract",
        "",
        "## 当前正式生产路径",
        "",
        f"- current_release: `{current.get('mechanic_profile_id', '')} / {current.get('content_pack_id', '')} / {current.get('sequence_template_id', '')} / {current.get('build_variant', '')}`",
        "- fallback_release: `posture_opening_pressure_v0_1 / posture_opening_pressure_v0_1_formal_sequence_pack_001`",
        "",
        "## 唯一合法链路",
        "",
        "1. build",
        "2. validate",
        "3. export",
        "4. preview",
        "5. acceptance",
        "6. human review",
        "7. promotion",
        "8. release switch",
        "9. smoke",
        "10. rollback",
        "",
        "## Schema Manifest 摘要",
        "",
        f"- frozen schemas: `{', '.join(sorted(schema_manifest.get('schemas', {}).keys()))}`",
        f"- prohibited fields: `{', '.join(schema_manifest.get('prohibited_fields', []))}`",
        "",
        "## Generated File Policy 摘要",
        "",
        f"- must_commit count: `{len(generated_file_policy.get('must_commit', []))}`",
        f"- commit_when_stage_delivered count: `{len(generated_file_policy.get('commit_when_stage_delivered', []))}`",
        f"- local_or_cleanable count: `{len(generated_file_policy.get('local_or_cleanable', []))}`",
        f"- never_overwrite_without_gate count: `{len(generated_file_policy.get('never_overwrite_without_gate', []))}`",
        "",
        "## Minimal Acceptance Command",
        "",
    ]
    for command in minimal_acceptance_command.get("command_list", []):
        lines.append(f"- `{command}`")
    lines.extend(
        [
            "",
            "## 串行执行要求",
            "",
            "- 所有 active_profile / current_release 相关脚本必须串行执行。",
            "- 禁止并行跑 acceptance / preview / promotion / release switch。",
            "",
            "## 禁止事项",
            "",
            "- 不直接写 runtime_manifest。",
            "- 不直接写 current_release。",
            "- 不绕过 acceptance。",
            "- 不绕过 promotion。",
            "- 不并行跑 active_profile 相关脚本。",
            "",
            "## 后续扩展规则",
            "",
            "- 新机制必须接 schema。",
            "- 新模板必须接 resolver。",
            "- 新候选必须过 acceptance。",
            "- 新 release 必须过 promotion + release switch。",
            "",
            "## Deprecated Probe Inventory 摘要",
            "",
            f"- active_required_count: `{deprecated_probe_inventory.get('active_required_count', 0)}`",
            f"- deprecated_candidate_count: `{deprecated_probe_inventory.get('deprecated_candidate_count', 0)}`",
            f"- historical_report_count: `{deprecated_probe_inventory.get('historical_report_count', 0)}`",
            f"- local_cleanable_count: `{deprecated_probe_inventory.get('local_cleanable_count', 0)}`",
        ]
    )
    return "\n".join(lines) + "\n"


def build_report_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Production Contract Freeze Report",
        "",
        f"- schema_manifest_ready: `{report.get('schema_manifest_ready', False)}`",
        f"- generated_file_policy_ready: `{report.get('generated_file_policy_ready', False)}`",
        f"- minimal_acceptance_command_ready: `{report.get('minimal_acceptance_command_ready', False)}`",
        f"- deprecated_probe_inventory_ready: `{report.get('deprecated_probe_inventory_ready', False)}`",
        f"- production_contract_doc_ready: `{report.get('production_contract_doc_ready', False)}`",
        f"- current_release_unchanged: `{report.get('current_release_unchanged', False)}`",
        f"- active_profile_matches_current_release: `{report.get('active_profile_matches_current_release', False)}`",
        f"- production_contract_frozen: `{report.get('production_contract_frozen', False)}`",
    ]
    return "\n".join(lines) + "\n"


def read_state() -> dict[str, Any]:
    return {
        "current": read_json(CURRENT_RELEASE_PATH),
        "fallback": read_json(FALLBACK_RELEASE_PATH),
        "active": read_json(ACTIVE_PROFILE_PATH),
    }


def active_matches_current(active: dict[str, Any], current: dict[str, Any]) -> bool:
    return (
        str(active.get("active_mechanic_profile_id", "")) == str(current.get("mechanic_profile_id", ""))
        and str(active.get("active_content_pack_id", "")) == str(current.get("content_pack_id", ""))
    )


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
