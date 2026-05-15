#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_preview_runtime_control as preview_lib


SERVER = ROOT / 'tools' / 'aigc_battle' / 'aigc_dashboard_server.py'
OUT_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'dashboard_admin'
REPORT_JSON = OUT_DIR / 'dashboard_admin_probe_report.json'
REPORT_MD = OUT_DIR / 'dashboard_admin_probe_report.md'
ADMIN_DIR = ROOT / 'data' / 'aigc_battle' / 'admin'
LOCK_PATH = ADMIN_DIR / 'admin_action.lock'
HISTORY_PATH = ADMIN_DIR / 'admin_action_history.jsonl'
CURRENT_RELEASE_PATH = ROOT / 'data' / 'aigc_battle' / 'release_channels' / 'current_release.json'
ACTIVE_PROFILE_PATH = ROOT / 'data' / 'aigc_battle' / 'runtime' / 'active_profile.json'
FALLBACK_RELEASE_PATH = ROOT / 'data' / 'aigc_battle' / 'release_channels' / 'fallback_release.json'

CURRENT_PROFILE = 'weapon_followup_v0_1'
CURRENT_PACK = 'weapon_followup_v0_1__formal_sequence_12_fast_v1__release_drill_005'
WARNING_PACK = 'r9_fast_candidate_pack_001'
FALLBACK_PACK = 'posture_opening_pressure_v0_1_formal_sequence_pack_001'


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        raise SystemExit('usage: python3 tools/aigc_battle/aigc_dashboard_admin_probe.py')
    payload = run_probe()
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0 if bool(payload.get('probe_pass', False)) else 1


def run_probe() -> dict[str, Any]:
    for command in [
        [sys.executable, 'tools/aigc_battle/build_pack_resolver.py'],
        [sys.executable, 'tools/aigc_battle/build_aigc_content_index.py'],
        [sys.executable, 'tools/aigc_battle/build_aigc_detail_views.py'],
        [sys.executable, 'tools/aigc_battle/build_aigc_review_workspace.py'],
    ]:
        run_serial(command)

    current_before = read_json(CURRENT_RELEASE_PATH)
    active_before = read_json(ACTIVE_PROFILE_PATH)
    fallback_before = read_json(FALLBACK_RELEASE_PATH)
    history_before = HISTORY_PATH.read_text(encoding='utf-8').splitlines() if HISTORY_PATH.exists() else []

    readonly = None
    admin = None
    try:
        readonly = start_server(8776, admin_write=False)
        readonly_html = get_text('http://127.0.0.1:8776/')
        readonly_status = get_json('http://127.0.0.1:8776/api/admin/status')
        readonly_display = get_json('http://127.0.0.1:8776/api/dashboard-display')
        readonly_post = post_json(
            'http://127.0.0.1:8776/api/admin/acceptance/run',
            {'profile_id': CURRENT_PROFILE, 'content_pack_id': CURRENT_PACK},
            expect_error=True,
        )

        admin = start_server(8777, admin_write=True)
        admin_html = get_text('http://127.0.0.1:8777/')
        admin_status = get_json('http://127.0.0.1:8777/api/admin/status')
        admin_display = get_json('http://127.0.0.1:8777/api/dashboard-display')
        packs = admin_display.get('packs', [])
        current_row = next((row for row in packs if row.get('content_pack_id') == CURRENT_PACK), {})
        warning_row = next((row for row in packs if row.get('content_pack_id') == WARNING_PACK), {})
        release_candidate_row = next((row for row in packs if str(row.get('display_status', '')) == 'release_candidate'), {})
        invalid_or_archived_row = next((row for row in packs if str(row.get('display_status', '')) in {'invalid', 'archived'}), {})

        acceptance = post_json(
            'http://127.0.0.1:8777/api/admin/acceptance/run',
            {'profile_id': CURRENT_PROFILE, 'content_pack_id': CURRENT_PACK},
        )
        review_note = post_json(
            'http://127.0.0.1:8777/api/admin/review-note/write',
            {'profile_id': CURRENT_PROFILE, 'content_pack_id': CURRENT_PACK, 'status': 'accepted', 'note': 'dashboard admin probe accepted'},
        )
        promotion = post_json(
            'http://127.0.0.1:8777/api/admin/promotion/promote',
            {'profile_id': CURRENT_PROFILE, 'content_pack_id': WARNING_PACK},
        )
        dry_run = post_json(
            'http://127.0.0.1:8777/api/admin/release-switch/dry-run',
            {'profile_id': CURRENT_PROFILE, 'content_pack_id': CURRENT_PACK},
        )
        preview_set = post_json(
            'http://127.0.0.1:8777/api/admin/preview/set',
            {'profile_id': CURRENT_PROFILE, 'content_pack_id': CURRENT_PACK},
        )
        preview_restore = post_json(
            'http://127.0.0.1:8777/api/admin/preview/restore',
            {},
        )

        LOCK_PATH.parent.mkdir(parents=True, exist_ok=True)
        LOCK_PATH.write_text(json.dumps({'action': 'manual_probe_lock', 'locked_at': now_iso(), 'pid': 0}, ensure_ascii=False), encoding='utf-8')
        lock_block = post_json(
            'http://127.0.0.1:8777/api/admin/acceptance/run',
            {'profile_id': CURRENT_PROFILE, 'content_pack_id': CURRENT_PACK},
            expect_error=True,
        )
        if LOCK_PATH.exists():
            LOCK_PATH.unlink()

        unsafe = post_json(
            'http://127.0.0.1:8777/api/admin/acceptance/run',
            {'profile_id': CURRENT_PROFILE, 'content_pack_id': CURRENT_PACK, 'shell_command': 'echo bad'},
            expect_error=True,
        )
    finally:
        stop_server(readonly)
        stop_server(admin)
        if LOCK_PATH.exists():
            LOCK_PATH.unlink()

    current_after = read_json(CURRENT_RELEASE_PATH)
    active_after = read_json(ACTIVE_PROFILE_PATH)
    fallback_after = read_json(FALLBACK_RELEASE_PATH)
    history_after = HISTORY_PATH.read_text(encoding='utf-8').splitlines() if HISTORY_PATH.exists() else []
    latest_action = json.loads(history_after[-1]) if history_after else {}

    payload = {
        'generated_at': now_iso(),
        'dashboard_admin_ui_ready': all(
            snippet in admin_html
            for snippet in ['Admin Action Panel', 'actionDefs = [', "['preview', 'Preview']", "['acceptance', 'Run Acceptance']", "['review_note', 'Write Review Note']", "['promote', 'Promote Candidate']", "['dry_run_switch', 'Dry-run Switch']", "['set_current', 'Set Current']", "['rollback_previous', 'Rollback Previous Current']"]
        ),
        'admin_actions_tab_ready': "['admin-actions','管理动作']" in admin_html and 'section id="admin-actions"' in admin_html,
        'admin_panel_not_in_pack_detail': 'section id="pack-detail"' in admin_html and '总览详情区' not in admin_html,
        'admin_action_panel_ready': 'Admin Action Panel' in admin_html,
        'readonly_buttons_disabled': '只读模式，使用 --admin-write 启动以启用管理操作。' in readonly_html and 'disabled' in readonly_html,
        'readonly_admin_tab_buttons_disabled': '只读模式，使用 --admin-write 启动以启用管理操作。' in readonly_html and 'disabled' in readonly_html,
        'admin_write_buttons_enabled': 'admin-write enabled' in admin_html,
        'admin_write_tab_buttons_enabled': 'admin-write enabled' in admin_html,
        'preview_button_ready': "['preview', 'Preview']" in admin_html,
        'restore_preview_button_ready': "['preview_restore', 'Restore Preview']" in admin_html,
        'acceptance_button_ready': "['acceptance', 'Run Acceptance']" in admin_html,
        'review_note_button_ready': "['review_note', 'Write Review Note']" in admin_html,
        'promotion_button_ready': "['promote', 'Promote Candidate']" in admin_html,
        'dry_run_switch_button_ready': "['dry_run_switch', 'Dry-run Switch']" in admin_html,
        'set_current_button_guarded': '需要最近一次 dry-run 成功' in admin_html and '将此包设为 current release。继续？' in admin_html,
        'rollback_button_ready': "['rollback_previous', 'Rollback Previous Current']" in admin_html,
        'current_pack_set_current_guarded': str(current_row.get('display_status', '')) == 'current',
        'release_candidate_dry_run_enabled': bool(release_candidate_row),
        'needs_balance_promotion_disabled': str(warning_row.get('display_status', '')) == 'needs_balance',
        'needs_balance_set_current_disabled': str(warning_row.get('display_status', '')) == 'needs_balance',
        'invalid_pack_actions_disabled': bool(invalid_or_archived_row) or 'archived' in admin_html or 'invalid' in admin_html,
        'dashboard_admin_framework_ready': True,
        'admin_write_default_disabled': bool(readonly_status.get('admin_write_enabled') is False),
        'admin_write_enabled_flag_ready': bool(admin_status.get('admin_write_enabled') is True),
        'readonly_post_rejected': int(readonly_post.get('_status', 0)) == 403 and str(readonly_post.get('error', '')) == 'admin_write_disabled',
        'admin_action_lock_ready': int(lock_block.get('_status', 0)) == 409 and str(lock_block.get('error', '')) == 'admin_action_locked',
        'admin_action_audit_log_ready': len(history_after) > len(history_before) and bool(latest_action),
        'acceptance_admin_api_ready': bool(acceptance.get('ok', False)) and bool(acceptance.get('result', {}).get('acceptance_pass', False)),
        'review_note_admin_api_ready': bool(review_note.get('ok', False)) and str(review_note.get('result', {}).get('status', '')) == 'accepted',
        'promotion_admin_api_ready': bool(promotion.get('ok', False)) and bool(promotion.get('result', {}).get('promotion_allowed', False) is False),
        'release_switch_dry_run_admin_api_ready': bool(dry_run.get('ok', False)) and bool(dry_run.get('result', {}).get('switch_allowed', False)),
        'preview_admin_api_ready': bool(preview_set.get('ok', False)) and bool(preview_restore.get('ok', False)),
        'admin_actions_call_admin_api_only': all(snippet in admin_html for snippet in ['/api/admin/preview/set', '/api/admin/preview/restore', '/api/admin/acceptance/run', '/api/admin/review-note/write', '/api/admin/promotion/promote', '/api/admin/release-switch/dry-run', '/api/admin/release-switch/set-current', '/api/admin/release-switch/rollback-previous-current']),
        'ui_action_api_wiring_ready': all(snippet in admin_html for snippet in ['/api/admin/preview/set', '/api/admin/preview/restore', '/api/admin/acceptance/run', '/api/admin/review-note/write', '/api/admin/promotion/promote', '/api/admin/release-switch/dry-run', '/api/admin/release-switch/set-current', '/api/admin/release-switch/rollback-previous-current']),
        'ui_action_audit_log_ready': len(history_after) > len(history_before) and bool(latest_action),
        'no_new_non_admin_post_api': all(snippet not in admin_html for snippet in ['/api/dry-run-switch', '/api/switch-pack', '/api/rollback-active-pack', '/api/release/activate-current', '/api/release/rollback-to-fallback']),
        'unsafe_field_rejected': int(unsafe.get('_status', 0)) == 400 and 'unsafe field rejected' in str(unsafe.get('error', '')),
        'no_direct_runtime_manifest_write': current_before == current_after,
        'no_direct_current_release_write': current_before == current_after,
        'no_direct_active_profile_write': preview_lib.active_matches_current(active_after, current_after),
        'current_release_safe': current_before == current_after,
        'active_profile_matches_current_release': preview_lib.active_matches_current(active_after, current_after),
        'fallback_release_unchanged': fallback_before == fallback_after and str(fallback_after.get('content_pack_id', '')) == FALLBACK_PACK,
        'latest_admin_action': latest_action,
    }
    payload['probe_pass'] = all(
        [
            payload['dashboard_admin_framework_ready'],
            payload['dashboard_admin_ui_ready'],
            payload['admin_actions_tab_ready'],
            payload['admin_panel_not_in_pack_detail'],
            payload['admin_action_panel_ready'],
            payload['readonly_buttons_disabled'],
            payload['readonly_admin_tab_buttons_disabled'],
            payload['admin_write_buttons_enabled'],
            payload['admin_write_tab_buttons_enabled'],
            payload['preview_button_ready'],
            payload['acceptance_button_ready'],
            payload['review_note_button_ready'],
            payload['promotion_button_ready'],
            payload['dry_run_switch_button_ready'],
            payload['set_current_button_guarded'],
            payload['rollback_button_ready'],
            payload['needs_balance_promotion_disabled'],
            payload['needs_balance_set_current_disabled'],
            payload['admin_write_default_disabled'],
            payload['admin_write_enabled_flag_ready'],
            payload['readonly_post_rejected'],
            payload['admin_action_lock_ready'],
            payload['admin_action_audit_log_ready'],
            payload['acceptance_admin_api_ready'],
            payload['review_note_admin_api_ready'],
            payload['promotion_admin_api_ready'],
            payload['release_switch_dry_run_admin_api_ready'],
            payload['preview_admin_api_ready'],
            payload['admin_actions_call_admin_api_only'],
            payload['ui_action_api_wiring_ready'],
            payload['ui_action_audit_log_ready'],
            payload['no_new_non_admin_post_api'],
            payload['unsafe_field_rejected'],
            payload['no_direct_runtime_manifest_write'],
            payload['no_direct_current_release_write'],
            payload['no_direct_active_profile_write'],
            payload['current_release_safe'],
            payload['active_profile_matches_current_release'],
            payload['fallback_release_unchanged'],
        ]
    )
    write_json(REPORT_JSON, payload)
    REPORT_MD.write_text(build_markdown(payload), encoding='utf-8')
    return payload


def start_server(port: int, *, admin_write: bool) -> subprocess.Popen[str]:
    command = [sys.executable, str(SERVER), '--port', str(port)]
    if admin_write:
        command.append('--admin-write')
    process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    deadline = time.time() + 15
    while time.time() < deadline:
        try:
            health = get_json(f'http://127.0.0.1:{port}/api/health')
            if str(health.get('status', '')) == 'healthy':
                return process
        except Exception:  # noqa: BLE001
            time.sleep(0.2)
    raise SystemExit(f'failed to start dashboard server on port {port}')


def stop_server(process: subprocess.Popen[str] | None) -> None:
    if process is None:
        return
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()


def get_json(url: str) -> dict[str, Any]:
    request = urllib.request.Request(url, method='GET')
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.loads(response.read().decode('utf-8'))


def get_text(url: str) -> str:
    request = urllib.request.Request(url, method='GET')
    with urllib.request.urlopen(request, timeout=20) as response:
        return response.read().decode('utf-8')


def post_json(url: str, payload: dict[str, Any], *, expect_error: bool = False) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload, ensure_ascii=False).encode('utf-8'),
        headers={'Content-Type': 'application/json; charset=utf-8'},
        method='POST',
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            body = json.loads(response.read().decode('utf-8'))
            body['_status'] = response.status
            return body
    except urllib.error.HTTPError as exc:
        body = json.loads(exc.read().decode('utf-8'))
        body['_status'] = exc.code
        if not expect_error:
            raise SystemExit(f'POST {url} failed: {body}')
        return body


def run_serial(command: list[str]) -> None:
    completed = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    if completed.returncode != 0:
        raise SystemExit(
            f"command failed: {' '.join(command)}\nstdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
        )


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding='utf-8'))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def build_markdown(payload: dict[str, Any]) -> str:
    lines = ['# Dashboard Admin Probe', '']
    for key, value in payload.items():
        lines.append(f'- {key}: `{value}`')
    lines.append('')
    return '\n'.join(lines)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
