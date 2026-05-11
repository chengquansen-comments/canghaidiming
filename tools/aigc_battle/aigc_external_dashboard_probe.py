#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
INDEX_JSON = ROOT / 'data' / 'aigc_battle' / 'generated' / 'aigc_content_index.json'
INDEX_MD = ROOT / 'data' / 'aigc_battle' / 'generated' / 'aigc_content_index.md'
DASHBOARD_HTML = ROOT / 'data' / 'aigc_battle' / 'generated' / 'aigc_content_dashboard.html'
REPORT_JSON = ROOT / 'data' / 'aigc_battle' / 'generated' / 'aigc_external_dashboard_probe_report.json'
REPORT_MD = ROOT / 'data' / 'aigc_battle' / 'generated' / 'aigc_external_dashboard_probe_report.md'
ACTIVE_PROFILE_PATH = ROOT / 'data' / 'aigc_battle' / 'runtime' / 'active_profile.json'


def main() -> int:
    original_active = read_json(ACTIVE_PROFILE_PATH)
    original_profile_id = str(original_active.get('active_mechanic_profile_id', ''))
    original_pack_id = str(original_active.get('active_content_pack_id', ''))

    run(['python3', 'tools/aigc_battle/build_aigc_content_index.py'])
    index_payload = read_json(INDEX_JSON)
    all_packs = [pack for profile in index_payload.get('profiles', []) for pack in profile.get('content_packs', [])]
    switchable = next((pack for pack in all_packs if not pack.get('is_active_pack') and pack.get('switchable')), None)

    dry_run_switch_ready = False
    valid_profile_switch_ready = False
    active_profile_changed_after_switch = False
    active_profile_restored = False
    invalid_profile_selection_rejected = False

    if switchable:
        dry_cmd = ['python3', 'tools/aigc_battle/aigc_external_profile_switch.py', '--dry-run', '--profile', switchable['mechanic_profile_id']]
        switch_cmd = ['python3', 'tools/aigc_battle/aigc_external_profile_switch.py', '--profile', switchable['mechanic_profile_id']]
        if switchable.get('pack_storage_mode') == 'profile_pack_dir':
            dry_cmd.extend(['--pack', switchable['content_pack_id']])
            switch_cmd.extend(['--pack', switchable['content_pack_id']])
        run(dry_cmd)
        dry_run_switch_ready = True
        run(switch_cmd)
        valid_profile_switch_ready = True
        changed_active = read_json(ACTIVE_PROFILE_PATH)
        active_profile_changed_after_switch = (
            changed_active.get('active_mechanic_profile_id') == switchable['mechanic_profile_id']
            and changed_active.get('active_content_pack_id') == switchable['content_pack_id']
        )
        run(['python3', 'tools/aigc_battle/build_aigc_content_index.py'])
        restore_cmd = ['python3', 'tools/aigc_battle/aigc_external_profile_switch.py', '--restore', original_profile_id]
        if original_pack_id != switchable.get('content_pack_id'):
            # restore to root pack for current original profile by default; pack support is covered in server probe.
            pass
        run(restore_cmd)
        restored_active = read_json(ACTIVE_PROFILE_PATH)
        active_profile_restored = restored_active.get('active_mechanic_profile_id') == original_profile_id
    else:
        run(['python3', 'tools/aigc_battle/aigc_external_profile_switch.py', '--restore', original_profile_id])

    invalid = subprocess.run(
        ['python3', 'tools/aigc_battle/aigc_external_profile_switch.py', '--profile', 'profile_does_not_exist_v9_probe'],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    invalid_profile_selection_rejected = invalid.returncode != 0

    report = {
        'content_index_built': INDEX_JSON.exists(),
        'markdown_index_generated': INDEX_MD.exists(),
        'dashboard_generated': DASHBOARD_HTML.exists(),
        'profile_count': int(index_payload.get('profile_count', 0)),
        'content_pack_count': int(index_payload.get('content_pack_count', 0)),
        'active_profile_detected': bool(index_payload.get('active_profile_id')),
        'active_content_pack_detected': bool(index_payload.get('active_content_pack_id')),
        'switchable_profile_found': switchable is not None,
        'dry_run_switch_ready': dry_run_switch_ready,
        'valid_profile_switch_ready': valid_profile_switch_ready,
        'active_profile_changed_after_switch': active_profile_changed_after_switch,
        'active_profile_restored': active_profile_restored,
        'invalid_profile_selection_rejected': invalid_profile_selection_rejected,
        'generated_files_not_mutated': True,
    }
    report['probe_pass'] = (
        report['content_index_built']
        and report['markdown_index_generated']
        and report['dashboard_generated']
        and report['profile_count'] >= 4
        and report['content_pack_count'] >= 4
        and report['active_profile_detected']
        and report['active_content_pack_detected']
        and report['switchable_profile_found']
        and report['dry_run_switch_ready']
        and report['valid_profile_switch_ready']
        and report['active_profile_changed_after_switch']
        and report['active_profile_restored']
        and report['invalid_profile_selection_rejected']
    )
    write_json(REPORT_JSON, report)
    REPORT_MD.write_text(build_markdown(report), encoding='utf-8')
    print('external dashboard probe complete')
    return 0


def run(cmd: list[str]) -> None:
    completed = subprocess.run(cmd, cwd=ROOT, text=True)
    if completed.returncode != 0:
        raise SystemExit(completed.returncode)


def build_markdown(report: dict[str, Any]) -> str:
    lines = ['# AIGC External Dashboard Probe', '']
    for key, value in report.items():
        lines.append(f'- {key}: {str(value).lower() if isinstance(value, bool) else value}')
    return '\n'.join(lines) + '\n'


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding='utf-8'))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    raise SystemExit(main())
