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

from tools.aigc_battle import aigc_preview_runtime_control as preview_lib
from tools.aigc_battle import aigc_release_gate as release_lib

OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "preview_runtime"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="preview smoke probe")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--pack", required=True)
    args = parser.parse_args(argv[1:])
    result = run_probe(args.profile, args.pack)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result.get("smoke_pass", False) else 1


def run_probe(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    current_before = release_lib.show_channels().get("current_release", {})
    preview_lib.set_preview(profile_id, content_pack_id, started_by="preview_smoke_probe", reason="preview smoke")
    smoke = preview_lib.smoke_preview(allow_keep_preview=False)
    current_after = release_lib.show_channels().get("current_release", {})
    payload = {
        "generated_at": now_iso(),
        "preview_pack_resolved": bool(smoke.get("preview_pack_resolved", False)),
        "preview_channel_ready": bool(smoke.get("preview_channel_ready", False)),
        "preview_active_profile_written": bool(smoke.get("preview_active_profile_written", False)),
        "preview_smoke_started": bool(smoke.get("preview_smoke_started", False)),
        "preview_formal_entry_smoke_pass": bool(smoke.get("preview_formal_entry_smoke_pass", False)),
        "preview_mechanic_profile_id": profile_id,
        "preview_content_pack_id": content_pack_id,
        "selected_preview_pack": f"{profile_id} / {content_pack_id}",
        "preview_generated_loadout_count": int(smoke.get("preview_generated_loadout_count", 0)),
        "preview_expected_encounter_count": int(smoke.get("preview_expected_encounter_count", 0)),
        "preview_fallback_loadout_count": int(smoke.get("preview_fallback_loadout_count", 0)),
        "preview_reward_coverage_complete": bool(smoke.get("preview_reward_coverage_complete", False)),
        "preview_runtime_manifest_loaded": bool(smoke.get("preview_runtime_manifest_loaded", False)),
        "preview_pack_identity_valid": bool(smoke.get("preview_pack_identity_valid", False)),
        "current_release_unchanged": current_before == current_after and bool(smoke.get("current_release_unchanged", False)),
        "restore_current_ready": bool(smoke.get("restore_current_ready", False)),
        "active_profile_matches_current_after_restore": bool(smoke.get("active_profile_matches_current_after_restore", False)),
        "smoke_pass": bool(smoke.get("smoke_pass", False)),
    }
    write_json(OUT_DIR / "preview_smoke_report.json", payload)
    (OUT_DIR / "preview_smoke_report.md").write_text(build_markdown(payload), encoding="utf-8")
    return payload


def build_markdown(payload: dict[str, Any]) -> str:
    return "\n".join([
        "# Preview Smoke Report",
        "",
        f"- selected_preview_pack: `{payload.get('selected_preview_pack', '')}`",
        f"- preview_expected_encounter_count: `{payload.get('preview_expected_encounter_count', 0)}`",
        f"- preview_generated_loadout_count: `{payload.get('preview_generated_loadout_count', 0)}`",
        f"- preview_fallback_loadout_count: `{payload.get('preview_fallback_loadout_count', 0)}`",
        f"- preview_reward_coverage_complete: `{payload.get('preview_reward_coverage_complete', False)}`",
        f"- smoke_pass: `{payload.get('smoke_pass', False)}`",
        "",
    ]) + "\n"


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
