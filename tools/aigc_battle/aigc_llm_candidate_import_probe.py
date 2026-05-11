#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = ROOT / 'tools' / 'aigc_battle'
GENERATED_DIR = ROOT / 'data' / 'aigc_battle' / 'generated'
CANDIDATE_DIR = ROOT / 'data' / 'aigc_battle' / 'llm_candidates' / 'posture_llm_candidate_v0_1'
PROFILE_ID = 'posture_llm_candidate_v0_1'


def main() -> int:
    run([sys.executable, str(TOOLS_DIR / 'import_llm_candidates.py'), PROFILE_ID])
    run([sys.executable, str(TOOLS_DIR / 'validate_content_pack.py'), PROFILE_ID])
    run([sys.executable, str(TOOLS_DIR / 'export_runtime_manifest.py'), PROFILE_ID])
    run([sys.executable, str(TOOLS_DIR / 'switch_active_profile.py'), PROFILE_ID])
    run([sys.executable, str(TOOLS_DIR / 'aigc_formal_sequence_probe.py')])
    run([sys.executable, str(TOOLS_DIR / 'aigc_full_sequence_reward_probe.py')])
    run([sys.executable, str(TOOLS_DIR / 'aigc_sequence_balance_probe.py')])

    generated_dir = GENERATED_DIR / PROFILE_ID
    summary = read_json(generated_dir / 'imported_candidate_summary.json')
    validation = read_json(generated_dir / 'validation_report.json')
    formal_probe = read_json(generated_dir / 'formal_sequence_probe_report.json')
    reward_probe = read_json(generated_dir / 'full_sequence_reward_probe_report.json')
    balance_probe = read_json(generated_dir / 'sequence_balance_probe_report.json')
    active_before_invalid = read_json(ROOT / 'data' / 'aigc_battle' / 'runtime' / 'active_profile.json')

    invalid_cards = CANDIDATE_DIR / 'llm_card_candidates.invalid.jsonl'
    invalid_decks = CANDIDATE_DIR / 'llm_deck_candidates.invalid.jsonl'
    invalid_result = subprocess.run(
        [sys.executable, str(TOOLS_DIR / 'import_llm_candidates.py'), PROFILE_ID, '--cards', str(invalid_cards), '--decks', str(invalid_decks)],
        cwd=ROOT,
    )
    invalid_summary_path = generated_dir / 'imported_candidate_summary.invalid_attempt.json'
    invalid_summary = read_json(invalid_summary_path) if invalid_summary_path.exists() else {}
    active_after_invalid = read_json(ROOT / 'data' / 'aigc_battle' / 'runtime' / 'active_profile.json')

    report = {
        'llm_candidate_import_ready': bool(summary.get('import_ready_for_validation', False)),
        'valid_candidate_imported': bool(summary.get('accepted_card_candidate_count', 0)) and bool(summary.get('accepted_deck_candidate_count', 0)),
        'valid_candidate_exported': bool(validation.get('ready_for_runtime_export', False)),
        'invalid_candidate_rejected': invalid_result.returncode != 0 and (
            int(invalid_summary.get('rejected_card_candidate_count', 0)) > 0 or int(invalid_summary.get('rejected_deck_candidate_count', 0)) > 0
        ),
        'invalid_candidate_blocked_before_export': invalid_result.returncode != 0,
        'invalid_candidate_not_active': active_before_invalid == active_after_invalid,
        'llm_full_sequence_coverage_complete': bool(validation.get('llm_full_sequence_coverage_complete', False)),
        'llm_sequence_balance_pass': bool(balance_probe.get('sequence_balance_pass', False)),
        'llm_reward_closure_ready': bool(reward_probe.get('full_sequence_loop_closed', False)),
        'llm_content_formal_playable': bool(formal_probe.get('all_formal_battles_use_generated_loadout', False)) and int(formal_probe.get('fallback_loadout_count', 999)) == 0,
        'fallback_loadout_count': int(formal_probe.get('fallback_loadout_count', 999)),
        'probe_pass': False,
    }
    report['probe_pass'] = all(
        [
            report['llm_candidate_import_ready'],
            report['valid_candidate_imported'],
            report['valid_candidate_exported'],
            report['invalid_candidate_rejected'],
            report['invalid_candidate_blocked_before_export'],
            report['invalid_candidate_not_active'],
            report['llm_full_sequence_coverage_complete'],
            report['llm_sequence_balance_pass'],
            report['llm_reward_closure_ready'],
            report['llm_content_formal_playable'],
            report['fallback_loadout_count'] == 0,
        ]
    )
    write_json(generated_dir / 'llm_candidate_import_probe_report.json', report)
    write_markdown(generated_dir / 'llm_candidate_import_probe_report.md', report)
    print('llm candidate import probe complete')
    return 0 if report['probe_pass'] else 1


def run(command: list[str]) -> None:
    subprocess.run(command, check=True, cwd=ROOT)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding='utf-8'))


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def write_markdown(path: Path, report: dict[str, Any]) -> None:
    lines = [
        '# AIGC Battle v6 LLM Candidate Import Probe',
        '',
        f"- llm_candidate_import_ready: {str(report['llm_candidate_import_ready']).lower()}",
        f"- valid_candidate_imported: {str(report['valid_candidate_imported']).lower()}",
        f"- valid_candidate_exported: {str(report['valid_candidate_exported']).lower()}",
        f"- invalid_candidate_rejected: {str(report['invalid_candidate_rejected']).lower()}",
        f"- invalid_candidate_blocked_before_export: {str(report['invalid_candidate_blocked_before_export']).lower()}",
        f"- invalid_candidate_not_active: {str(report['invalid_candidate_not_active']).lower()}",
        f"- llm_full_sequence_coverage_complete: {str(report['llm_full_sequence_coverage_complete']).lower()}",
        f"- llm_sequence_balance_pass: {str(report['llm_sequence_balance_pass']).lower()}",
        f"- llm_reward_closure_ready: {str(report['llm_reward_closure_ready']).lower()}",
        f"- llm_content_formal_playable: {str(report['llm_content_formal_playable']).lower()}",
        f"- fallback_loadout_count: {report['fallback_loadout_count']}",
        f"- probe_pass: {str(report['probe_pass']).lower()}",
    ]
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')


if __name__ == '__main__':
    raise SystemExit(main())
