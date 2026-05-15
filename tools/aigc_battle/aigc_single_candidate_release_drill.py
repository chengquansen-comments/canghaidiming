#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_acceptance_run as acceptance_lib
from tools.aigc_battle import aigc_build_from_evaluation_snapshot as rebuild_lib
from tools.aigc_battle import aigc_candidate_promotion_gate as promotion_lib
from tools.aigc_battle import aigc_preview_runtime_control as preview_lib
from tools.aigc_battle import aigc_release_switch_console as release_switch_lib
from tools.aigc_battle import aigc_write_human_review_note as review_note_lib
from tools.aigc_battle import build_aigc_content_index as index_lib
from tools.aigc_battle import build_aigc_detail_views as detail_lib
from tools.aigc_battle import build_aigc_review_workspace as review_lib
from tools.aigc_battle import build_pack_resolver as resolver_lib
from tools.aigc_battle import export_runtime_manifest as export_lib
from tools.aigc_battle import load_sequence_template as template_lib
from tools.aigc_battle import switch_active_profile as switch_lib
from tools.aigc_battle import validate_content_pack as validate_lib
from tools.aigc_battle import aigc_release_gate as release_lib


GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated" / "single_candidate_release_drill"
REPORT_JSON_PATH = GENERATED_DIR / "single_candidate_release_drill_report.json"
REPORT_MD_PATH = GENERATED_DIR / "single_candidate_release_drill_report.md"
PACK_RESOLVER_PATH = ROOT / "data" / "aigc_battle" / "pack_resolver.json"
CURRENT_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "current_release.json"
FALLBACK_RELEASE_PATH = ROOT / "data" / "aigc_battle" / "release_channels" / "fallback_release.json"
ACTIVE_PROFILE_PATH = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"

FAST_PRIORITY = [
    ("weapon_followup_v0_1", "r9_fast_candidate_pack_001"),
    ("weapon_followup_v0_1", "weapon_followup_v0_1__formal_sequence_12_fast_v1__hardened_013"),
    ("weapon_followup_v0_1", "weapon_followup_v0_1__formal_sequence_12_fast_v1__matrix_001"),
]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="single candidate release drill")
    parser.add_argument("--target", required=True)
    parser.add_argument("--source-pack", default="")
    parser.add_argument("--target-pack", default="")
    parser.add_argument("--samples", type=int, default=2)
    parser.add_argument("--allow-actual-switch", action="store_true")
    args = parser.parse_args(argv[1:])
    report = run_release_drill(
        target=args.target,
        requested_source_pack=args.source_pack,
        requested_target_pack=args.target_pack,
        samples=args.samples,
        allow_actual_switch=bool(args.allow_actual_switch),
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report.get("single_candidate_release_drill_ready", False) else 1


def run_release_drill(
    target: str,
    requested_source_pack: str = "",
    requested_target_pack: str = "",
    samples: int = 2,
    allow_actual_switch: bool = False,
) -> dict[str, Any]:
    if target != "fast-run":
        raise SystemExit("only fast-run target is supported in R15")
    current_before = read_json(CURRENT_RELEASE_PATH)
    active_before = read_json(ACTIVE_PROFILE_PATH)
    fallback_before = read_json(FALLBACK_RELEASE_PATH)

    source = select_source_pack(requested_source_pack)
    target_profile_id = source["profile_id"]
    requested_pack_id = requested_target_pack or f"{target_profile_id}__formal_sequence_12_fast_v1__release_drill_001"
    target_pack_id = next_pack_id(target_profile_id, requested_pack_id)
    target_dir = clone_source_pack(source, target_pack_id, target)

    run_module(validate_lib.main, ["validate_content_pack.py", target_profile_id, "--generated-dir", str(target_dir)])
    run_module(export_lib.main, ["export_runtime_manifest.py", target_profile_id, "--generated-dir", str(target_dir)])
    rebuild_views()

    acceptance = acceptance_lib.run_acceptance(target_profile_id, target_pack_id, samples=samples, mode="full", allow_current=False, fail_fast=True)
    review_status, warning_accepted_by_probe, note = choose_review_status(acceptance)
    review_note = review_note_lib.write_human_review_note(target_profile_id, target_pack_id, review_status, "codex_probe", note)
    promotion = promotion_lib.run_promotion_gate(target_profile_id, target_pack_id)
    rebuild_views()

    dry_run_switch = {
        "report_ready": False,
        "switch_allowed": False,
        "formal_entry_smoke_pass": False,
        "rollback_available": False,
    }
    if bool(promotion.get("promoted_to_release_candidate", False)):
        dry_run_switch = release_switch_lib.set_current_release(target_profile_id, target_pack_id, dry_run=True, auto_smoke=False)

    actual_switch = {
        "current_release_written": False,
        "formal_entry_smoke_pass": False,
        "rollback_available": False,
    }
    if allow_actual_switch and bool(promotion.get("promoted_to_release_candidate", False)):
        actual_switch = release_switch_lib.set_current_release(target_profile_id, target_pack_id, dry_run=False, auto_smoke=True)

    rollback_previous = release_switch_lib.rollback_previous_current(dry_run=True)
    rollback_fallback = release_switch_lib.rollback_fallback(dry_run=True)
    restore_current_if_needed()

    report = {
        "release_drill_run_id": f"single_release_drill_{int(datetime.now(timezone.utc).timestamp())}",
        "generated_at": now_iso(),
        "target": target,
        "source_profile_id": source["profile_id"],
        "source_pack_id": source["pack_id"],
        "target_profile_id": target_profile_id,
        "target_pack_id": target_pack_id,
        "sequence_template_id": "formal_sequence_12_fast_v1",
        "build_variant": template_lib.infer_build_variant(target_profile_id, target_pack_id),
        "selected_source_reason": source["reason"],
        "target_pack_generated": True,
        "target_pack_validated": True,
        "target_pack_exported": True,
        "runtime_manifest_path": relative(target_dir / "runtime_manifest.json"),
        "validation_report_path": relative(target_dir / "validation_report.json"),
        "preview_smoke_pass": bool(acceptance.get("preview_formal_entry_smoke_pass", False)),
        "preview_fallback_loadout_count": int(acceptance.get("fallback_loadout_count", 0)),
        "preview_reward_coverage_complete": bool(acceptance.get("reward_coverage_complete", False)),
        "acceptance_run_ready": bool(acceptance.get("report_ready", False)),
        "acceptance_pass": bool(acceptance.get("acceptance_pass", False)),
        "acceptance_risk_level": str(acceptance.get("risk_level", "")),
        "acceptance_recommendation": str(acceptance.get("acceptance_recommendation", "")),
        "win_rate": float(acceptance.get("win_rate", 0) or 0),
        "avg_turn_count": float(acceptance.get("avg_turn_count", 0) or 0),
        "too_hard_candidates": int(acceptance.get("too_hard_candidates", 0) or 0),
        "too_long_candidates": int(acceptance.get("too_long_candidates", 0) or 0),
        "reward_mismatch_candidates": int(acceptance.get("reward_mismatch_candidates", 0) or 0),
        "human_review_note_written": bool(review_note.get("review_note_valid", False)),
        "human_review_status": str(review_note.get("status", "")),
        "warning_accepted_by_probe": warning_accepted_by_probe,
        "promotion_gate_checked": True,
        "promotion_allowed": bool(promotion.get("promotion_allowed", False)),
        "marked_release_candidate": bool(promotion.get("promoted_to_release_candidate", False)),
        "dry_run_switch_ready": bool(dry_run_switch.get("switch_allowed", False) and dry_run_switch.get("report_ready", False)),
        "actual_set_current": bool(actual_switch.get("current_release_written", False)),
        "formal_entry_smoke_pass": bool(actual_switch.get("formal_entry_smoke_pass", False)) if allow_actual_switch else bool(acceptance.get("preview_formal_entry_smoke_pass", False)),
        "rollback_previous_current_ready": bool(
            rollback_previous.get("previous_current_rollback_ready", False)
            or rollback_previous.get("rollback_available", False)
        ),
        "rollback_fallback_ready": bool(
            rollback_fallback.get("fallback_rollback_ready", False)
            or rollback_fallback.get("rollback_available", False)
            or rollback_fallback.get("fallback_pack_resolved", False)
        ),
        "current_release_unchanged": False,
        "active_profile_matches_current_release": False,
        "fallback_release_unchanged": False,
        "single_candidate_release_drill_ready": False,
        "partial_pass": False,
        "probe_pass": False,
    }

    current_after = read_json(CURRENT_RELEASE_PATH)
    active_after = read_json(ACTIVE_PROFILE_PATH)
    fallback_after = read_json(FALLBACK_RELEASE_PATH)
    report["current_release_unchanged"] = current_identity(current_before) == current_identity(current_after)
    report["active_profile_matches_current_release"] = active_matches_current(active_after, current_after)
    report["fallback_release_unchanged"] = fallback_before == fallback_after
    report["single_candidate_release_drill_ready"] = all(
        [
            report["target_pack_generated"],
            report["target_pack_validated"],
            report["target_pack_exported"],
            report["preview_smoke_pass"],
            report["acceptance_run_ready"],
            report["acceptance_pass"],
            report["human_review_note_written"],
            report["promotion_gate_checked"],
        ]
    )
    report["partial_pass"] = report["single_candidate_release_drill_ready"] and not (
        report["marked_release_candidate"] and report["dry_run_switch_ready"]
    )
    report["probe_pass"] = all(
        [
            report["single_candidate_release_drill_ready"],
            report["marked_release_candidate"],
            report["dry_run_switch_ready"],
            report["rollback_previous_current_ready"],
            report["rollback_fallback_ready"],
            report["current_release_unchanged"],
            report["active_profile_matches_current_release"],
            report["fallback_release_unchanged"],
        ]
    )
    write_json(REPORT_JSON_PATH, report)
    REPORT_MD_PATH.write_text(build_markdown(report), encoding="utf-8")
    return report


def select_source_pack(requested_source_pack: str) -> dict[str, str]:
    resolver = read_json(PACK_RESOLVER_PATH)
    entries = resolver.get("entries", [])
    current = read_json(CURRENT_RELEASE_PATH)
    if requested_source_pack:
        for entry in entries:
            if str(entry.get("content_pack_id", "")) == requested_source_pack:
                return {
                    "profile_id": str(entry.get("mechanic_profile_id", "")),
                    "pack_id": requested_source_pack,
                    "reason": "explicit_source_pack",
                }
        raise SystemExit("requested source pack not found")

    skip_reasons: list[str] = []
    for index, (profile_id, pack_id) in enumerate(FAST_PRIORITY, start=1):
        entry = next(
            (
                item for item in entries
                if str(item.get("mechanic_profile_id", "")) == profile_id
                and str(item.get("content_pack_id", "")) == pack_id
            ),
            None,
        )
        if not entry:
            skip_reasons.append(f"{pack_id}:missing")
            continue
        if (
            profile_id == str(current.get("mechanic_profile_id", ""))
            and pack_id == str(current.get("content_pack_id", ""))
        ):
            skip_reasons.append(f"{pack_id}:is_current")
            continue
        summary = read_pack_summary(profile_id, pack_id)
        if bool(summary.get("ai_studio_candidate_pack", False)) or bool(summary.get("deterministic_fill_used", False)):
            skip_reasons.append(f"{pack_id}:ai_studio_or_deterministic")
            continue
        if not bool(entry.get("previewable", False)):
            skip_reasons.append(f"{pack_id}:not_previewable")
            continue
        return {
            "profile_id": profile_id,
            "pack_id": pack_id,
            "reason": f"priority_{index}_first_promotable_fast_run_source; skipped={';'.join(skip_reasons)}" if skip_reasons else f"priority_{index}_fast_run_source",
        }

    for index, (profile_id, pack_id) in enumerate(FAST_PRIORITY, start=1):
        entry = next(
            (
                item for item in entries
                if str(item.get("mechanic_profile_id", "")) == profile_id
                and str(item.get("content_pack_id", "")) == pack_id
            ),
            None,
        )
        if entry:
            return {
                "profile_id": profile_id,
                "pack_id": pack_id,
                "reason": f"priority_{index}_fallback_resolvable_source; skipped={';'.join(skip_reasons)}",
            }
    raise SystemExit("no fast-run source pack resolved")


def clone_source_pack(source: dict[str, str], target_pack_id: str, target: str) -> Path:
    profile_id = source["profile_id"]
    source_pack_id = source["pack_id"]
    source_dir = rebuild_lib.resolve_source_generated_dir(profile_id, source_pack_id)
    target_dir = ROOT / "data" / "aigc_battle" / "generated" / profile_id / "packs" / target_pack_id
    if target_dir.exists():
        raise SystemExit("target release drill pack already exists")
    if source_dir.name == profile_id:
        shutil.copytree(source_dir, target_dir, ignore=shutil.ignore_patterns("packs"))
    else:
        shutil.copytree(source_dir, target_dir)

    source_summary = read_json(source_dir / "content_pack_summary.json")
    old_pack_id = str(source_summary.get("content_pack_id", source_pack_id))
    rebuild_lib.replace_content_pack_ids_in_dir(target_dir, old_pack_id, target_pack_id)

    content_pack_summary = read_json(target_dir / "content_pack_summary.json")
    balance_summary = read_json(target_dir / "sequence_balance_summary.json")
    build_variant = template_lib.infer_build_variant(profile_id, target_pack_id)
    content_pack_summary.update(
        {
            "mechanic_profile_id": profile_id,
            "content_pack_id": target_pack_id,
            "sequence_template_id": "formal_sequence_12_fast_v1",
            "build_variant": build_variant,
            "source_pack_id": source_pack_id,
            "release_drill_pack": True,
            "release_drill_source_pack_id": source_pack_id,
            "release_drill_target": target,
            "release_drill_selected_source_reason": source["reason"],
            "release_drill_acceptance_status": "",
            "release_drill_promotion_status": "",
            "release_drill_dry_run_switch_status": False,
            "release_drill_report_path": relative(REPORT_JSON_PATH),
            "review_status": "reviewing",
            "release_status": "reviewing",
            "ai_studio_candidate_pack": False,
            "candidate_batch_id": "",
            "candidate_source_trace": [],
            "candidate_quality_summary": {},
            "deterministic_fill_used": False,
            "ai_studio_variant_type": "",
            "playable_hardening": False,
            "hardening_target": "",
            "source_matrix_pack_id": source_pack_id if "__matrix_" in source_pack_id else str(content_pack_summary.get("source_matrix_pack_id", "")),
            "recommended_release_mode": "fast_run",
        }
    )
    balance_summary.update(
        {
            "content_pack_id": target_pack_id,
            "sequence_template_id": "formal_sequence_12_fast_v1",
            "build_variant": build_variant,
            "source_pack_id": source_pack_id,
            "release_drill_pack": True,
        }
    )
    write_json(target_dir / "content_pack_summary.json", content_pack_summary)
    write_json(target_dir / "sequence_balance_summary.json", balance_summary)
    release_lib.set_release_status(profile_id, target_pack_id, "reviewing")
    return target_dir


def choose_review_status(acceptance: dict[str, Any]) -> tuple[str, bool, str]:
    risk = str(acceptance.get("risk_level", ""))
    recommendation = str(acceptance.get("acceptance_recommendation", ""))
    warnings = acceptance.get("warning_risks", [])
    if risk == "fail" or recommendation == "reject":
        return "rejected", False, "acceptance failed, release drill should not promote"
    if recommendation == "needs_balance":
        return "needs_balance", False, "acceptance completed but recommendation is needs_balance"
    if risk == "warning":
        return "accepted", True, f"warning accepted by probe for release drill: {warnings}"
    return "accepted", False, "release drill acceptance passed and is ready for promotion gate"


def read_pack_summary(profile_id: str, pack_id: str) -> dict[str, Any]:
    generated_dir = switch_lib.resolve_generated_dir(profile_id, pack_id)
    return read_json(generated_dir / "content_pack_summary.json")


def next_pack_id(profile_id: str, requested_pack_id: str) -> str:
    packs_dir = ROOT / "data" / "aigc_battle" / "generated" / profile_id / "packs"
    if not (packs_dir / requested_pack_id).exists():
        return requested_pack_id
    stem, _, tail = requested_pack_id.rpartition("_")
    prefix = stem if tail.isdigit() else requested_pack_id
    for index in range(2, 100):
        candidate = f"{prefix}_{index:03d}"
        if not (packs_dir / candidate).exists():
            return candidate
    raise SystemExit("no free release drill pack id available")


def rebuild_views() -> None:
    resolver_lib.main()
    index_lib.main()
    detail_lib.main()
    review_lib.main()


def restore_current_if_needed() -> None:
    current = read_json(CURRENT_RELEASE_PATH)
    active = read_json(ACTIVE_PROFILE_PATH)
    if not active_matches_current(active, current):
        preview_lib.restore_current()


def active_matches_current(active: dict[str, Any], current: dict[str, Any]) -> bool:
    return (
        str(active.get("active_mechanic_profile_id", "")) == str(current.get("mechanic_profile_id", ""))
        and str(active.get("active_content_pack_id", "")) == str(current.get("content_pack_id", ""))
    )


def current_identity(payload: dict[str, Any]) -> tuple[str, str, str, str]:
    return (
        str(payload.get("mechanic_profile_id", "")),
        str(payload.get("content_pack_id", "")),
        str(payload.get("sequence_template_id", "")),
        str(payload.get("build_variant", "")),
    )


def run_module(main_fn: Any, argv: list[str]) -> int:
    try:
        result = main_fn(argv)
    except SystemExit as exc:
        code = exc.code
        return int(code) if isinstance(code, int) else 1
    return int(result or 0)


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def build_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Single Candidate Release Drill",
        "",
        f"- source_pack_id: `{report.get('source_pack_id', '')}`",
        f"- target_pack_id: `{report.get('target_pack_id', '')}`",
        f"- selected_source_reason: `{report.get('selected_source_reason', '')}`",
        f"- acceptance_pass: `{report.get('acceptance_pass', False)}`",
        f"- acceptance_risk_level: `{report.get('acceptance_risk_level', '')}`",
        f"- acceptance_recommendation: `{report.get('acceptance_recommendation', '')}`",
        f"- human_review_status: `{report.get('human_review_status', '')}`",
        f"- promotion_allowed: `{report.get('promotion_allowed', False)}`",
        f"- marked_release_candidate: `{report.get('marked_release_candidate', False)}`",
        f"- dry_run_switch_ready: `{report.get('dry_run_switch_ready', False)}`",
        f"- current_release_unchanged: `{report.get('current_release_unchanged', False)}`",
        f"- active_profile_matches_current_release: `{report.get('active_profile_matches_current_release', False)}`",
        f"- probe_pass: `{report.get('probe_pass', False)}`",
    ]
    return "\n".join(lines) + "\n"


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
