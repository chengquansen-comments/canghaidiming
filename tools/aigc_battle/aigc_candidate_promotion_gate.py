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

from tools.aigc_battle import aigc_acceptance_run as acceptance_lib
from tools.aigc_battle import aigc_preview_runtime_control as preview_lib
from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import aigc_write_human_review_note as review_note_lib
from tools.aigc_battle import build_aigc_content_index as index_lib
from tools.aigc_battle import build_aigc_detail_views as detail_lib
from tools.aigc_battle import build_aigc_review_workspace as review_lib
from tools.aigc_battle import build_pack_resolver as resolver_lib
from tools.aigc_battle import switch_active_profile as switch_lib


PACK_RESOLVER_PATH = ROOT / "data" / "aigc_battle" / "pack_resolver.json"
PROMOTION_DIR = ROOT / "data" / "aigc_battle" / "promotion"
PROMOTION_HISTORY_PATH = PROMOTION_DIR / "promotion_history.jsonl"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="candidate promotion gate")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--pack", required=True)
    args = parser.parse_args(argv[1:])
    payload = run_promotion_gate(args.profile, args.pack)
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0


def run_promotion_gate(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    switch_lib.ensure_safe_id(profile_id, "profile_id")
    switch_lib.ensure_safe_id(content_pack_id, "content_pack_id")
    current_before = release_lib.show_channels().get("current_release", {})
    active_before = preview_lib.read_active_profile()
    payload: dict[str, Any] = {
        "promotion_run_id": f"promotion_{profile_id}_{content_pack_id}_{int(datetime.now(timezone.utc).timestamp())}",
        "timestamp": now_iso(),
        "mechanic_profile_id": profile_id,
        "sequence_template_id": "",
        "content_pack_id": content_pack_id,
        "build_variant": "",
        "source_channel": "",
        "acceptance_report_path": "",
        "human_review_note_path": "",
        "pack_resolved": False,
        "acceptance_report_found": False,
        "acceptance_pass": False,
        "acceptance_risk_level": "",
        "acceptance_recommendation": "",
        "human_review_note_found": False,
        "human_review_status": "",
        "human_review_accepted": False,
        "release_gate_policy_pass": False,
        "promotion_allowed": False,
        "promoted_to_release_candidate": False,
        "release_candidate_manifest_path": "",
        "current_release_unchanged": False,
        "active_profile_matches_current_release": False,
        "promotion_error": "",
        "blocked_reasons": [],
    }
    try:
        entry = resolve_pack(profile_id, content_pack_id)
        payload["pack_resolved"] = True
        payload["sequence_template_id"] = str(entry.get("sequence_template_id", ""))
        payload["build_variant"] = str(entry.get("build_variant", ""))
        payload["source_channel"] = str(entry.get("channel", ""))
        if str(entry.get("release_status", "")) == "archived":
            payload["blocked_reasons"].append("archived_pack")
            return finalize_promotion(payload, current_before, active_before)

        acceptance_path = acceptance_lib.acceptance_json_path(profile_id, content_pack_id)
        if acceptance_path.exists():
            acceptance_report = preview_lib.read_json(acceptance_path)
            payload["acceptance_report_found"] = True
            payload["acceptance_report_path"] = acceptance_path.relative_to(ROOT).as_posix()
            payload["acceptance_pass"] = bool(acceptance_report.get("acceptance_pass", False))
            payload["acceptance_risk_level"] = str(acceptance_report.get("risk_level", ""))
            payload["acceptance_recommendation"] = str(acceptance_report.get("acceptance_recommendation", ""))
        else:
            payload["blocked_reasons"].append("no_acceptance_report")

        note_path = review_note_lib.human_review_note_path(profile_id, content_pack_id)
        if note_path.exists():
            note = preview_lib.read_json(note_path)
            payload["human_review_note_found"] = True
            payload["human_review_note_path"] = note_path.relative_to(ROOT).as_posix()
            payload["human_review_status"] = str(note.get("status", ""))
            payload["human_review_accepted"] = payload["human_review_status"] == "accepted"
        else:
            payload["blocked_reasons"].append("human_review_missing")

        if not payload["acceptance_report_found"]:
            payload["blocked_reasons"].append("pack_not_resolved" if not payload["pack_resolved"] else "acceptance_report_missing")
        if payload["acceptance_report_found"] and not payload["acceptance_pass"]:
            payload["blocked_reasons"].append("acceptance_failed")
        if payload["acceptance_risk_level"] == "fail":
            payload["blocked_reasons"].append("risk_level_fail")
        if payload["acceptance_recommendation"] == "reject":
            payload["blocked_reasons"].append("recommendation_reject")
        if payload["human_review_note_found"] and not payload["human_review_accepted"]:
            payload["blocked_reasons"].append("human_review_not_accepted")

        payload["release_gate_policy_pass"] = compute_release_gate_policy_pass(profile_id, content_pack_id, payload)
        payload["promotion_allowed"] = (
            payload["pack_resolved"]
            and payload["acceptance_report_found"]
            and payload["acceptance_pass"]
            and payload["acceptance_risk_level"] != "fail"
            and payload["acceptance_recommendation"] != "reject"
            and payload["human_review_note_found"]
            and payload["human_review_accepted"]
            and payload["release_gate_policy_pass"]
        )

        if payload["promotion_allowed"]:
            release_lib.set_release_status(profile_id, content_pack_id, "accepted")
            manifest = release_lib.get_release_status(profile_id, content_pack_id)
            if not manifest.get("frozen", False):
                release_lib.freeze_pack(profile_id, content_pack_id)
            manifest = release_lib.mark_release_candidate(profile_id, content_pack_id)
            payload["promoted_to_release_candidate"] = manifest.get("release_status") == "release_candidate"
            payload["release_candidate_manifest_path"] = release_lib.release_manifest_path(profile_id, content_pack_id).relative_to(ROOT).as_posix()
            resolver_lib.main()
            index_lib.main()
            detail_lib.main()
            review_lib.main()
        write_promotion_report(payload)
        append_history(payload, "ok" if payload["promoted_to_release_candidate"] else "blocked")
        return finalize_promotion(payload, current_before, active_before)
    except SystemExit as exc:
        payload["promotion_error"] = str(exc)
        if not payload["blocked_reasons"]:
            payload["blocked_reasons"].append("release_gate_policy_fail")
        write_promotion_report(payload)
        append_history(payload, "fail")
        return finalize_promotion(payload, current_before, active_before)


def compute_release_gate_policy_pass(profile_id: str, content_pack_id: str, payload: dict[str, Any]) -> bool:
    if not payload["pack_resolved"]:
        return False
    if payload["acceptance_recommendation"] in {"reject", "needs_balance"}:
        return False
    try:
        release_lib.validate_release_pack(profile_id, content_pack_id, allow_archived=False)
        return True
    except SystemExit:
        return False


def finalize_promotion(payload: dict[str, Any], current_before: dict[str, Any], active_before: dict[str, Any]) -> dict[str, Any]:
    current_after = release_lib.show_channels().get("current_release", {})
    active_after = preview_lib.read_active_profile()
    payload["current_release_unchanged"] = current_before == current_after
    payload["active_profile_matches_current_release"] = preview_lib.active_matches_current(active_after, current_after)
    if not payload["current_release_unchanged"] and "current_mutation_attempted" not in payload["blocked_reasons"]:
        payload["blocked_reasons"].append("current_mutation_attempted")
    write_promotion_report(payload)
    return payload


def resolve_pack(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    resolver = preview_lib.read_required_json(PACK_RESOLVER_PATH)
    for entry in resolver.get("entries", []):
        if str(entry.get("mechanic_profile_id", "")) == profile_id and str(entry.get("content_pack_id", "")) == content_pack_id:
            return entry
    raise SystemExit("pack not found in pack_resolver")


def promotion_report_path(profile_id: str, content_pack_id: str) -> Path:
    return PROMOTION_DIR / f"{profile_id}__{content_pack_id}__promotion_report.json"


def write_promotion_report(payload: dict[str, Any]) -> None:
    path = promotion_report_path(str(payload.get("mechanic_profile_id", "")), str(payload.get("content_pack_id", "")))
    md_path = path.with_suffix(".md")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    md_path.write_text(build_markdown(payload), encoding="utf-8")


def append_history(payload: dict[str, Any], result: str) -> None:
    PROMOTION_DIR.mkdir(parents=True, exist_ok=True)
    entry = {
        "event_id": payload.get("promotion_run_id", ""),
        "timestamp": now_iso(),
        "mechanic_profile_id": payload.get("mechanic_profile_id", ""),
        "content_pack_id": payload.get("content_pack_id", ""),
        "result": result,
        "promotion_allowed": bool(payload.get("promotion_allowed", False)),
        "promoted_to_release_candidate": bool(payload.get("promoted_to_release_candidate", False)),
        "blocked_reasons": payload.get("blocked_reasons", []),
        "promotion_error": payload.get("promotion_error", ""),
    }
    with PROMOTION_HISTORY_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, ensure_ascii=False) + "\n")


def build_markdown(payload: dict[str, Any]) -> str:
    return "\n".join(
        [
            "# Promotion Report",
            "",
            f"- content_pack_id: `{payload.get('content_pack_id', '')}`",
            f"- source_channel: `{payload.get('source_channel', '')}`",
            f"- acceptance_pass: `{payload.get('acceptance_pass', False)}`",
            f"- acceptance_risk_level: `{payload.get('acceptance_risk_level', '')}`",
            f"- acceptance_recommendation: `{payload.get('acceptance_recommendation', '')}`",
            f"- human_review_status: `{payload.get('human_review_status', '')}`",
            f"- release_gate_policy_pass: `{payload.get('release_gate_policy_pass', False)}`",
            f"- promotion_allowed: `{payload.get('promotion_allowed', False)}`",
            f"- promoted_to_release_candidate: `{payload.get('promoted_to_release_candidate', False)}`",
            f"- current_release_unchanged: `{payload.get('current_release_unchanged', False)}`",
            "",
        ]
    ) + "\n"


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
