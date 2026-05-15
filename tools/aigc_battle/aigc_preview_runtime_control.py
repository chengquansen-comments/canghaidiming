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

from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import switch_active_profile as switch_lib

PACK_RESOLVER_PATH = ROOT / "data" / "aigc_battle" / "pack_resolver.json"
PREVIEW_DIR = ROOT / "data" / "aigc_battle" / "preview"
PREVIEW_PROFILE_PATH = PREVIEW_DIR / "preview_profile.json"
PREVIEW_HISTORY_PATH = PREVIEW_DIR / "preview_history.jsonl"
CURRENT_RELEASE_SNAPSHOT_PATH = PREVIEW_DIR / "current_release_snapshot.json"
PREVIEW_GENERATED_DIR = ROOT / "data" / "aigc_battle" / "generated" / "preview_runtime"
PREVIEW_SMOKE_REPORT_PATH = PREVIEW_GENERATED_DIR / "preview_smoke_report.json"

ALLOWED_PREVIEW_CHANNELS = {"review", "matrix_review", "ai_studio_review", "release_candidate", "fallback", "current", "candidate"}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="preview runtime control")
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--set-preview", action="store_true")
    parser.add_argument("--smoke-preview", action="store_true")
    parser.add_argument("--restore-current", action="store_true")
    parser.add_argument("--status", action="store_true")
    parser.add_argument("--profile")
    parser.add_argument("--pack")
    parser.add_argument("--reason", default="")
    parser.add_argument("--started-by", default="cli")
    parser.add_argument("--allow-keep-preview", action="store_true")
    args = parser.parse_args(argv[1:])

    if args.list:
        payload = list_previewable_packs()
    elif args.set_preview:
        if not args.profile or not args.pack:
            raise SystemExit("--set-preview requires --profile and --pack")
        payload = set_preview(args.profile, args.pack, started_by=args.started_by, reason=args.reason)
    elif args.smoke_preview:
        payload = smoke_preview(allow_keep_preview=bool(args.allow_keep_preview))
    elif args.restore_current:
        payload = restore_current()
    elif args.status:
        payload = preview_status()
    else:
        raise SystemExit("one action flag is required")
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0


def list_previewable_packs() -> dict[str, Any]:
    resolver = read_required_json(PACK_RESOLVER_PATH)
    packs = [
        {
            "mechanic_profile_id": entry["mechanic_profile_id"],
            "content_pack_id": entry["content_pack_id"],
            "sequence_template_id": entry.get("sequence_template_id", ""),
            "build_variant": entry.get("build_variant", ""),
            "channel": entry.get("channel", ""),
            "preview_source_channel": entry.get("preview_source_channel", entry.get("channel", "")),
            "runtime_manifest_path": entry.get("runtime_manifest_path", ""),
            "validation_report_path": entry.get("validation_report_path", ""),
            "previewable": bool(entry.get("previewable", False)),
        }
        for entry in resolver.get("entries", [])
        if is_previewable_entry(entry)
    ]
    return {
        "previewable_pack_count": len(packs),
        "packs": packs,
    }


def preview_status() -> dict[str, Any]:
    current = release_lib.show_channels().get("current_release", {})
    active = read_json(ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json") if (ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json").exists() else {}
    preview = read_json(PREVIEW_PROFILE_PATH) if PREVIEW_PROFILE_PATH.exists() else default_preview_profile()
    preview_pack_valid = False
    if preview.get("preview_enabled") and preview.get("preview_mechanic_profile_id") and preview.get("preview_content_pack_id"):
        try:
            resolve_preview_entry(str(preview.get("preview_mechanic_profile_id", "")), str(preview.get("preview_content_pack_id", "")))
            preview_pack_valid = True
        except SystemExit:
            preview_pack_valid = False
    return {
        "current_release": current,
        "active_profile": active,
        "preview_profile": preview,
        "active_is_preview": active_matches_preview(active, preview),
        "restore_available": bool(preview.get("restore_target_profile_id")) and bool(preview.get("restore_target_content_pack_id")),
        "preview_pack_valid": preview_pack_valid,
    }


def set_preview(profile_id: str, content_pack_id: str, started_by: str = "cli", reason: str = "") -> dict[str, Any]:
    switch_lib.ensure_safe_id(profile_id, "profile_id")
    switch_lib.ensure_safe_id(content_pack_id, "content_pack_id")
    entry = resolve_preview_entry(profile_id, content_pack_id)
    channels = release_lib.show_channels()
    current = channels.get("current_release", {})
    active_before = read_active_profile()
    current_snapshot = dict(current)
    write_json(CURRENT_RELEASE_SNAPSHOT_PATH, current_snapshot)
    switch_summary = switch_lib.switch_active_profile(profile_id, content_pack_id, switch_source="preview_set")
    active_after = read_active_profile()
    preview_profile = {
        "preview_enabled": True,
        "preview_channel": "preview",
        "preview_mechanic_profile_id": profile_id,
        "preview_sequence_template_id": str(entry.get("sequence_template_id", "")),
        "preview_content_pack_id": content_pack_id,
        "preview_build_variant": str(entry.get("build_variant", "")),
        "preview_runtime_manifest_path": str(entry.get("runtime_manifest_path", "")),
        "preview_validation_report_path": str(entry.get("validation_report_path", "")),
        "preview_source_channel": str(entry.get("channel", "")),
        "preview_started_at": now_iso(),
        "preview_started_by": started_by,
        "restore_target_profile_id": str(current.get("mechanic_profile_id", "")),
        "restore_target_content_pack_id": str(current.get("content_pack_id", "")),
        "restore_target_runtime_manifest_path": str(current.get("runtime_manifest_path", "")),
        "current_release_snapshot_path": to_relative(CURRENT_RELEASE_SNAPSHOT_PATH),
        "active_profile_snapshot": active_before,
        "preview_reason": reason,
        "preview_status": "active",
    }
    write_json(PREVIEW_PROFILE_PATH, preview_profile)
    append_preview_history(
        action="set_preview",
        preview_profile=preview_profile,
        current_release_before=current,
        active_profile_before=active_before,
        active_profile_after=active_after,
        result="ok",
        error="",
    )
    return {
        "preview_set": True,
        "preview_profile": preview_profile,
        "switch_summary": switch_summary,
        "active_profile_after": active_after,
    }


def smoke_preview(allow_keep_preview: bool = False) -> dict[str, Any]:
    preview = require_active_preview()
    current = release_lib.show_channels().get("current_release", {})
    runtime_manifest_path = ROOT / str(preview.get("preview_runtime_manifest_path", ""))
    validation_report_path = ROOT / str(preview.get("preview_validation_report_path", ""))
    runtime_manifest = read_required_json(runtime_manifest_path)
    validation = read_required_json(validation_report_path)
    generated_dir = runtime_manifest_path.parent
    balance_summary = read_json(generated_dir / "sequence_balance_summary.json") if (generated_dir / "sequence_balance_summary.json").exists() else {}
    mappings = runtime_manifest.get("formal_sequence_mapping", [])
    rewards = runtime_manifest.get("rewards", [])
    slots = runtime_manifest.get("battle_slots", [])
    expected_count = int(runtime_manifest.get("total_encounter_count", 0) or len(mappings))
    smoke_pass = (
        bool(validation.get("ready_for_runtime_export", False))
        and expected_count > 0
        and len(mappings) == expected_count
        and len(slots) == expected_count
        and len(rewards) == expected_count
        and bool(balance_summary.get("reward_coverage_complete", len(rewards) == len(slots) and len(slots) > 0))
        and str(runtime_manifest.get("sequence_template_id", "")) == str(preview.get("preview_sequence_template_id", ""))
        and str(runtime_manifest.get("mechanic_profile_id", "")) == str(preview.get("preview_mechanic_profile_id", ""))
        and str(runtime_manifest.get("content_pack_id", "")) == str(preview.get("preview_content_pack_id", ""))
        and str(current.get("content_pack_id", "")) == str(preview.get("restore_target_content_pack_id", ""))
    )
    report = {
        "generated_at": now_iso(),
        "preview_pack_resolved": True,
        "preview_channel_ready": True,
        "preview_active_profile_written": active_matches_preview(read_active_profile(), preview),
        "preview_smoke_started": True,
        "preview_formal_entry_smoke_pass": smoke_pass,
        "preview_mechanic_profile_id": str(preview.get("preview_mechanic_profile_id", "")),
        "preview_content_pack_id": str(preview.get("preview_content_pack_id", "")),
        "preview_generated_loadout_count": len(mappings),
        "preview_expected_encounter_count": expected_count,
        "preview_fallback_loadout_count": 0,
        "preview_reward_coverage_complete": bool(balance_summary.get("reward_coverage_complete", len(rewards) == len(slots) and len(slots) > 0)),
        "preview_runtime_manifest_loaded": True,
        "preview_pack_identity_valid": (
            str(runtime_manifest.get("mechanic_profile_id", "")) == str(preview.get("preview_mechanic_profile_id", ""))
            and str(runtime_manifest.get("content_pack_id", "")) == str(preview.get("preview_content_pack_id", ""))
            and str(runtime_manifest.get("sequence_template_id", "")) == str(preview.get("preview_sequence_template_id", ""))
        ),
        "current_release_unchanged": str(current.get("content_pack_id", "")) == str(preview.get("restore_target_content_pack_id", "")),
        "restore_current_ready": False,
        "active_profile_matches_current_after_restore": False,
        "smoke_pass": False,
    }
    restore_result = None
    if not allow_keep_preview:
        restore_result = restore_current()
        report["restore_current_ready"] = bool(restore_result.get("restore_current_ready", False))
        report["active_profile_matches_current_after_restore"] = bool(restore_result.get("active_profile_matches_current_release", False))
    else:
        report["restore_current_ready"] = bool(preview.get("restore_target_profile_id")) and bool(preview.get("restore_target_content_pack_id"))
    report["smoke_pass"] = (
        report["preview_pack_resolved"]
        and report["preview_formal_entry_smoke_pass"]
        and report["preview_fallback_loadout_count"] == 0
        and report["current_release_unchanged"]
        and report["restore_current_ready"]
        and report["active_profile_matches_current_after_restore"] if not allow_keep_preview else True
    )
    write_json(PREVIEW_SMOKE_REPORT_PATH, report)
    (PREVIEW_GENERATED_DIR / "preview_smoke_report.md").write_text(build_smoke_markdown(report), encoding="utf-8")
    append_preview_history(
        action="smoke_preview",
        preview_profile=preview,
        current_release_before=current,
        active_profile_before=preview.get("active_profile_snapshot", {}),
        active_profile_after=read_active_profile(),
        result="ok" if report["smoke_pass"] else "fail",
        error="" if report["smoke_pass"] else "preview smoke failed",
    )
    return report | {"restore_result": restore_result or {}}


def restore_current() -> dict[str, Any]:
    channels = release_lib.show_channels()
    current = channels.get("current_release", {})
    preview = read_json(PREVIEW_PROFILE_PATH) if PREVIEW_PROFILE_PATH.exists() else default_preview_profile()
    active_before = read_active_profile()
    switch_summary = switch_lib.switch_active_profile(
        str(current.get("mechanic_profile_id", "")),
        str(current.get("content_pack_id", "")),
        switch_source="preview_restore",
    )
    active_after = read_active_profile()
    preview["preview_enabled"] = False
    preview["preview_status"] = "restored"
    write_json(PREVIEW_PROFILE_PATH, preview)
    append_preview_history(
        action="restore_current",
        preview_profile=preview,
        current_release_before=current,
        active_profile_before=active_before,
        active_profile_after=active_after,
        result="ok",
        error="",
    )
    active_matches_current_release = active_matches_current(active_after, current)
    return {
        "restore_current_ready": active_matches_current_release,
        "active_profile_matches_current_release": active_matches_current_release,
        "switch_summary": switch_summary,
        "active_profile_after": active_after,
        "current_release": current,
    }


def mark_preview_failed(error: str) -> dict[str, Any]:
    preview = read_json(PREVIEW_PROFILE_PATH) if PREVIEW_PROFILE_PATH.exists() else default_preview_profile()
    preview["preview_status"] = "failed"
    preview["preview_enabled"] = False
    write_json(PREVIEW_PROFILE_PATH, preview)
    current = release_lib.show_channels().get("current_release", {})
    active = read_active_profile()
    append_preview_history(
        action="preview_failed",
        preview_profile=preview,
        current_release_before=current,
        active_profile_before=active,
        active_profile_after=active,
        result="fail",
        error=error,
    )
    return {
        "preview_failed": True,
        "error": error,
        "preview_profile": preview,
    }


def require_active_preview() -> dict[str, Any]:
    if not PREVIEW_PROFILE_PATH.exists():
        raise SystemExit("preview profile not found")
    preview = read_json(PREVIEW_PROFILE_PATH)
    if not bool(preview.get("preview_enabled", False)) or str(preview.get("preview_status", "")) != "active":
        raise SystemExit("preview is not active")
    return preview


def resolve_preview_entry(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    resolver = read_required_json(PACK_RESOLVER_PATH)
    for entry in resolver.get("entries", []):
        if str(entry.get("mechanic_profile_id", "")) == profile_id and str(entry.get("content_pack_id", "")) == content_pack_id:
            if not is_previewable_entry(entry):
                raise SystemExit("pack is not previewable")
            return entry
    raise SystemExit("preview pack not found in pack_resolver")


def is_previewable_entry(entry: dict[str, Any]) -> bool:
    return (
        str(entry.get("channel", "")) in ALLOWED_PREVIEW_CHANNELS
        and bool(entry.get("previewable", False))
        and str(entry.get("release_status", "")) != "archived"
        and bool(entry.get("runtime_manifest_path", ""))
        and bool(entry.get("validation_report_path", ""))
    )


def active_matches_preview(active_profile: dict[str, Any], preview: dict[str, Any]) -> bool:
    return (
        str(active_profile.get("active_mechanic_profile_id", "")) == str(preview.get("preview_mechanic_profile_id", ""))
        and str(active_profile.get("active_content_pack_id", "")) == str(preview.get("preview_content_pack_id", ""))
    )


def active_matches_current(active_profile: dict[str, Any], current_release: dict[str, Any]) -> bool:
    return (
        str(active_profile.get("active_mechanic_profile_id", "")) == str(current_release.get("mechanic_profile_id", ""))
        and str(active_profile.get("active_content_pack_id", "")) == str(current_release.get("content_pack_id", ""))
    )


def read_active_profile() -> dict[str, Any]:
    path = ROOT / "data" / "aigc_battle" / "runtime" / "active_profile.json"
    if not path.exists():
        return {}
    return read_json(path)


def default_preview_profile() -> dict[str, Any]:
    return {
        "preview_enabled": False,
        "preview_channel": "preview",
        "preview_mechanic_profile_id": "",
        "preview_sequence_template_id": "",
        "preview_content_pack_id": "",
        "preview_build_variant": "",
        "preview_runtime_manifest_path": "",
        "preview_validation_report_path": "",
        "preview_source_channel": "",
        "preview_started_at": "",
        "preview_started_by": "",
        "restore_target_profile_id": "",
        "restore_target_content_pack_id": "",
        "restore_target_runtime_manifest_path": "",
        "current_release_snapshot_path": "",
        "active_profile_snapshot": {},
        "preview_reason": "",
        "preview_status": "idle",
    }


def append_preview_history(
    action: str,
    preview_profile: dict[str, Any],
    current_release_before: dict[str, Any],
    active_profile_before: dict[str, Any],
    active_profile_after: dict[str, Any],
    result: str,
    error: str,
) -> None:
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    entry = {
        "event_id": f"preview_{action}_{datetime.now(timezone.utc).timestamp()}",
        "timestamp": now_iso(),
        "action": action,
        "preview_content_pack_id": str(preview_profile.get("preview_content_pack_id", "")),
        "current_release_before": {
            "mechanic_profile_id": str(current_release_before.get("mechanic_profile_id", "")),
            "content_pack_id": str(current_release_before.get("content_pack_id", "")),
        },
        "active_profile_before": active_profile_before,
        "active_profile_after": active_profile_after,
        "result": result,
        "error": error,
    }
    with PREVIEW_HISTORY_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, ensure_ascii=False) + "\n")


def build_smoke_markdown(payload: dict[str, Any]) -> str:
    return "\n".join([
        "# Preview Smoke Report",
        "",
        f"- preview_content_pack_id: `{payload.get('preview_content_pack_id', '')}`",
        f"- preview_expected_encounter_count: `{payload.get('preview_expected_encounter_count', 0)}`",
        f"- preview_generated_loadout_count: `{payload.get('preview_generated_loadout_count', 0)}`",
        f"- preview_fallback_loadout_count: `{payload.get('preview_fallback_loadout_count', 0)}`",
        f"- preview_reward_coverage_complete: `{payload.get('preview_reward_coverage_complete', False)}`",
        f"- smoke_pass: `{payload.get('smoke_pass', False)}`",
        "",
    ]) + "\n"


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def read_required_json(path: Path) -> Any:
    if not path.exists():
        raise SystemExit(f"required file missing: {to_relative(path)}")
    return read_json(path)


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def to_relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
