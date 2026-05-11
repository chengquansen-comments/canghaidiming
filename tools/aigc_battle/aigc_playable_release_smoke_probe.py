#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_release_gate as release_lib

REPORT_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'release_smoke'
REPORT_JSON = REPORT_DIR / 'playable_release_smoke_report.json'
REPORT_MD = REPORT_DIR / 'playable_release_smoke_report.md'


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print('usage: python3 tools/aigc_battle/aigc_playable_release_smoke_probe.py', file=sys.stderr)
        return 1
    rollback_performed = False
    try:
        channels = release_lib.show_channels()
        current = channels.get('current_release', {})
        current_release_valid = validate_current_release(current)
        activation = release_lib.activate_current_release()
        current_release_activated = bool(activation.get('active_profile_matches_current_release', False))
        generated_dir = (ROOT / str(activation.get('active_profile', {}).get('runtime_manifest_path', ''))).parent
        profile_id = str(current.get('mechanic_profile_id', ''))
        run_serial([sys.executable, 'tools/aigc_battle/validate_content_pack.py', profile_id, '--generated-dir', str(generated_dir)])
        run_serial([sys.executable, 'tools/aigc_battle/export_runtime_manifest.py', profile_id, '--generated-dir', str(generated_dir)])
        run_serial([sys.executable, 'tools/aigc_battle/aigc_formal_entry_release_probe.py'])
        run_serial([sys.executable, 'tools/aigc_battle/aigc_full_sequence_reward_probe.py'])
        run_serial([sys.executable, 'tools/aigc_battle/aigc_sequence_balance_probe.py'])
        if profile_id == 'weapon_followup_v0_1':
            run_serial([sys.executable, 'tools/aigc_battle/aigc_weapon_followup_probe.py'])
            runtime_probe = read_json(ROOT / 'data' / 'aigc_battle' / 'generated' / profile_id / 'weapon_followup_probe_report.json')
            weapon_followup_runtime_ready = bool(runtime_probe.get('probe_pass', False))
            runtime_primitive_ready = weapon_followup_runtime_ready
        else:
            run_serial([sys.executable, 'tools/aigc_battle/aigc_runtime_primitive_probe.py'])
            runtime_probe = read_json(ROOT / 'data' / 'aigc_battle' / 'generated' / profile_id / 'runtime_primitive_probe_report.json')
            weapon_followup_runtime_ready = False
            runtime_primitive_ready = bool(runtime_probe.get('probe_pass', False))
        run_serial([sys.executable, 'tools/aigc_battle/build_aigc_content_index.py'])
        run_serial([sys.executable, 'tools/aigc_battle/build_aigc_detail_views.py'])
        run_serial([sys.executable, 'tools/aigc_battle/build_aigc_review_workspace.py'])

        formal_entry_report = read_json(ROOT / 'data' / 'aigc_battle' / 'generated' / 'release_smoke' / 'formal_entry_release_probe_report.json')
        reward_report = read_json(generated_dir / 'full_sequence_reward_probe_report.json')
        balance_report = read_json(ROOT / 'data' / 'aigc_battle' / 'generated' / profile_id / 'sequence_balance_probe_report.json')
        channels_after = release_lib.show_channels()
        report = {
            'current_release_valid': current_release_valid,
            'current_release_activated': current_release_activated,
            'active_release_pack_visible': bool(channels_after.get('active_runtime', {}).get('matches_current_release', False)),
            'player_formal_entry_uses_ai_pack': bool(formal_entry_report.get('formal_entry_uses_release_pack', False)),
            'full_sequence_generated_loadout_count': int(formal_entry_report.get('full_sequence_generated_loadout_count', 0)),
            'fallback_loadout_count': int(formal_entry_report.get('fallback_loadout_count', 0)),
            'reward_coverage_complete': bool(reward_report.get('all_generated_slots_have_reward', False)),
            'sequence_balance_pass': bool(balance_report.get('sequence_balance_pass', False)),
            'runtime_primitive_ready': runtime_primitive_ready,
            'weapon_followup_runtime_ready': weapon_followup_runtime_ready,
            'release_candidate_playable': bool(formal_entry_report.get('probe_pass', False)),
            'rollback_to_fallback_ready': bool(channels_after.get('rollback_to_fallback_ready', False)),
            'smoke_pass': False,
            'rollback_performed': False,
        }
        report['smoke_pass'] = (
            report['current_release_valid']
            and report['current_release_activated']
            and report['active_release_pack_visible']
            and report['player_formal_entry_uses_ai_pack']
            and report['full_sequence_generated_loadout_count'] == 15
            and report['fallback_loadout_count'] == 0
            and report['reward_coverage_complete']
            and report['sequence_balance_pass']
            and report['runtime_primitive_ready']
            and report['rollback_to_fallback_ready']
        )
        update_current_smoke_status(report)
        write_json(REPORT_JSON, report)
        REPORT_MD.write_text(build_markdown(report), encoding='utf-8')
        print('playable release smoke probe complete')
        return 0 if report['smoke_pass'] else 1
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


def validate_current_release(current: dict[str, Any]) -> bool:
    release_lib.validate_release_pack(str(current.get('mechanic_profile_id', '')), str(current.get('content_pack_id', '')), allow_archived=False)
    return True


def update_current_smoke_status(report: dict[str, Any]) -> None:
    current = release_lib.read_release_channel('current', required=True)
    current['smoke_test_status'] = 'pass' if report['smoke_pass'] else 'fail'
    current['last_smoke_report_path'] = REPORT_JSON.relative_to(ROOT).as_posix()
    release_lib.write_json(release_lib.release_channel_path('current'), current)


def run_serial(command: list[str]) -> None:
    subprocess.run(command, check=True, cwd=ROOT)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding='utf-8'))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def build_markdown(report: dict[str, Any]) -> str:
    lines = ['# R1 Playable Release Smoke', '']
    for key in [
        'current_release_valid',
        'current_release_activated',
        'active_release_pack_visible',
        'player_formal_entry_uses_ai_pack',
        'full_sequence_generated_loadout_count',
        'fallback_loadout_count',
        'reward_coverage_complete',
        'sequence_balance_pass',
        'runtime_primitive_ready',
        'weapon_followup_runtime_ready',
        'release_candidate_playable',
        'rollback_to_fallback_ready',
        'smoke_pass',
        'rollback_performed',
    ]:
        lines.append(f'- {key}: `{report.get(key)}`')
    return '\n'.join(lines) + '\n'


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
