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

from tools.aigc_battle import aigc_release_switch_console as switch_console
from tools.aigc_battle import aigc_release_gate as release_lib


OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "release_switch"
REPORT_JSON = OUT_DIR / "release_switch_smoke_report.json"
REPORT_MD = OUT_DIR / "release_switch_smoke_report.md"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="release switch smoke probe")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--pack", required=True)
    args = parser.parse_args(argv[1:])
    payload = run_probe(args.profile, args.pack)
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if bool(payload.get("smoke_pass", False)) else 1


def run_probe(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    switch_result = switch_console.set_current_release(profile_id, content_pack_id, dry_run=False, auto_smoke=False)
    smoke = switch_console.smoke_current_release()
    current = release_lib.read_release_channel("current", required=True)
    payload = {
        "generated_at": now_iso(),
        "release_candidate_valid": bool(switch_result.get("release_candidate_valid", False)),
        "set_current_ready": bool(switch_result.get("current_release_written", False) and switch_result.get("active_profile_written", False)),
        "formal_entry_uses_new_current": bool(smoke.get("formal_entry_uses_new_current", False)),
        "generated_loadout_count": int(smoke.get("generated_loadout_count", 0)),
        "expected_encounter_count": int(smoke.get("expected_encounter_count", 0)),
        "fallback_loadout_count": int(smoke.get("fallback_loadout_count", 0)),
        "reward_coverage_complete": bool(smoke.get("reward_coverage_complete", False)),
        "active_profile_matches_current_release": bool(smoke.get("current_release_matches_active_profile", False)),
        "current_profile_id": str(current.get("mechanic_profile_id", "")),
        "current_content_pack_id": str(current.get("content_pack_id", "")),
        "smoke_pass": (
            bool(switch_result.get("release_candidate_valid", False))
            and bool(switch_result.get("current_release_written", False))
            and bool(smoke.get("formal_entry_uses_new_current", False))
            and int(smoke.get("fallback_loadout_count", 0)) == 0
            and bool(smoke.get("reward_coverage_complete", False))
            and bool(smoke.get("current_release_matches_active_profile", False))
        ),
    }
    write_json(REPORT_JSON, payload)
    REPORT_MD.write_text(build_markdown(payload), encoding="utf-8")
    return payload


def build_markdown(payload: dict[str, Any]) -> str:
    return "\n".join(
        [
            "# Release Switch Smoke Report",
            "",
            f"- release_candidate_valid: `{payload.get('release_candidate_valid', False)}`",
            f"- set_current_ready: `{payload.get('set_current_ready', False)}`",
            f"- formal_entry_uses_new_current: `{payload.get('formal_entry_uses_new_current', False)}`",
            f"- generated_loadout_count: `{payload.get('generated_loadout_count', 0)}`",
            f"- expected_encounter_count: `{payload.get('expected_encounter_count', 0)}`",
            f"- fallback_loadout_count: `{payload.get('fallback_loadout_count', 0)}`",
            f"- reward_coverage_complete: `{payload.get('reward_coverage_complete', False)}`",
            f"- active_profile_matches_current_release: `{payload.get('active_profile_matches_current_release', False)}`",
            f"- smoke_pass: `{payload.get('smoke_pass', False)}`",
            "",
        ]
    ) + "\n"


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
