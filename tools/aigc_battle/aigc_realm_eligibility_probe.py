#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
GENERATED_DIR = ROOT / 'data' / 'aigc_battle' / 'generated'
PROFILE_ID = 'posture_opening_pressure_v0_1'


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print('usage: python3 tools/aigc_battle/aigc_realm_eligibility_probe.py', file=sys.stderr)
        return 1

    run_serial([sys.executable, 'tools/aigc_battle/build_content_for_profile.py', PROFILE_ID])
    run_serial([sys.executable, 'tools/aigc_battle/validate_content_pack.py', PROFILE_ID])
    run_serial([sys.executable, 'tools/aigc_battle/export_runtime_manifest.py', PROFILE_ID])
    run_serial([sys.executable, 'tools/aigc_battle/switch_active_profile.py', PROFILE_ID])
    run_serial([sys.executable, 'tools/aigc_battle/aigc_formal_sequence_probe.py'])
    run_serial([sys.executable, 'tools/aigc_battle/aigc_full_sequence_reward_probe.py'])
    run_serial([sys.executable, 'tools/aigc_battle/aigc_sequence_balance_probe.py'])
    run_serial([sys.executable, 'tools/aigc_battle/aigc_runtime_primitive_probe.py'])

    generated_dir = GENERATED_DIR / PROFILE_ID
    valid_validation = read_json(generated_dir / 'validation_report.json')
    formal_probe = read_json(generated_dir / 'formal_sequence_probe_report.json')

    invalid_result = run_invalid_realm_case(generated_dir)
    missing_result = run_missing_metadata_case(generated_dir)

    report = {
        'realm_eligibility_rule_enabled': bool(valid_validation.get('card_eligibility_rules_declared', False)),
        'valid_pack_realm_eligibility_pass': bool(valid_validation.get('deck_card_realm_eligibility_valid', False)) and bool(valid_validation.get('no_card_above_player_wujing_in_deck', False)),
        'deck_card_realm_eligibility_valid': bool(valid_validation.get('deck_card_realm_eligibility_valid', False)),
        'no_card_above_player_wujing_in_deck': bool(valid_validation.get('no_card_above_player_wujing_in_deck', False)),
        'invalid_realm_card_count': int(valid_validation.get('invalid_realm_card_count', 0)),
        'missing_realm_metadata_count': int(valid_validation.get('missing_realm_metadata_count', 0)),
        'invalid_realm_card_detected': invalid_result['invalid_realm_card_detected'],
        'missing_realm_metadata_detected': missing_result['missing_realm_metadata_detected'],
        'export_blocked_for_invalid_realm': invalid_result['export_blocked_for_invalid_realm'],
        'export_blocked_for_missing_realm_metadata': missing_result['export_blocked_for_missing_realm_metadata'],
        'full_sequence_coverage_still_valid': bool(valid_validation.get('full_sequence_coverage_complete', False)),
        'fallback_loadout_count': int(formal_probe.get('fallback_loadout_count', 0)),
        'probe_pass': False,
    }
    report['probe_pass'] = (
        report['valid_pack_realm_eligibility_pass']
        and report['deck_card_realm_eligibility_valid']
        and report['no_card_above_player_wujing_in_deck']
        and report['invalid_realm_card_count'] == 0
        and report['missing_realm_metadata_count'] == 0
        and report['invalid_realm_card_detected']
        and report['missing_realm_metadata_detected']
        and report['export_blocked_for_invalid_realm']
        and report['export_blocked_for_missing_realm_metadata']
        and report['full_sequence_coverage_still_valid']
        and report['fallback_loadout_count'] == 0
    )
    write_json(generated_dir / 'realm_eligibility_probe_report.json', report)
    write_markdown(generated_dir / 'realm_eligibility_probe_report.md', report)
    print('realm eligibility probe complete')
    return 0 if report['probe_pass'] else 1


def run_invalid_realm_case(source_dir: Path) -> dict[str, Any]:
    with tempfile.TemporaryDirectory(prefix='aigc_invalid_realm_') as temp_dir:
        temp_path = Path(temp_dir)
        shutil.copytree(source_dir, temp_path / source_dir.name, dirs_exist_ok=True)
        generated_dir = temp_path / source_dir.name
        card_pool = read_json(generated_dir / 'card_pool.generated.json')
        target_card_id = None
        for card in card_pool:
            if 'technique' in [str(tag).lower() for tag in card.get('tags', [])]:
                card['required_wujing'] = 99
                card['closing_form_tier'] = 99
                target_card_id = str(card['card_id'])
                break
        write_json(generated_dir / 'card_pool.generated.json', card_pool)
        validate = subprocess.run([sys.executable, 'tools/aigc_battle/validate_content_pack.py', PROFILE_ID, '--generated-dir', str(generated_dir)], cwd=ROOT)
        validation_report = read_json(generated_dir / 'validation_report.json')
        export = subprocess.run([sys.executable, 'tools/aigc_battle/export_runtime_manifest.py', PROFILE_ID, '--generated-dir', str(generated_dir)], cwd=ROOT)
        return {
            'invalid_realm_card_detected': validate.returncode != 0 and int(validation_report.get('invalid_realm_card_count', 0)) > 0,
            'export_blocked_for_invalid_realm': export.returncode != 0,
            'target_card_id': target_card_id,
        }


def run_missing_metadata_case(source_dir: Path) -> dict[str, Any]:
    with tempfile.TemporaryDirectory(prefix='aigc_missing_realm_') as temp_dir:
        temp_path = Path(temp_dir)
        shutil.copytree(source_dir, temp_path / source_dir.name, dirs_exist_ok=True)
        generated_dir = temp_path / source_dir.name
        card_pool = read_json(generated_dir / 'card_pool.generated.json')
        for card in card_pool:
            if 'technique' in [str(tag).lower() for tag in card.get('tags', [])]:
                card.pop('required_wujing', None)
                break
        write_json(generated_dir / 'card_pool.generated.json', card_pool)
        validate = subprocess.run([sys.executable, 'tools/aigc_battle/validate_content_pack.py', PROFILE_ID, '--generated-dir', str(generated_dir)], cwd=ROOT)
        validation_report = read_json(generated_dir / 'validation_report.json')
        export = subprocess.run([sys.executable, 'tools/aigc_battle/export_runtime_manifest.py', PROFILE_ID, '--generated-dir', str(generated_dir)], cwd=ROOT)
        return {
            'missing_realm_metadata_detected': validate.returncode != 0 and int(validation_report.get('missing_realm_metadata_count', 0)) > 0,
            'export_blocked_for_missing_realm_metadata': export.returncode != 0,
        }


def run_serial(command: list[str]) -> None:
    subprocess.run(command, check=True, cwd=ROOT)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding='utf-8'))


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def write_markdown(path: Path, report: dict[str, Any]) -> None:
    lines = [
        '# AIGC Battle Realm Eligibility Probe',
        '',
        f"- valid_pack_realm_eligibility_pass: {str(report['valid_pack_realm_eligibility_pass']).lower()}",
        f"- deck_card_realm_eligibility_valid: {str(report['deck_card_realm_eligibility_valid']).lower()}",
        f"- no_card_above_player_wujing_in_deck: {str(report['no_card_above_player_wujing_in_deck']).lower()}",
        f"- invalid_realm_card_count: {report['invalid_realm_card_count']}",
        f"- missing_realm_metadata_count: {report['missing_realm_metadata_count']}",
        f"- invalid_realm_card_detected: {str(report['invalid_realm_card_detected']).lower()}",
        f"- missing_realm_metadata_detected: {str(report['missing_realm_metadata_detected']).lower()}",
        f"- export_blocked_for_invalid_realm: {str(report['export_blocked_for_invalid_realm']).lower()}",
        f"- export_blocked_for_missing_realm_metadata: {str(report['export_blocked_for_missing_realm_metadata']).lower()}",
        f"- full_sequence_coverage_still_valid: {str(report['full_sequence_coverage_still_valid']).lower()}",
        f"- fallback_loadout_count: {report['fallback_loadout_count']}",
        f"- probe_pass: {str(report['probe_pass']).lower()}",
    ]
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
