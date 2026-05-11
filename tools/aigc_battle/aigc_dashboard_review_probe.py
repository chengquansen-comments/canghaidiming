#!/usr/bin/env python3
from __future__ import annotations

import json
import socket
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
REPORT_JSON = ROOT / 'data' / 'aigc_battle' / 'generated' / 'aigc_dashboard_review_probe_report.json'
REPORT_MD = ROOT / 'data' / 'aigc_battle' / 'generated' / 'aigc_dashboard_review_probe_report.md'
ACTIVE_PROFILE_PATH = ROOT / 'data' / 'aigc_battle' / 'runtime' / 'active_profile.json'
REVIEW_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'review'

import sys
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_dashboard_server as server_lib
from tools.aigc_battle import build_aigc_content_index as index_lib
from tools.aigc_battle import build_aigc_detail_views as detail_lib
from tools.aigc_battle import build_aigc_review_workspace as review_lib


def main() -> int:
    original_active = read_json(ACTIVE_PROFILE_PATH)
    original_profile_id = str(original_active.get('active_mechanic_profile_id', ''))
    original_content_pack_id = str(original_active.get('active_content_pack_id', ''))

    index_lib.main()
    detail_lib.main()
    index_lib.main()
    review_lib.main()

    workspace = read_json(REVIEW_DIR / 'aigc_review_workspace.json')
    compare = read_json(REVIEW_DIR / 'pack_compare_matrix.json')
    active_pack = next((item for item in workspace.get('pack_reviews', []) if item.get('is_active_pack')), None)
    active_pack_review = read_json(ROOT / active_pack['pack_review_json_path']) if active_pack else {}

    pack_reports_ready = all((ROOT / item['pack_review_json_path']).exists() and (ROOT / item['pack_review_md_path']).exists() for item in workspace.get('pack_reviews', []))
    review_reports_exported = all((ROOT / item['review_report_md_path']).exists() for item in workspace.get('pack_reviews', []))

    port = find_free_port()
    server = server_lib.make_server('127.0.0.1', port)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    time.sleep(0.1)

    try:
        review_workspace_api = get_json(port, '/api/review-workspace')
        pack_review_api = get_json(port, f"/api/pack-review?profile_id={workspace['active_profile_id']}&content_pack_id={workspace['active_content_pack_id']}")
        compare_api = get_json(port, '/api/compare-matrix')
        review_report_api = get_json(port, f"/api/review-report?profile_id={workspace['active_profile_id']}&content_pack_id={workspace['active_content_pack_id']}")
        invalid_review_request_rejected = (
            expect_get_failure(port, '/api/pack-review?profile_id=../evil&content_pack_id=x')
            and expect_get_failure(port, '/api/review-report?profile_id=posture_opening_pressure_v0_1&content_pack_id=../evil')
            and expect_get_failure(port, '/api/review-workspace?path=evil')
        )
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=1)

    final_active = read_json(ACTIVE_PROFILE_PATH)
    report = {
        'review_workspace_built': (REVIEW_DIR / 'aigc_review_workspace.json').exists() and (REVIEW_DIR / 'aigc_review_workspace.md').exists(),
        'pack_review_count': len(workspace.get('pack_reviews', [])),
        'compare_matrix_ready': (REVIEW_DIR / 'pack_compare_matrix.json').exists() and (REVIEW_DIR / 'pack_compare_matrix.md').exists(),
        'active_pack_encounter_review_ready': bool(active_pack_review.get('encounter_review_table')),
        'active_pack_card_pool_review_ready': bool(active_pack_review.get('card_pool_review_table')),
        'active_pack_deck_review_ready': bool(active_pack_review.get('deck_review_table')),
        'active_pack_reward_review_ready': bool(active_pack_review.get('reward_review_table')),
        'run_pacing_view_ready': bool(active_pack_review.get('run_pacing_view')),
        'encounter_design_cards_ready': bool(active_pack_review.get('encounter_design_cards')),
        'deck_behavior_review_ready': bool(active_pack_review.get('deck_review_table')),
        'reward_progression_review_ready': bool(active_pack_review.get('reward_review_table')),
        'risk_board_ready': bool(active_pack_review.get('risk_summary')),
        'filter_options_ready': bool(active_pack_review.get('visual_filter_options')),
        'review_reports_exported': review_reports_exported,
        'strongest_pack_detected': bool(compare.get('strongest_pack_by_avg_power')),
        'most_risky_pack_detected': bool(compare.get('most_risky_pack')),
        'healthiest_pack_detected': bool(compare.get('healthiest_pack')),
        'server_review_workspace_api_ready': bool(review_workspace_api.get('active_profile_id')),
        'server_pack_review_api_ready': bool(pack_review_api.get('pack_identity')),
        'server_compare_matrix_api_ready': bool(compare_api.get('packs')),
        'server_review_report_api_ready': bool(review_report_api.get('content')),
        'invalid_review_request_rejected': invalid_review_request_rejected,
        'active_profile_unchanged': final_active.get('active_mechanic_profile_id') == original_profile_id and final_active.get('active_content_pack_id') == original_content_pack_id,
        'profile_count': int(workspace.get('profile_count', 0)),
        'content_pack_count': int(workspace.get('content_pack_count', 0)),
        'pack_review_files_ready': pack_reports_ready,
        'active_profile_id': workspace.get('active_profile_id', ''),
        'active_content_pack_id': workspace.get('active_content_pack_id', ''),
    }
    report['probe_pass'] = (
        report['review_workspace_built']
        and report['pack_review_count'] >= report['content_pack_count']
        and report['compare_matrix_ready']
        and report['active_pack_encounter_review_ready']
        and report['active_pack_card_pool_review_ready']
        and report['active_pack_deck_review_ready']
        and report['active_pack_reward_review_ready']
        and report['run_pacing_view_ready']
        and report['encounter_design_cards_ready']
        and report['deck_behavior_review_ready']
        and report['reward_progression_review_ready']
        and report['risk_board_ready']
        and report['filter_options_ready']
        and report['review_reports_exported']
        and report['server_review_workspace_api_ready']
        and report['server_pack_review_api_ready']
        and report['server_compare_matrix_api_ready']
        and report['server_review_report_api_ready']
        and report['invalid_review_request_rejected']
        and report['active_profile_unchanged']
        and report['profile_count'] >= 4
        and report['content_pack_count'] >= 5
        and report['pack_review_files_ready']
    )
    write_json(REPORT_JSON, report)
    REPORT_MD.write_text(build_markdown(report), encoding='utf-8')
    print('aigc dashboard review probe complete')
    return 0


def get_json(port: int, path: str) -> dict[str, Any]:
    request = urllib.request.Request(f'http://127.0.0.1:{port}{path}')
    with urllib.request.urlopen(request, timeout=5) as response:
        return json.loads(response.read().decode('utf-8'))


def expect_get_failure(port: int, path: str) -> bool:
    request = urllib.request.Request(f'http://127.0.0.1:{port}{path}')
    try:
        urllib.request.urlopen(request, timeout=5)
    except urllib.error.HTTPError:
        return True
    return False


def find_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(('127.0.0.1', 0))
        return int(sock.getsockname()[1])


def build_markdown(report: dict[str, Any]) -> str:
    lines = ['# AIGC Dashboard Review Probe', '']
    for key, value in report.items():
        lines.append(f"- {key}: {str(value).lower() if isinstance(value, bool) else value}")
    return '\n'.join(lines) + '\n'


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding='utf-8'))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    raise SystemExit(main())
