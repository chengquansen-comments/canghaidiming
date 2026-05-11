#!/usr/bin/env python3
from __future__ import annotations

import json
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
INDEX_JSON = ROOT / 'data' / 'aigc_battle' / 'generated' / 'aigc_content_index.json'
REPORT_JSON = ROOT / 'data' / 'aigc_battle' / 'generated' / 'aigc_dashboard_detail_probe_report.json'
REPORT_MD = ROOT / 'data' / 'aigc_battle' / 'generated' / 'aigc_dashboard_detail_probe_report.md'
ACTIVE_PROFILE_PATH = ROOT / 'data' / 'aigc_battle' / 'runtime' / 'active_profile.json'

import sys
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_dashboard_server as server_lib
from tools.aigc_battle import build_aigc_content_index as index_lib
from tools.aigc_battle import build_aigc_detail_views as detail_lib


def main() -> int:
    original_active = read_json(ACTIVE_PROFILE_PATH)
    index_lib.write_index_artifacts()
    detail_lib.main()
    index_lib.write_index_artifacts()

    index_payload = read_json(INDEX_JSON)
    all_packs = [pack for profile in index_payload.get('profiles', []) for pack in profile.get('content_packs', [])]
    active_profile_id = index_payload.get('active_profile_id', '')
    active_pack_id = index_payload.get('active_content_pack_id', '')
    active_pack = next((pack for pack in all_packs if pack.get('is_active_pack')), None)
    active_pack_detail = {}
    if active_pack and active_pack.get('pack_detail_json_path'):
        active_pack_detail = read_json(ROOT / active_pack['pack_detail_json_path'])

    profile_detail_count = 0
    pack_detail_count = 0
    profile_detail_all_generated = True
    pack_detail_all_generated = True
    for profile in index_payload.get('profiles', []):
        if not profile.get('profile_detail_json_path') or not profile.get('profile_detail_md_path'):
            profile_detail_all_generated = False
        else:
            profile_detail_count += 1
        for pack in profile.get('content_packs', []):
            if not pack.get('pack_detail_json_path') or not pack.get('pack_detail_md_path'):
                pack_detail_all_generated = False
            else:
                pack_detail_count += 1

    sequence_detail_count = len(active_pack_detail.get('sequence_detail', []))
    card_pool_summary_ready = 'card_pool_summary' in active_pack_detail
    card_pool_detail_ready = bool(active_pack_detail.get('card_pool_detail'))
    card_usage_index_ready = bool(active_pack_detail.get('card_usage_index'))
    unused_cards_reported = 'unused_cards' in active_pack_detail
    orphan_card_count_checked = 'orphan_card_count' in active_pack_detail
    card_summaries_ready = any(item.get('card_summaries') for item in active_pack_detail.get('sequence_detail', []))
    deck_summaries_ready = all('deck_summary' in item for item in active_pack_detail.get('sequence_detail', [])) if active_pack_detail.get('sequence_detail') else False
    reward_summaries_ready = all('reward_summary' in item for item in active_pack_detail.get('sequence_detail', [])) if active_pack_detail.get('sequence_detail') else False
    validation_summary_ready = 'validation_summary' in active_pack_detail
    runtime_primitive_detail_ready = bool(active_pack_detail.get('runtime_primitive_summary')) and any(item.get('opening_pressure') for item in active_pack_detail.get('sequence_detail', []))
    realm_eligibility_detail_ready = bool(active_pack_detail.get('validation_summary', {}).get('deck_card_realm_eligibility_valid') is not None) and any('realm_eligible_for_slot' in card for item in active_pack_detail.get('sequence_detail', []) for card in item.get('card_summaries', []))

    server = server_lib.make_server('127.0.0.1', 8766)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    time.sleep(0.1)
    try:
        profile_detail_api = get_json('/api/profile-detail?profile_id=' + urllib.parse.quote(str(active_profile_id)), port=8766)
        pack_detail_api = get_json('/api/pack-detail?profile_id=' + urllib.parse.quote(str(active_profile_id)) + '&content_pack_id=', port=8766)
        server_profile_detail_api_ready = profile_detail_api.get('mechanic_profile_id') == active_profile_id
        server_pack_detail_api_ready = pack_detail_api.get('content_pack_id') == active_pack_id
        invalid_detail_request_rejected = expect_get_failure('/api/profile-detail?profile_id=../evil', port=8766) and expect_get_failure('/api/pack-detail?profile_id=' + urllib.parse.quote(str(active_profile_id)) + '&content_pack_id=../evil', port=8766)
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=1)

    active_profile_after = read_json(ACTIVE_PROFILE_PATH)
    active_profile_unchanged = active_profile_after == original_active

    report = {
        'detail_builder_ready': True,
        'profile_detail_count': profile_detail_count,
        'pack_detail_count': pack_detail_count,
        'profile_detail_all_generated': profile_detail_all_generated,
        'pack_detail_all_generated': pack_detail_all_generated,
        'active_pack_sequence_detail_ready': active_pack is not None and sequence_detail_count == int(active_pack_detail.get('formal_encounter_total_count', 0)),
        'sequence_detail_count': sequence_detail_count,
        'card_pool_summary_ready': card_pool_summary_ready,
        'card_pool_detail_ready': card_pool_detail_ready,
        'card_usage_index_ready': card_usage_index_ready,
        'unused_cards_reported': unused_cards_reported,
        'orphan_card_count_checked': orphan_card_count_checked,
        'card_summaries_ready': card_summaries_ready,
        'deck_summaries_ready': deck_summaries_ready,
        'reward_summaries_ready': reward_summaries_ready,
        'validation_summary_ready': validation_summary_ready,
        'runtime_primitive_detail_ready': runtime_primitive_detail_ready,
        'realm_eligibility_detail_ready': realm_eligibility_detail_ready,
        'server_profile_detail_api_ready': server_profile_detail_api_ready,
        'server_pack_detail_api_ready': server_pack_detail_api_ready,
        'invalid_detail_request_rejected': invalid_detail_request_rejected,
        'active_profile_unchanged': active_profile_unchanged,
    }
    report['probe_pass'] = (
        report['detail_builder_ready']
        and report['profile_detail_all_generated']
        and report['pack_detail_all_generated']
        and report['active_pack_sequence_detail_ready']
        and report['card_pool_summary_ready']
        and report['card_pool_detail_ready']
        and report['card_usage_index_ready']
        and report['orphan_card_count_checked']
        and report['card_summaries_ready']
        and report['deck_summaries_ready']
        and report['reward_summaries_ready']
        and report['validation_summary_ready']
        and report['realm_eligibility_detail_ready']
        and report['server_profile_detail_api_ready']
        and report['server_pack_detail_api_ready']
        and report['invalid_detail_request_rejected']
        and report['active_profile_unchanged']
    )
    write_json(REPORT_JSON, report)
    REPORT_MD.write_text(build_markdown(report), encoding='utf-8')
    print('dashboard detail probe complete')
    return 0


def get_json(path: str, port: int) -> dict[str, Any]:
    request = urllib.request.Request(f'http://127.0.0.1:{port}{path}')
    with urllib.request.urlopen(request, timeout=5) as response:
        return json.loads(response.read().decode('utf-8'))


def expect_get_failure(path: str, port: int) -> bool:
    request = urllib.request.Request(f'http://127.0.0.1:{port}{path}')
    try:
        urllib.request.urlopen(request, timeout=5)
    except urllib.error.HTTPError:
        return True
    return False


def build_markdown(report: dict[str, Any]) -> str:
    lines = ['# AIGC Dashboard Detail Probe', '']
    for key, value in report.items():
        lines.append(f'- {key}: {str(value).lower() if isinstance(value, bool) else value}')
    return '\n'.join(lines) + '\n'


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding='utf-8'))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    raise SystemExit(main())
