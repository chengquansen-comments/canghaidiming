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

from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import aigc_release_switch_console as switch_console
from tools.aigc_battle import aigc_preview_runtime_control as preview_lib


OUT_DIR = ROOT / "data" / "aigc_battle" / "generated" / "release_switch"
REPORT_JSON = OUT_DIR / "release_rollback_probe_report.json"
REPORT_MD = OUT_DIR / "release_rollback_probe_report.md"


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        raise SystemExit("usage: python3 tools/aigc_battle/aigc_release_rollback_probe.py")
    payload = run_probe()
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if bool(payload.get("probe_pass", False)) else 1


def run_probe() -> dict[str, Any]:
    current = release_lib.read_release_channel("current", required=True)
    fallback = release_lib.read_release_channel("fallback", required=True)
    previous = switch_console.rollback_previous_current(dry_run=True)
    fallback_probe = switch_console.rollback_fallback(dry_run=True)
    active = preview_lib.read_active_profile()
    payload = {
        "generated_at": now_iso(),
        "previous_current_rollback_ready": bool(previous.get("previous_current_rollback_ready", False)),
        "fallback_rollback_ready": bool(fallback_probe.get("fallback_rollback_ready", False)),
        "fallback_pack_resolved": bool(fallback_probe.get("fallback_pack_resolved", False)),
        "rollback_history_ready": len(switch_console.read_switch_history()) > 0,
        "active_profile_matches_current_release": preview_lib.active_matches_current(active, current),
        "current_release": switch_console.current_ref_from_channel(current),
        "fallback_release": switch_console.current_ref_from_channel(fallback),
        "probe_pass": (
            bool(previous.get("previous_current_rollback_ready", False))
            and bool(fallback_probe.get("fallback_rollback_ready", False))
            and bool(fallback_probe.get("fallback_pack_resolved", False))
            and preview_lib.active_matches_current(active, current)
        ),
    }
    write_json(REPORT_JSON, payload)
    REPORT_MD.write_text(build_markdown(payload), encoding="utf-8")
    return payload


def build_markdown(payload: dict[str, Any]) -> str:
    return "\n".join(
        [
            "# Release Rollback Probe Report",
            "",
            f"- previous_current_rollback_ready: `{payload.get('previous_current_rollback_ready', False)}`",
            f"- fallback_rollback_ready: `{payload.get('fallback_rollback_ready', False)}`",
            f"- fallback_pack_resolved: `{payload.get('fallback_pack_resolved', False)}`",
            f"- rollback_history_ready: `{payload.get('rollback_history_ready', False)}`",
            f"- active_profile_matches_current_release: `{payload.get('active_profile_matches_current_release', False)}`",
            f"- probe_pass: `{payload.get('probe_pass', False)}`",
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
