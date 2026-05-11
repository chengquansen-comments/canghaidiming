#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
import threading
import urllib.request
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_dashboard_server as dashboard_lib
from tools.aigc_battle import aigc_release_gate as release_lib

REPORT_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'release_smoke'
REPORT_JSON = REPORT_DIR / 'r1_playable_release_probe_report.json'
REPORT_MD = REPORT_DIR / 'r1_playable_release_probe_report.md'


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print('usage: python3 tools/aigc_battle/aigc_r1_playable_release_probe.py', file=sys.stderr)
        return 1
    rollback_performed = False
    try:
        run_serial([sys.executable, 'tools/aigc_battle/build_aigc_content_index.py'])
        run_serial([sys.executable, 'tools/aigc_battle/build_aigc_detail_views.py'])
        run_serial([sys.executable, 'tools/aigc_battle/build_aigc_review_workspace.py'])
        release_lib.set_release_channel('fallback', 'posture_opening_pressure_v0_1', 'posture_opening_pressure_v0_1_formal_sequence_pack_001')
        release_lib.set_release_channel('current', 'weapon_followup_v0_1', 'weapon_followup_v0_1_formal_sequence_pack_001')
        run_serial([sys.executable, 'tools/aigc_battle/aigc_release_channel_probe.py'])
        run_serial([sys.executable, 'tools/aigc_battle/aigc_playable_release_smoke_probe.py'])
        run_serial([sys.executable, 'tools/aigc_battle/aigc_formal_entry_release_probe.py'])
        run_serial([sys.executable, 'tools/aigc_battle/build_aigc_content_index.py'])
        run_serial([sys.executable, 'tools/aigc_battle/build_aigc_detail_views.py'])
        run_serial([sys.executable, 'tools/aigc_battle/build_aigc_review_workspace.py'])
        dashboard_release_channel_ready = verify_dashboard_api()
        smoke_report = read_json(ROOT / 'data' / 'aigc_battle' / 'generated' / 'release_smoke' / 'playable_release_smoke_report.json')
        formal_entry_report = read_json(ROOT / 'data' / 'aigc_battle' / 'generated' / 'release_smoke' / 'formal_entry_release_probe_report.json')
        channels = release_lib.show_channels()
        current = channels.get('current_release', {})
        fallback = channels.get('fallback_release', {})
        active_runtime = channels.get('active_runtime', {})
        report = {
            'playable_ai_release_ready': bool(smoke_report.get('smoke_pass', False)) and bool(formal_entry_report.get('probe_pass', False)),
            'current_release_profile_id': str(current.get('mechanic_profile_id', '')),
            'current_release_content_pack_id': str(current.get('content_pack_id', '')),
            'fallback_release_profile_id': str(fallback.get('mechanic_profile_id', '')),
            'fallback_release_content_pack_id': str(fallback.get('content_pack_id', '')),
            'player_formal_entry_uses_ai_pack': bool(smoke_report.get('player_formal_entry_uses_ai_pack', False)),
            'active_release_pack_visible': bool(smoke_report.get('active_release_pack_visible', False)),
            'full_sequence_generated_loadout_count': int(smoke_report.get('full_sequence_generated_loadout_count', 0)),
            'formal_encounter_total_count': int(formal_entry_report.get('formal_encounter_total_count', 0)),
            'fallback_loadout_count': int(smoke_report.get('fallback_loadout_count', 0)),
            'reward_coverage_complete': bool(smoke_report.get('reward_coverage_complete', False)),
            'weapon_followup_or_selected_mechanic_runtime_ready': bool(smoke_report.get('runtime_primitive_ready', False)),
            'release_candidate_playable': bool(smoke_report.get('release_candidate_playable', False)),
            'rollback_to_fallback_ready': bool(smoke_report.get('rollback_to_fallback_ready', False)),
            'dashboard_release_channel_ready': dashboard_release_channel_ready,
            'active_profile_matches_current_release': bool(active_runtime.get('matches_current_release', False)),
            'smoke_pass': bool(smoke_report.get('smoke_pass', False)),
            'rollback_performed': bool(smoke_report.get('rollback_performed', False)),
            'probe_pass': False,
        }
        report['probe_pass'] = (
            report['playable_ai_release_ready']
            and report['player_formal_entry_uses_ai_pack']
            and report['active_release_pack_visible']
            and report['full_sequence_generated_loadout_count'] == 15
            and report['fallback_loadout_count'] == 0
            and report['reward_coverage_complete']
            and report['weapon_followup_or_selected_mechanic_runtime_ready']
            and report['release_candidate_playable']
            and report['rollback_to_fallback_ready']
            and report['dashboard_release_channel_ready']
            and report['active_profile_matches_current_release']
            and report['smoke_pass']
        )
        write_json(REPORT_JSON, report)
        REPORT_MD.write_text(build_markdown(report), encoding='utf-8')
        print('r1 playable release probe complete')
        return 0 if report['probe_pass'] else 1
    except Exception:
        release_lib.rollback_to_fallback()
        rollback_performed = True
        raise
    finally:
        if rollback_performed and REPORT_JSON.exists():
            payload = read_json(REPORT_JSON)
            payload['rollback_performed'] = True
            write_json(REPORT_JSON, payload)
            REPORT_MD.write_text(build_markdown(payload), encoding='utf-8')


def verify_dashboard_api() -> bool:
    server = dashboard_lib.make_server('127.0.0.1', 0)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        port = server.server_port
        channels = read_url_json(f'http://127.0.0.1:{port}/api/release/channels')
        smoke = read_url_json(f'http://127.0.0.1:{port}/api/release/smoke-report')
        return bool(channels.get('current_release')) and bool(channels.get('fallback_release')) and ('smoke_pass' in smoke or smoke.get('ok') is False)
    finally:
        server.shutdown()
        server.server_close()


def read_url_json(url: str) -> dict[str, Any]:
    with urllib.request.urlopen(url, timeout=5) as response:
        return json.loads(response.read().decode('utf-8'))


def run_serial(command: list[str]) -> None:
    subprocess.run(command, check=True, cwd=ROOT)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding='utf-8'))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def build_markdown(report: dict[str, Any]) -> str:
    lines = ['# R1 Playable AI Release Probe', '']
    for key in [
        'playable_ai_release_ready',
        'current_release_profile_id',
        'current_release_content_pack_id',
        'fallback_release_profile_id',
        'fallback_release_content_pack_id',
        'player_formal_entry_uses_ai_pack',
        'active_release_pack_visible',
        'full_sequence_generated_loadout_count',
        'formal_encounter_total_count',
        'fallback_loadout_count',
        'reward_coverage_complete',
        'weapon_followup_or_selected_mechanic_runtime_ready',
        'release_candidate_playable',
        'rollback_to_fallback_ready',
        'dashboard_release_channel_ready',
        'active_profile_matches_current_release',
        'smoke_pass',
        'rollback_performed',
        'probe_pass',
    ]:
        lines.append(f'- {key}: `{report.get(key)}`')
    return '\n'.join(lines) + '\n'


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
