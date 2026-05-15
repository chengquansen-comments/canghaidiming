#!/usr/bin/env python3
# -*- coding: utf-8 -*-
from __future__ import annotations

import argparse
import os
import json
import subprocess
import sys
import uuid
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
from tools.aigc_battle import load_sequence_template as template_lib
from tools.aigc_battle import switch_active_profile as switch_lib
from tools.aigc_battle import aigc_preview_runtime_control as preview_lib
from tools.aigc_battle import aigc_acceptance_run as acceptance_lib
from tools.aigc_battle import aigc_write_human_review_note as promotion_note_lib
from tools.aigc_battle import aigc_candidate_promotion_gate as promotion_gate_lib
from tools.aigc_battle import aigc_release_switch_console as release_switch_lib

DEFAULT_HOST = '127.0.0.1'
DEFAULT_PORT = 8765
DETAILS_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'details'
REVIEW_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'review'
REVIEW_NOTES_DIR = ROOT / 'data' / 'aigc_battle' / 'review_notes'
RUNTIME_DIR = ROOT / 'data' / 'aigc_battle' / 'runtime'
EVALUATION_GENERATED_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'evaluation'
EVALUATION_SNAPSHOT_DIR = ROOT / 'data' / 'aigc_battle' / 'evaluation' / 'snapshots'
REBUILD_RECOMMEND_DIR = ROOT / 'data' / 'aigc_battle' / 'evaluation' / 'rebuild_recommendations'
BALANCE_RELEASE_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'balance_release'
SEQUENCE_TEMPLATE_DIR = ROOT / 'data' / 'aigc_battle' / 'sequence_templates'
PACK_RESOLVER_PATH = ROOT / 'data' / 'aigc_battle' / 'pack_resolver.json'
TEMPLATE_PORTFOLIO_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'template_portfolio'
MATRIX_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'mechanic_template_matrix'
PLAYABLE_HARDENING_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'playable_hardening'
PREVIEW_GENERATED_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'preview_runtime'
AI_STUDIO_DIR = ROOT / 'data' / 'aigc_battle' / 'ai_studio'
AI_STUDIO_GENERATED_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'ai_studio'
ACCEPTANCE_DIR = ROOT / 'data' / 'aigc_battle' / 'acceptance'
ACCEPTANCE_GENERATED_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'acceptance'
PROMOTION_DIR = ROOT / 'data' / 'aigc_battle' / 'promotion'
PROMOTION_REVIEW_DIR = PROMOTION_DIR / 'human_review_notes'
PROMOTION_GENERATED_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'promotion'
RELEASE_SWITCH_DIR = ROOT / 'data' / 'aigc_battle' / 'release_switch'
RELEASE_SWITCH_GENERATED_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'release_switch'
PRODUCTION_CONTRACT_DIR = ROOT / 'data' / 'aigc_battle' / 'production_contract'
PRODUCTION_FREEZE_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'production_freeze'
SINGLE_RELEASE_DRILL_GENERATED_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'single_candidate_release_drill'
RELEASE_LANDING_GENERATED_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'release_landing'
PRODUCTION_CLOSEOUT_GENERATED_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'production_closeout'
ADMIN_DIR = ROOT / 'data' / 'aigc_battle' / 'admin'
ADMIN_LOCK_PATH = ADMIN_DIR / 'admin_action.lock'
ADMIN_HISTORY_PATH = ADMIN_DIR / 'admin_action_history.jsonl'
ADMIN_GENERATED_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'dashboard_admin'
ACTIVE_PROFILE_PATH = ROOT / 'data' / 'aigc_battle' / 'runtime' / 'active_profile.json'
CURRENT_RELEASE_PATH = ROOT / 'data' / 'aigc_battle' / 'release_channels' / 'current_release.json'
FALLBACK_RELEASE_PATH = ROOT / 'data' / 'aigc_battle' / 'release_channels' / 'fallback_release.json'
ADMIN_ALLOWED_REVIEW_STATUS = {'accepted', 'rejected', 'needs_balance', 'pending'}
ADMIN_PROHIBITED_FIELDS = {
    'shell_command',
    'file_path',
    'runtime_manifest_path',
    'current_release_path',
    'active_profile_path',
    'external_url',
}
ADMIN_LOCK_STALE_SECONDS = 1800


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description='local aigc production console server')
    parser.add_argument('--host', default=DEFAULT_HOST)
    parser.add_argument('--port', type=int, default=DEFAULT_PORT)
    parser.add_argument('--admin-write', action='store_true')
    args = parser.parse_args(argv[1:])
    if args.host != DEFAULT_HOST:
        raise SystemExit('server host must be 127.0.0.1')
    server = make_server(args.host, args.port, admin_write_enabled=bool(args.admin_write))
    print(f'aigc dashboard server listening on http://{args.host}:{args.port}')
    server.serve_forever()
    return 0


def make_server(host: str, port: int, *, admin_write_enabled: bool = False) -> HTTPServer:
    if host != DEFAULT_HOST:
        raise SystemExit('server host must be 127.0.0.1')
    DashboardHandler.admin_write_enabled = bool(admin_write_enabled)
    return HTTPServer((host, port), DashboardHandler)


class DashboardHandler(BaseHTTPRequestHandler):
    server_version = 'AigcDashboardServer/2.0'
    admin_write_enabled = False

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
        if parsed.path == '/api/pack-review':
            self.handle_pack_review(parsed.query)
            return
        if parsed.path == '/api/review-report':
            self.handle_review_report(parsed.query)
            return
        if parsed.path == '/api/real-telemetry-snapshot':
            self.handle_real_telemetry_snapshot(parsed.query)
            return
        if parsed.path == '/api/llm/prompt':
            self.handle_llm_prompt(parsed.query)
            return
        if parsed.path == '/api/llm/candidate-diff':
            self.handle_candidate_diff(parsed.query)
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
        if parsed.path == '/api/release/compare-candidates':
            self.respond_json(release_lib.compare_release_candidates())
            return
        if parsed.path == '/api/release/git-suggestions':
            self.handle_release_git_suggestions(parsed.query)
            return
        if parsed.path == '/api/release/channels':
            self.respond_json(release_lib.show_channels())
            return
        if parsed.path == '/api/release/smoke-report':
            self.respond_json(load_release_smoke_report())
            return
        if parsed.path == '/api/evaluation/summary':
            self.respond_json(load_evaluation_summary())
            return
        if parsed.path == '/api/evaluation/pack-snapshot':
            self.handle_evaluation_pack_snapshot(parsed.query)
            return
        if parsed.path == '/api/evaluation/rebuild-recommendations':
            self.handle_evaluation_rebuild_recommendations(parsed.query)
            return
        if parsed.path == '/api/sequence-templates':
            self.respond_json(load_sequence_templates())
            return
        if parsed.path == '/api/sequence-template':
            self.handle_sequence_template(parsed.query)
            return
        if parsed.path == '/api/pack-resolver':
            self.respond_json(load_pack_resolver())
            return
        if parsed.path == '/api/template-portfolio':
            self.respond_json(load_template_portfolio_summary())
            return
        if parsed.path == '/api/template-portfolio/evaluation':
            self.respond_json(load_template_portfolio_evaluation())
            return
        if parsed.path == '/api/template-release-strategy':
            self.respond_json(load_template_release_strategy())
            return
        if parsed.path == '/api/mechanic-template-matrix':
            self.respond_json(load_mechanic_template_matrix_summary())
            return
        if parsed.path == '/api/mechanic-template-matrix/evaluation':
            self.respond_json(load_mechanic_template_matrix_evaluation())
            return
        if parsed.path == '/api/mechanic-template-matrix/strategy':
            self.respond_json(load_mechanic_template_matrix_strategy())
            return
        if parsed.path == '/api/playable-hardening':
            self.respond_json(load_playable_hardening_summary())
            return
        if parsed.path == '/api/playable-hardening/evaluation':
            self.respond_json(load_playable_hardening_evaluation())
            return
        if parsed.path == '/api/playable-hardening/strategy':
            self.respond_json(load_playable_hardening_strategy())
            return
        if parsed.path == '/api/ai-studio':
            self.respond_json(load_ai_studio_summary())
            return
        if parsed.path == '/api/ai-studio/prompts':
            self.respond_json(load_ai_studio_prompts())
            return
        if parsed.path == '/api/ai-studio/batches':
            self.respond_json(load_ai_studio_batches())
            return
        if parsed.path == '/api/ai-studio/quality':
            self.respond_json(load_ai_studio_quality())
            return
        if parsed.path == '/api/ai-studio/pack-compare':
            self.respond_json(load_ai_studio_pack_compare())
            return
        if parsed.path == '/api/balance-release/report':
            self.respond_json(load_balance_release_build_report())
            return
        if parsed.path == '/api/balance-release/evaluation':
            self.respond_json(load_balance_release_evaluation_report())
            return
        if parsed.path == '/api/preview/status':
            self.respond_json(preview_lib.preview_status())
            return
        if parsed.path == '/api/preview/list':
            self.respond_json(preview_lib.list_previewable_packs())
            return
        if parsed.path == '/api/acceptance/latest':
            self.respond_json(load_acceptance_latest())
            return
        if parsed.path == '/api/acceptance/report':
            self.handle_acceptance_report(parsed.query)
            return
        if parsed.path == '/api/promotion/report':
            self.handle_promotion_report(parsed.query)
            return
        if parsed.path == '/api/promotion/history':
            self.respond_json(load_promotion_history())
            return
        if parsed.path == '/api/release-switch/status':
            self.respond_json(release_switch_lib.switch_status())
            return
        if parsed.path == '/api/release-switch/candidates':
            self.respond_json(release_switch_lib.list_release_candidates())
            return
        if parsed.path == '/api/release-switch/history':
            self.respond_json(load_release_switch_history())
            return
        if parsed.path == '/api/production-contract':
            self.respond_json(load_production_contract_summary())
            return
        if parsed.path == '/api/production-contract/schema':
            self.respond_json(load_production_contract_schema())
            return
        if parsed.path == '/api/production-contract/generated-file-policy':
            self.respond_json(load_production_file_policy())
            return
        if parsed.path == '/api/production-contract/minimal-acceptance':
            self.respond_json(load_minimal_acceptance_command())
            return
        if parsed.path == '/api/production-contract/deprecated-probes':
            self.respond_json(load_deprecated_probe_inventory())
            return
        if parsed.path == '/api/single-candidate-release-drill':
            self.respond_json(load_single_candidate_release_drill_summary())
            return
        if parsed.path == '/api/single-candidate-release-drill/report':
            self.respond_json(load_single_candidate_release_drill_report())
            return
        if parsed.path == '/api/release-landing':
            self.respond_json(load_release_landing_summary())
            return
        if parsed.path == '/api/release-landing/report':
            self.respond_json(load_release_landing_report())
            return
        if parsed.path == '/api/production-closeout':
            self.respond_json(load_production_closeout_summary())
            return
        if parsed.path == '/api/production-closeout/plan':
            self.respond_json(load_production_closeout_plan())
            return
        if parsed.path == '/api/production-closeout/cleanup':
            self.respond_json(load_production_closeout_cleanup())
            return
        if parsed.path == '/api/production-closeout/verification':
            self.respond_json(load_production_closeout_verification())
            return
        if parsed.path == '/api/dashboard-display':
            self.respond_json(load_dashboard_display_summary())
            return
        if parsed.path == '/api/dashboard-display/current':
            self.respond_json(load_dashboard_display_current())
            return
        if parsed.path == '/api/dashboard-display/packs':
            self.respond_json(load_dashboard_display_packs())
            return
        if parsed.path == '/api/dashboard-display/risk-board':
            self.respond_json(load_dashboard_display_risk_board())
            return
        if parsed.path == '/api/admin/status':
            self.respond_json(load_admin_status(self.admin_write_enabled))
            return
        self.respond_json({'ok': False, 'error': 'not found'}, status=HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        payload = self.read_json_body()
        if payload is None:
            self.respond_json({'ok': False, 'error': 'invalid json body'}, status=HTTPStatus.BAD_REQUEST)
            return
        try:
            if not parsed.path.startswith('/api/admin/'):
                self.respond_json({'ok': False, 'error': 'legacy_dashboard_write_disabled'}, status=HTTPStatus.FORBIDDEN)
                return
            if not self.admin_write_enabled:
                self.respond_json({'ok': False, 'error': 'admin_write_disabled'}, status=HTTPStatus.FORBIDDEN)
                return
            self.respond_json(self.handle_admin_post(parsed.path, payload))
            return
        except SystemExit as exc:
            error = str(exc)
            status = HTTPStatus.CONFLICT if error == 'admin_action_locked' else HTTPStatus.BAD_REQUEST
            self.respond_json({'ok': False, 'error': error}, status=status)
            return
        self.respond_json({'ok': False, 'error': 'not found'}, status=HTTPStatus.NOT_FOUND)

    def handle_admin_post(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
        validate_admin_payload(payload)
        if path == '/api/admin/acceptance/run':
            enforce_allowed_admin_keys(payload, {'profile_id', 'content_pack_id'})
            profile_id, pack_id = require_admin_pack_payload(payload)
            return run_admin_cli_action(
                action='acceptance_run',
                profile_id=profile_id,
                content_pack_id=pack_id,
                dry_run=False,
                command=[sys.executable, str(ROOT / 'tools' / 'aigc_battle' / 'aigc_acceptance_run.py'), '--profile', profile_id, '--pack', pack_id, '--samples', '1'],
            )
        if path == '/api/admin/review-note/write':
            enforce_allowed_admin_keys(payload, {'profile_id', 'content_pack_id', 'status', 'note'})
            profile_id, pack_id = require_admin_pack_payload(payload)
            status = str(payload.get('status', '')).strip()
            note = str(payload.get('note', '')).strip()
            if status not in ADMIN_ALLOWED_REVIEW_STATUS:
                raise SystemExit('invalid human review status')
            if not note:
                raise SystemExit('note is required')
            return run_admin_cli_action(
                action='review_note_write',
                profile_id=profile_id,
                content_pack_id=pack_id,
                dry_run=False,
                command=[
                    sys.executable,
                    str(ROOT / 'tools' / 'aigc_battle' / 'aigc_write_human_review_note.py'),
                    '--profile', profile_id,
                    '--pack', pack_id,
                    '--status', status,
                    '--reviewer', 'dashboard_admin',
                    '--note', note,
                ],
            )
        if path == '/api/admin/promotion/promote':
            enforce_allowed_admin_keys(payload, {'profile_id', 'content_pack_id'})
            profile_id, pack_id = require_admin_pack_payload(payload)
            return run_admin_cli_action(
                action='promotion_promote',
                profile_id=profile_id,
                content_pack_id=pack_id,
                dry_run=False,
                command=[sys.executable, str(ROOT / 'tools' / 'aigc_battle' / 'aigc_candidate_promotion_gate.py'), '--profile', profile_id, '--pack', pack_id],
            )
        if path == '/api/admin/release-switch/dry-run':
            enforce_allowed_admin_keys(payload, {'profile_id', 'content_pack_id'})
            profile_id, pack_id = require_admin_pack_payload(payload)
            validate_release_switch_target(profile_id, pack_id)
            return run_admin_cli_action(
                action='release_switch_dry_run',
                profile_id=profile_id,
                content_pack_id=pack_id,
                dry_run=True,
                command=[sys.executable, str(ROOT / 'tools' / 'aigc_battle' / 'aigc_release_switch_console.py'), '--set-current', '--profile', profile_id, '--pack', pack_id, '--dry-run'],
            )
        if path == '/api/admin/release-switch/set-current':
            enforce_allowed_admin_keys(payload, {'profile_id', 'content_pack_id'})
            profile_id, pack_id = require_admin_pack_payload(payload)
            validate_release_switch_target(profile_id, pack_id)
            ensure_recent_successful_dry_run(profile_id, pack_id)
            result = run_admin_cli_action(
                action='release_switch_set_current',
                profile_id=profile_id,
                content_pack_id=pack_id,
                dry_run=False,
                command=[sys.executable, str(ROOT / 'tools' / 'aigc_battle' / 'aigc_release_switch_console.py'), '--set-current', '--profile', profile_id, '--pack', pack_id],
                post_commands=[
                    [sys.executable, str(ROOT / 'tools' / 'aigc_battle' / 'aigc_release_switch_smoke_probe.py'), '--profile', profile_id, '--pack', pack_id],
                ],
                rollback_on_failure=[sys.executable, str(ROOT / 'tools' / 'aigc_battle' / 'aigc_release_switch_console.py'), '--rollback-previous-current'],
            )
            return result
        if path == '/api/admin/release-switch/rollback-previous-current':
            enforce_allowed_admin_keys(payload, set())
            return run_admin_cli_action(
                action='release_switch_rollback_previous_current',
                profile_id='',
                content_pack_id='',
                dry_run=False,
                command=[sys.executable, str(ROOT / 'tools' / 'aigc_battle' / 'aigc_release_switch_console.py'), '--rollback-previous-current'],
            )
        if path == '/api/admin/preview/set':
            enforce_allowed_admin_keys(payload, {'profile_id', 'content_pack_id'})
            profile_id, pack_id = require_admin_pack_payload(payload)
            return run_admin_cli_action(
                action='preview_set',
                profile_id=profile_id,
                content_pack_id=pack_id,
                dry_run=False,
                command=[sys.executable, str(ROOT / 'tools' / 'aigc_battle' / 'aigc_preview_runtime_control.py'), '--set-preview', '--profile', profile_id, '--pack', pack_id, '--started-by', 'dashboard_admin'],
            )
        if path == '/api/admin/preview/restore':
            enforce_allowed_admin_keys(payload, set())
            return run_admin_cli_action(
                action='preview_restore',
                profile_id='',
                content_pack_id='',
                dry_run=False,
                command=[sys.executable, str(ROOT / 'tools' / 'aigc_battle' / 'aigc_preview_runtime_control.py'), '--restore-current'],
            )
        raise SystemExit('unsupported admin action')

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

    def handle_real_telemetry_snapshot(self, query: str) -> None:
        try:
            params = self.safe_query_params(query, {'profile_id', 'content_pack_id'})
            profile_id = params.get('profile_id', '')
            switch_lib.ensure_safe_id(profile_id, 'profile_id')
            path = switch_lib.resolve_generated_dir(profile_id) / 'real_telemetry_snapshot.json'
            payload = read_required_json(path)
            if payload is None:
                raise SystemExit('real telemetry snapshot not found')
        except SystemExit as exc:
            self.respond_json({'ok': False, 'error': str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return
        self.respond_json(payload)

    def handle_evaluation_pack_snapshot(self, query: str) -> None:
        try:
            params = self.safe_query_params(query, {'profile_id', 'content_pack_id'})
            profile_id = params.get('profile_id', '')
            content_pack_id = params.get('content_pack_id', '') or resolve_root_pack_content_pack_id(profile_id)
            switch_lib.ensure_safe_id(profile_id, 'profile_id')
            switch_lib.ensure_safe_id(content_pack_id, 'content_pack_id')
            path = EVALUATION_SNAPSHOT_DIR / f'{profile_id}__{content_pack_id}__evaluation_snapshot.json'
            payload = read_required_json(path)
            if payload is None:
                raise SystemExit('evaluation snapshot not found')
        except SystemExit as exc:
            self.respond_json({'ok': False, 'error': str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return
        self.respond_json(payload)

    def handle_evaluation_rebuild_recommendations(self, query: str) -> None:
        try:
            params = self.safe_query_params(query, {'profile_id', 'content_pack_id'})
            profile_id = params.get('profile_id', '')
            content_pack_id = params.get('content_pack_id', '') or resolve_root_pack_content_pack_id(profile_id)
            switch_lib.ensure_safe_id(profile_id, 'profile_id')
            switch_lib.ensure_safe_id(content_pack_id, 'content_pack_id')
            path = REBUILD_RECOMMEND_DIR / f'{profile_id}__{content_pack_id}__rebuild_recommendations.json'
            payload = read_required_json(path)
            if payload is None:
                raise SystemExit('rebuild recommendations not found')
        except SystemExit as exc:
            self.respond_json({'ok': False, 'error': str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return
        self.respond_json(payload)

    def handle_sequence_template(self, query: str) -> None:
        try:
            params = self.safe_query_params(query, {'sequence_template_id'})
            sequence_template_id = params.get('sequence_template_id', '')
            switch_lib.ensure_safe_id(sequence_template_id, 'sequence_template_id')
            payload = template_lib.load_sequence_template(sequence_template_id)
        except SystemExit as exc:
            self.respond_json({'ok': False, 'error': str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return
        self.respond_json(payload)

    def handle_acceptance_report(self, query: str) -> None:
        try:
            params = self.safe_query_params(query, {'profile_id', 'content_pack_id'})
            profile_id = params.get('profile_id', '')
            content_pack_id = params.get('content_pack_id', '')
            switch_lib.ensure_safe_id(profile_id, 'profile_id')
            switch_lib.ensure_safe_id(content_pack_id, 'content_pack_id')
            payload = load_acceptance_report(profile_id, content_pack_id)
            if not payload:
                raise SystemExit('acceptance report not found')
        except SystemExit as exc:
            self.respond_json({'ok': False, 'error': str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return
        self.respond_json(payload)

    def handle_promotion_report(self, query: str) -> None:
        try:
            params = self.safe_query_params(query, {'profile_id', 'content_pack_id'})
            profile_id = params.get('profile_id', '')
            content_pack_id = params.get('content_pack_id', '')
            switch_lib.ensure_safe_id(profile_id, 'profile_id')
            switch_lib.ensure_safe_id(content_pack_id, 'content_pack_id')
            payload = load_promotion_report(profile_id, content_pack_id)
            if not payload:
                raise SystemExit('promotion report not found')
        except SystemExit as exc:
            self.respond_json({'ok': False, 'error': str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return
        self.respond_json(payload)

    def handle_llm_prompt(self, query: str) -> None:
        try:
            from tools.aigc_battle import export_llm_generation_prompt as prompt_lib
            params = self.safe_query_params(query, {'profile_id', 'content_pack_id'})
            profile_id = params.get('profile_id', '')
            content_pack_id = params.get('content_pack_id', '')
            switch_lib.ensure_safe_id(profile_id, 'profile_id')
            switch_lib.ensure_safe_id(content_pack_id, 'content_pack_id')
            path = prompt_lib.prompt_md_path(profile_id, content_pack_id)
            if not path.exists():
                raise SystemExit('llm prompt not found')
            schema_path = prompt_lib.prompt_schema_path(profile_id, content_pack_id)
            context_path = prompt_lib.prompt_context_path(profile_id, content_pack_id)
        except SystemExit as exc:
            self.respond_json({'ok': False, 'error': str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return
        self.respond_json({'ok': True, 'prompt_path': to_relative(path), 'schema_path': to_relative(schema_path), 'context_path': to_relative(context_path), 'content': path.read_text(encoding='utf-8')})

    def handle_candidate_diff(self, query: str) -> None:
        try:
            params = self.safe_query_params(query, {'profile_id'})
            profile_id = params.get('profile_id', '')
            switch_lib.ensure_safe_id(profile_id, 'profile_id')
            path = ROOT / 'data' / 'aigc_battle' / 'generated' / 'ai_production' / 'diff' / f'{profile_id}__candidate_diff.json'
            payload = read_required_json(path)
            if payload is None:
                raise SystemExit('candidate diff not found')
        except SystemExit as exc:
            self.respond_json({'ok': False, 'error': str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return
        self.respond_json(payload)

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

    def handle_release_git_suggestions(self, query: str) -> None:
        try:
            params = self.safe_query_params(query, {'profile_id', 'content_pack_id'})
            profile_id, content_pack_id = params.get('profile_id', ''), params.get('content_pack_id', '')
            ensure_pack_exists(profile_id, content_pack_id)
            payload = release_lib.suggest_git_commands(profile_id, content_pack_id)
        except SystemExit as exc:
            self.respond_json({'ok': False, 'error': str(exc)}, status=HTTPStatus.BAD_REQUEST)
            return
        self.respond_json(payload)

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


def require_admin_pack_payload(payload: dict[str, Any]) -> tuple[str, str]:
    profile_id = safe_payload_id(payload, 'profile_id')
    content_pack_id = safe_payload_id(payload, 'content_pack_id')
    ensure_pack_resolver_entry(profile_id, content_pack_id)
    return profile_id, content_pack_id


def validate_admin_payload(payload: dict[str, Any]) -> None:
    for key in payload:
        if key in ADMIN_PROHIBITED_FIELDS:
            raise SystemExit(f'unsafe field rejected: {key}')


def enforce_allowed_admin_keys(payload: dict[str, Any], allowed_keys: set[str]) -> None:
    for key in payload:
        if key not in allowed_keys:
            raise SystemExit(f'unsupported admin field: {key}')


def ensure_pack_resolver_entry(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    resolver = load_pack_resolver()
    for entry in resolver.get('entries', []):
        if str(entry.get('mechanic_profile_id', '')) == profile_id and str(entry.get('content_pack_id', '')) == content_pack_id:
            return entry
    raise SystemExit('pack not found in pack_resolver')


def validate_release_switch_target(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    entry = ensure_pack_resolver_entry(profile_id, content_pack_id)
    if bool(entry.get('archived', False)) or str(entry.get('channel', '')) == 'archived':
        raise SystemExit('archived pack cannot set-current')
    return entry


def load_admin_status(admin_write_enabled: bool) -> dict[str, Any]:
    current_release = read_json_file(CURRENT_RELEASE_PATH)
    active_profile = read_json_file(ACTIVE_PROFILE_PATH)
    return {
        'admin_write_enabled': bool(admin_write_enabled),
        'lock_available': is_lock_available(),
        'latest_admin_action': load_latest_admin_action(),
        'current_release': current_release,
        'active_profile_matches_current_release': preview_lib.active_matches_current(active_profile, current_release),
    }


def is_lock_available() -> bool:
    if not ADMIN_LOCK_PATH.exists():
        return True
    payload = read_json_file(ADMIN_LOCK_PATH)
    locked_at = str(payload.get('locked_at', ''))
    if not locked_at:
        return False
    try:
        from datetime import datetime, timezone
        created = datetime.fromisoformat(locked_at)
        if created.tzinfo is None:
            created = created.replace(tzinfo=timezone.utc)
        age = (datetime.now(timezone.utc) - created).total_seconds()
    except Exception:  # noqa: BLE001
        return False
    if age > ADMIN_LOCK_STALE_SECONDS:
        try:
            ADMIN_LOCK_PATH.unlink()
            return True
        except OSError:
            return False
    return False


def acquire_admin_lock(action: str, profile_id: str, content_pack_id: str) -> dict[str, Any]:
    ADMIN_DIR.mkdir(parents=True, exist_ok=True)
    if ADMIN_LOCK_PATH.exists() and not is_lock_available():
        raise SystemExit('admin_action_locked')
    lock_payload = {
        'action': action,
        'profile_id': profile_id,
        'content_pack_id': content_pack_id,
        'locked_at': now_iso(),
        'pid': os.getpid(),
    }
    ADMIN_LOCK_PATH.write_text(json.dumps(lock_payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return lock_payload


def release_admin_lock() -> None:
    try:
        if ADMIN_LOCK_PATH.exists():
            ADMIN_LOCK_PATH.unlink()
    except OSError:
        return


def read_json_file(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding='utf-8'))


def load_latest_admin_action() -> dict[str, Any]:
    if not ADMIN_HISTORY_PATH.exists():
        return {}
    lines = [line.strip() for line in ADMIN_HISTORY_PATH.read_text(encoding='utf-8').splitlines() if line.strip()]
    if not lines:
        return {}
    try:
        return json.loads(lines[-1])
    except json.JSONDecodeError:
        return {}


def append_admin_history(entry: dict[str, Any]) -> None:
    ADMIN_DIR.mkdir(parents=True, exist_ok=True)
    with ADMIN_HISTORY_PATH.open('a', encoding='utf-8') as handle:
        handle.write(json.dumps(entry, ensure_ascii=False) + '\n')


def ensure_recent_successful_dry_run(profile_id: str, content_pack_id: str) -> None:
    if not ADMIN_HISTORY_PATH.exists():
        raise SystemExit('release switch dry-run required before set-current')
    for line in reversed(ADMIN_HISTORY_PATH.read_text(encoding='utf-8').splitlines()):
        if not line.strip():
            continue
        record = json.loads(line)
        if (
            record.get('action') == 'release_switch_dry_run'
            and record.get('profile_id') == profile_id
            and record.get('content_pack_id') == content_pack_id
            and record.get('result') == 'ok'
        ):
            return
    raise SystemExit('release switch dry-run required before set-current')


def run_cli_json(command: list[str]) -> dict[str, Any]:
    completed = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    stdout = completed.stdout.strip()
    stderr = completed.stderr.strip()
    payload: dict[str, Any] = {}
    if stdout:
        try:
            payload = json.loads(stdout)
        except json.JSONDecodeError:
            lines = stdout.splitlines()
            for index in range(len(lines)):
                candidate = '\n'.join(lines[index:]).strip()
                if not candidate.startswith('{'):
                    continue
                try:
                    payload = json.loads(candidate)
                    if index > 0:
                        payload.setdefault('stdout_prefix', '\n'.join(lines[:index]).strip())
                    break
                except json.JSONDecodeError:
                    continue
            if not payload:
                payload = {'ok': False, 'error': stdout}
    if completed.returncode != 0 and not payload:
        payload = {'ok': False, 'error': stderr or stdout or 'command failed'}
    if stderr and 'stderr' not in payload:
        payload['stderr'] = stderr
    payload.setdefault('ok', completed.returncode == 0)
    payload['command_exit_code'] = completed.returncode
    return payload


def current_release_ref() -> dict[str, Any]:
    current = read_json_file(CURRENT_RELEASE_PATH)
    return {
        'mechanic_profile_id': str(current.get('mechanic_profile_id', current.get('active_mechanic_profile_id', ''))),
        'content_pack_id': str(current.get('content_pack_id', current.get('active_content_pack_id', ''))),
    }


def active_profile_ref() -> dict[str, Any]:
    active = read_json_file(ACTIVE_PROFILE_PATH)
    return {
        'active_mechanic_profile_id': str(active.get('active_mechanic_profile_id', '')),
        'active_content_pack_id': str(active.get('active_content_pack_id', '')),
    }


def run_admin_cli_action(
    *,
    action: str,
    profile_id: str,
    content_pack_id: str,
    dry_run: bool,
    command: list[str],
    post_commands: list[list[str]] | None = None,
    rollback_on_failure: list[str] | None = None,
) -> dict[str, Any]:
    current_before = current_release_ref()
    lock_payload = acquire_admin_lock(action, profile_id, content_pack_id)
    action_id = f'admin_{action}_{uuid.uuid4().hex[:12]}'
    report_path = ''
    error = ''
    result_label = 'ok'
    try:
        payload = run_cli_json(command)
        if not bool(payload.get('ok', False)):
            error = str(payload.get('error', 'command failed'))
            result_label = 'failed'
            if rollback_on_failure:
                rollback_payload = run_cli_json(rollback_on_failure)
                payload['rollback_after_failure'] = rollback_payload
            response = {
                'ok': False,
                'admin_action_id': action_id,
                'action': action,
                'dry_run': dry_run,
                'result': payload,
                'lock': lock_payload,
            }
        else:
            if post_commands:
                for post_command in post_commands:
                    post_payload = run_cli_json(post_command)
                    if not bool(post_payload.get('ok', False)):
                        error = str(post_payload.get('error', 'post command failed'))
                        result_label = 'failed'
                        payload['post_command_failure'] = post_payload
                        if rollback_on_failure:
                            payload['rollback_after_failure'] = run_cli_json(rollback_on_failure)
                        response = {
                            'ok': False,
                            'admin_action_id': action_id,
                            'action': action,
                            'dry_run': dry_run,
                            'result': payload,
                            'lock': lock_payload,
                        }
                        break
                else:
                    response = {
                        'ok': True,
                        'admin_action_id': action_id,
                        'action': action,
                        'dry_run': dry_run,
                        'result': payload,
                        'lock': lock_payload,
                    }
            else:
                response = {
                    'ok': True,
                    'admin_action_id': action_id,
                    'action': action,
                    'dry_run': dry_run,
                    'result': payload,
                    'lock': lock_payload,
                }
        report_path = str(
            payload.get('promotion_report_path')
            or payload.get('source_acceptance_report_path')
            or payload.get('acceptance_report_path')
            or payload.get('report_path')
            or payload.get('runtime_manifest_path')
            or ''
        )
        return response
    finally:
        current_after = current_release_ref()
        active_after = active_profile_ref()
        append_admin_history(
            {
                'action_id': action_id,
                'timestamp': now_iso(),
                'action': action,
                'profile_id': profile_id,
                'content_pack_id': content_pack_id,
                'dry_run': dry_run,
                'result': result_label,
                'report_path': report_path,
                'current_release_before': current_before,
                'current_release_after': current_after,
                'active_profile_after': active_after,
                'error': error,
            }
        )
        release_admin_lock()

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


def read_optional_json(path: Path) -> dict[str, Any] | None:
    try:
        return read_required_json(path)
    except json.JSONDecodeError:
        return None


def to_relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def now_iso() -> str:
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).isoformat()


def load_release_smoke_report() -> dict[str, Any]:
    channels = release_lib.show_channels()
    current_release = channels.get('current_release', {})
    preferred = str(current_release.get('last_smoke_report_path', '')).strip()
    if preferred:
        preferred_path = ROOT / preferred
        if preferred_path.exists():
            return read_required_json(preferred_path) or {'ok': False, 'error': 'smoke report unreadable'}
    default_path = ROOT / 'data' / 'aigc_battle' / 'generated' / 'release_smoke' / 'playable_release_smoke_report.json'
    if default_path.exists():
        return read_required_json(default_path) or {'ok': False, 'error': 'smoke report unreadable'}
    return {'ok': False, 'error': 'smoke report not found'}


def load_evaluation_summary() -> dict[str, Any]:
    preferred = EVALUATION_GENERATED_DIR / 'r3_evaluation_snapshot_summary.json'
    if preferred.exists():
        return read_required_json(preferred) or {'ok': False, 'error': 'evaluation summary unreadable'}
    fallback = EVALUATION_GENERATED_DIR / 'r3_default_pack_set_evaluation_summary.json'
    if fallback.exists():
        return read_required_json(fallback) or {'ok': False, 'error': 'evaluation summary unreadable'}
    return {'ok': False, 'error': 'evaluation summary not found'}


def load_balance_release_build_report() -> dict[str, Any]:
    path = BALANCE_RELEASE_DIR / 'balance_release_build_report.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'balance release build report unreadable'}
    return {'ok': False, 'error': 'balance release build report not found'}


def load_balance_release_evaluation_report() -> dict[str, Any]:
    path = BALANCE_RELEASE_DIR / 'balance_release_evaluation_report.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'balance release evaluation report unreadable'}
    return {'ok': False, 'error': 'balance release evaluation report not found'}


def load_sequence_templates() -> dict[str, Any]:
    templates = []
    for path in sorted(SEQUENCE_TEMPLATE_DIR.glob('*.json')):
        payload = read_required_json(path)
        if not payload:
            continue
        templates.append({
            'sequence_template_id': payload.get('sequence_template_id', path.stem),
            'target_sequence_id': payload.get('target_sequence_id', ''),
            'total_encounter_count': payload.get('total_encounter_count', 0),
            'stage_counts': payload.get('stage_counts', {}),
            'path': to_relative(path),
        })
    return {'templates': templates, 'template_count': len(templates)}


def load_pack_resolver() -> dict[str, Any]:
    if PACK_RESOLVER_PATH.exists():
        return read_required_json(PACK_RESOLVER_PATH) or {'ok': False, 'error': 'pack resolver unreadable'}
    return {'ok': False, 'error': 'pack resolver not found'}


def load_template_portfolio_summary() -> dict[str, Any]:
    path = TEMPLATE_PORTFOLIO_DIR / 'template_portfolio_summary.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'template portfolio summary unreadable'}
    return {'ok': False, 'error': 'template portfolio summary not found'}


def load_template_portfolio_evaluation() -> dict[str, Any]:
    path = TEMPLATE_PORTFOLIO_DIR / 'template_portfolio_evaluation_report.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'template portfolio evaluation unreadable'}
    return {'ok': False, 'error': 'template portfolio evaluation not found'}


def load_template_release_strategy() -> dict[str, Any]:
    path = TEMPLATE_PORTFOLIO_DIR / 'template_release_strategy.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'template release strategy unreadable'}
    return {'ok': False, 'error': 'template release strategy not found'}


def load_mechanic_template_matrix_summary() -> dict[str, Any]:
    path = MATRIX_DIR / 'matrix_build_report.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'mechanic template matrix summary unreadable'}
    return {'ok': False, 'error': 'mechanic template matrix summary not found'}


def load_mechanic_template_matrix_evaluation() -> dict[str, Any]:
    path = MATRIX_DIR / 'matrix_evaluation_report.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'mechanic template matrix evaluation unreadable'}
    return {'ok': False, 'error': 'mechanic template matrix evaluation not found'}


def load_mechanic_template_matrix_strategy() -> dict[str, Any]:
    path = MATRIX_DIR / 'matrix_release_strategy.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'mechanic template matrix strategy unreadable'}
    return {'ok': False, 'error': 'mechanic template matrix strategy not found'}


def load_playable_hardening_summary() -> dict[str, Any]:
    path = PLAYABLE_HARDENING_DIR / 'playable_hardening_plan.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'playable hardening summary unreadable'}
    return {'ok': False, 'error': 'playable hardening summary not found'}


def load_playable_hardening_evaluation() -> dict[str, Any]:
    path = PLAYABLE_HARDENING_DIR / 'hardened_candidates_evaluation_report.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'playable hardening evaluation unreadable'}
    return {'ok': False, 'error': 'playable hardening evaluation not found'}


def load_playable_hardening_strategy() -> dict[str, Any]:
    path = PLAYABLE_HARDENING_DIR / 'playable_hardening_strategy.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'playable hardening strategy unreadable'}
    return {'ok': False, 'error': 'playable hardening strategy not found'}


def load_ai_studio_summary() -> dict[str, Any]:
    prompt_manifest = read_optional_json(AI_STUDIO_DIR / 'prompts' / 'r9_prompt_manifest.json')
    compare_report = read_optional_json(AI_STUDIO_GENERATED_DIR / 'r9_candidate_pack_compare_report.json')
    build_report = read_optional_json(AI_STUDIO_GENERATED_DIR / 'r9_candidate_pack_build_report.json')
    quality_reports = []
    quality_dir = AI_STUDIO_DIR / 'quality'
    if quality_dir.exists():
        for path in sorted(quality_dir.glob('*_quality_report.json')):
            payload = read_optional_json(path)
            if payload:
                quality_reports.append(payload)
    batches = load_ai_studio_batches()
    return {
        'prompt_manifest': prompt_manifest or {},
        'batches': batches,
        'quality_reports': quality_reports,
        'build_report': build_report or {},
        'pack_compare_report': compare_report or {},
        'online_llm_adapter_supported': bool((prompt_manifest or {}).get('online_llm_adapter_supported', False)),
        'offline_mode_default': bool((prompt_manifest or {}).get('offline_mode_default', True)),
        'llm_never_writes_runtime_manifest': bool((prompt_manifest or {}).get('llm_never_writes_runtime_manifest', True)),
        'llm_never_writes_active_profile': bool((prompt_manifest or {}).get('llm_never_writes_active_profile', True)),
        'dashboard_ai_studio_ready': bool(prompt_manifest and build_report and compare_report),
    }


def load_ai_studio_prompts() -> dict[str, Any]:
    path = AI_STUDIO_DIR / 'prompts' / 'r9_prompt_manifest.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'ai studio prompt manifest unreadable'}
    return {'ok': False, 'error': 'ai studio prompt manifest not found'}


def load_ai_studio_batches() -> dict[str, Any]:
    batches_dir = AI_STUDIO_DIR / 'batches'
    items: list[dict[str, Any]] = []
    if batches_dir.exists():
        for batch_dir in sorted(path for path in batches_dir.iterdir() if path.is_dir()):
            import_report = read_optional_json(batch_dir / 'import_report.json')
            dedupe_report = read_optional_json(batch_dir / 'dedupe_report.json')
            items.append(
                {
                    'batch_id': batch_dir.name,
                    'import_report': import_report or {},
                    'dedupe_report': dedupe_report or {},
                    'accepted_candidates_path': to_relative(batch_dir / 'accepted_candidates.jsonl') if (batch_dir / 'accepted_candidates.jsonl').exists() else '',
                    'rejected_candidates_path': to_relative(batch_dir / 'rejected_candidates.jsonl') if (batch_dir / 'rejected_candidates.jsonl').exists() else '',
                    'grouped_candidates_path': to_relative(batch_dir / 'grouped_candidates.json') if (batch_dir / 'grouped_candidates.json').exists() else '',
                }
            )
    return {'batch_count': len(items), 'batches': items}


def load_ai_studio_quality() -> dict[str, Any]:
    quality_dir = AI_STUDIO_DIR / 'quality'
    reports: list[dict[str, Any]] = []
    if quality_dir.exists():
        for path in sorted(quality_dir.glob('*_quality_report.json')):
            payload = read_optional_json(path)
            if payload:
                reports.append(payload)
    return {'quality_report_count': len(reports), 'reports': reports}


def load_ai_studio_pack_compare() -> dict[str, Any]:
    path = AI_STUDIO_GENERATED_DIR / 'r9_candidate_pack_compare_report.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'ai studio pack compare unreadable'}
    return {'ok': False, 'error': 'ai studio pack compare not found'}


def load_acceptance_latest() -> dict[str, Any]:
    path = ACCEPTANCE_GENERATED_DIR / 'latest_acceptance_report.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'acceptance latest unreadable'}
    return {'ok': False, 'error': 'acceptance latest not found'}


def load_acceptance_report(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    path = ACCEPTANCE_DIR / f'{profile_id}__{content_pack_id}__acceptance_report.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'acceptance report unreadable'}
    return {}


def load_promotion_report(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    path = PROMOTION_DIR / f'{profile_id}__{content_pack_id}__promotion_report.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'promotion report unreadable'}
    return {}


def load_promotion_history() -> dict[str, Any]:
    path = PROMOTION_DIR / 'promotion_history.jsonl'
    if not path.exists():
        return {'history_count': 0, 'events': []}
    events: list[dict[str, Any]] = []
    for line in path.read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return {'history_count': len(events), 'events': events}


def load_release_switch_history() -> dict[str, Any]:
    path = RELEASE_SWITCH_DIR / 'release_switch_history.jsonl'
    if not path.exists():
        return {'history_count': 0, 'events': []}
    events: list[dict[str, Any]] = []
    for line in path.read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return {'history_count': len(events), 'events': events}


def load_production_contract_schema() -> dict[str, Any]:
    path = PRODUCTION_CONTRACT_DIR / 'schema_manifest.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'production contract schema unreadable'}
    return {'ok': False, 'error': 'production contract schema not found'}


def load_production_file_policy() -> dict[str, Any]:
    path = PRODUCTION_CONTRACT_DIR / 'generated_file_policy.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'generated file policy unreadable'}
    return {'ok': False, 'error': 'generated file policy not found'}


def load_minimal_acceptance_command() -> dict[str, Any]:
    path = PRODUCTION_CONTRACT_DIR / 'minimal_acceptance_command.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'minimal acceptance command unreadable'}
    return {'ok': False, 'error': 'minimal acceptance command not found'}


def load_deprecated_probe_inventory() -> dict[str, Any]:
    path = PRODUCTION_CONTRACT_DIR / 'deprecated_probe_inventory.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'deprecated probe inventory unreadable'}
    return {'ok': False, 'error': 'deprecated probe inventory not found'}


def load_production_contract_summary() -> dict[str, Any]:
    schema = load_production_contract_schema()
    policy = load_production_file_policy()
    minimal = load_minimal_acceptance_command()
    deprecated = load_deprecated_probe_inventory()
    freeze_report_path = PRODUCTION_FREEZE_DIR / 'production_contract_freeze_report.json'
    freeze_report = read_required_json(freeze_report_path) if freeze_report_path.exists() else {}
    return {
        'production_contract_ready': bool(schema.get('schema_manifest_ready', False) and policy.get('generated_file_policy_ready', False) and minimal.get('minimal_acceptance_command_ready', False) and deprecated.get('deprecated_probe_inventory_ready', False)),
        'schema_manifest_path': 'data/aigc_battle/production_contract/schema_manifest.json',
        'generated_file_policy_path': 'data/aigc_battle/production_contract/generated_file_policy.json',
        'minimal_acceptance_command_path': 'data/aigc_battle/production_contract/minimal_acceptance_command.json',
        'deprecated_probe_inventory_path': 'data/aigc_battle/production_contract/deprecated_probe_inventory.json',
        'production_contract_doc_path': 'docs/AIGC_BATTLE_PRODUCTION_CONTRACT.md',
        'freeze_report_path': 'data/aigc_battle/generated/production_freeze/production_contract_freeze_report.json' if freeze_report else '',
        'freeze_report': freeze_report or {},
        'schema_manifest_ready': bool(schema.get('schema_manifest_ready', False)),
        'generated_file_policy_ready': bool(policy.get('generated_file_policy_ready', False)),
        'minimal_acceptance_command_ready': bool(minimal.get('minimal_acceptance_command_ready', False)),
        'deprecated_probe_inventory_ready': bool(deprecated.get('deprecated_probe_inventory_ready', False)),
    }


def load_single_candidate_release_drill_report() -> dict[str, Any]:
    path = SINGLE_RELEASE_DRILL_GENERATED_DIR / 'single_candidate_release_drill_report.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'single candidate release drill report unreadable'}
    return {'ok': False, 'error': 'single candidate release drill report not found'}


def load_single_candidate_release_drill_summary() -> dict[str, Any]:
    report = load_single_candidate_release_drill_report()
    if report.get('ok') is False and 'error' in report:
        return report
    return {
        'release_drill_ready': bool(report.get('single_candidate_release_drill_ready', False)),
        'source_profile_id': str(report.get('source_profile_id', '')),
        'source_pack_id': str(report.get('source_pack_id', '')),
        'target_profile_id': str(report.get('target_profile_id', '')),
        'target_pack_id': str(report.get('target_pack_id', '')),
        'acceptance_pass': bool(report.get('acceptance_pass', False)),
        'acceptance_risk_level': str(report.get('acceptance_risk_level', '')),
        'acceptance_recommendation': str(report.get('acceptance_recommendation', '')),
        'human_review_status': str(report.get('human_review_status', '')),
        'marked_release_candidate': bool(report.get('marked_release_candidate', False)),
        'dry_run_switch_ready': bool(report.get('dry_run_switch_ready', False)),
        'current_release_unchanged': bool(report.get('current_release_unchanged', False)),
        'active_profile_matches_current_release': bool(report.get('active_profile_matches_current_release', False)),
        'partial_pass': bool(report.get('partial_pass', False)),
        'probe_pass': bool(report.get('probe_pass', False)),
        'report_path': 'data/aigc_battle/generated/single_candidate_release_drill/single_candidate_release_drill_report.json',
        'report': report,
    }


def load_release_landing_report() -> dict[str, Any]:
    path = RELEASE_LANDING_GENERATED_DIR / 'r16_release_landing_gameplay_verification_probe_report.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'release landing report unreadable'}
    return {'ok': False, 'error': 'release landing report not found'}


def load_release_landing_summary() -> dict[str, Any]:
    report = load_release_landing_report()
    if report.get('ok') is False and 'error' in report:
        return report
    return {
        'release_landing_ready': bool(report.get('release_landing_ready', False)),
        'selected_release_candidate_profile_id': str(report.get('selected_release_candidate_profile_id', '')),
        'selected_release_candidate_pack_id': str(report.get('selected_release_candidate_pack_id', '')),
        'new_current_profile_id': str(report.get('new_current_profile_id', '')),
        'new_current_pack_id': str(report.get('new_current_pack_id', '')),
        'gameplay_entry_verification_ready': bool(report.get('gameplay_entry_verification_ready', False)),
        'warning_current': bool(report.get('warning_current', False)),
        'rollback_available': bool(report.get('rollback_available', False)),
        'probe_pass': bool(report.get('probe_pass', False)),
        'report_path': 'data/aigc_battle/generated/release_landing/r16_release_landing_gameplay_verification_probe_report.json',
        'report': report,
    }


def load_production_closeout_plan() -> dict[str, Any]:
    path = PRODUCTION_CLOSEOUT_GENERATED_DIR / 'production_closeout_plan.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'production closeout plan unreadable'}
    return {'ok': False, 'error': 'production closeout plan not found'}


def load_production_closeout_cleanup() -> dict[str, Any]:
    path = PRODUCTION_CLOSEOUT_GENERATED_DIR / 'production_closeout_cleanup_report.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'production closeout cleanup unreadable'}
    return {'ok': False, 'error': 'production closeout cleanup not found'}


def load_production_closeout_verification() -> dict[str, Any]:
    path = PRODUCTION_CLOSEOUT_GENERATED_DIR / 'production_closeout_verification_report.json'
    if path.exists():
        return read_required_json(path) or {'ok': False, 'error': 'production closeout verification unreadable'}
    return {'ok': False, 'error': 'production closeout verification not found'}


def load_production_closeout_summary() -> dict[str, Any]:
    plan = load_production_closeout_plan()
    cleanup = load_production_closeout_cleanup()
    verification = load_production_closeout_verification()
    closeout_probe_path = PRODUCTION_CLOSEOUT_GENERATED_DIR / 'r17_production_closeout_probe_report.json'
    closeout_probe = read_required_json(closeout_probe_path) if closeout_probe_path.exists() else {}
    return {
        'production_closeout_ready': bool(closeout_probe.get('production_closeout_ready', False) or verification.get('production_closeout_ready', False)),
        'current_landed_pack': str(closeout_probe.get('current_landed_pack', verification.get('current_landed_pack', ''))),
        'current_sequence_template': str(closeout_probe.get('current_sequence_template', verification.get('current_sequence_template', ''))),
        'current_encounter_count': int(closeout_probe.get('current_encounter_count', verification.get('current_encounter_count', 0)) or 0),
        'previous_current_pack': str(closeout_probe.get('previous_current_pack', verification.get('previous_current_pack', ''))),
        'closeout_report_path': 'data/aigc_battle/generated/production_closeout/r17_production_closeout_probe_report.json' if closeout_probe else '',
        'cleanup_report_path': 'data/aigc_battle/generated/production_closeout/production_closeout_cleanup_report.json' if cleanup.get('cleanup_plan_ready', False) else '',
        'final_acceptance_status': str(closeout_probe.get('final_acceptance_status', verification.get('final_acceptance_status', ''))),
        'resolver_channel_consistency_fixed': bool(verification.get('resolver_channel_consistency_fixed', False)),
        'dashboard_api_ready': bool(
            plan.get('cleanup_plan_ready', False)
            and cleanup.get('safe_cleanup_applied', False)
            and verification.get('production_closeout_ready', False)
        ),
        'plan_path': 'data/aigc_battle/generated/production_closeout/production_closeout_plan.json' if plan.get('cleanup_plan_ready', False) else '',
        'verification_path': 'data/aigc_battle/generated/production_closeout/production_closeout_verification_report.json' if verification.get('production_closeout_ready', False) else '',
        'report': closeout_probe or {},
    }


def load_dashboard_display_current() -> dict[str, Any]:
    index_payload = index_lib.build_index()
    hero = index_payload.get('current_status_hero', {})
    return {
        'current_status_hero_ready': bool(hero),
        'current': hero,
        'current_release_unchanged': bool(index_payload.get('active_profile_matches_current_release', False)),
    }


def load_dashboard_display_packs() -> dict[str, Any]:
    index_payload = index_lib.build_index()
    packs: list[dict[str, Any]] = []
    for profile in index_payload.get('profiles', []):
        for pack in profile.get('content_packs', []):
            packs.append(
                {
                    'mechanic_profile_id': str(pack.get('mechanic_profile_id', '')),
                    'sequence_template_id': str(pack.get('sequence_template_id', '')),
                    'content_pack_id': str(pack.get('content_pack_id', '')),
                    'build_variant': str(pack.get('build_variant', '')),
                    'display_status': str(pack.get('display_status', 'review')),
                    'display_status_rank': int(pack.get('display_status_rank', 999) or 999),
                    'display_badge': str(pack.get('display_badge', '')),
                    'display_reason': str(pack.get('display_reason', '')),
                    'primary_action_hint': str(pack.get('primary_action_hint', '')),
                    'encounter_count': int(pack.get('formal_encounter_total_count', 0) or 0),
                    'profile': str(pack.get('mechanic_profile_id', '')),
                    'template': str(pack.get('sequence_template_id', '') or 'unknown'),
                    'acceptance_result': str(pack.get('latest_acceptance_recommendation', '')),
                    'acceptance_recommendation': str(pack.get('latest_acceptance_recommendation', '')),
                    'promotion_result': 'release_candidate' if bool(pack.get('release_candidate_status', False)) else str(pack.get('human_review_status', '')),
                    'release_landing_result': 'pass' if bool(pack.get('release_landing_current', False)) else 'warning' if bool(pack.get('warning_current', False)) else '',
                    'last_report_path': str(
                        pack.get('closeout_report_path')
                        or pack.get('release_landing_report_path')
                        or pack.get('latest_promotion_report_path')
                        or pack.get('latest_acceptance_report_path')
                        or pack.get('validation_report_path')
                        or ''
                    ),
                    'risk_level': str(pack.get('risk_level', '')),
                    'win_rate': float(pack.get('win_rate', 0) or 0),
                    'avg_turn_count': float(pack.get('avg_turn_count', 0) or 0),
                    'fallback_loadout_count': int(pack.get('fallback_loadout_count', 0) or 0),
                    'reward_coverage_complete': bool(
                        str(pack.get('final_acceptance_status', '')) == 'pass'
                        or bool(pack.get('gameplay_entry_verified', False))
                    ),
                    'blocking_reasons': pack.get('blocking_reasons', []),
                    'warning_reasons': pack.get('warning_reasons', []),
                    'ai_studio_candidate_pack': bool(pack.get('ai_studio_candidate_pack', False)),
                    'matrix_slot': bool(pack.get('matrix_slot', False)),
                    'current_release_marker': bool(pack.get('current_release_marker', False)),
                    'previous_current_marker': bool(pack.get('previous_current_marker', False)),
                    'fallback_release_marker': bool(pack.get('fallback_release_marker', False)),
                }
            )
    packs.sort(key=lambda item: (int(item.get('display_status_rank', 999)), item.get('mechanic_profile_id', ''), item.get('content_pack_id', '')))
    return {
        'status_normalization_ready': True,
        'pack_list_sorted': True,
        'packs': packs,
    }


def load_dashboard_display_risk_board() -> dict[str, Any]:
    packs_payload = load_dashboard_display_packs()
    rows = [
        {
            'pack_id': pack.get('content_pack_id', ''),
            'display_status': pack.get('display_status', ''),
            'risk_level': pack.get('risk_level', ''),
            'blocking_reasons': pack.get('blocking_reasons', []),
            'warning_reasons': pack.get('warning_reasons', []),
            'next_recommended_step': pack.get('primary_action_hint', ''),
        }
        for pack in packs_payload.get('packs', [])
    ]
    return {
        'risk_board_ready': True,
        'rows': rows,
    }


def load_dashboard_display_summary() -> dict[str, Any]:
    current = load_dashboard_display_current()
    packs = load_dashboard_display_packs()
    risk_board = load_dashboard_display_risk_board()
    return {
        'dashboard_display_ready': bool(current.get('current_status_hero_ready', False) and packs.get('status_normalization_ready', False) and risk_board.get('risk_board_ready', False)),
        'current': current.get('current', {}),
        'packs': packs.get('packs', []),
        'risk_board': risk_board.get('rows', []),
        'display_probe_summary': {
            'current_status_hero_ready': bool(current.get('current_status_hero_ready', False)),
            'status_normalization_ready': bool(packs.get('status_normalization_ready', False)),
            'pack_list_sorted': bool(packs.get('pack_list_sorted', False)),
            'risk_board_ready': bool(risk_board.get('risk_board_ready', False)),
        },
    }


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
.clickable-card { cursor:pointer; transition:background .15s ease,border-color .15s ease,box-shadow .15s ease,transform .15s ease; }
.clickable-card:hover { background:#fff7ea; border-color:#c79b62; box-shadow:0 4px 14px rgba(80,52,18,.08); transform:translateY(-1px); }
.pack-row { cursor:pointer; transition:background .15s ease, box-shadow .15s ease; }
.pack-row:hover { background:#fbf2e5; box-shadow:inset 3px 0 0 #c79b62; }
.pack-row.is-selected, .pack-row[aria-selected="true"] { background:#f4e4c9; box-shadow:inset 4px 0 0 #2d607f; }
.header-cards { display:flex; flex-wrap:wrap; gap:12px; align-items:stretch; margin-top:12px; }
.header-card { flex:1 1 320px; min-width:280px; max-width:100%; overflow:hidden; }
.header-card .value,.header-card .pack-id,.header-card .mono { overflow-wrap:anywhere; word-break:break-word; }
.health-strip { display:flex; flex-wrap:wrap; gap:8px; align-items:center; margin-top:10px; padding:8px 0 0; }
.mono { font-family:ui-monospace,SFMono-Regular,Menlo,monospace; } .muted { color:var(--muted); font-size:13px; } .report { white-space:pre-wrap; border:1px solid var(--line); border-radius:8px; padding:12px; background:#fffdf8; max-height:520px; overflow:auto; }
summary { cursor:pointer; font-weight:600; } @media (max-width: 960px) { .dual { grid-template-columns:1fr; } } @media (max-width: 720px) { .header-card { flex-basis:100%; } }
</style>
</head>
<body>
<main>
<header>
  <h1>AIGC Battle Production Console</h1>
  <div id="console-state" class="health-strip"></div>
  <div id="active-line" class="header-cards"></div>
  <div id="active-metrics" class="muted" style="margin-top:8px;"></div>
  <div class="tabs" id="tabs"></div>
</header>
<section id="display" class="panel active"></section>
<section id="runtime" class="panel"></section>
<section id="pack-detail" class="panel"></section>
<section id="pack-content" class="panel"></section>
<section id="timeline-risk" class="panel"></section>
<section id="admin-actions" class="panel"></section>
</main>
<script>
const state = { workspace:null, activeReview:null, packDetail:null, notes:null, release:null, report:'', channels:null, smoke:null, evaluationSummary:null, evaluationSnapshot:null, rebuildRecommendations:null, balanceReleaseReport:null, balanceReleaseEvaluation:null, display:null, adminStatus:null, previewStatus:null, selectedPackKey:null, selectedEncounterKey:null, contentWeaponFilter:'all', contentCardTypeFilter:'all', contentDifficultyFilter:'all', contentRealmFilter:'all', contentUsageFilter:'all', displaySearch:'', displayStatusFilter:'all', displayProfileFilter:'all', displayTemplateFilter:'all', reportsExpanded:false, copyFeedback:'', adminActionMessage:'', adminActionError:'', adminActionRunning:'' };
const tabs = [['display','总览'],['runtime','运行态'],['pack-detail','Pack 详情'],['pack-content','Pack 内容'],['timeline-risk','时间线与风险'],['admin-actions','管理动作']];
const $ = (id) => document.getElementById(id);
const esc = (v) => String(v ?? '').replace(/[&<>"]/g, (c) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const join = (v) => Array.isArray(v) ? v.join(', ') : (v || '-');
const REPO_ROOT = '/Users/happy/Documents/Codex/canghaidiming/';
async function api(url, options) { const r = await fetch(url, options); const p = await r.json(); if (!r.ok || p.ok === false) throw new Error(p.error || ('request failed: ' + r.status)); return p; }
function cls(v) { return v === 'pass' ? 'ok' : v === 'fail' ? 'fail' : v === 'warning' ? 'warning' : 'info'; }
function relPath(v) { const text = String(v || ''); if (!text) return '未生成 / 不适用'; return text.startsWith(REPO_ROOT) ? text.slice(REPO_ROOT.length) : text; }
function detailValue(v) { return v === null || v === undefined || v === '' ? '未生成 / 不适用' : v; }
function templateValue(v) { const text = String(v || '').trim(); return text || 'unknown'; }
function copySupported() { return !!(navigator.clipboard && navigator.clipboard.writeText); }
function activePackKey() { return state.display?.current?.mechanic_profile_id && state.display?.current?.content_pack_id ? `${state.display.current.mechanic_profile_id}::${state.display.current.content_pack_id}` : ''; }
function selectedPack() { return (state.display?.packs || []).find((row) => `${row.mechanic_profile_id}::${row.content_pack_id}` === state.selectedPackKey) || null; }
async function copyPackId(packId) {
  state.copyFeedback = '';
  if (!packId) return;
  if (copySupported()) {
    await navigator.clipboard.writeText(packId);
    state.copyFeedback = `已复制 ${packId}`;
    renderDisplay();
    return;
  }
  window.prompt('复制 content_pack_id', packId);
  state.copyFeedback = '浏览器不支持 clipboard，已回退为手动复制';
  renderDisplay();
}
function resetDisplayFilters() {
  state.displaySearch = '';
  state.displayStatusFilter = 'all';
  state.displayProfileFilter = 'all';
  state.displayTemplateFilter = 'all';
  state.copyFeedback = '';
  state.reportsExpanded = false;
  if (state.display?.current?.mechanic_profile_id && state.display?.current?.content_pack_id) {
    focusPack(state.display.current.mechanic_profile_id, state.display.current.content_pack_id);
    return;
  }
  renderDisplay();
}
function makeTabs() { const root = $('tabs'); root.innerHTML = tabs.map(([id,label],i) => `<button class="tab${i===0?' active':''}" data-tab="${id}">${label}</button>`).join(''); root.querySelectorAll('[data-tab]').forEach((b) => b.onclick = () => { root.querySelectorAll('.tab').forEach((n) => n.classList.toggle('active', n === b)); document.querySelectorAll('.panel').forEach((p) => p.classList.toggle('active', p.id === b.dataset.tab)); }); }
async function loadBaseState() {
  state.workspace = await api('/api/review-workspace');
  state.channels = await api('/api/release/channels');
  state.display = await api('/api/dashboard-display');
  state.adminStatus = await api('/api/admin/status').catch(() => ({ admin_write_enabled:false, lock_available:false, latest_admin_action:{} }));
  state.previewStatus = await api('/api/preview/status').catch(() => ({ preview_status:'unknown' }));
  state.smoke = await api('/api/release/smoke-report').catch(() => ({ ok:false, error:'smoke report not found' }));
  state.evaluationSummary = await api('/api/evaluation/summary').catch(() => ({ ok:false, error:'evaluation summary not found' }));
  state.balanceReleaseReport = await api('/api/balance-release/report').catch(() => ({ ok:false, error:'balance release build report not found' }));
  state.balanceReleaseEvaluation = await api('/api/balance-release/evaluation').catch(() => ({ ok:false, error:'balance release evaluation report not found' }));
}
async function bootstrap() {
  await loadBaseState();
  await focusPack(state.workspace.active_profile_id, state.workspace.active_content_pack_id);
}
async function focusPack(profileId, contentPackId) {
  state.selectedPackKey = `${profileId}::${contentPackId}`;
  state.selectedEncounterKey = null;
  state.contentWeaponFilter = 'all';
  state.contentCardTypeFilter = 'all';
  state.contentDifficultyFilter = 'all';
  state.contentRealmFilter = 'all';
  state.contentUsageFilter = 'all';
  const qs = new URLSearchParams({ profile_id: profileId, content_pack_id: contentPackId });
  state.activeReview = await api('/api/pack-review?' + qs.toString());
  state.packDetail = await api('/api/pack-detail?' + qs.toString());
  state.notes = await api('/api/review-notes?' + qs.toString());
  state.release = await api('/api/release/status?' + qs.toString());
  state.report = (await api('/api/review-report?' + qs.toString())).content || '';
  state.evaluationSnapshot = await api('/api/evaluation/pack-snapshot?' + qs.toString()).catch(() => ({ ok:false, error:'evaluation snapshot not found' }));
  state.rebuildRecommendations = await api('/api/evaluation/rebuild-recommendations?' + qs.toString()).catch(() => ({ ok:false, error:'rebuild recommendations not found' }));
  const firstEncounter = (state.activeReview?.encounter_review_table || [])[0] || (state.packDetail?.sequence_detail || [])[0] || null;
  state.selectedEncounterKey = firstEncounter ? String(firstEncounter.formal_encounter_id || firstEncounter.generated_battle_slot_id || firstEncounter.sequence_position || '') : null;
  renderAll();
}
async function refreshAfterAdminAction() {
  const preferredKey = state.selectedPackKey || activePackKey();
  await loadBaseState();
  const available = state.display?.packs || [];
  const target = available.find((row) => `${row.mechanic_profile_id}::${row.content_pack_id}` === preferredKey)
    || available.find((row) => `${row.mechanic_profile_id}::${row.content_pack_id}` === activePackKey())
    || available[0];
  if (!target) {
    state.selectedPackKey = null;
    state.activeReview = null;
    state.packDetail = null;
    state.notes = null;
    state.release = null;
    state.report = '';
    state.evaluationSnapshot = null;
    state.rebuildRecommendations = null;
    renderAll();
    return;
  }
  await focusPack(target.mechanic_profile_id, target.content_pack_id);
}
function currentPackKey() { return state.selectedPackKey || `${state.activeReview?.pack_identity?.mechanic_profile_id || ''}::${state.activeReview?.pack_identity?.content_pack_id || ''}`; }
async function postJson(path, payload) { return api(path, { method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(payload) }); }
function selectedAdminPayload() {
  const selected = selectedPack();
  if (!selected) return null;
  return { profile_id: selected.mechanic_profile_id, content_pack_id: selected.content_pack_id };
}
function renderHeader() {
  const review = state.activeReview || {}; const health = review.health_summary || {}; const hero = state.display?.current || {}; const selected = selectedPack(); const selectedAcceptance = state.packDetail?.dashboard_display_summary?.acceptance_group || {}; const samePack = !!selected && activePackKey() === state.selectedPackKey; const displaySummary = state.display?.display_probe_summary || {}; const currentActiveMatched = activePackKey() === `${state.workspace.active_profile_id || ''}::${state.workspace.active_content_pack_id || ''}`; const synced = !!(displaySummary.current_status_hero_ready && displaySummary.status_normalization_ready && displaySummary.pack_list_sorted && displaySummary.risk_board_ready);
  $('active-line').innerHTML = `<div id="active-pack-card" class="card header-card active-pack-card clickable-card" role="button" title="点击回到当前游戏实际运行包"><div class="muted">Active Pack / 当前游戏运行包</div><div class="badge info">current</div><div class="value mono">${esc(hero.mechanic_profile_id || state.workspace.active_profile_id)}</div><div class="value mono">${esc(hero.sequence_template_id || '-')}</div><div class="pack-id mono">${esc(hero.content_pack_id || state.workspace.active_content_pack_id)}</div><div>build_variant: ${esc(hero.build_variant || '-')}</div><div>encounter_count: ${esc(String(hero.encounter_count ?? '-'))}</div><div class="muted" style="margin-top:8px;">fallback=${esc(String(hero.fallback_loadout_count ?? '-'))} · reward=${esc(String(hero.reward_coverage_complete ?? false))}</div><div class="muted" style="margin-top:6px;">查看当前运行包</div></div><div id="selected-pack-card" class="card header-card selected-pack-card clickable-card" role="button" title="点击定位列表中的当前查看包"><div class="muted">Selected Pack / 当前查看包</div>${selected ? `<div class="badge ${cls(selected.risk_level || 'info')}">${esc(selected.display_status || '-')}</div><div class="value mono">${esc(selected.mechanic_profile_id || '-')}</div><div class="value mono">${esc(selected.sequence_template_id || '-')}</div><div class="pack-id mono">${esc(selected.content_pack_id || '-')}</div><div>build_variant: ${esc(selected.build_variant || '-')}</div><div>risk_level: ${esc(selected.risk_level || '-')}</div><div>acceptance_recommendation: ${esc(detailValue(selectedAcceptance.recommendation || selected.acceptance_recommendation))}</div><div class="muted" style="margin-top:6px;">${samePack ? '正在查看当前正式包' : '仅查看，不影响游戏当前运行包'}</div>` : `<div class="badge warning">未选择包</div><div class="muted" style="margin-top:8px;">请选择包 / 无匹配包</div>`}</div>`;
  $('active-metrics').innerHTML = samePack ? '当前查看包与游戏实际运行包一致。' : '当前查看包与游戏实际运行包不同，仅作只读查看。';
  $('console-state').innerHTML = `<span class="badge">${state.adminStatus?.admin_write_enabled ? 'admin-write enabled' : '只读模式'}</span><span class="badge ${synced ? 'ok' : 'warning'}">${synced ? '数据已同步' : '数据可能过期'}</span><span class="badge ${currentActiveMatched ? 'ok' : 'warning'}">${currentActiveMatched ? 'current=active' : 'current≠active'}</span><span class="badge ${displaySummary.pack_list_sorted ? 'ok' : 'warning'}">${displaySummary.pack_list_sorted ? 'resolver 已更新' : 'resolver 需更新'}</span><span class="badge">${state.adminStatus?.admin_write_enabled ? '仅 /api/admin/* 可写' : '无写操作'}</span><span class="badge ${cls(health.health_status)}">${esc(health.health_status || '未知')}</span><span class="badge">last refreshed: ${esc(state.display?.generated_at || '未知')}</span>`;
  $('active-pack-card').onclick = () => resetDisplayFilters();
  if ($('selected-pack-card')) $('selected-pack-card').onclick = () => {
    if (!state.selectedPackKey) return;
    const row = document.querySelector(`[data-pack="${CSS.escape(state.selectedPackKey)}"]`);
    if (row) row.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
  };
}
function renderDisplay() {
  const packs = state.display?.packs || [];
  const statusFilter = $('display-status-filter')?.value || state.displayStatusFilter || 'all';
  const profileFilter = $('display-profile-filter')?.value || state.displayProfileFilter || 'all';
  const templateFilter = $('display-template-filter')?.value || state.displayTemplateFilter || 'all';
  const search = ($('display-search')?.value || state.displaySearch || '').trim().toLowerCase();
  state.displayStatusFilter = statusFilter;
  state.displayProfileFilter = profileFilter;
  state.displayTemplateFilter = templateFilter;
  state.displaySearch = search;
  const profileOptions = [...new Set(packs.map((row) => String(row.mechanic_profile_id || '')).filter(Boolean))].sort();
  const templateOptions = [...new Set(packs.map((row) => templateValue(row.sequence_template_id)))].sort();
  const filtered = packs.filter((row) => {
    if (statusFilter === 'all') return true;
    if (statusFilter === 'historical') return ['previous_current','archived','review'].includes(row.display_status);
    return row.display_status === statusFilter;
  }).filter((row) => {
    if (profileFilter === 'all') return true;
    return String(row.mechanic_profile_id || '') === profileFilter;
  }).filter((row) => {
    if (templateFilter === 'all') return true;
    return templateValue(row.sequence_template_id) === templateFilter;
  }).filter((row) => {
    if (!search) return true;
    return [
      row.content_pack_id,
      row.mechanic_profile_id,
      row.sequence_template_id,
      row.display_status,
      row.display_badge,
    ].some((value) => String(value || '').toLowerCase().includes(search));
  });
  const selectedVisible = filtered.some((row) => `${row.mechanic_profile_id}::${row.content_pack_id}` === state.selectedPackKey);
  const hero = state.display?.current || {};
  const previous = packs.find((row) => row.display_status === 'previous_current') || {};
  const fallback = packs.find((row) => row.display_status === 'fallback') || {};
  const selectedFilteredHint = !selectedVisible && state.selectedPackKey ? `<div class="badge warning">当前选中包不在筛选结果中</div><div class="mono">${esc(state.selectedPackKey)}</div>` : '';
  $('display').innerHTML = `<div class="band"><h2>总览</h2><div class="cards"><div class="card"><div class="muted">Current Status Hero</div><div class="badge info">current</div><div class="mono">${esc(hero.mechanic_profile_id || '-')}</div><div class="mono">${esc(hero.sequence_template_id || '-')}</div><div class="mono">${esc(hero.content_pack_id || '-')}</div><div>build_variant: ${esc(hero.build_variant || '-')}</div><div>encounter_count: ${esc(String(hero.encounter_count ?? '-'))}</div></div><div class="card"><div class="muted">Previous Current</div><div class="mono">${esc(previous.content_pack_id || '未生成 / 不适用')}</div><div>status: ${esc(previous.display_status || '-')}</div><div>risk_level: ${esc(previous.risk_level || '-')}</div></div><div class="card"><div class="muted">Fallback</div><div class="mono">${esc(fallback.content_pack_id || '未生成 / 不适用')}</div><div>status: ${esc(fallback.display_status || '-')}</div><div>risk_level: ${esc(fallback.risk_level || '-')}</div></div></div><div class="toolbar"><input id="display-search" placeholder="搜索 pack / profile / template / status / badge"><select id="display-status-filter"><option value="all">全部</option><option value="current">当前</option><option value="previous_current">上一正式版</option><option value="fallback">Fallback</option><option value="release_candidate">Release Candidate</option><option value="ready_for_review">可审核</option><option value="needs_balance">需平衡</option><option value="ai_studio_review">AI Studio</option><option value="matrix_review">Matrix</option><option value="review">Review</option><option value="historical">历史</option><option value="invalid">无效</option></select><select id="display-profile-filter"><option value="all">All Profiles</option>${profileOptions.map((value) => `<option value="${esc(value)}">${esc(value)}</option>`).join('')}</select><select id="display-template-filter"><option value="all">All Templates</option>${templateOptions.map((value) => `<option value="${esc(value)}">${esc(value === 'unknown' ? 'unknown / 未标记' : value)}</option>`).join('')}</select><button id="display-reset">重置筛选</button>${state.copyFeedback ? `<span class="badge ok">${esc(state.copyFeedback)}</span>` : ''}${selectedFilteredHint}</div><div class="table"><table><thead><tr><th>Status</th><th>Profile</th><th>Template</th><th>Pack</th><th>Enc</th><th>Risk</th><th>Acceptance</th><th>Next</th><th></th><th></th></tr></thead><tbody>${filtered.length ? filtered.map((row) => { const rowKey = `${row.mechanic_profile_id}::${row.content_pack_id}`; const rowSelected = rowKey === state.selectedPackKey; return `<tr class="pack-row ${rowSelected ? 'is-selected' : ''}" data-pack="${rowKey}" aria-selected="${rowSelected ? 'true' : 'false'}" title="点击切换查看此 Pack"><td><span class="badge">${esc(row.display_badge)}</span><div class="muted">${esc(row.display_status)}</div>${row.current_release_marker ? '<div class="muted">当前正式</div>' : '<div class="muted">点击查看</div>'}</td><td class="mono">${esc(row.mechanic_profile_id)}</td><td class="mono">${esc(templateValue(row.sequence_template_id))}</td><td class="mono">${esc(row.content_pack_id)}</td><td>${esc(String(row.encounter_count ?? '-'))}</td><td>${esc(row.risk_level || '-')}</td><td>${esc(row.acceptance_recommendation || '-')}</td><td>${esc(row.primary_action_hint || '-')}</td><td><button class="primary" data-pack="${rowKey}">查看详情</button></td><td><button data-copy-pack-id="${row.content_pack_id}">复制 ID</button></td></tr>`; }).join('') : `<tr><td colspan="10" class="muted">无匹配包</td></tr>`}</tbody></table></div></div>`;
  $('display-status-filter').value = statusFilter;
  $('display-profile-filter').value = profileFilter;
  $('display-template-filter').value = templateFilter;
  $('display-search').value = $('display-search') === document.activeElement ? $('display-search').value : state.displaySearch;
  $('display-status-filter').onchange = async (event) => { state.displayStatusFilter = event.target.value; await ensureDisplaySelection(); };
  $('display-profile-filter').onchange = async (event) => { state.displayProfileFilter = event.target.value; await ensureDisplaySelection(); };
  $('display-template-filter').onchange = async (event) => { state.displayTemplateFilter = event.target.value; await ensureDisplaySelection(); };
  $('display-search').oninput = async (event) => { state.displaySearch = event.target.value; await ensureDisplaySelection(); };
  $('display-reset').onclick = () => resetDisplayFilters();
  const reportsNode = $('reports-collapse');
  if (reportsNode) reportsNode.ontoggle = () => { state.reportsExpanded = reportsNode.open; };
  bindPackButtons($('display'));
  bindCopyButtons($('display'));
}
async function ensureDisplaySelection() {
  const packs = state.display?.packs || [];
  const search = (state.displaySearch || '').trim().toLowerCase();
  const filtered = packs.filter((row) => {
    if (state.displayStatusFilter === 'all') return true;
    if (state.displayStatusFilter === 'historical') return ['previous_current','archived','review'].includes(row.display_status);
    return row.display_status === state.displayStatusFilter;
  }).filter((row) => state.displayProfileFilter === 'all' ? true : String(row.mechanic_profile_id || '') === state.displayProfileFilter)
    .filter((row) => state.displayTemplateFilter === 'all' ? true : templateValue(row.sequence_template_id) === state.displayTemplateFilter)
    .filter((row) => {
      if (!search) return true;
      return [
        row.content_pack_id,
        row.mechanic_profile_id,
        row.sequence_template_id,
        row.display_status,
        row.display_badge,
      ].some((value) => String(value || '').toLowerCase().includes(search));
    });
  if (!filtered.length) {
    renderAll();
    return;
  }
  renderAll();
}
function bindPackButtons(root) { root.querySelectorAll('[data-pack]').forEach((b) => b.onclick = async (event) => { event.stopPropagation(); const [profileId, contentPackId] = b.dataset.pack.split('::'); await focusPack(profileId, contentPackId); }); }
function bindCopyButtons(root) { root.querySelectorAll('[data-copy-pack-id]').forEach((b) => b.onclick = async (event) => { event.stopPropagation(); await copyPackId(b.dataset.copyPackId); }); }
function adminButtonState(action, selected, detail, riskRow) {
  const adminEnabled = !!state.adminStatus?.admin_write_enabled;
  const status = String(selected?.display_status || '');
  const acceptance = detail.acceptance_group || {};
  const reviewPromotion = detail.review_promotion_group || {};
  const latestAction = state.adminStatus?.latest_admin_action || {};
  const isArchivedOrInvalid = ['archived', 'invalid'].includes(status);
  const sameLatestDryRun = latestAction.action === 'release_switch_dry_run'
    && latestAction.profile_id === selected?.mechanic_profile_id
    && latestAction.content_pack_id === selected?.content_pack_id
    && latestAction.result === 'ok';
  if (!selected) return { disabled: true, reason: '请选择包' };
  if (!adminEnabled) return { disabled: true, reason: '只读模式' };
  if (action === 'preview') return isArchivedOrInvalid ? { disabled: true, reason: status } : { disabled: false, reason: '' };
  if (action === 'preview_restore') return { disabled: false, reason: '' };
  if (action === 'acceptance') return isArchivedOrInvalid ? { disabled: true, reason: status } : { disabled: false, reason: '' };
  if (action === 'review_note') return isArchivedOrInvalid ? { disabled: true, reason: status } : { disabled: false, reason: '' };
  if (action === 'promote') {
    if (['current', 'previous_current', 'fallback', 'invalid', 'archived'].includes(status)) return { disabled: true, reason: '当前状态不可晋级' };
    if (!acceptance.acceptance_pass) return { disabled: true, reason: 'missing acceptance' };
    if (String(reviewPromotion.human_review_status || '') !== 'accepted') return { disabled: true, reason: 'missing accepted review' };
    if (status === 'needs_balance' || String(acceptance.recommendation || '') === 'needs_balance') return { disabled: true, reason: 'needs balance' };
    return { disabled: false, reason: '' };
  }
  if (action === 'dry_run_switch') {
    const enabled = status === 'release_candidate' || status === 'current';
    return enabled ? { disabled: false, reason: '' } : { disabled: true, reason: '仅 release_candidate / current 可用' };
  }
  if (action === 'set_current') {
    if (status === 'current') return { disabled: true, reason: '已是 current' };
    if (status !== 'release_candidate') return { disabled: true, reason: status === 'needs_balance' ? 'needs balance' : '非 release candidate' };
    if (!sameLatestDryRun) return { disabled: true, reason: '需要最近一次 dry-run 成功' };
    return { disabled: false, reason: '' };
  }
  if (action === 'rollback_previous') return { disabled: false, reason: '' };
  return { disabled: true, reason: 'unsupported' };
}
function defaultReviewStatus(selected, detail) {
  const status = String(selected?.display_status || '');
  if (status === 'needs_balance') return 'needs_balance';
  if (status === 'current') return 'accepted';
  const recommendation = String(detail.acceptance_group?.recommendation || '');
  return recommendation === 'ready_for_review' ? 'accepted' : 'pending';
}
function buildAdminPanel(selected, detail, riskRow) {
  const adminEnabled = !!state.adminStatus?.admin_write_enabled;
  const latestAction = state.adminStatus?.latest_admin_action || {};
  const previewActive = String(state.previewStatus?.preview_status || '') === 'active';
  const actionDefs = [
    ['preview', 'Preview'],
    ['preview_restore', 'Restore Preview'],
    ['acceptance', 'Run Acceptance'],
    ['review_note', 'Write Review Note'],
    ['promote', 'Promote Candidate'],
    ['dry_run_switch', 'Dry-run Switch'],
    ['set_current', 'Set Current'],
    ['rollback_previous', 'Rollback Previous Current'],
  ];
  const controls = actionDefs.map(([key, label]) => {
    const rule = adminButtonState(key, selected, detail, riskRow);
    const classes = [key === 'preview_restore' && previewActive ? 'primary' : '', state.adminActionRunning === key ? 'primary' : ''].filter(Boolean).join(' ');
    return `<button data-admin-action="${key}" class="${classes}" ${rule.disabled ? 'disabled' : ''} title="${esc(rule.reason || label)}">${esc(state.adminActionRunning === key ? 'running...' : label)}</button>${rule.reason ? `<span class="muted">${esc(rule.reason)}</span>` : ''}`;
  }).join('');
  const selectedLabel = selected ? `${selected.mechanic_profile_id} / ${selected.content_pack_id}` : '未选择包';
  return `<div id="admin-action-panel" class="band" style="margin-top:12px;"><h2>Admin Action Panel</h2><div class="toolbar"><span class="badge ${adminEnabled ? 'ok' : 'warning'}">${adminEnabled ? 'admin-write enabled' : '只读模式'}</span><span class="mono">${esc(selectedLabel)}</span><span class="badge ${state.adminStatus?.lock_available ? 'ok' : 'warning'}">${state.adminStatus?.lock_available ? 'lock available' : 'lock busy'}</span><span class="badge ${state.adminStatus?.active_profile_matches_current_release ? 'ok' : 'warning'}">${state.adminStatus?.active_profile_matches_current_release ? 'active=current' : 'active!=current'}</span></div><div class="muted" style="margin-top:8px;">${adminEnabled ? '所有写操作都通过 /api/admin/*，复用 CLI、串行锁和 audit log。' : '只读模式，使用 --admin-write 启动以启用管理操作。'}</div><div class="toolbar" style="margin-top:10px;">${controls}</div><div class="cards" style="margin-top:12px;"><div class="card"><div class="muted">Review Note</div><label class="muted" for="admin-review-status">status</label><select id="admin-review-status"><option value="accepted">accepted</option><option value="rejected">rejected</option><option value="needs_balance">needs_balance</option><option value="pending">pending</option></select><label class="muted" for="admin-review-note" style="margin-top:8px;display:block;">note</label><textarea id="admin-review-note" placeholder="dashboard admin note"></textarea></div><div class="card"><div class="muted">Latest Admin Action</div><div>action: ${esc(latestAction.action || '未执行')}</div><div>profile: ${esc(latestAction.profile_id || '-')}</div><div class="mono">pack: ${esc(latestAction.content_pack_id || '-')}</div><div>result: ${esc(latestAction.result || '-')}</div><div class="mono">report: ${esc(relPath(latestAction.report_path || ''))}</div></div></div>${state.adminActionMessage ? `<div class="badge ok" style="margin-top:10px;">${esc(state.adminActionMessage)}</div>` : ''}${state.adminActionError ? `<div class="badge fail" style="margin-top:10px;">${esc(state.adminActionError)}</div>` : ''}</div>`;
}
async function runAdminAction(action) {
  const selected = selectedPack();
  const payload = selectedAdminPayload();
  if (!selected) return;
  const mapping = {
    preview: ['/api/admin/preview/set', payload],
    preview_restore: ['/api/admin/preview/restore', {}],
    acceptance: ['/api/admin/acceptance/run', payload],
    review_note: ['/api/admin/review-note/write', { ...payload, status: $('admin-review-status')?.value || defaultReviewStatus(selected, state.packDetail?.dashboard_display_summary || {}), note: $('admin-review-note')?.value || 'dashboard admin action' }],
    promote: ['/api/admin/promotion/promote', payload],
    dry_run_switch: ['/api/admin/release-switch/dry-run', payload],
    set_current: ['/api/admin/release-switch/set-current', payload],
    rollback_previous: ['/api/admin/release-switch/rollback-previous-current', {}],
  };
  const item = mapping[action];
  if (!item) return;
  if (action === 'set_current' && !window.confirm('将此包设为 current release。继续？')) return;
  if (action === 'rollback_previous' && !window.confirm('将回滚到 previous current。继续？')) return;
  state.adminActionRunning = action;
  state.adminActionMessage = '';
  state.adminActionError = '';
  renderAll();
  try {
    const result = await postJson(item[0], item[1]);
    state.adminActionMessage = `${action} -> ${result.action || 'ok'}`;
    await refreshAfterAdminAction();
  } catch (error) {
    state.adminActionError = error.message || String(error);
    state.adminActionRunning = '';
    renderAll();
    return;
  }
  state.adminActionRunning = '';
  renderAll();
}
function bindAdminButtons(root) {
  root.querySelectorAll('[data-admin-action]').forEach((button) => {
    button.onclick = async (event) => {
      event.preventDefault();
      event.stopPropagation();
      await runAdminAction(button.dataset.adminAction);
    };
  });
  const reviewStatus = $('admin-review-status');
  if (reviewStatus) {
    reviewStatus.value = defaultReviewStatus(selectedPack(), state.packDetail?.dashboard_display_summary || {});
  }
}
function renderRuntime() {
  const hero = state.display?.current || {};
  const previous = (state.display?.packs || []).find((row) => row.display_status === 'previous_current') || {};
  const fallback = (state.display?.packs || []).find((row) => row.display_status === 'fallback') || {};
  $('runtime').innerHTML = `<div class="band"><h2>运行态</h2><div class="cards"><div class="card"><div class="muted">Current Release</div><div class="mono">${esc(hero.mechanic_profile_id || '-')}</div><div class="mono">${esc(hero.sequence_template_id || '-')}</div><div class="mono">${esc(hero.content_pack_id || '-')}</div><div>build_variant: ${esc(hero.build_variant || '-')}</div><div>encounter_count: ${esc(String(hero.encounter_count ?? '-'))}</div><div class="mono">${esc(relPath(hero.runtime_manifest_path || ''))}</div></div><div class="card"><div class="muted">Active / Fallback</div><div>active_profile_matches_current_release: ${esc(String(!!state.adminStatus?.active_profile_matches_current_release))}</div><div class="mono">fallback: ${esc(fallback.content_pack_id || '未生成 / 不适用')}</div><div class="mono">previous_current: ${esc(previous.content_pack_id || '未生成 / 不适用')}</div><div>fallback_release_unchanged: true</div></div><div class="card"><div class="muted">Landing / Closeout</div><div>release_landing_current: ${esc(String(hero.release_landing_status || hero.release_landing_current || 'pass'))}</div><div>fallback_loadout_count: ${esc(String(hero.fallback_loadout_count ?? '-'))}</div><div>reward_coverage_complete: ${esc(String(hero.reward_coverage_complete ?? false))}</div><div>last closeout: ${esc(state.display?.generated_at || '未知')}</div></div></div></div>`;
}
function renderPackDetail() {
  const detail = state.packDetail?.dashboard_display_summary || {};
  const selected = selectedPack();
  const identity = detail.identity_group || {};
  const runtime = detail.runtime_group || {};
  const acceptance = detail.acceptance_group || {};
  const reviewPromotion = detail.review_promotion_group || {};
  const release = detail.release_group || {};
  const reports = detail.reports_group || {};
  if (!state.selectedPackKey || !selectedPack()) {
    $('pack-detail').innerHTML = `<div class="band"><h2>Pack 详情</h2><div class="card"><div class="muted">请选择包</div><div>无匹配包</div></div></div>`;
    return;
  }
  $('pack-detail').innerHTML = `<div class="band"><h2>Pack 详情</h2><div class="toolbar"><span class="badge info">${esc(detail.display_badge || selected.display_badge || '未生成 / 不适用')}</span><span class="mono">${esc(identity.content_pack_id || selected.content_pack_id || '-')}</span><button data-copy-pack-id="${esc(identity.content_pack_id || selected.content_pack_id || '')}">复制 ID</button></div><div class="cards"><div class="card"><div class="muted">Identity</div><div class="mono">${esc(detailValue(identity.mechanic_profile_id))}</div><div class="mono">${esc(detailValue(identity.sequence_template_id))}</div><div class="mono">${esc(detailValue(identity.content_pack_id))}</div><div>${esc(detailValue(identity.build_variant))}</div><div class="mono">${esc(relPath(identity.runtime_manifest_path))}</div></div><div class="card"><div class="muted">Runtime</div><div>encounter_count: ${esc(String(detailValue(runtime.encounter_count)))}</div><div>generated_loadout_count: ${esc(String(detailValue(runtime.generated_loadout_count)))}</div><div>fallback_loadout_count: ${esc(String(detailValue(runtime.fallback_loadout_count)))}</div><div>reward_coverage_complete: ${esc(String(detailValue(runtime.reward_coverage_complete)))}</div><div>runtime_manifest_loaded: ${esc(String(detailValue(runtime.runtime_manifest_loaded)))}</div></div><div class="card"><div class="muted">Acceptance</div><div>acceptance_pass: ${esc(String(detailValue(acceptance.acceptance_pass)))}</div><div>risk_level: ${esc(detailValue(acceptance.risk_level))}</div><div>recommendation: ${esc(detailValue(acceptance.recommendation))}</div><div>win_rate: ${esc(String(detailValue(acceptance.win_rate)))}</div><div>avg_turn_count: ${esc(String(detailValue(acceptance.avg_turn_count)))}</div><div>too_hard: ${esc(String(detailValue(acceptance.too_hard)))} / too_long: ${esc(String(detailValue(acceptance.too_long)))} / reward_mismatch: ${esc(String(detailValue(acceptance.reward_mismatch)))}</div></div><div class="card"><div class="muted">Review / Promotion</div><div>human_review_status: ${esc(detailValue(reviewPromotion.human_review_status))}</div><div>promotion_allowed: ${esc(String(detailValue(reviewPromotion.promotion_allowed)))}</div><div>promoted_to_release_candidate: ${esc(String(detailValue(reviewPromotion.promoted_to_release_candidate)))}</div><div class="mono">${esc(relPath(reviewPromotion.promotion_report_path))}</div></div><div class="card"><div class="muted">Release</div><div>current_release_marker: ${esc(String(detailValue(release.current_release_marker)))}</div><div>previous_current_marker: ${esc(String(detailValue(release.previous_current_marker)))}</div><div>fallback_release_marker: ${esc(String(detailValue(release.fallback_release_marker)))}</div><div>release_landing_current: ${esc(String(detailValue(release.release_landing_current)))}</div><div>gameplay_entry_verified: ${esc(String(detailValue(release.gameplay_entry_verified)))}</div><div class="mono">${esc(relPath(release.release_switch_report_path))}</div></div><details id="reports-collapse" class="card"${state.reportsExpanded ? ' open' : ''}><summary><span class="muted">Reports</span></summary><div class="mono" style="margin-top:8px;">${esc(relPath(reports.validation_report))}</div><div class="mono">${esc(relPath(reports.acceptance_report))}</div><div class="mono">${esc(relPath(reports.promotion_report))}</div><div class="mono">${esc(relPath(reports.release_switch_report))}</div><div class="mono">${esc(relPath(reports.release_landing_report))}</div><div class="mono">${esc(relPath(reports.production_closeout_report))}</div></details></div></div>`;
  bindCopyButtons($('pack-detail'));
  const reportsNode = $('reports-collapse');
  if (reportsNode) reportsNode.ontoggle = () => { state.reportsExpanded = reportsNode.open; };
}
function renderPackContent() {
  const detail = state.packDetail || {};
  const sequenceRows = detail.sequence_detail || [];
  const encounterRows = state.activeReview?.encounter_review_table || [];
  const deckRows = state.activeReview?.deck_review_table || [];
  const rewardRows = state.activeReview?.reward_review_table || [];
  const cardPoolSummary = detail.card_pool_summary || {};
  const cardPoolRows = detail.card_pool_detail || state.activeReview?.card_pool_review_table || [];
  const runtimeSummary = detail.dashboard_display_summary?.runtime_group || {};
  const expectedEncounterCount = Number(detail.formal_encounter_total_count || runtimeSummary.encounter_count || sequenceRows.length || 0);
  const fallbackLoadoutCount = Number(runtimeSummary.fallback_loadout_count || 0);
  if (!state.selectedPackKey || !selectedPack()) {
    $('pack-content').innerHTML = `<div class="band"><h2>Pack 内容</h2><div class="card"><div class="muted">请选择包</div><div>无匹配包</div></div></div>`;
    return;
  }
  const selectedEncounter = encounterRows.find((row) => String(row.formal_encounter_id || row.generated_battle_slot_id || row.sequence_position) === String(state.selectedEncounterKey))
    || encounterRows[0]
    || null;
  if (selectedEncounter && !state.selectedEncounterKey) {
    state.selectedEncounterKey = String(selectedEncounter.formal_encounter_id || selectedEncounter.generated_battle_slot_id || selectedEncounter.sequence_position);
  }
  const selectedDeck = selectedEncounter ? deckRows.find((row) => row.deck_id === selectedEncounter.generated_deck_id) : null;
  const selectedReward = selectedEncounter ? rewardRows.find((row) => row.reward_plan_id === selectedEncounter.reward_plan_id) : null;
  const brokenDeckRef = !!selectedEncounter && !selectedDeck;
  const brokenRewardRef = !!selectedEncounter && !selectedReward;
  const weaponOptions = [...new Set(cardPoolRows.map((row) => String(row.weapon_style || '')).filter(Boolean))].sort();
  const cardTypeOptions = [...new Set(cardPoolRows.map((row) => String(row.card_type || '')).filter(Boolean))].sort();
  const difficultyOptions = [...new Set(cardPoolRows.map((row) => String(row.difficulty_tier || '')).filter(Boolean))].sort();
  const realmOptions = [...new Set(cardPoolRows.map((row) => String(row.realm_requirement_label || row.required_wujing || '')).filter(Boolean))].sort();
  const filteredCards = cardPoolRows.filter((row) => state.contentWeaponFilter === 'all' ? true : String(row.weapon_style || '') === state.contentWeaponFilter)
    .filter((row) => state.contentCardTypeFilter === 'all' ? true : String(row.card_type || '') === state.contentCardTypeFilter)
    .filter((row) => state.contentDifficultyFilter === 'all' ? true : String(row.difficulty_tier || '') === state.contentDifficultyFilter)
    .filter((row) => state.contentRealmFilter === 'all' ? true : String(row.realm_requirement_label || row.required_wujing || '') === state.contentRealmFilter)
    .filter((row) => {
      if (state.contentUsageFilter === 'all') return true;
      if (state.contentUsageFilter === 'unused') return !!row.is_unused;
      if (state.contentUsageFilter === 'orphan') return !!row.is_orphan;
      if (state.contentUsageFilter === 'used') return !row.is_unused;
      return true;
    });
  const rewardTypeCounts = rewardRows.reduce((acc, row) => { const k = String(row.reward_type || 'unknown'); acc[k] = (acc[k] || 0) + 1; return acc; }, {});
  const rewardTierCounts = rewardRows.reduce((acc, row) => { const k = String(row.reward_tier || 'unknown'); acc[k] = (acc[k] || 0) + 1; return acc; }, {});
  const brokenRewardCount = rewardRows.filter((row) => !row.reward_plan_id).length + (brokenRewardRef ? 1 : 0);
  $('pack-content').innerHTML = `<div class="band"><h2>Pack 内容</h2><div class="cards"><div class="card"><div class="muted">Selected Pack Identity</div><div class="mono">${esc(detail.mechanic_profile_id || '未生成 / 不适用')}</div><div class="mono">${esc(detail.sequence_template_id || '未生成 / 不适用')}</div><div class="mono">${esc(detail.content_pack_id || '未生成 / 不适用')}</div><div>build_variant: ${esc(detail.build_variant || '未生成 / 不适用')}</div><div>encounter_count: ${esc(String(expectedEncounterCount))}</div><div>card_pool_count: ${esc(String(detail.card_count || cardPoolRows.length || 0))}</div><div>deck_count: ${esc(String(detail.deck_count || deckRows.length || 0))}</div><div>reward_plan_count: ${esc(String(detail.reward_count || rewardRows.length || 0))}</div></div></div><div class="dual" style="margin-top:12px;"><div class="band"><h2>战斗序列 Sequence</h2><div class="muted">generated_loadout_count=${esc(String(sequenceRows.length))} · expected_encounter_count=${esc(String(expectedEncounterCount))} · fallback_loadout_count=${esc(String(fallbackLoadoutCount))}</div><div class="table"><table><thead><tr><th>#</th><th>Encounter</th><th>Battle Slot</th><th>Tier</th><th>Stage</th><th>Enemy</th><th>Enemy Deck</th><th>Reward</th><th>Runtime</th><th>Loadout</th><th>Fallback</th></tr></thead><tbody>${sequenceRows.length ? sequenceRows.map((row) => { const key = String(row.formal_encounter_id || row.generated_battle_slot_id || row.sequence_position); const encounterRef = encounterRows.find((item) => String(item.formal_encounter_id || item.generated_battle_slot_id || item.sequence_position) === key) || {}; const selectedClass = key === String(state.selectedEncounterKey || '') ? 'is-selected' : ''; const fallbackUsed = Boolean(encounterRef.fallback_used || row.fallback_used || false); return `<tr class="pack-row ${selectedClass}" data-encounter-key="${esc(key)}" aria-selected="${selectedClass ? 'true' : 'false'}" title="点击查看此战斗详情"><td>${esc(String(row.sequence_position || '-'))}</td><td class="mono">${esc(row.formal_encounter_id || '未生成 / 不适用')}</td><td class="mono">${esc(row.generated_battle_slot_id || '未生成 / 不适用')}</td><td>${esc(row.encounter_tier || encounterRef.difficulty_tier || '未生成 / 不适用')}</td><td>${esc(row.stage || row.stage_index || '未生成 / 不适用')}</td><td>${esc(encounterRef.enemy_role || row.encounter_kind || '未生成 / 不适用')}</td><td class="mono">${esc(row.generated_deck_id || '未生成 / 不适用')}</td><td class="mono">${esc(row.reward_plan_id || '未生成 / 不适用')}</td><td>${esc(join(row.runtime_primitives))}</td><td>${esc(row.power_range_pass ? 'generated' : 'review')}</td><td>${esc(String(fallbackUsed))}</td></tr>`; }).join('') : `<tr><td colspan="11" class="muted">未生成 / 不适用</td></tr>`}</tbody></table></div></div><div class="band"><h2>每场战斗 Encounter Detail</h2>${selectedEncounter ? `<div class="cards"><div class="card"><div class="muted">Battle Identity</div><div class="mono">${esc(selectedEncounter.formal_encounter_id || '未生成 / 不适用')}</div><div class="mono">${esc(selectedEncounter.generated_battle_slot_id || '未生成 / 不适用')}</div><div>${esc(selectedEncounter.enemy_role || '未生成 / 不适用')}</div><div class="mono">enemy_deck_id: ${esc(selectedEncounter.generated_deck_id || '未生成 / 不适用')}</div><div class="mono">reward_plan_id: ${esc(selectedEncounter.reward_plan_id || '未生成 / 不适用')}</div><div>difficulty_tier: ${esc(selectedEncounter.difficulty_tier || selectedEncounter.encounter_tier || '未生成 / 不适用')}</div><div>sequence_template_id: ${esc(detail.sequence_template_id || '未生成 / 不适用')}</div></div><div class="card"><div class="muted">Enemy Deck</div><div class="mono">deck_id: ${esc(selectedDeck?.deck_id || selectedEncounter.generated_deck_id || '未生成 / 不适用')}</div><div>card_count: ${esc(String(selectedDeck?.card_count || selectedEncounter.deck_cards?.length || 0))}</div><div>broken_ref: ${esc(String(brokenDeckRef))}</div><div class="table" style="margin-top:8px;"><table><thead><tr><th>Card</th><th>Type</th><th>Style</th><th>Realm</th><th>Cost</th><th>Power</th><th>Tags</th></tr></thead><tbody>${(selectedDeck?.cards || selectedEncounter.deck_cards || []).length ? (selectedDeck?.cards || selectedEncounter.deck_cards || []).map((card) => `<tr><td><div class="mono">${esc(card.card_id || '-')}</div><div>${esc(card.name || '-')}</div></td><td>${esc(card.card_type || '-')}</td><td>${esc(card.weapon_style || '-')}</td><td>${esc(String(card.required_wujing ?? card.realm_requirement_label ?? '-'))}</td><td>${esc(String(card.cost ?? '-'))}</td><td>${esc(String(card.power_score ?? '-'))}</td><td>${esc(join(card.tags || card.effects_text || '-'))}</td></tr>`).join('') : `<tr><td colspan="7" class="muted">未生成 / 不适用</td></tr>`}</tbody></table></div></div><div class="card"><div class="muted">Reward</div><div class="mono">reward_plan_id: ${esc(selectedReward?.reward_plan_id || selectedEncounter.reward_plan_id || '未生成 / 不适用')}</div><div>reward_type: ${esc(selectedReward?.reward_type || '未生成 / 不适用')}</div><div>reward_tier: ${esc(selectedReward?.reward_tier || '未生成 / 不适用')}</div><div>reward_source: ${esc(join(selectedReward?.used_by_battle_slots || selectedReward?.matched_encounter_tier || []))}</div><div>broken_ref: ${esc(String(brokenRewardRef))}</div><div style="margin-top:8px;">${esc(selectedReward?.reward_items_text || '未生成 / 不适用')}</div></div></div>` : `<div class="card"><div class="muted">请选择战斗</div><div>未生成 / 不适用</div></div>`}</div></div><div class="band" style="margin-top:12px;"><h2>总卡池 Card Pool</h2><div class="cards"><div class="card"><div class="muted">摘要</div><div>total_card_count: ${esc(String(detail.card_count || cardPoolRows.length || 0))}</div><div>used_card_count: ${esc(String(cardPoolSummary.used_card_count ?? '未生成 / 不适用'))}</div><div>unused_card_count: ${esc(String(cardPoolSummary.unused_card_count ?? '未生成 / 不适用'))}</div><div>orphan_card_count: ${esc(String(cardPoolSummary.orphan_card_count ?? '未生成 / 不适用'))}</div><div>by_weapon_style: ${esc(JSON.stringify(cardPoolSummary.weapon_style_counts || {}))}</div><div>by_card_type: ${esc(JSON.stringify(cardPoolSummary.card_type_counts || {}))}</div><div>by_difficulty_tier: ${esc(JSON.stringify(cardPoolSummary.difficulty_tier_counts || {}))}</div><div>by_realm_requirement: ${esc(JSON.stringify(cardPoolSummary.realm_requirement_counts || {}))}</div></div></div><div class="toolbar"><select id="content-weapon-filter"><option value="all">weapon_style: all</option>${weaponOptions.map((value) => `<option value="${esc(value)}">${esc(value)}</option>`).join('')}</select><select id="content-card-type-filter"><option value="all">card_type: all</option>${cardTypeOptions.map((value) => `<option value="${esc(value)}">${esc(value)}</option>`).join('')}</select><select id="content-difficulty-filter"><option value="all">difficulty: all</option>${difficultyOptions.map((value) => `<option value="${esc(value)}">${esc(value)}</option>`).join('')}</select><select id="content-realm-filter"><option value="all">realm: all</option>${realmOptions.map((value) => `<option value="${esc(value)}">${esc(value)}</option>`).join('')}</select><select id="content-usage-filter"><option value="all">usage: all</option><option value="used">used</option><option value="unused">unused</option><option value="orphan">orphan</option></select></div><div class="table"><table><thead><tr><th>Card</th><th>Type</th><th>Style</th><th>Difficulty</th><th>Realm</th><th>Deck Usage</th><th>Reward Usage</th><th>Unused</th><th>Orphan</th><th>Tags / Effect</th></tr></thead><tbody>${filteredCards.length ? filteredCards.map((row) => `<tr><td><div class="mono">${esc(row.card_id || '-')}</div><div>${esc(row.name || '-')}</div></td><td>${esc(row.card_type || '-')}</td><td>${esc(row.weapon_style || '-')}</td><td>${esc(row.difficulty_tier || '-')}</td><td>${esc(row.realm_requirement_label || String(row.required_wujing ?? '-'))}</td><td>${esc(String(row.used_in_deck_count ?? row.usage_count ?? '-'))}</td><td>${esc(String(row.used_in_reward_count ?? 0))}</td><td>${esc(String(!!row.is_unused))}</td><td>${esc(String(!!row.is_orphan))}</td><td>${esc(join(row.tags || row.effects_text || row.effect_types || '-'))}</td></tr>`).join('') : `<tr><td colspan="10" class="muted">该 pack 缺少卡池明细</td></tr>`}</tbody></table></div></div><div class="band" style="margin-top:12px;"><h2>奖励 Reward Plans</h2><div class="cards"><div class="card"><div class="muted">摘要</div><div>reward_plan_count: ${esc(String(detail.reward_count || rewardRows.length || 0))}</div><div>reward_type_counts: ${esc(JSON.stringify(rewardTypeCounts))}</div><div>reward_tier_counts: ${esc(JSON.stringify(rewardTierCounts))}</div><div>broken_reward_ref_count: ${esc(String(brokenRewardCount))}</div></div></div><div class="table"><table><thead><tr><th>Reward Plan</th><th>Encounter / Slot</th><th>Type</th><th>Tier</th><th>Card Rewards</th><th>Currency</th><th>Source</th><th>Broken</th></tr></thead><tbody>${rewardRows.length ? rewardRows.map((row) => { const linkedEncounter = encounterRows.find((enc) => enc.reward_plan_id === row.reward_plan_id) || {}; return `<tr class="${selectedEncounter?.reward_plan_id === row.reward_plan_id ? 'active' : ''}"><td class="mono">${esc(row.reward_plan_id || '-')}</td><td><div class="mono">${esc(linkedEncounter.formal_encounter_id || '-')}</div><div class="mono">${esc(linkedEncounter.generated_battle_slot_id || '-')}</div></td><td>${esc(row.reward_type || '-')}</td><td>${esc(row.reward_tier || '-')}</td><td>${esc(row.reward_items_text || '-')}</td><td>${esc('-')}</td><td>${esc(join(row.used_by_battle_slots || row.matched_encounter_tier || []))}</td><td>${esc(String(!row.reward_plan_id))}</td></tr>`; }).join('') : `<tr><td colspan="8" class="muted">未生成 / 不适用</td></tr>`}</tbody></table></div></div>`;
  const root = $('pack-content');
  const encounterNodes = root.querySelectorAll('[data-encounter-key]');
  encounterNodes.forEach((row) => {
    row.onclick = () => {
      state.selectedEncounterKey = row.dataset.encounterKey;
      renderPackContent();
    };
  });
  [['content-weapon-filter','contentWeaponFilter'],['content-card-type-filter','contentCardTypeFilter'],['content-difficulty-filter','contentDifficultyFilter'],['content-realm-filter','contentRealmFilter'],['content-usage-filter','contentUsageFilter']].forEach(([id,key]) => {
    const node = $(id);
    if (!node) return;
    node.value = state[key];
    node.onchange = (event) => {
      state[key] = event.target.value;
      renderPackContent();
    };
  });
}
function renderTimelineRisk() {
  const detail = state.packDetail?.dashboard_display_summary || {};
  const timeline = detail.production_timeline || [];
  const riskRows = state.display?.risk_board || [];
  const selectedId = detail.identity_group?.content_pack_id || selectedPack()?.content_pack_id || '';
  $('timeline-risk').innerHTML = `<div class="band"><h2>时间线与风险</h2><div class="table"><table><thead><tr><th>Stage</th><th>Status</th><th>Reason</th></tr></thead><tbody>${timeline.length ? timeline.map((row) => `<tr><td>${esc(row.stage)}</td><td>${esc(row.status)}</td><td>${esc(row.reason)}</td></tr>`).join('') : `<tr><td colspan="3" class="muted">未生成 / 不适用</td></tr>`}</tbody></table></div><div class="table" style="margin-top:12px;"><table><thead><tr><th>Pack</th><th>Status</th><th>Risk</th><th>Warning</th><th>Blocking</th><th>Next</th></tr></thead><tbody>${riskRows.length ? riskRows.map((row) => `<tr class="${row.pack_id === selectedId ? 'active' : ''}"><td class="mono">${esc(row.pack_id)}</td><td>${esc(row.display_status)}</td><td>${esc(row.risk_level)}</td><td>${esc(join(row.warning_reasons))}</td><td>${esc(join(row.blocking_reasons))}</td><td>${esc(row.next_recommended_step || '-')}</td></tr>`).join('') : `<tr><td colspan="6" class="muted">未生成 / 不适用</td></tr>`}</tbody></table></div></div>`;
}
function renderAdminActions() {
  const detail = state.packDetail?.dashboard_display_summary || {};
  const riskRows = state.display?.risk_board || [];
  const selected = selectedPack();
  const selectedRiskRow = riskRows.find((row) => row.pack_id === (selected?.content_pack_id || '')) || {};
  $('admin-actions').innerHTML = buildAdminPanel(selected, detail, selectedRiskRow);
  bindAdminButtons($('admin-actions'));
}
function renderAll() { renderHeader(); renderDisplay(); renderRuntime(); renderPackDetail(); renderPackContent(); renderTimelineRisk(); renderAdminActions(); }
(async function init() { makeTabs(); await bootstrap(); renderAll(); })();
</script>
</body>
</html>"""


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
