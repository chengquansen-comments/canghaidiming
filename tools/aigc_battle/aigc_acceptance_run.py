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

from tools.aigc_battle import aigc_headless_evaluation_runner as evaluation_lib
from tools.aigc_battle import aigc_preview_runtime_control as preview_lib
from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import export_runtime_manifest as export_lib
from tools.aigc_battle import switch_active_profile as switch_lib
from tools.aigc_battle import validate_content_pack as validate_lib


PACK_RESOLVER_PATH = ROOT / "data" / "aigc_battle" / "pack_resolver.json"
ACCEPTANCE_DIR = ROOT / "data" / "aigc_battle" / "acceptance"
GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated" / "acceptance"
LATEST_JSON = GENERATED_DIR / "latest_acceptance_report.json"
LATEST_MD = GENERATED_DIR / "latest_acceptance_report.md"
ALLOWED_MODES = {"resolve_only", "smoke_only", "eval_only", "full"}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="one-click acceptance run")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--pack", required=True)
    parser.add_argument("--samples", type=int, default=2)
    parser.add_argument("--mode", default="full")
    parser.add_argument("--allow-current", action="store_true")
    parser.add_argument("--fail-fast", dest="fail_fast", action="store_true", default=True)
    parser.add_argument("--no-fail-fast", dest="fail_fast", action="store_false")
    args = parser.parse_args(argv[1:])
    report = run_acceptance(
        profile_id=args.profile,
        content_pack_id=args.pack,
        samples=args.samples,
        mode=args.mode,
        allow_current=args.allow_current,
        fail_fast=args.fail_fast,
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report.get("report_ready", False) else 1


def run_acceptance(
    profile_id: str,
    content_pack_id: str,
    samples: int = 2,
    mode: str = "full",
    allow_current: bool = False,
    fail_fast: bool = True,
) -> dict[str, Any]:
    if mode not in ALLOWED_MODES:
        raise SystemExit(f"unsupported mode: {mode}")
    if samples <= 0:
        raise SystemExit("samples must be positive")
    switch_lib.ensure_safe_id(profile_id, "profile_id")
    switch_lib.ensure_safe_id(content_pack_id, "content_pack_id")

    channels_before = release_lib.show_channels()
    current_before = channels_before.get("current_release", {})
    active_before = preview_lib.read_active_profile()
    acceptance_run_id = f"acceptance_{profile_id}_{content_pack_id}_{int(datetime.now(timezone.utc).timestamp())}"
    report: dict[str, Any] = {
        "acceptance_run_id": acceptance_run_id,
        "timestamp": now_iso(),
        "mechanic_profile_id": profile_id,
        "sequence_template_id": "",
        "content_pack_id": content_pack_id,
        "build_variant": "",
        "source_channel": "",
        "runtime_manifest_path": "",
        "validation_report_path": "",
        "pack_resolved": False,
        "pack_resolved_by_pack_resolver": False,
        "pack_identity_valid": False,
        "pack_previewable": False,
        "pack_acceptable": False,
        "validate_pass": False,
        "ready_for_runtime_export": False,
        "export_pass": False,
        "runtime_manifest_loaded": False,
        "preview_channel_ready": False,
        "preview_switch_ready": False,
        "preview_formal_entry_smoke_pass": False,
        "generated_loadout_count": 0,
        "expected_encounter_count": 0,
        "fallback_loadout_count": 0,
        "reward_coverage_complete": False,
        "runtime_primitive_ready": False,
        "preview_restore_ready": False,
        "evaluation_ready": False,
        "samples": samples,
        "evaluation_event_count": 0,
        "win_rate": 0.0,
        "avg_turn_count": 0.0,
        "avg_player_hp_end": 0.0,
        "too_hard_candidates": 0,
        "too_long_candidates": 0,
        "reward_mismatch_candidates": 0,
        "mechanic_trigger_rate": 0.0,
        "risk_summary_ready": False,
        "risk_level": "fail",
        "blocking_risks": [],
        "warning_risks": [],
        "acceptance_recommendation": "reject",
        "current_release_unchanged": False,
        "active_profile_restored": False,
        "active_profile_matches_current_release": False,
        "acceptance_pass": False,
        "acceptance_failed_stage": "",
        "acceptance_error": "",
        "report_ready": False,
    }

    preview_started = False
    try:
        resolver_entry = resolve_acceptance_entry(profile_id, content_pack_id)
        report["pack_resolved"] = True
        report["pack_resolved_by_pack_resolver"] = True
        report["pack_previewable"] = bool(resolver_entry.get("previewable", False))
        report["pack_acceptable"] = bool(resolver_entry.get("previewable", False))
        report["pack_identity_valid"] = bool(
            resolver_entry.get("resolver_entry_valid", False)
            and resolver_entry.get("sequence_template_id")
            and resolver_entry.get("content_pack_id")
        )
        report["source_channel"] = str(resolver_entry.get("channel", ""))
        report["sequence_template_id"] = str(resolver_entry.get("sequence_template_id", ""))
        report["build_variant"] = str(resolver_entry.get("build_variant", ""))
        report["runtime_manifest_path"] = str(resolver_entry.get("runtime_manifest_path", ""))
        report["validation_report_path"] = str(resolver_entry.get("validation_report_path", ""))

        is_current_pack = (
            profile_id == str(current_before.get("mechanic_profile_id", ""))
            and content_pack_id == str(current_before.get("content_pack_id", ""))
        )
        if is_current_pack and not allow_current:
            allow_current = True
        if not report["pack_acceptable"]:
            fail_stage(report, "resolve", "pack is not acceptable")
            return finalize_report(report, current_before, preview_started)

        if mode == "resolve_only":
            report["risk_summary_ready"] = True
            report["risk_level"] = "pass"
            report["acceptance_recommendation"] = "current_reference_pass" if is_current_pack else "ready_for_review"
            report["acceptance_pass"] = True
            return finalize_report(report, current_before, preview_started)

        report["validate_pass"] = run_module(validate_lib.main, ["validate_content_pack.py", profile_id, "--pack", content_pack_id]) == 0
        validation_report = preview_lib.read_required_json(ROOT / report["validation_report_path"]) if report["validation_report_path"] else {}
        report["ready_for_runtime_export"] = bool(validation_report.get("ready_for_runtime_export", False))
        report["runtime_primitive_ready"] = bool(
            validation_report.get("runtime_primitive_playable", True)
            and validation_report.get("runtime_primitives_supported", True)
        )
        if not report["validate_pass"]:
            fail_stage(report, "validate", "validate content pack failed")
            return finalize_report(report, current_before, preview_started)

        report["export_pass"] = run_module(export_lib.main, ["export_runtime_manifest.py", profile_id, "--pack", content_pack_id]) == 0
        runtime_manifest = preview_lib.read_required_json(ROOT / report["runtime_manifest_path"]) if report["runtime_manifest_path"] else {}
        report["runtime_manifest_loaded"] = bool(runtime_manifest)
        report["sequence_template_id"] = str(runtime_manifest.get("sequence_template_id", report["sequence_template_id"]))
        report["build_variant"] = str(runtime_manifest.get("build_variant", report["build_variant"]))
        if not report["export_pass"]:
            fail_stage(report, "export", "export runtime manifest failed")
            return finalize_report(report, current_before, preview_started)

        if mode in {"smoke_only", "full"}:
            preview_lib.set_preview(profile_id, content_pack_id, started_by="acceptance_run", reason=f"acceptance:{mode}")
            preview_started = True
            smoke = preview_lib.smoke_preview(allow_keep_preview=False)
            preview_started = False
            report["preview_channel_ready"] = True
            report["preview_switch_ready"] = True
            report["preview_formal_entry_smoke_pass"] = bool(smoke.get("preview_formal_entry_smoke_pass", False))
            report["generated_loadout_count"] = int(smoke.get("preview_generated_loadout_count", 0))
            report["expected_encounter_count"] = int(smoke.get("preview_expected_encounter_count", 0))
            report["fallback_loadout_count"] = int(smoke.get("preview_fallback_loadout_count", 0))
            report["reward_coverage_complete"] = bool(smoke.get("preview_reward_coverage_complete", False))
            report["preview_restore_ready"] = bool(smoke.get("restore_current_ready", False))
            if not report["preview_formal_entry_smoke_pass"]:
                fail_stage(report, "preview_smoke", "preview smoke failed")
                return finalize_report(report, current_before, preview_started)
        else:
            report["preview_channel_ready"] = True
            report["preview_switch_ready"] = True
            report["preview_formal_entry_smoke_pass"] = True
            report["generated_loadout_count"] = int(runtime_manifest.get("total_encounter_count", 0))
            report["expected_encounter_count"] = int(runtime_manifest.get("total_encounter_count", 0))
            report["fallback_loadout_count"] = 0
            report["reward_coverage_complete"] = True
            report["preview_restore_ready"] = True

        if mode in {"eval_only", "full"}:
            evaluation_report = evaluation_lib.evaluate_pack(profile_id, content_pack_id, samples)
            pack_metrics = evaluation_report.get("pack_metrics", {})
            report["evaluation_ready"] = bool(evaluation_report.get("evaluation_ready", False))
            report["evaluation_event_count"] = int(evaluation_report.get("evaluation_event_count", 0))
            report["win_rate"] = float(pack_metrics.get("win_rate", 0) or 0)
            report["avg_turn_count"] = float(pack_metrics.get("avg_turn_count", 0) or 0)
            report["avg_player_hp_end"] = float(pack_metrics.get("avg_player_hp_end", 0) or 0)
            report["too_hard_candidates"] = int(len(pack_metrics.get("too_hard_candidates", [])))
            report["too_long_candidates"] = int(len(pack_metrics.get("too_long_candidates", [])))
            report["reward_mismatch_candidates"] = int(len(pack_metrics.get("reward_mismatch_candidates", [])))
            report["mechanic_trigger_rate"] = float(pack_metrics.get("runtime_primitive_trigger_rate", 0) or 0)
            if not report["evaluation_ready"]:
                fail_stage(report, "evaluation", "evaluation failed")
                return finalize_report(report, current_before, preview_started)
        else:
            report["evaluation_ready"] = True

        content_pack_summary_path = switch_lib.resolve_generated_dir(profile_id, content_pack_id) / "content_pack_summary.json"
        content_pack_summary = preview_lib.read_json(content_pack_summary_path) if content_pack_summary_path.exists() else {}
        build_risk_summary(report, resolver_entry, content_pack_summary, is_current_pack)
        report["acceptance_pass"] = (
            report["pack_resolved"]
            and report["pack_resolved_by_pack_resolver"]
            and report["validate_pass"]
            and report["export_pass"]
            and report["preview_formal_entry_smoke_pass"]
            and report["fallback_loadout_count"] == 0
            and report["reward_coverage_complete"]
            and report["evaluation_ready"]
            and report["risk_summary_ready"]
        )
        return finalize_report(report, current_before, preview_started)
    except SystemExit as exc:
        fail_stage(report, report["acceptance_failed_stage"] or "resolve", str(exc))
        return finalize_report(report, current_before, preview_started)
    except Exception as exc:  # noqa: BLE001
        fail_stage(report, report["acceptance_failed_stage"] or "internal", str(exc))
        return finalize_report(report, current_before, preview_started)


def resolve_acceptance_entry(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    resolver = preview_lib.read_required_json(PACK_RESOLVER_PATH)
    for entry in resolver.get("entries", []):
        if str(entry.get("mechanic_profile_id", "")) == profile_id and str(entry.get("content_pack_id", "")) == content_pack_id:
            return entry
    raise SystemExit("pack not found in pack_resolver")


def run_module(main_fn: Any, argv: list[str]) -> int:
    try:
        result = main_fn(argv)
    except SystemExit as exc:
        code = exc.code
        return int(code) if isinstance(code, int) else 1
    return int(result) if isinstance(result, int) else 0


def build_risk_summary(
    report: dict[str, Any],
    resolver_entry: dict[str, Any],
    content_pack_summary: dict[str, Any],
    is_current_pack: bool,
) -> None:
    blocking_risks: list[str] = []
    warning_risks: list[str] = []
    if not report["pack_identity_valid"]:
        blocking_risks.append("pack_identity_invalid")
    if not report["validate_pass"]:
        blocking_risks.append("validate_failed")
    if not report["export_pass"]:
        blocking_risks.append("export_failed")
    if not report["preview_formal_entry_smoke_pass"]:
        blocking_risks.append("preview_smoke_failed")
    if report["fallback_loadout_count"] > 0:
        blocking_risks.append("fallback_loadout_detected")
    if not report["reward_coverage_complete"]:
        blocking_risks.append("reward_coverage_incomplete")

    if report["evaluation_ready"]:
        if report["win_rate"] < 0.30:
            warning_risks.append("low_win_rate")
        if report["win_rate"] > 0.90:
            warning_risks.append("win_rate_too_high")
        if report["avg_turn_count"] > 8.0:
            warning_risks.append("avg_turn_too_high")
        if report["too_hard_candidates"] > max(1, report["expected_encounter_count"] // 3):
            warning_risks.append("too_many_hard_encounters")
        if report["too_long_candidates"] > max(1, report["expected_encounter_count"] // 3):
            warning_risks.append("too_many_long_encounters")
        if report["reward_mismatch_candidates"] > 0:
            warning_risks.append("reward_mismatch_detected")
        if report["mechanic_trigger_rate"] < 0.6:
            warning_risks.append("mechanic_trigger_rate_low")

    if bool(content_pack_summary.get("deterministic_fill_used", False)):
        warning_risks.append("deterministic_fill_used")
    if str(resolver_entry.get("channel", "")) == "ai_studio_review":
        warning_risks.append("ai_studio_review_pack")

    if blocking_risks:
        report["risk_level"] = "fail"
        report["acceptance_recommendation"] = "reject"
    elif is_current_pack:
        report["risk_level"] = "pass"
        report["acceptance_recommendation"] = "current_reference_pass"
    elif warning_risks:
        report["risk_level"] = "warning"
        report["acceptance_recommendation"] = "needs_balance" if (
            "ai_studio_review_pack" in warning_risks or "deterministic_fill_used" in warning_risks
        ) else "ready_for_review"
    else:
        report["risk_level"] = "pass"
        report["acceptance_recommendation"] = "ready_for_review"

    report["blocking_risks"] = blocking_risks
    report["warning_risks"] = warning_risks
    report["risk_summary_ready"] = True


def finalize_report(report: dict[str, Any], current_before: dict[str, Any], preview_started: bool) -> dict[str, Any]:
    current_after = release_lib.show_channels().get("current_release", {})
    active_after = preview_lib.read_active_profile()
    if preview_started or not preview_lib.active_matches_current(active_after, current_after):
        try:
            preview_lib.restore_current()
        except SystemExit:
            pass
        current_after = release_lib.show_channels().get("current_release", {})
        active_after = preview_lib.read_active_profile()
    report["current_release_unchanged"] = current_after == current_before
    report["active_profile_restored"] = preview_lib.active_matches_current(active_after, current_after)
    report["active_profile_matches_current_release"] = report["active_profile_restored"]
    if not report["current_release_unchanged"]:
        if "current_release_changed" not in report["blocking_risks"]:
            report["blocking_risks"].append("current_release_changed")
    if not report["active_profile_matches_current_release"]:
        if "restore_failed" not in report["blocking_risks"]:
            report["blocking_risks"].append("restore_failed")
    if report["blocking_risks"]:
        report["risk_level"] = "fail"
        report["acceptance_recommendation"] = "reject"
    if not (report["risk_summary_ready"] and report["current_release_unchanged"] and report["active_profile_matches_current_release"]):
        report["acceptance_pass"] = False
    report["report_ready"] = True
    write_acceptance_report(report)
    return report


def fail_stage(report: dict[str, Any], stage: str, error: str) -> None:
    if not report["acceptance_failed_stage"]:
        report["acceptance_failed_stage"] = stage
    report["acceptance_error"] = error


def write_acceptance_report(report: dict[str, Any]) -> None:
    json_path = acceptance_json_path(str(report.get("mechanic_profile_id", "")), str(report.get("content_pack_id", "")))
    md_path = acceptance_md_path(str(report.get("mechanic_profile_id", "")), str(report.get("content_pack_id", "")))
    report["report_json_path"] = to_relative(json_path)
    report["report_md_path"] = to_relative(md_path)
    write_json(json_path, report)
    md_path.write_text(build_markdown(report), encoding="utf-8")
    write_json(LATEST_JSON, report)
    LATEST_MD.write_text(build_markdown(report), encoding="utf-8")


def acceptance_json_path(profile_id: str, content_pack_id: str) -> Path:
    return ACCEPTANCE_DIR / f"{profile_id}__{content_pack_id}__acceptance_report.json"


def acceptance_md_path(profile_id: str, content_pack_id: str) -> Path:
    return ACCEPTANCE_DIR / f"{profile_id}__{content_pack_id}__acceptance_report.md"


def build_markdown(report: dict[str, Any]) -> str:
    return "\n".join(
        [
            "# Acceptance Report",
            "",
            f"- mechanic_profile_id: `{report.get('mechanic_profile_id', '')}`",
            f"- content_pack_id: `{report.get('content_pack_id', '')}`",
            f"- sequence_template_id: `{report.get('sequence_template_id', '')}`",
            f"- source_channel: `{report.get('source_channel', '')}`",
            f"- acceptance_pass: `{report.get('acceptance_pass', False)}`",
            f"- validate_pass: `{report.get('validate_pass', False)}`",
            f"- export_pass: `{report.get('export_pass', False)}`",
            f"- preview_formal_entry_smoke_pass: `{report.get('preview_formal_entry_smoke_pass', False)}`",
            f"- fallback_loadout_count: `{report.get('fallback_loadout_count', 0)}`",
            f"- evaluation_ready: `{report.get('evaluation_ready', False)}`",
            f"- risk_level: `{report.get('risk_level', '')}`",
            f"- acceptance_recommendation: `{report.get('acceptance_recommendation', '')}`",
            f"- active_profile_matches_current_release: `{report.get('active_profile_matches_current_release', False)}`",
            "",
        ]
    ) + "\n"


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def to_relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
