#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import aigc_pack_factory as factory_lib
from tools.aigc_battle import aigc_release_gate as release_lib
from tools.aigc_battle import build_aigc_content_index as index_lib
from tools.aigc_battle import build_aigc_detail_views as detail_lib
from tools.aigc_battle import build_aigc_review_workspace as review_lib
from tools.aigc_battle import switch_active_profile as switch_lib

DEFAULT_HOST = '127.0.0.1'
DEFAULT_PORT = 8765
DETAILS_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'details'
REVIEW_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'review'
REVIEW_NOTES_DIR = ROOT / 'data' / 'aigc_battle' / 'review_notes'
RUNTIME_DIR = ROOT / 'data' / 'aigc_battle' / 'runtime'


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description='local aigc production console server')
    parser.add_argument('--host', default=DEFAULT_HOST)
    parser.add_argument('--port', type=int, default=DEFAULT_PORT)
    args = parser.parse_args(argv[1:])
    if args.host != DEFAULT_HOST:
        raise SystemExit('server host must be 127.0.0.1')
    server = make_server(args.host, args.port)
    print(f'aigc dashboard server listening on http://{args.host}:{args.port}')
    server.serve_forever()
    return 0


def make_server(host: str, port: int) -> HTTPServer:
    if host != DEFAULT_HOST:
        raise SystemExit('server host must be 127.0.0.1')
    return HTTPServer((host, port), DashboardHandler)


class DashboardHandler(BaseHTTPRequestHandler):
    server_version = 'AigcDashboardServer/2.0'

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == '/':
            self.respond_text(build_console_html(), 'text/html; charset=utf-8')
            return
        if parsed.path == '/api/health':
            self.respond_json({'ok': True, 'status': 'healthy'})
            return
        if parsed.path == '/api/index':
            self.respond_json(index_lib.write_index_artifacts())
            return
        if parsed.path == '/api/profile-detail':
            self.handle_profile_detail(parsed.query)
            return
        if parsed.path == '/api/pack-detail':
            self.handle_pack_detail(parsed.query)
            return
        if parsed.path == '/api/review-workspace':
            self.handle_json_file(parsed.query, set(), REVIEW_DIR / 'aigc_review_workspace.json', 'review workspace not found')
            return
        if parsed.path == '/api/compare-matrix':
            self.handle_json_file(parsed.query, set(), REVIEW_DIR / 'pack_compare_matrix.json', 'compare matrix not found')
            return
        if parsed.path == '/api/pack-review':
            self.handle_pack_review(parsed.query)
            return
        if parsed.path == '/api/review-report':
            self.handle_review_report(parsed.query)
            return
        if parsed.path == '/api/review-notes':
            self.handle_review_notes_get(parsed.query)
            return
        if parsed.path == '/api/release/status':
            self.handle_release_status(parsed.query)
            return
        if parsed.path == '/api/release/report':
            self.handle_release_report(parsed.query)
            return
        self.respond_json({'ok': False, 'error': 'not found'}, status=HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        payload = self.read_json_body()
        if payload is None:
            self.respond_json({'ok': False, 'error': 'invalid json body'}, status=HTTPStatus.BAD_REQUEST)
            return
        try:
            if parsed.path == '/api/dry-run-switch':
                self.respond_json(self.handle_switch(payload, dry_run=True))
                return
            if parsed.path in {'/api/switch-pack', '/api/switch-profile'}:
                self.respond_json(self.handle_switch(payload, dry_run=False))
                return
            if parsed.path == '/api/rollback-active-pack':
                result = switch_lib.rollback_active_profile(switch_source='dashboard_api_rollback')
                self.respond_json({'ok': True, **result})
                return
            if parsed.path == '/api/review-notes':
                self.respond_json(self.handle_review_notes_post(payload))
                return
            if parsed.path == '/api/factory/build-pack':
                self.respond_json(factory_lib.run_action('build', safe_payload_id(payload, 'profile_id'), '', lambda log: factory_lib.build_root_pack(safe_payload_id(payload, 'profile_id'), log)))
                return
            if parsed.path == '/api/factory/snapshot-pack':
                profile_id = safe_payload_id(payload, 'profile_id')
                pack_id = safe_payload_id(payload, 'pack_id')
                self.respond_json(factory_lib.run_action('snapshot', profile_id, pack_id, lambda log: factory_lib.snapshot_pack(profile_id, pack_id, bool(payload.get('force', False)), log)))
                return
            if parsed.path == '/api/factory/build-from-snapshot':
                profile_id = safe_payload_id(payload, 'profile_id')
                pack_id = safe_payload_id(payload, 'pack_id')
                snapshot_path = str(payload.get('snapshot_path', '')).strip()
                self.respond_json(factory_lib.run_action('build_from_snapshot', profile_id, pack_id, lambda log: factory_lib.build_from_snapshot(profile_id, snapshot_path, pack_id, bool(payload.get('force', False)), log)))
                return
            if parsed.path == '/api/factory/build-from-telemetry':
                profile_id = safe_payload_id(payload, 'profile_id')
                pack_id = safe_payload_id(payload, 'pack_id')
                self.respond_json(factory_lib.run_action('build_from_telemetry', profile_id, pack_id, lambda log: factory_lib.build_from_telemetry(profile_id, pack_id, bool(payload.get('force', False)), log)))
                return
            if parsed.path == '/api/factory/build-from-llm':
                profile_id = safe_payload_id(payload, 'profile_id')
                pack_id = safe_payload_id(payload, 'pack_id')
                self.respond_json(factory_lib.run_action('build_from_llm', profile_id, pack_id, lambda log: factory_lib.build_from_llm(profile_id, pack_id, bool(payload.get('force', False)), log)))
                return
            if parsed.path == '/api/factory/validate-pack':
                profile_id = safe_payload_id(payload, 'profile_id')
                pack_id = optional_safe_payload_id(payload, 'content_pack_id')
                self.respond_json(factory_lib.run_action('validate', profile_id, pack_id or '', lambda log: factory_lib.validate_pack(profile_id, pack_id, log)))
                return
            if parsed.path == '/api/factory/export-pack':
                profile_id = safe_payload_id(payload, 'profile_id')
                pack_id = optional_safe_payload_id(payload, 'content_pack_id')
                self.respond_json(factory_lib.run_action('export', profile_id, pack_id or '', lambda log: factory_lib.export_pack(profile_id, pack_id, log)))
                return
            if parsed.path == '/api/factory/refresh-review':
                self.respond_json(factory_lib.run_action('refresh_review', 'global', '', lambda log: factory_lib.refresh_review(log)))
                return
            if parsed.path == '/api/release/freeze-pack':
                profile_id, pack_id = require_pack_payload(payload)
                self.respond_json({'ok': True, 'result': release_lib.freeze_pack(profile_id, pack_id)})
                return
            if parsed.path == '/api/release/mark-release-candidate':
                profile_id, pack_id = require_pack_payload(payload)
                self.respond_json({'ok': True, 'result': release_lib.mark_release_candidate(profile_id, pack_id)})
                return
            if parsed.path == '/api/release/archive-pack':
                profile_id, pack_id = require_pack_payload(payload)
                self.respond_json({'ok': True, 'result': release_lib.archive_pack(profile_id, pack_id)})
                return
        except SystemExit as exc:
            self.respond_json({'ok': False, 'error': str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return
        self.respond_json({'ok': False, 'error': 'not found'}, status=HTTPStatus.NOT_FOUND)

    def handle_profile_detail(self, query: str) -> None:
        try:
            params = self.safe_query_params(query, {'profile_id'})
            profile_id = params.get('profile_id', '')
            switch_lib.ensure_safe_id(profile_id, 'profile_id')
            detail_lib.main()
            payload = detail_lib.try_read_json(DETAILS_DIR / f'profile_{profile_id}.json')
            if not payload:
                raise SystemExit('profile detail not found')
        except SystemExit as exc:
            self.respond_json({'ok': False, 'error': str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return
        self.respond_json(payload)

    def handle_pack_detail(self, query: str) -> None:
        try:
            params = self.safe_query_params(query, {'profile_id', 'content_pack_id'})
            profile_id = params.get('profile_id', '')
            content_pack_id = params.get('content_pack_id', '')
            switch_lib.ensure_safe_id(profile_id, 'profile_id')
            detail_lib.main()
            if not content_pack_id:
                content_pack_id = resolve_root_pack_content_pack_id(profile_id)
            switch_lib.ensure_safe_id(content_pack_id, 'content_pack_id')
            payload = detail_lib.try_read_json(detail_lib.detail_pack_json_path(profile_id, content_pack_id))
            if not payload:
                raise SystemExit('pack detail not found')
        except SystemExit as exc:
            self.respond_json({'ok': False, 'error': str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return
        self.respond_json(payload)

    def handle_pack_review(self, query: str) -> None:
        try:
            params = self.safe_query_params(query, {'profile_id', 'content_pack_id'})
            profile_id = params.get('profile_id', '')
            content_pack_id = params.get('content_pack_id', '') or resolve_root_pack_content_pack_id(profile_id)
            switch_lib.ensure_safe_id(profile_id, 'profile_id')
            switch_lib.ensure_safe_id(content_pack_id, 'content_pack_id')
            path = review_lib.pack_review_json_path(profile_id, content_pack_id)
            payload = read_required_json(path)
            if payload is None:
                raise SystemExit('pack review not found')
        except SystemExit as exc:
            self.respond_json({'ok': False, 'error': str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return
        self.respond_json(payload)

    def handle_review_report(self, query: str) -> None:
        try:
            params = self.safe_query_params(query, {'profile_id', 'content_pack_id'})
            profile_id = params.get('profile_id', '')
            content_pack_id = params.get('content_pack_id', '') or resolve_root_pack_content_pack_id(profile_id)
            switch_lib.ensure_safe_id(profile_id, 'profile_id')
            switch_lib.ensure_safe_id(content_pack_id, 'content_pack_id')
            path = review_lib.review_report_md_path(profile_id, content_pack_id)
            if not path.exists():
                raise SystemExit('review report not found')
        except SystemExit as exc:
            self.respond_json({'ok': False, 'error': str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return
        self.respond_json({'ok': True, 'path': to_relative(path), 'content': path.read_text(encoding='utf-8')})

    def handle_review_notes_get(self, query: str) -> None:
        try:
            params = self.safe_query_params(query, {'profile_id', 'content_pack_id'})
            profile_id = params.get('profile_id', '')
            content_pack_id = params.get('content_pack_id', '')
            ensure_pack_exists(profile_id, content_pack_id)
        except SystemExit as exc:
            self.respond_json({'ok': False, 'error': str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return
        self.respond_json(load_review_notes(profile_id, content_pack_id))

    def handle_review_notes_post(self, payload: dict[str, Any]) -> dict[str, Any]:
        profile_id, content_pack_id = require_pack_payload(payload)
        ensure_pack_exists(profile_id, content_pack_id)
        notes = review_lib.default_review_notes(profile_id, content_pack_id)
        notes.update({
            'review_status': str(payload.get('review_status', notes['review_status'])),
            'reviewer': str(payload.get('reviewer', '')).strip(),
            'review_time': now_iso(),
            'summary': str(payload.get('summary', '')).strip(),
            'recommended_action': str(payload.get('recommended_action', notes['recommended_action'])).strip(),
            'global_notes': str(payload.get('global_notes', '')).strip(),
            'encounter_notes': payload.get('encounter_notes', {}) if isinstance(payload.get('encounter_notes', {}), dict) else {},
            'card_notes': payload.get('card_notes', {}) if isinstance(payload.get('card_notes', {}), dict) else {},
            'deck_notes': payload.get('deck_notes', {}) if isinstance(payload.get('deck_notes', {}), dict) else {},
            'reward_notes': payload.get('reward_notes', {}) if isinstance(payload.get('reward_notes', {}), dict) else {},
            'risk_decisions': payload.get('risk_decisions', {}) if isinstance(payload.get('risk_decisions', {}), dict) else {},
            'last_updated_at': now_iso(),
        })
        path = REVIEW_NOTES_DIR / f'{profile_id}__{content_pack_id}.json'
        write_json(path, notes)
        review_lib.main()
        return {'ok': True, 'path': to_relative(path), 'notes': notes}

    def handle_release_status(self, query: str) -> None:
        try:
            params = self.safe_query_params(query, {'profile_id', 'content_pack_id'})
            profile_id, content_pack_id = params.get('profile_id', ''), params.get('content_pack_id', '')
            ensure_pack_exists(profile_id, content_pack_id)
            payload = release_lib.get_release_status(profile_id, content_pack_id)
        except SystemExit as exc:
            self.respond_json({'ok': False, 'error': str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return
        self.respond_json(payload)

    def handle_release_report(self, query: str) -> None:
        try:
            params = self.safe_query_params(query, {'profile_id', 'content_pack_id'})
            profile_id, content_pack_id = params.get('profile_id', ''), params.get('content_pack_id', '')
            ensure_pack_exists(profile_id, content_pack_id)
            release_lib.generate_release_report(profile_id, content_pack_id)
            path = release_lib.release_report_path(profile_id, content_pack_id)
        except SystemExit as exc:
            self.respond_json({'ok': False, 'error': str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return
        self.respond_json({'ok': True, 'path': to_relative(path), 'content': path.read_text(encoding='utf-8')})

    def handle_json_file(self, query: str, allowed_keys: set[str], path: Path, missing_message: str) -> None:
        try:
            self.safe_query_params(query, allowed_keys)
            payload = read_required_json(path)
            if payload is None:
                raise SystemExit(missing_message)
        except SystemExit as exc:
            self.respond_json({'ok': False, 'error': str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return
        self.respond_json(payload)

    def handle_switch(self, payload: dict[str, Any], dry_run: bool) -> dict[str, Any]:
        profile_id = safe_payload_id(payload, 'profile_id')
        content_pack_id = optional_safe_payload_id(payload, 'content_pack_id')
        if 'runtime_manifest_path' in payload or 'generated_dir' in payload:
            raise SystemExit('direct path override is not allowed')
        summary = switch_lib.validate_profile_ready(profile_id, content_pack_id)
        if dry_run:
            return {'ok': True, 'can_switch': True, 'summary': summary, 'reasons': []}
        switch_lib.switch_active_profile(profile_id, content_pack_id, switch_source='dashboard_api')
        active_profile = switch_lib.read_json(RUNTIME_DIR / 'active_profile.json')
        index_lib.write_index_artifacts()
        review_lib.main()
        return {'ok': True, 'can_switch': True, 'summary': summary, 'active_profile': active_profile}

    def read_json_body(self) -> dict[str, Any] | None:
        try:
            length = int(self.headers.get('Content-Length', '0'))
        except ValueError:
            return None
        raw = self.rfile.read(length) if length > 0 else b'{}'
        try:
            payload = json.loads(raw.decode('utf-8'))
        except json.JSONDecodeError:
            return None
        return payload if isinstance(payload, dict) else None

    def safe_query_params(self, query: str, allowed_keys: set[str]) -> dict[str, str]:
        parsed = parse_qs(query, keep_blank_values=True)
        for key in parsed:
            if key not in allowed_keys:
                raise SystemExit(f'unsupported query parameter: {key}')
        return {key: values[0] for key, values in parsed.items()}

    def respond_json(self, payload: dict[str, Any], status: HTTPStatus = HTTPStatus.OK) -> None:
        body = json.dumps(payload, ensure_ascii=False, indent=2).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def respond_text(self, body: str, content_type: str, status: HTTPStatus = HTTPStatus.OK) -> None:
        encoded = body.encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, format: str, *args: Any) -> None:
        return


def safe_payload_id(payload: dict[str, Any], key: str) -> str:
    value = str(payload.get(key, '')).strip()
    switch_lib.ensure_safe_id(value, key)
    return value


def optional_safe_payload_id(payload: dict[str, Any], key: str) -> str | None:
    value = str(payload.get(key, '')).strip()
    if not value:
        return None
    switch_lib.ensure_safe_id(value, key)
    return value


def require_pack_payload(payload: dict[str, Any]) -> tuple[str, str]:
    profile_id = safe_payload_id(payload, 'profile_id')
    content_pack_id = safe_payload_id(payload, 'content_pack_id' if 'content_pack_id' in payload else 'pack_id')
    return profile_id, content_pack_id


def ensure_pack_exists(profile_id: str, content_pack_id: str) -> None:
    switch_lib.ensure_safe_id(profile_id, 'profile_id')
    switch_lib.ensure_safe_id(content_pack_id, 'content_pack_id')
    index_payload = index_lib.build_index()
    exists = any(
        profile.get('mechanic_profile_id') == profile_id
        and any(pack.get('content_pack_id') == content_pack_id for pack in profile.get('content_packs', []))
        for profile in index_payload.get('profiles', [])
    )
    if not exists:
        raise SystemExit('pack not found in content index')


def resolve_root_pack_content_pack_id(profile_id: str) -> str:
    manifest = switch_lib.read_json(switch_lib.resolve_runtime_manifest_path(profile_id))
    return str(manifest.get('content_pack_id', ''))


def load_review_notes(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    path = REVIEW_NOTES_DIR / f'{profile_id}__{content_pack_id}.json'
    if path.exists():
        return json.loads(path.read_text(encoding='utf-8'))
    return review_lib.default_review_notes(profile_id, content_pack_id)


def read_required_json(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding='utf-8'))


def to_relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def now_iso() -> str:
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).isoformat()


def build_console_html() -> str:
    return """<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>AIGC Battle Production Console</title>
<style>
:root { --bg:#f4efe6; --panel:#fffaf1; --line:#d6ccbb; --text:#201d18; --muted:#6c665d; --ok:#2f7d32; --warn:#b46e19; --bad:#9a2f2f; --info:#245f83; }
* { box-sizing:border-box; } body { margin:0; font-family:'SF Pro Text','PingFang SC','Noto Serif SC',serif; background:var(--bg); color:var(--text); }
main { max-width:1560px; margin:0 auto; padding:18px 18px 80px; } header,.band,.card,details { background:var(--panel); border:1px solid var(--line); border-radius:8px; }
header,.band { padding:16px; } .grid,.cards,.stats,.dual { display:grid; gap:12px; } .dual { grid-template-columns:2fr 1fr; } .stats { grid-template-columns:repeat(auto-fit,minmax(150px,1fr)); } .cards { grid-template-columns:repeat(auto-fit,minmax(220px,1fr)); }
.card { padding:12px; } .tabs { display:flex; gap:8px; flex-wrap:wrap; margin-top:12px; } .tab { padding:8px 12px; border:1px solid var(--line); border-radius:8px; background:#f1e8d9; cursor:pointer; } .tab.active { background:#e6d1b2; }
.panel { display:none; margin-top:14px; } .panel.active { display:block; } .badge { display:inline-block; padding:4px 8px; border-radius:999px; background:#ece0ce; font-size:12px; margin:4px 6px 0 0; } .ok{color:var(--ok)} .warning{color:var(--warn)} .fail{color:var(--bad)} .info{color:var(--info)}
.toolbar { display:flex; gap:8px; flex-wrap:wrap; margin-top:12px; align-items:center; } button,input,select,textarea { font:inherit; } button,input,select,textarea { border:1px solid var(--line); border-radius:8px; padding:8px 10px; background:#fff; }
button { background:#f0e0c4; color:#5e3b13; cursor:pointer; } button.primary { background:#2d607f; color:#fff; border-color:#2d607f; } textarea { width:100%; min-height:88px; resize:vertical; }
table { width:100%; border-collapse:collapse; font-size:13px; } th,td { border-bottom:1px solid var(--line); padding:8px 9px; text-align:left; vertical-align:top; } th { background:#f6efe2; position:sticky; top:0; } .table { overflow:auto; border:1px solid var(--line); border-radius:8px; margin-top:10px; background:#fffdf9; }
.mono { font-family:ui-monospace,SFMono-Regular,Menlo,monospace; } .muted { color:var(--muted); font-size:13px; } .report { white-space:pre-wrap; border:1px solid var(--line); border-radius:8px; padding:12px; background:#fffdf8; max-height:520px; overflow:auto; }
summary { cursor:pointer; font-weight:600; } @media (max-width: 960px) { .dual { grid-template-columns:1fr; } }
</style>
</head>
<body>
<main>
<header>
  <h1>AIGC Battle Production Console</h1>
  <div class="dual" style="margin-top:12px;">
    <div class="card">
      <div class="muted">当前 active</div>
      <div id="active-line" style="margin-top:8px;"></div>
      <div id="active-metrics" style="margin-top:8px;"></div>
    </div>
    <div class="card">
      <div class="muted">控制台状态</div>
      <div id="console-state" style="margin-top:8px;"></div>
      <div class="mono" id="focus-pack" style="margin-top:8px; font-size:12px;"></div>
    </div>
  </div>
  <div class="tabs" id="tabs"></div>
</header>
<section id="overview" class="panel active"></section>
<section id="compare" class="panel"></section>
<section id="review" class="panel"></section>
<section id="encounters" class="panel"></section>
<section id="pool" class="panel"></section>
<section id="rewards" class="panel"></section>
<section id="actions" class="panel"></section>
</main>
<script>
const state = { workspace:null, compare:null, activeReview:null, notes:null, release:null, report:'' };
const tabs = [['overview','总览'],['compare','Pack 对比'],['review','审核'],['encounters','战斗链路'],['pool','卡池卡组'],['rewards','奖励'],['actions','生产动作']];
const $ = (id) => document.getElementById(id);
const esc = (v) => String(v ?? '').replace(/[&<>"]/g, (c) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const join = (v) => Array.isArray(v) ? v.join(', ') : (v || '-');
async function api(url, options) { const r = await fetch(url, options); const p = await r.json(); if (!r.ok || p.ok === false) throw new Error(p.error || ('request failed: ' + r.status)); return p; }
function cls(v) { return v === 'pass' ? 'ok' : v === 'fail' ? 'fail' : v === 'warning' ? 'warning' : 'info'; }
function makeTabs() { const root = $('tabs'); root.innerHTML = tabs.map(([id,label],i) => `<button class="tab${i===0?' active':''}" data-tab="${id}">${label}</button>`).join(''); root.querySelectorAll('[data-tab]').forEach((b) => b.onclick = () => { root.querySelectorAll('.tab').forEach((n) => n.classList.toggle('active', n === b)); document.querySelectorAll('.panel').forEach((p) => p.classList.toggle('active', p.id === b.dataset.tab)); }); }
async function bootstrap() {
  state.workspace = await api('/api/review-workspace');
  state.compare = await api('/api/compare-matrix');
  await focusPack(state.workspace.active_profile_id, state.workspace.active_content_pack_id);
}
async function focusPack(profileId, contentPackId) {
  const qs = new URLSearchParams({ profile_id: profileId, content_pack_id: contentPackId });
  state.activeReview = await api('/api/pack-review?' + qs.toString());
  state.notes = await api('/api/review-notes?' + qs.toString());
  state.release = await api('/api/release/status?' + qs.toString());
  state.report = (await api('/api/review-report?' + qs.toString())).content || '';
  renderAll();
}
function currentPackKey() { return `${state.activeReview?.pack_identity?.mechanic_profile_id || ''}::${state.activeReview?.pack_identity?.content_pack_id || ''}`; }
async function postJson(path, payload) { return api(path, { method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(payload) }); }
async function saveNotes() {
  const payload = {
    profile_id: state.activeReview.pack_identity.mechanic_profile_id,
    content_pack_id: state.activeReview.pack_identity.content_pack_id,
    review_status: $('note-status').value,
    reviewer: $('note-reviewer').value,
    summary: $('note-summary').value,
    recommended_action: $('note-action').value,
    global_notes: $('note-global').value,
    encounter_notes: {},
    card_notes: {},
    deck_notes: {},
    reward_notes: {},
    risk_decisions: {}
  };
  await postJson('/api/review-notes', payload);
  await focusPack(payload.profile_id, payload.content_pack_id);
}
async function doSwitch(dryRun) {
  const payload = { profile_id: state.activeReview.pack_identity.mechanic_profile_id, content_pack_id: state.activeReview.pack_identity.content_pack_id };
  const path = dryRun ? '/api/dry-run-switch' : '/api/switch-pack';
  await postJson(path, payload);
  if (!dryRun) location.reload();
}
async function doRollback() { await postJson('/api/rollback-active-pack', {}); location.reload(); }
async function doFactory(path, payload) { await postJson(path, payload); await bootstrap(); }
async function doRelease(path) { const payload = { profile_id: state.activeReview.pack_identity.mechanic_profile_id, content_pack_id: state.activeReview.pack_identity.content_pack_id }; await postJson(path, payload); await focusPack(payload.profile_id, payload.content_pack_id); }
function renderHeader() {
  const review = state.activeReview || {}; const notes = state.notes || {}; const release = state.release || {}; const risk = review.risk_summary || {}; const health = review.health_summary || {};
  $('active-line').innerHTML = `<span class="badge mono">${esc(state.workspace.active_profile_id)}</span><span class="badge mono">${esc(state.workspace.active_content_pack_id)}</span><span class="badge ${cls(health.health_status)}">${esc(health.health_status || '-')}</span><span class="badge">${health.health_score || 0}</span>`;
  $('active-metrics').innerHTML = `<span class="badge">risk ${risk.risk_count || 0}</span><span class="badge fail">fail ${risk.fail_count || 0}</span><span class="badge warning">warning ${risk.warning_count || 0}</span><span class="badge info">review ${esc(notes.review_status || '-')}</span><span class="badge info">release ${esc(release.release_status || '-')}</span>`;
  $('console-state').innerHTML = `<span class="badge">profiles ${state.workspace.profile_count}</span><span class="badge">packs ${state.workspace.content_pack_count}</span><span class="badge">${release.frozen ? 'frozen' : 'mutable'}</span>`;
  $('focus-pack').textContent = currentPackKey();
}
function bindPackButtons(root) { root.querySelectorAll('[data-pack]').forEach((b) => b.onclick = async () => { const [profileId, contentPackId] = b.dataset.pack.split('::'); await focusPack(profileId, contentPackId); }); }
function renderOverview() {
  const review = state.activeReview; const health = review.health_summary || {}; const notes = state.notes || {}; const release = state.release || {};
  $('overview').innerHTML = `<div class="band"><h2>总览</h2><div class="stats"><div class="card"><div class="muted">Health</div><strong>${health.health_score || 0}</strong></div><div class="card"><div class="muted">Review Status</div><strong>${esc(notes.review_status || '-')}</strong></div><div class="card"><div class="muted">Release Status</div><strong>${esc(release.release_status || '-')}</strong></div><div class="card"><div class="muted">Reviewer</div><strong>${esc(notes.reviewer || '-')}</strong></div></div><div class="toolbar"><button onclick="bootstrap()">Refresh Index</button><button onclick="doFactory('/api/factory/refresh-review', {})">Rebuild Review Workspace</button><button onclick="doSwitch(true)">Dry Run Switch</button><button class="primary" onclick="doSwitch(false)">Enable Pack</button><button onclick="doRollback()">Rollback</button><button onclick="snapshotPrompt()">Snapshot Pack</button><button onclick="doRelease('/api/release/freeze-pack')">Freeze Pack</button><button onclick="doRelease('/api/release/mark-release-candidate')">Mark Release Candidate</button></div></div>`;
}
function renderCompare() {
  const q = ($('compare-q')?.value || '').toLowerCase(); const sort = $('compare-sort')?.value || 'health_score';
  const rows = [...(state.compare.packs || [])].filter((row) => `${row.mechanic_profile_id} ${row.content_pack_id}`.toLowerCase().includes(q));
  rows.sort((a,b) => sort === 'risk_count' ? (b.risk_count-a.risk_count) : sort === 'warning_count' ? (b.warning_count-a.warning_count) : sort === 'average_deck_power' ? (b.average_deck_power-a.average_deck_power) : sort === 'card_count' ? (b.card_count-a.card_count) : (b.health_score-a.health_score));
  $('compare').innerHTML = `<div class="band"><h2>Pack 对比</h2><div class="toolbar"><input id="compare-q" placeholder="搜索 profile_id / content_pack_id"><select id="compare-sort"><option value="health_score">health_score</option><option value="risk_count">risk_count</option><option value="warning_count">warning_count</option><option value="average_deck_power">average_deck_power</option><option value="card_count">card_count</option></select></div><div class="table"><table><thead><tr><th>Pack</th><th>Health</th><th>Review</th><th>Release</th><th>Risk</th><th>Avg Power</th><th>Cards</th><th></th></tr></thead><tbody>${rows.map((row) => `<tr><td><div class="mono">${esc(row.mechanic_profile_id)}</div><div class="mono muted">${esc(row.content_pack_id)}</div>${row.is_active?'<span class="badge info">ACTIVE</span>':''}${row.release_candidate?'<span class="badge">RC</span>':''}${row.frozen?'<span class="badge">FROZEN</span>':''}${row.archived?'<span class="badge">ARCHIVED</span>':''}</td><td>${esc(row.health_status)} / ${row.health_score}</td><td>${esc(row.review_status || '-')}</td><td>${esc(row.release_status || '-')}</td><td>${row.risk_count}</td><td>${row.average_deck_power}</td><td>${row.card_count}</td><td><button class="primary" data-pack="${row.mechanic_profile_id}::${row.content_pack_id}">Focus</button></td></tr>`).join('')}</tbody></table></div></div>`;
  $('compare-q').value = q; $('compare-sort').value = sort; $('compare-q').oninput = renderCompare; $('compare-sort').onchange = renderCompare; bindPackButtons($('compare'));
}
function renderReview() {
  const notes = state.notes || {}; const review = state.activeReview || {};
  $('review').innerHTML = `<div class="grid"><div class="band"><h2>审核摘要</h2><div class="muted">${esc(review.recommended_action || '-')}</div><div class="stats"><div class="card"><div class="muted">review_status</div><strong>${esc(notes.review_status || '-')}</strong></div><div class="card"><div class="muted">recommended_action</div><strong>${esc(notes.recommended_action || '-')}</strong></div><div class="card"><div class="muted">release_status</div><strong>${esc(state.release?.release_status || '-')}</strong></div></div></div><div class="band"><h2>Review Notes</h2><div class="toolbar"><select id="note-status"><option>pending</option><option>accepted</option><option>rejected</option><option>needs_rebuild</option></select><select id="note-action"><option>safe_to_test</option><option>needs_rebuild</option><option>needs_balance_adjustment</option><option>blocked_by_validation</option><option>blocked_by_runtime</option><option>needs_real_telemetry</option><option>ready_for_release_candidate</option></select><input id="note-reviewer" placeholder="reviewer"></div><textarea id="note-summary" placeholder="summary"></textarea><textarea id="note-global" placeholder="global_notes"></textarea><div class="toolbar"><button class="primary" onclick="saveNotes()">保存审核备注</button></div></div><div class="band"><h2>Risk Board</h2><div class="table"><table><thead><tr><th>Severity</th><th>Type</th><th>Message</th><th>Action</th></tr></thead><tbody>${(review.risk_summary?.top_risks || []).map((risk) => `<tr><td>${esc(risk.severity)}</td><td>${esc(risk.risk_type)}</td><td>${esc(risk.message)}</td><td>${esc(risk.suggested_action)}</td></tr>`).join('')}</tbody></table></div></div><div class="band"><h2>Review Report</h2><div class="report">${esc(state.report || '')}</div></div></div>`;
  $('note-status').value = notes.review_status || 'pending'; $('note-action').value = notes.recommended_action || 'safe_to_test'; $('note-reviewer').value = notes.reviewer || ''; $('note-summary').value = notes.summary || ''; $('note-global').value = notes.global_notes || '';
}
function renderEncounters() {
  const rows = state.activeReview?.encounter_review_table || [];
  $('encounters').innerHTML = `<div class="band"><h2>战斗链路</h2><div class="table"><table><thead><tr><th>#</th><th>Encounter</th><th>Battle</th><th>Deck</th><th>Reward</th><th>Tier</th><th>Kind</th><th>Power</th><th>Wujing</th><th>Risk</th></tr></thead><tbody>${rows.map((row) => `<tr><td>${row.sequence_position}</td><td class="mono">${esc(row.formal_encounter_id)}</td><td class="mono">${esc(row.formal_battle_id)}</td><td class="mono">${esc(row.generated_deck_id)}</td><td class="mono">${esc(row.reward_plan_id)}</td><td>${esc(row.encounter_tier)}</td><td>${esc(row.encounter_kind)}</td><td>${row.deck_power_score}</td><td>${row.player_wujing_cap}</td><td>${esc(join(row.risk_flags))}</td></tr>`).join('')}</tbody></table></div><div class="grid" style="margin-top:12px;">${(state.activeReview?.encounter_design_cards || []).map((card) => `<details><summary>${esc(card.title)} | ${esc(card.deck_archetype)} | ${esc(card.suggested_action)}</summary><div class="muted" style="margin-top:8px;">${esc(card.progression_notes)}</div><div class="muted">${esc(card.realm_notes)}</div><div>${esc(join(card.high_pressure_cards))}</div></details>`).join('')}</div></div>`;
}
function renderPool() {
  const cards = state.activeReview?.card_pool_review_table || []; const decks = state.activeReview?.deck_review_table || [];
  $('pool').innerHTML = `<div class="band"><h2>卡池卡组</h2><div class="table"><table><thead><tr><th>Card</th><th>Type</th><th>Power</th><th>Usage</th><th>Realm</th><th>Risk</th></tr></thead><tbody>${cards.map((row) => `<tr><td><div class="mono">${esc(row.card_id)}</div><div>${esc(row.name)}</div></td><td>${esc(row.card_type)}</td><td>${row.power_score}</td><td>${row.usage_count}${row.is_unused?' / unused':''}${row.is_high_power?' / high_power':''}</td><td>${esc(row.realm_requirement_label)}</td><td>${esc(join(row.risk_flags))}</td></tr>`).join('')}</tbody></table></div><div class="table" style="margin-top:12px;"><table><thead><tr><th>Deck</th><th>Archetype</th><th>Power</th><th>Scores</th><th>Risk</th></tr></thead><tbody>${decks.map((row) => `<tr><td class="mono">${esc(row.deck_id)}</td><td>${esc(row.deck_archetype)}</td><td>${row.deck_power_score}</td><td>A${row.aggression_score} D${row.defense_score} M${row.momentum_score} B${row.break_score}</td><td>${esc(join(row.risk_flags))}</td></tr>`).join('')}</tbody></table></div></div>`;
}
function renderRewards() {
  const rows = state.activeReview?.reward_review_table || [];
  $('rewards').innerHTML = `<div class="band"><h2>奖励</h2><div class="table"><table><thead><tr><th>Reward</th><th>Type</th><th>Tier</th><th>Items</th><th>Matched Encounter</th><th>Risk</th></tr></thead><tbody>${rows.map((row) => `<tr><td class="mono">${esc(row.reward_plan_id)}</td><td>${esc(row.reward_type)}</td><td>${esc(row.reward_tier)}</td><td>${esc(row.reward_items_text)}</td><td>${esc(join(row.matched_encounter_tier))}</td><td>${esc(join(row.risk_flags))}</td></tr>`).join('')}</tbody></table></div></div>`;
}
function renderActions() {
  $('actions').innerHTML = `<div class="band"><h2>生产动作</h2><div class="toolbar"><input id="action-pack-id" placeholder="新 pack_id / snapshot_id"><input id="action-snapshot" placeholder="approved snapshot path"><button onclick="buildRoot()">Build Root Pack</button><button onclick="snapshotPrompt()">Snapshot Current Pack</button><button onclick="buildFromSnapshotPrompt()">Build From Snapshot</button><button onclick="buildFromTelemetryPrompt()">Build From Telemetry Snapshot</button><button onclick="buildFromLlmPrompt()">Build From LLM Candidates</button><button onclick="factoryValidate()">Validate Pack</button><button onclick="factoryExport()">Export Manifest</button><button onclick="doSwitch(false)">Safe Switch</button><button onclick="doRollback()">Rollback</button><button onclick="doRelease('/api/release/freeze-pack')">Freeze Pack</button><button onclick="doRelease('/api/release/mark-release-candidate')">Mark Release Candidate</button><button onclick="doRelease('/api/release/archive-pack')">Archive Pack</button></div></div>`;
}
async function buildRoot() { await doFactory('/api/factory/build-pack', { profile_id: state.activeReview.pack_identity.mechanic_profile_id }); }
async function snapshotPrompt() { const packId = $('action-pack-id')?.value || 'snapshot_pack_id_required'; await doFactory('/api/factory/snapshot-pack', { profile_id: state.activeReview.pack_identity.mechanic_profile_id, pack_id: packId }); }
async function buildFromSnapshotPrompt() { const packId = $('action-pack-id')?.value || 'rebuild_pack_id_required'; const snapshotPath = $('action-snapshot')?.value || ''; await doFactory('/api/factory/build-from-snapshot', { profile_id: state.activeReview.pack_identity.mechanic_profile_id, pack_id: packId, snapshot_path: snapshotPath }); }
async function buildFromTelemetryPrompt() { const packId = $('action-pack-id')?.value || 'telemetry_pack_id_required'; await doFactory('/api/factory/build-from-telemetry', { profile_id: state.activeReview.pack_identity.mechanic_profile_id, pack_id: packId }); }
async function buildFromLlmPrompt() { const packId = $('action-pack-id')?.value || 'llm_pack_id_required'; await doFactory('/api/factory/build-from-llm', { profile_id: state.activeReview.pack_identity.mechanic_profile_id, pack_id: packId }); }
async function factoryValidate() { await doFactory('/api/factory/validate-pack', { profile_id: state.activeReview.pack_identity.mechanic_profile_id, content_pack_id: state.activeReview.pack_identity.pack_storage_mode === 'profile_pack_dir' ? state.activeReview.pack_identity.content_pack_id : '' }); }
async function factoryExport() { await doFactory('/api/factory/export-pack', { profile_id: state.activeReview.pack_identity.mechanic_profile_id, content_pack_id: state.activeReview.pack_identity.pack_storage_mode === 'profile_pack_dir' ? state.activeReview.pack_identity.content_pack_id : '' }); }
function renderAll() { renderHeader(); renderOverview(); renderCompare(); renderReview(); renderEncounters(); renderPool(); renderRewards(); renderActions(); }
(async function init() { makeTabs(); await bootstrap(); renderAll(); })();
</script>
</body>
</html>"""


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
