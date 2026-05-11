#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
import threading
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_dashboard_server as dashboard_lib
from tools.aigc_battle import aigc_release_gate as release_lib

REPORT_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'release_smoke'
REPORT_JSON = REPORT_DIR / 'release_channel_probe_report.json'
REPORT_MD = REPORT_DIR / 'release_channel_probe_report.md'


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print('usage: python3 tools/aigc_battle/aigc_release_channel_probe.py', file=sys.stderr)
        return 1
    release_lib.ensure_default_release_channels()
    channels = release_lib.show_channels()
    current = channels.get('current_release', {})
    fallback = channels.get('fallback_release', {})
    current_release_valid = validate_channel_pack(current, allow_archived=False)
    fallback_release_valid = validate_channel_pack(fallback, allow_archived=True)
    release_lib.activate_current_release()
    activate_current_ready = bool(release_lib.show_channels().get('active_runtime', {}).get('matches_current_release', False))
    release_lib.rollback_to_fallback()
    rollback_to_fallback_ready = bool(release_lib.active_profile_matches(str(fallback.get('mechanic_profile_id', '')), str(fallback.get('content_pack_id', ''))))
    release_lib.activate_current_release()
    api_ready, invalid_release_pack_rejected = verify_channel_api()
    report = {
        'release_channels_ready': release_lib.release_channel_path('current').exists() and release_lib.release_channel_path('fallback').exists(),
        'current_release_ready': bool(current),
        'fallback_release_ready': bool(fallback),
        'current_release_valid': current_release_valid,
        'fallback_release_valid': fallback_release_valid,
        'activate_current_ready': activate_current_ready,
        'rollback_to_fallback_ready': rollback_to_fallback_ready,
        'channel_api_ready': api_ready,
        'invalid_release_pack_rejected': invalid_release_pack_rejected,
    }
    report['probe_pass'] = all(bool(report[key]) for key in [
        'release_channels_ready',
        'current_release_ready',
        'fallback_release_ready',
        'current_release_valid',
        'fallback_release_valid',
        'activate_current_ready',
        'rollback_to_fallback_ready',
        'channel_api_ready',
        'invalid_release_pack_rejected',
    ])
    write_json(REPORT_JSON, report)
    REPORT_MD.write_text(build_markdown(report), encoding='utf-8')
    print('release channel probe complete')
    return 0 if report['probe_pass'] else 1


def validate_channel_pack(payload: dict[str, Any], allow_archived: bool) -> bool:
    try:
        release_lib.validate_release_pack(str(payload.get('mechanic_profile_id', '')), str(payload.get('content_pack_id', '')), allow_archived=allow_archived)
        return True
    except SystemExit:
        return False


def verify_channel_api() -> tuple[bool, bool]:
    server = dashboard_lib.make_server('127.0.0.1', 0)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        port = server.server_port
        channels = read_url_json(f'http://127.0.0.1:{port}/api/release/channels')
        api_ready = bool(channels.get('current_release')) and bool(channels.get('fallback_release'))
        invalid_payload = json.dumps({'profile_id': '../evil', 'content_pack_id': 'bad'}).encode('utf-8')
        request = urllib.request.Request(f'http://127.0.0.1:{port}/api/release/set-current', data=invalid_payload, headers={'Content-Type': 'application/json'}, method='POST')
        try:
            urllib.request.urlopen(request, timeout=5)
            invalid_release_pack_rejected = False
        except urllib.error.HTTPError as exc:
            invalid_release_pack_rejected = exc.code == 400
        return api_ready, invalid_release_pack_rejected
    finally:
        server.shutdown()
        server.server_close()


def read_url_json(url: str) -> dict[str, Any]:
    with urllib.request.urlopen(url, timeout=5) as response:
        return json.loads(response.read().decode('utf-8'))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def build_markdown(report: dict[str, Any]) -> str:
    lines = ['# R1 Release Channel Probe', '']
    for key in [
        'release_channels_ready',
        'current_release_ready',
        'fallback_release_ready',
        'current_release_valid',
        'fallback_release_valid',
        'activate_current_ready',
        'rollback_to_fallback_ready',
        'channel_api_ready',
        'invalid_release_pack_rejected',
        'probe_pass',
    ]:
        lines.append(f'- {key}: `{report[key]}`')
    return '\n'.join(lines) + '\n'


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
