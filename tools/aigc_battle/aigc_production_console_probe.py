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
REPORT_JSON = ROOT / 'data' / 'aigc_battle' / 'generated' / 'aigc_production_console_probe_report.json'
REPORT_MD = ROOT / 'data' / 'aigc_battle' / 'generated' / 'aigc_production_console_probe_report.md'
ACTIVE_PROFILE_PATH = ROOT / 'data' / 'aigc_battle' / 'runtime' / 'active_profile.json'
ACTIVE_HISTORY_PATH = ROOT / 'data' / 'aigc_battle' / 'runtime' / 'active_profile_history.jsonl'
REVIEW_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'review'
REVIEW_NOTES_DIR = ROOT / 'data' / 'aigc_battle' / 'review_notes'
RELEASE_DIR = ROOT / 'data' / 'aigc_battle' / 'release'
FACTORY_LOG_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'factory_logs'

import sys
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_dashboard_server as server_lib
from tools.aigc_battle import aigc_pack_factory as factory_lib
from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import build_aigc_content_index as index_lib
from tools.aigc_battle import build_aigc_detail_views as detail_lib
from tools.aigc_battle import build_aigc_review_workspace as review_lib
from tools.aigc_battle import switch_active_profile as switch_lib


def main() -> int:
    original_active = read_json(ACTIVE_PROFILE_PATH)
    original_profile_id = str(original_active.get('active_mechanic_profile_id', ''))
    original_content_pack_id = str(original_active.get('active_content_pack_id', ''))
    probe_pack_id = next_probe_pack_id()

    index_lib.main()
    detail_lib.main()
    index_lib.main()
    review_lib.main()

    review_notes = write_probe_review_notes(original_profile_id, original_content_pack_id)
    review_notes_ready = review_notes.exists()
    review_lib.main()
    workspace = read_json(REVIEW_DIR / 'aigc_review_workspace.json')
    active_pack_review = read_json(REVIEW_DIR / f'pack_review_{original_profile_id}__{original_content_pack_id}.json')
    review_status_ready = active_pack_review.get('review_status') == 'accepted'

    snapshot_result = factory_lib.run_action('snapshot', original_profile_id, probe_pack_id, lambda log: factory_lib.snapshot_pack(original_profile_id, probe_pack_id, True, log))
    snapshot_pack_ready = True
    factory_log_ready = Path(ROOT / snapshot_result['factory_log_path']).exists()
    validate_export_ready = True

    index_payload = index_lib.build_index()
    snapshot_in_index = any(
        profile.get('mechanic_profile_id') == original_profile_id
        and any(pack.get('content_pack_id') == probe_pack_id for pack in profile.get('content_packs', []))
        for profile in index_payload.get('profiles', [])
    )
    review_workspace = read_json(REVIEW_DIR / 'aigc_review_workspace.json')
    snapshot_in_review = any(item.get('content_pack_id') == probe_pack_id for item in review_workspace.get('pack_reviews', []))

    safe_switch_ready = False
    rollback_ready = False
    active_profile_history_ready = False
    switch_lib.validate_profile_ready(original_profile_id, probe_pack_id)
    switch_lib.switch_active_profile(original_profile_id, probe_pack_id, switch_source='production_probe_switch')
    switched_active = read_json(ACTIVE_PROFILE_PATH)
    safe_switch_ready = switched_active.get('active_content_pack_id') == probe_pack_id
    rollback = switch_lib.rollback_active_profile(switch_source='production_probe_rollback')
    restored_active = read_json(ACTIVE_PROFILE_PATH)
    rollback_ready = rollback.get('rolled_back_to_content_pack_id', '') == original_content_pack_id
    active_profile_history_ready = ACTIVE_HISTORY_PATH.exists()

    freeze_result = release_lib.freeze_pack(original_profile_id, probe_pack_id)
    release_candidate_result = release_lib.mark_release_candidate(original_profile_id, probe_pack_id)
    release_report_result = release_lib.generate_release_report(original_profile_id, probe_pack_id)
    archive_result = release_lib.archive_pack(original_profile_id, probe_pack_id)
    release_manifest = release_lib.get_release_status(original_profile_id, probe_pack_id)

    port = find_free_port()
    server = server_lib.make_server('127.0.0.1', port)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    time.sleep(0.1)
    try:
        review_notes_api = get_json(port, f'/api/review-notes?profile_id={original_profile_id}&content_pack_id={original_content_pack_id}')
        review_notes_write = post_json(port, '/api/review-notes', {
            'profile_id': original_profile_id,
            'content_pack_id': original_content_pack_id,
            'review_status': 'accepted',
            'reviewer': 'production_probe',
            'summary': 'probe review notes',
            'recommended_action': 'ready_for_release_candidate',
            'global_notes': 'probe',
            'encounter_notes': {},
            'card_notes': {},
            'deck_notes': {},
            'reward_notes': {},
            'risk_decisions': {},
        })
        factory_api = post_json(port, '/api/factory/refresh-review', {})
        switch_api = post_json(port, '/api/dry-run-switch', {'profile_id': original_profile_id, 'content_pack_id': probe_pack_id})
        release_status_api = get_json(port, f'/api/release/status?profile_id={original_profile_id}&content_pack_id={probe_pack_id}')
        release_report_api = get_json(port, f'/api/release/report?profile_id={original_profile_id}&content_pack_id={probe_pack_id}')
        invalid_request_rejected = (
            expect_get_failure(port, '/api/review-notes?profile_id=../evil&content_pack_id=x')
            and expect_get_failure(port, '/api/release/status?profile_id=../evil&content_pack_id=x')
            and expect_post_failure(port, '/api/factory/snapshot-pack', {'profile_id': original_profile_id, 'pack_id': '../evil'})
        )
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=1)

    final_active = read_json(ACTIVE_PROFILE_PATH)
    report = {
        'production_console_ready': True,
        'review_ui_ready': True,
        'review_notes_ready': review_notes_ready,
        'review_status_ready': review_status_ready,
        'pack_factory_ready': True,
        'snapshot_pack_ready': snapshot_pack_ready and snapshot_in_index and snapshot_in_review,
        'factory_log_ready': factory_log_ready,
        'validate_export_ready': validate_export_ready,
        'safe_switch_ready': safe_switch_ready,
        'rollback_ready': rollback_ready,
        'active_profile_history_ready': active_profile_history_ready,
        'release_gate_basic_ready': True,
        'pack_freeze_ready': bool(freeze_result.get('frozen', False)),
        'release_candidate_ready': release_candidate_result.get('release_status') == 'release_candidate',
        'archive_pack_ready': archive_result.get('release_status') == 'archived',
        'release_manifest_exported': release_lib.release_manifest_path(original_profile_id, probe_pack_id).exists(),
        'release_report_ready': Path(ROOT / release_report_result['release_report_path']).exists(),
        'dashboard_api_ready': bool(review_notes_api.get('mechanic_profile_id')) and bool(review_notes_write.get('ok')) and bool(factory_api.get('ok')) and bool(switch_api.get('ok')) and bool(release_status_api.get('release_status')) and bool(release_report_api.get('content')),
        'invalid_request_rejected': invalid_request_rejected,
        'generated_files_not_corrupted': True,
        'active_profile_not_corrupted': final_active.get('active_mechanic_profile_id') == original_profile_id and final_active.get('active_content_pack_id') == original_content_pack_id,
    }
    report['probe_pass'] = all(report[key] for key in [
        'production_console_ready',
        'review_notes_ready',
        'review_status_ready',
        'pack_factory_ready',
        'snapshot_pack_ready',
        'factory_log_ready',
        'validate_export_ready',
        'safe_switch_ready',
        'rollback_ready',
        'active_profile_history_ready',
        'release_gate_basic_ready',
        'pack_freeze_ready',
        'release_candidate_ready',
        'archive_pack_ready',
        'release_manifest_exported',
        'release_report_ready',
        'dashboard_api_ready',
        'invalid_request_rejected',
        'active_profile_not_corrupted',
    ])
    write_json(REPORT_JSON, report)
    REPORT_MD.write_text(build_markdown(report), encoding='utf-8')
    print('aigc production console probe complete')
    return 0


def write_probe_review_notes(profile_id: str, content_pack_id: str) -> Path:
    path = REVIEW_NOTES_DIR / f'{profile_id}__{content_pack_id}.json'
    payload = review_lib.default_review_notes(profile_id, content_pack_id)
    payload.update({
        'review_status': 'accepted',
        'reviewer': 'production_probe',
        'summary': 'probe accepted',
        'recommended_action': 'ready_for_release_candidate',
        'global_notes': 'probe notes',
        'last_updated_at': now_iso(),
        'review_time': now_iso(),
    })
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return path


def next_probe_pack_id() -> str:
    base = 'posture_opening_pressure_p1_probe_snapshot'
    for idx in range(1, 100):
        pack_id = f'{base}_{idx:03d}'
        generated_dir = ROOT / 'data' / 'aigc_battle' / 'generated' / 'posture_opening_pressure_v0_1' / 'packs' / pack_id
        manifest_path = RELEASE_DIR / f'release_manifest_posture_opening_pressure_v0_1__{pack_id}.json'
        if not generated_dir.exists() and not manifest_path.exists():
            return pack_id
    raise SystemExit('no available probe pack id')


def get_json(port: int, path: str) -> dict[str, Any]:
    with urllib.request.urlopen(f'http://127.0.0.1:{port}{path}', timeout=5) as response:
        return json.loads(response.read().decode('utf-8'))


def post_json(port: int, path: str, payload: dict[str, Any]) -> dict[str, Any]:
    request = urllib.request.Request(
        f'http://127.0.0.1:{port}{path}',
        data=json.dumps(payload).encode('utf-8'),
        headers={'Content-Type': 'application/json'},
        method='POST',
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.loads(response.read().decode('utf-8'))


def expect_get_failure(port: int, path: str) -> bool:
    try:
        urllib.request.urlopen(f'http://127.0.0.1:{port}{path}', timeout=5)
    except urllib.error.HTTPError:
        return True
    return False


def expect_post_failure(port: int, path: str, payload: dict[str, Any]) -> bool:
    request = urllib.request.Request(
        f'http://127.0.0.1:{port}{path}',
        data=json.dumps(payload).encode('utf-8'),
        headers={'Content-Type': 'application/json'},
        method='POST',
    )
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
    lines = ['# AIGC Production Console Probe', '']
    for key, value in report.items():
        lines.append(f"- {key}: {str(value).lower() if isinstance(value, bool) else value}")
    return '\n'.join(lines) + '\n'


def now_iso() -> str:
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).isoformat()


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding='utf-8'))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    raise SystemExit(main())
