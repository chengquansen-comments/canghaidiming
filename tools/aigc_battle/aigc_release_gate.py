#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import build_aigc_detail_views as detail_lib
from tools.aigc_battle import build_aigc_review_workspace as review_lib
from tools.aigc_battle import load_sequence_template as template_lib
from tools.aigc_battle import switch_active_profile as switch_lib

RELEASE_DIR = ROOT / 'data' / 'aigc_battle' / 'release'
RELEASE_CHANNELS_DIR = ROOT / 'data' / 'aigc_battle' / 'release_channels'
REVIEW_NOTES_DIR = ROOT / 'data' / 'aigc_battle' / 'review_notes'
DETAILS_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'details'
RELEASE_SMOKE_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'release_smoke'
BALANCE_RELEASE_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'balance_release'
PLAYABLE_HARDENING_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'playable_hardening'
RUNTIME_DIR = ROOT / 'data' / 'aigc_battle' / 'runtime'
PACK_RESOLVER_PATH = ROOT / 'data' / 'aigc_battle' / 'pack_resolver.json'

DEFAULT_CURRENT_PROFILE_ID = 'weapon_followup_v0_1'
DEFAULT_CURRENT_PACK_ID = 'weapon_followup_v0_1_formal_sequence_pack_001'
DEFAULT_FALLBACK_PROFILE_ID = 'posture_opening_pressure_v0_1'
DEFAULT_FALLBACK_PACK_ID = 'posture_opening_pressure_v0_1_formal_sequence_pack_001'


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description='aigc release gate')
    sub = parser.add_subparsers(dest='command', required=True)
    for name in [
        'freeze',
        'mark-release-candidate',
        'archive',
        'report',
        'status',
        'activate-release-candidate',
        'suggest-git-commands',
    ]:
        sp = sub.add_parser(name)
        sp.add_argument('--profile', required=True)
        sp.add_argument('--pack', required=True)
    set_status = sub.add_parser('set-status')
    set_status.add_argument('--profile', required=True)
    set_status.add_argument('--pack', required=True)
    set_status.add_argument('--status', required=True)
    sub.add_parser('rollback-release')
    sub.add_parser('compare-release-candidates')

    for name in ['set-current', 'set-candidate', 'set-fallback']:
        sp = sub.add_parser(name)
        sp.add_argument('--profile', required=True)
        sp.add_argument('--pack', required=True)
    sub.add_parser('activate-current')
    sub.add_parser('rollback-to-fallback')
    sub.add_parser('show-channels')

    args = parser.parse_args(argv[1:])
    ensure_default_release_channels()
    if args.command == 'freeze':
        payload = freeze_pack(args.profile, args.pack)
    elif args.command == 'set-status':
        payload = set_release_status(args.profile, args.pack, args.status)
    elif args.command == 'mark-release-candidate':
        payload = mark_release_candidate(args.profile, args.pack)
    elif args.command == 'activate-release-candidate':
        payload = activate_release_candidate(args.profile, args.pack)
    elif args.command == 'rollback-release':
        payload = rollback_release()
    elif args.command == 'archive':
        payload = archive_pack(args.profile, args.pack)
    elif args.command == 'report':
        payload = generate_release_report(args.profile, args.pack)
    elif args.command == 'compare-release-candidates':
        payload = compare_release_candidates()
    elif args.command == 'suggest-git-commands':
        payload = suggest_git_commands(args.profile, args.pack)
    elif args.command == 'set-current':
        payload = set_release_channel('current', args.profile, args.pack)
    elif args.command == 'set-candidate':
        payload = set_release_channel('candidate', args.profile, args.pack)
    elif args.command == 'set-fallback':
        payload = set_release_channel('fallback', args.profile, args.pack)
    elif args.command == 'activate-current':
        payload = activate_current_release()
    elif args.command == 'rollback-to-fallback':
        payload = rollback_to_fallback()
    elif args.command == 'show-channels':
        payload = show_channels()
    else:
        payload = get_release_status(args.profile, args.pack)
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0


def set_release_status(profile_id: str, content_pack_id: str, status: str) -> dict[str, Any]:
    allowed = {'draft', 'reviewing', 'accepted', 'rejected', 'release_candidate', 'active', 'archived'}
    if status not in allowed:
        raise SystemExit('invalid release status')
    if status == 'accepted':
        ensure_balance_release_gate(profile_id, content_pack_id)
    manifest = get_release_status(profile_id, content_pack_id)
    manifest['release_status'] = status
    manifest['updated_at'] = now_iso()
    write_json(release_manifest_path(profile_id, content_pack_id), manifest)
    return manifest


def freeze_pack(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    switch_lib.ensure_safe_id(profile_id, 'profile_id')
    switch_lib.ensure_safe_id(content_pack_id, 'content_pack_id')
    detail = load_pack_detail(profile_id, content_pack_id)
    notes = load_review_notes(profile_id, content_pack_id)
    validation = detail.get('validation_summary', {})
    checks = [
        ('ready_for_runtime_export', bool(validation.get('ready_for_runtime_export', False))),
        ('full_sequence_coverage_complete', bool(validation.get('full_sequence_coverage_complete', False))),
        ('runtime_export_allowed', bool(validation.get('runtime_export_allowed', False))),
        ('sequence_balance_pass', bool(validation.get('sequence_balance_pass', False))),
    ]
    for optional in ['deck_card_realm_eligibility_valid', 'no_card_above_player_wujing_in_deck']:
        if optional in validation:
            checks.append((optional, bool(validation.get(optional, False))))
    ensure_balance_release_gate(profile_id, content_pack_id)
    failed = [name for name, passed in checks if not passed]
    if failed:
        raise SystemExit(f'freeze blocked: {", ".join(failed)}')
    if notes.get('review_status') == 'rejected':
        raise SystemExit('freeze blocked: review_status rejected')
    manifest = build_release_manifest(profile_id, content_pack_id)
    manifest['frozen'] = True
    manifest['frozen_at'] = now_iso()
    manifest['review_status'] = notes.get('review_status', 'pending')
    manifest['release_status'] = 'accepted' if notes.get('review_status') == 'accepted' else 'reviewing'
    manifest['rollback_available'] = False
    manifest['updated_at'] = now_iso()
    manifest.update(suggest_git_commands(profile_id, content_pack_id))
    write_json(release_manifest_path(profile_id, content_pack_id), manifest)
    return manifest


def mark_release_candidate(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    ensure_balance_release_gate(profile_id, content_pack_id)
    ensure_playable_hardening_gate(profile_id, content_pack_id)
    manifest = get_release_status(profile_id, content_pack_id)
    if not manifest.get('frozen', False):
        raise SystemExit('mark release candidate blocked: pack is not frozen')
    manifest['release_status'] = 'release_candidate'
    manifest['release_candidate_id'] = f'{profile_id}__{content_pack_id}'
    manifest['playable_mechanic_candidate'] = bool(manifest.get('ready_for_runtime_export', False))
    manifest['updated_at'] = now_iso()
    write_json(release_manifest_path(profile_id, content_pack_id), manifest)
    return manifest


def activate_release_candidate(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    manifest = get_release_status(profile_id, content_pack_id)
    if manifest.get('release_status') != 'release_candidate':
        raise SystemExit('activate blocked: pack is not release_candidate')
    if not manifest.get('frozen', False):
        raise SystemExit('activate blocked: pack is not frozen')
    if str(manifest.get('review_status', 'pending')) != 'accepted':
        raise SystemExit('activate blocked: review_status is not accepted')
    previous_active = read_active_profile()
    summary = switch_lib.switch_active_profile(profile_id, content_pack_id, switch_source='release_activation')
    manifest['release_status'] = 'active'
    manifest['activated_at'] = now_iso()
    manifest['previous_active_profile_id'] = str(previous_active.get('active_mechanic_profile_id', ''))
    manifest['previous_active_content_pack_id'] = str(previous_active.get('active_content_pack_id', ''))
    manifest['rollback_available'] = True
    manifest['updated_at'] = now_iso()
    write_json(release_manifest_path(profile_id, content_pack_id), manifest)
    if manifest['previous_active_profile_id'] and manifest['previous_active_content_pack_id']:
        previous_manifest = get_release_status(manifest['previous_active_profile_id'], manifest['previous_active_content_pack_id'])
        if previous_manifest.get('content_pack_id') != content_pack_id or previous_manifest.get('mechanic_profile_id') != profile_id:
            previous_manifest['release_status'] = 'archived'
            previous_manifest['archived_at'] = now_iso()
            previous_manifest['updated_at'] = now_iso()
            write_json(release_manifest_path(previous_manifest['mechanic_profile_id'], previous_manifest['content_pack_id']), previous_manifest)
    return {'ok': True, 'summary': summary, 'manifest': manifest}


def rollback_release() -> dict[str, Any]:
    previous_active = read_active_profile()
    result = switch_lib.rollback_active_profile(switch_source='release_rollback')
    current_manifest = get_release_status(str(previous_active.get('active_mechanic_profile_id', '')), str(previous_active.get('active_content_pack_id', '')))
    current_manifest['release_status'] = 'release_candidate'
    current_manifest['rollback_available'] = False
    current_manifest['updated_at'] = now_iso()
    write_json(release_manifest_path(current_manifest['mechanic_profile_id'], current_manifest['content_pack_id']), current_manifest)
    restored_manifest = get_release_status(result['rolled_back_to_profile_id'], result['rolled_back_to_content_pack_id'])
    restored_manifest['release_status'] = 'active'
    restored_manifest['updated_at'] = now_iso()
    write_json(release_manifest_path(restored_manifest['mechanic_profile_id'], restored_manifest['content_pack_id']), restored_manifest)
    return {'ok': True, **result}


def archive_pack(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    manifest = get_release_status(profile_id, content_pack_id)
    manifest['release_status'] = 'archived'
    manifest['archived_at'] = now_iso()
    manifest['updated_at'] = now_iso()
    write_json(release_manifest_path(profile_id, content_pack_id), manifest)
    return manifest


def generate_release_report(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    manifest = get_release_status(profile_id, content_pack_id)
    notes = load_review_notes(profile_id, content_pack_id)
    detail = load_pack_detail(profile_id, content_pack_id)
    review_report_path = review_lib.review_report_md_path(profile_id, content_pack_id)
    report_path = release_report_path(profile_id, content_pack_id)
    lines = [
        f'# 发布报告：{profile_id} / {content_pack_id}',
        '',
        '## 基本信息',
        f"- release_status: `{manifest['release_status']}`",
        f"- frozen: `{manifest['frozen']}`",
        f"- review_status: `{notes.get('review_status', 'pending')}`",
        f"- runtime_manifest_path: `{manifest['runtime_manifest_path']}`",
        '',
        '## 校验状态',
        f"- ready_for_runtime_export: `{detail.get('validation_summary', {}).get('ready_for_runtime_export', False)}`",
        f"- full_sequence_coverage_complete: `{detail.get('validation_summary', {}).get('full_sequence_coverage_complete', False)}`",
        f"- runtime_export_allowed: `{detail.get('validation_summary', {}).get('runtime_export_allowed', False)}`",
        f"- sequence_balance_pass: `{detail.get('validation_summary', {}).get('sequence_balance_pass', False)}`",
        '',
        '## 审核摘要',
        f"- reviewer: `{notes.get('reviewer', '')}`",
        f"- summary: {notes.get('summary', '') or '-'}",
        f"- recommended_action: `{notes.get('recommended_action', '')}`",
        '',
        '## 参考路径',
        f"- review_notes_path: `{manifest['review_notes_path']}`",
        f"- review_report_path: `{manifest['review_report_path']}`",
        f"- release_manifest_path: `{to_relative(release_manifest_path(profile_id, content_pack_id))}`",
    ]
    report_path.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    manifest['release_report_path'] = to_relative(report_path)
    manifest['updated_at'] = now_iso()
    manifest.update(suggest_git_commands(profile_id, content_pack_id))
    write_json(release_manifest_path(profile_id, content_pack_id), manifest)
    return {'ok': True, 'release_report_path': manifest['release_report_path'], 'release_manifest_path': to_relative(release_manifest_path(profile_id, content_pack_id)), 'review_report_exists': review_report_path.exists()}


def get_release_status(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    switch_lib.ensure_safe_id(profile_id, 'profile_id')
    switch_lib.ensure_safe_id(content_pack_id, 'content_pack_id')
    path = release_manifest_path(profile_id, content_pack_id)
    if path.exists():
        return read_json(path)
    manifest = build_release_manifest(profile_id, content_pack_id)
    write_json(path, manifest)
    return manifest


def build_release_manifest(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    detail = load_pack_detail(profile_id, content_pack_id)
    notes = load_review_notes(profile_id, content_pack_id)
    report_path = review_lib.review_report_md_path(profile_id, content_pack_id)
    switch_summary = switch_lib.validate_profile_ready(profile_id, content_pack_id)
    is_active = active_profile_matches(profile_id, content_pack_id)
    suggestions = build_git_suggestions(profile_id, content_pack_id)
    pack_summary = detail.get('content_pack_summary', {}) if isinstance(detail.get('content_pack_summary', {}), dict) else {}
    sequence_template_id = str(
        pack_summary.get('sequence_template_id')
        or detail.get('sequence_template_id', '')
        or template_lib.infer_sequence_template_id(pack_summary, {})
    )
    build_variant = template_lib.resolve_build_variant(
        pack_summary.get('build_variant') or detail.get('build_variant', ''),
        profile_id,
        content_pack_id,
    )
    pack_identity = template_lib.build_pack_identity(sequence_template_id, profile_id, build_variant, content_pack_id)
    balance_report = load_balance_release_evaluation_report(profile_id, content_pack_id)
    hardening_report = load_playable_hardening_evaluation_report(profile_id, content_pack_id)
    hardening_smoke = load_playable_hardening_smoke_report(profile_id, content_pack_id)
    return {
        'mechanic_profile_id': profile_id,
        'content_pack_id': content_pack_id,
        'sequence_template_id': sequence_template_id,
        'build_variant': build_variant,
        'pack_identity': pack_identity,
        'release_status': 'active' if is_active else 'draft',
        'frozen': False,
        'frozen_at': '',
        'activated_at': '',
        'archived_at': '',
        'review_status': notes.get('review_status', 'pending'),
        'release_candidate_id': '',
        'previous_active_profile_id': '',
        'previous_active_content_pack_id': '',
        'rollback_available': False,
        'review_notes_path': to_relative(review_notes_path(profile_id, content_pack_id)),
        'runtime_manifest_path': str(switch_summary.get('runtime_manifest_path', '')),
        'validation_report_path': str(switch_summary.get('validation_report_path', '')),
        'review_report_path': to_relative(report_path),
        'release_report_path': to_relative(release_report_path(profile_id, content_pack_id)) if release_report_path(profile_id, content_pack_id).exists() else '',
        'suggested_git_commit_command': suggestions['suggested_git_commit_command'],
        'suggested_git_tag_command': suggestions['suggested_git_tag_command'],
        'detail_path': to_relative(detail_lib.detail_pack_json_path(profile_id, content_pack_id)),
        'created_at': now_iso(),
        'updated_at': now_iso(),
        'ready_for_runtime_export': bool(detail.get('validation_summary', {}).get('ready_for_runtime_export', False)),
        'full_sequence_coverage_complete': bool(detail.get('validation_summary', {}).get('full_sequence_coverage_complete', False)),
        'runtime_export_allowed': bool(detail.get('validation_summary', {}).get('runtime_export_allowed', False)),
        'sequence_balance_pass': bool(detail.get('validation_summary', {}).get('sequence_balance_pass', False)),
        'mechanic_difference_summary': build_mechanic_difference_summary(detail),
        'runtime_primitive_summary': detail.get('runtime_primitive_summary', {}),
        'max_wujing': int(detail.get('runtime_primitive_summary', {}).get('max_wujing', 0) or detail.get('validation_summary', {}).get('max_wujing', 0) or 0),
        'dual_weapon_enabled': 'dual_weapon' in detail.get('runtime_primitive_summary', {}).get('runtime_primitives', []) or bool(detail.get('runtime_primitive_summary', {}).get('dual_weapon_declared', False)),
        'clue_pressure_enabled': 'clue_pressure' in detail.get('runtime_primitive_summary', {}).get('runtime_primitives', []) or bool(detail.get('runtime_primitive_summary', {}).get('clue_pressure_declared', False)),
        'playable_mechanic_candidate': bool(detail.get('validation_summary', {}).get('ready_for_runtime_export', False)),
        'balance_release': bool(pack_summary.get('balance_release', False)),
        'source_pack_id': str(pack_summary.get('source_pack_id', '')),
        'balance_evaluation_report_path': balance_report.get('report_path', ''),
        'playable_balance_gate_pass': bool(balance_report.get('playable_balance_gate_pass', False)),
        'source_win_rate': float(balance_report.get('source_win_rate', 0) or 0),
        'balanced_win_rate': float(balance_report.get('balanced_win_rate', 0) or 0),
        'too_hard_candidates_reduced': bool(balance_report.get('too_hard_candidates_reduced', False)),
        'activated_as_current_release': is_active and bool(pack_summary.get('balance_release', False)),
        'playable_hardening': bool(pack_summary.get('playable_hardening', False)),
        'hardening_target': str(pack_summary.get('hardening_target', '')),
        'source_matrix_pack_id': str(pack_summary.get('source_matrix_pack_id', '')),
        'hardening_evaluation_report_path': hardening_report.get('report_path', ''),
        'target_gate_pass': bool(hardening_report.get('target_gate_pass', False)),
        'smoke_pass': bool(hardening_smoke.get('smoke_pass', False)),
        'recommended_release_mode': str(pack_summary.get('recommended_release_mode', '')),
        'current_release_unchanged': bool(pack_summary.get('playable_hardening', False)),
    }


def compare_release_candidates() -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    if RELEASE_DIR.exists():
        for path in sorted(RELEASE_DIR.glob('release_manifest_*.json')):
            manifest = read_json(path)
            if manifest.get('release_status') not in {'release_candidate', 'active'}:
                continue
            rows.append({
                'mechanic_profile_id': manifest.get('mechanic_profile_id', ''),
                'content_pack_id': manifest.get('content_pack_id', ''),
                'release_status': manifest.get('release_status', ''),
                'review_status': manifest.get('review_status', ''),
                'rollback_available': manifest.get('rollback_available', False),
            })
    return {'release_candidates': rows, 'compare_ready': True}


def build_mechanic_difference_summary(detail: dict[str, Any]) -> dict[str, Any]:
    runtime_summary = detail.get('runtime_primitive_summary', {})
    card_summary = detail.get('card_pool_summary', {})
    return {
        'runtime_primitives': runtime_summary.get('runtime_primitives', []),
        'clue_pressure_enabled': bool(runtime_summary.get('clue_pressure_declared', False)),
        'dual_weapon_enabled': bool(runtime_summary.get('dual_weapon_declared', False)),
        'max_wujing': int(runtime_summary.get('max_wujing', 0) or 0),
        'weapon_style_counts': card_summary.get('weapon_style_counts', {}),
        'realm_requirement_counts': card_summary.get('realm_requirement_counts', {}),
    }


def suggest_git_commands(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    return build_git_suggestions(profile_id, content_pack_id)


def build_git_suggestions(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    slug = f'{profile_id}__{content_pack_id}'
    return {
        'suggested_git_commit_command': f'git commit -am "release: {slug}"',
        'suggested_git_tag_command': f'git tag aigc-release/{slug}',
    }


def set_release_channel(channel: str, profile_id: str, content_pack_id: str) -> dict[str, Any]:
    if channel == 'current':
        ensure_balance_release_gate(profile_id, content_pack_id)
    validated = validate_release_pack(profile_id, content_pack_id, allow_archived=(channel == 'fallback'))
    ensure_pack_resolver_entry(channel, validated)
    previous = read_release_channel(channel)
    payload = build_release_channel_payload(channel, validated)
    if channel == 'current':
        payload['activated_at'] = str(previous.get('activated_at', ''))
        payload['formal_entry_enabled'] = True
        payload['fallback_enabled'] = True
        fallback = read_release_channel('fallback')
        payload['fallback_profile_id'] = str(fallback.get('mechanic_profile_id', DEFAULT_FALLBACK_PROFILE_ID))
        payload['fallback_content_pack_id'] = str(fallback.get('content_pack_id', DEFAULT_FALLBACK_PACK_ID))
        payload['fallback_runtime_manifest_path'] = str(fallback.get('runtime_manifest_path', ''))
        payload['smoke_test_status'] = str(previous.get('smoke_test_status', 'pending'))
        payload['last_smoke_report_path'] = str(previous.get('last_smoke_report_path', ''))
    elif channel == 'candidate':
        payload['candidate_created_at'] = now_iso()
        payload['smoke_test_required'] = True
    elif channel == 'fallback':
        payload['reason'] = 'rollback_target'
    write_json(release_channel_path(channel), payload)
    return payload


def activate_current_release() -> dict[str, Any]:
    current = read_release_channel('current', required=True)
    fallback = read_release_channel('fallback', required=True)
    validate_release_pack(str(current.get('mechanic_profile_id', '')), str(current.get('content_pack_id', '')), allow_archived=False)
    validate_release_pack(str(fallback.get('mechanic_profile_id', '')), str(fallback.get('content_pack_id', '')), allow_archived=True)
    previous_active = read_active_profile()
    summary = switch_lib.switch_active_profile(str(current.get('mechanic_profile_id', '')), str(current.get('content_pack_id', '')), switch_source='release_channel_current')
    active_profile = read_active_profile()
    if not active_profile_matches(str(current.get('mechanic_profile_id', '')), str(current.get('content_pack_id', '')), active_profile):
        raise SystemExit('activate-current failed: active profile does not match current_release')
    current['activated_at'] = now_iso()
    current['release_status'] = 'active'
    current['formal_entry_enabled'] = True
    current['fallback_enabled'] = True
    current['fallback_profile_id'] = str(fallback.get('mechanic_profile_id', ''))
    current['fallback_content_pack_id'] = str(fallback.get('content_pack_id', ''))
    current['fallback_runtime_manifest_path'] = str(fallback.get('runtime_manifest_path', ''))
    write_json(release_channel_path('current'), current)
    update_release_manifest_after_switch(
        previous_profile_id=str(previous_active.get('active_mechanic_profile_id', '')),
        previous_content_pack_id=str(previous_active.get('active_content_pack_id', '')),
        next_profile_id=str(current.get('mechanic_profile_id', '')),
        next_content_pack_id=str(current.get('content_pack_id', '')),
    )
    return {
        'ok': True,
        'summary': summary,
        'current_release': current,
        'active_profile': active_profile,
        'active_profile_matches_current_release': True,
    }


def rollback_to_fallback() -> dict[str, Any]:
    fallback = read_release_channel('fallback', required=True)
    validate_release_pack(str(fallback.get('mechanic_profile_id', '')), str(fallback.get('content_pack_id', '')), allow_archived=True)
    previous_active = read_active_profile()
    summary = switch_lib.switch_active_profile(str(fallback.get('mechanic_profile_id', '')), str(fallback.get('content_pack_id', '')), switch_source='release_channel_fallback')
    active_profile = read_active_profile()
    if not active_profile_matches(str(fallback.get('mechanic_profile_id', '')), str(fallback.get('content_pack_id', '')), active_profile):
        raise SystemExit('rollback-to-fallback failed: active profile does not match fallback_release')
    update_release_manifest_after_switch(
        previous_profile_id=str(previous_active.get('active_mechanic_profile_id', '')),
        previous_content_pack_id=str(previous_active.get('active_content_pack_id', '')),
        next_profile_id=str(fallback.get('mechanic_profile_id', '')),
        next_content_pack_id=str(fallback.get('content_pack_id', '')),
    )
    return {
        'ok': True,
        'summary': summary,
        'fallback_release': fallback,
        'active_profile': active_profile,
        'active_profile_matches_fallback_release': True,
    }


def show_channels() -> dict[str, Any]:
    ensure_default_release_channels()
    current = read_release_channel('current')
    candidate = read_release_channel('candidate')
    fallback = read_release_channel('fallback')
    active_profile = read_active_profile()
    active_profile_id = str(active_profile.get('active_mechanic_profile_id', ''))
    active_content_pack_id = str(active_profile.get('active_content_pack_id', ''))
    current_match = active_profile_matches(str(current.get('mechanic_profile_id', '')), str(current.get('content_pack_id', '')), active_profile) if current else False
    fallback_ready = False
    if fallback:
        try:
            validate_release_pack(str(fallback.get('mechanic_profile_id', '')), str(fallback.get('content_pack_id', '')), allow_archived=True)
            fallback_ready = True
        except SystemExit:
            fallback_ready = False
    return {
        'current_release': current,
        'candidate_release': candidate,
        'fallback_release': fallback,
        'active_runtime': {
            'active_profile_id': active_profile_id,
            'active_content_pack_id': active_content_pack_id,
            'runtime_manifest_path': str(active_profile.get('runtime_manifest_path', '')),
            'matches_current_release': current_match,
            'active_profile_drift_from_current_release': bool(current) and not current_match,
        },
        'rollback_to_fallback_ready': fallback_ready,
    }


def ensure_default_release_channels() -> None:
    if not release_channel_path('fallback').exists():
        set_release_channel('fallback', DEFAULT_FALLBACK_PROFILE_ID, DEFAULT_FALLBACK_PACK_ID)
    if not release_channel_path('current').exists():
        set_release_channel('current', DEFAULT_CURRENT_PROFILE_ID, DEFAULT_CURRENT_PACK_ID)
    if not release_channel_path('candidate').exists():
        write_json(release_channel_path('candidate'), {
            'channel': 'candidate',
            'mechanic_profile_id': '',
            'content_pack_id': '',
            'sequence_template_id': '',
            'build_variant': '',
            'pack_identity': {},
            'runtime_manifest_path': '',
            'release_status': 'pending',
            'candidate_created_at': '',
            'smoke_test_required': True,
        })


def validate_release_pack(profile_id: str, content_pack_id: str, allow_archived: bool) -> dict[str, Any]:
    switch_lib.ensure_safe_id(profile_id, 'profile_id')
    switch_lib.ensure_safe_id(content_pack_id, 'content_pack_id')
    switch_summary = switch_lib.validate_profile_ready(profile_id, content_pack_id)
    detail = load_pack_detail(profile_id, content_pack_id)
    validation = detail.get('validation_summary', {})
    runtime_manifest = read_json(ROOT / str(switch_summary['runtime_manifest_path']))
    sequence_template_id = str(
        runtime_manifest.get('sequence_template_id')
        or validation.get('sequence_template_id')
        or detail.get('sequence_template_id', '')
        or template_lib.infer_sequence_template_id({}, runtime_manifest)
    )
    build_variant = template_lib.resolve_build_variant(
        runtime_manifest.get('build_variant') or validation.get('build_variant') or detail.get('build_variant', ''),
        profile_id,
        content_pack_id,
    )
    pack_identity = template_lib.build_pack_identity(sequence_template_id, profile_id, build_variant, content_pack_id)
    runtime_primitives = [str(item) for item in runtime_manifest.get('runtime_primitives', [])]
    checks = [
        ('ready_for_runtime_export', bool(validation.get('ready_for_runtime_export', False))),
        ('full_sequence_coverage_complete', bool(validation.get('full_sequence_coverage_complete', False))),
        ('runtime_export_allowed', bool(validation.get('runtime_export_allowed', False))),
        ('sequence_balance_pass', bool(validation.get('sequence_balance_pass', False))),
        ('sequence_template_runtime_export_allowed', bool(validation.get('sequence_template_runtime_export_allowed', True))),
        ('template_mechanic_pack_binding_valid', bool(validation.get('template_mechanic_pack_binding_valid', True))),
    ]
    if 'deck_card_realm_eligibility_valid' in validation:
        checks.append(('deck_card_realm_eligibility_valid', bool(validation.get('deck_card_realm_eligibility_valid', False))))
    if 'no_card_above_player_wujing_in_deck' in validation:
        checks.append(('no_card_above_player_wujing_in_deck', bool(validation.get('no_card_above_player_wujing_in_deck', False))))
    if 'realm_eligibility_valid' in validation:
        checks.append(('realm_eligibility_valid', bool(validation.get('realm_eligibility_valid', False))))
    if 'weapon_followup' in runtime_primitives:
        checks.append(('weapon_followup_chain_valid', bool(read_validation_report(profile_id, content_pack_id).get('weapon_followup_chain_valid', False))))
    rewards = runtime_manifest.get('rewards', [])
    battle_slots = runtime_manifest.get('battle_slots', [])
    checks.append(('reward_coverage_complete', len(rewards) == len(battle_slots) and len(rewards) > 0))
    release_manifest = get_release_status(profile_id, content_pack_id)
    if not allow_archived and str(release_manifest.get('release_status', '')) == 'archived':
        raise SystemExit('release channel blocked: archived pack cannot be activated')
    failed = [name for name, passed in checks if not passed]
    if failed:
        raise SystemExit('release channel blocked: ' + ', '.join(failed))
    return {
        'mechanic_profile_id': profile_id,
        'content_pack_id': content_pack_id,
        'sequence_template_id': sequence_template_id,
        'build_variant': build_variant,
        'pack_identity': pack_identity,
        'runtime_manifest_path': str(switch_summary.get('runtime_manifest_path', '')),
        'validation_report_path': str(switch_summary.get('validation_report_path', '')),
        'release_status': str(release_manifest.get('release_status', 'draft')),
        'release_manifest_path': to_relative(release_manifest_path(profile_id, content_pack_id)),
        'review_report_path': to_relative(review_lib.review_report_md_path(profile_id, content_pack_id)),
        'review_notes_path': to_relative(review_notes_path(profile_id, content_pack_id)),
        'formal_encounter_total_count': int(detail.get('formal_encounter_total_count', 0)),
        'runtime_primitives': runtime_primitives,
        'reward_coverage_complete': len(rewards) == len(battle_slots) and len(rewards) > 0,
        'validation_summary': validation,
    }


def build_release_channel_payload(channel: str, validated: dict[str, Any]) -> dict[str, Any]:
    payload = {
        'channel': channel,
        'mechanic_profile_id': validated['mechanic_profile_id'],
        'content_pack_id': validated['content_pack_id'],
        'sequence_template_id': validated.get('sequence_template_id', ''),
        'build_variant': validated.get('build_variant', ''),
        'pack_identity': validated.get('pack_identity', {}),
        'runtime_manifest_path': validated['runtime_manifest_path'],
        'release_status': validated['release_status'],
    }
    if channel == 'current':
        payload.update({
            'release_manifest_path': validated['release_manifest_path'],
            'review_report_path': validated['review_report_path'],
            'activated_at': '',
            'formal_entry_enabled': True,
            'fallback_enabled': True,
            'fallback_profile_id': DEFAULT_FALLBACK_PROFILE_ID,
            'fallback_content_pack_id': DEFAULT_FALLBACK_PACK_ID,
            'fallback_runtime_manifest_path': '',
            'smoke_test_status': 'pending',
            'last_smoke_report_path': '',
        })
    elif channel == 'candidate':
        payload.update({
            'candidate_created_at': '',
            'smoke_test_required': True,
        })
    elif channel == 'fallback':
        payload.update({
            'reason': 'rollback_target',
        })
    return payload


def update_release_manifest_after_switch(
    previous_profile_id: str,
    previous_content_pack_id: str,
    next_profile_id: str,
    next_content_pack_id: str,
) -> None:
    if previous_profile_id and previous_content_pack_id:
        previous_manifest = get_release_status(previous_profile_id, previous_content_pack_id)
        if previous_profile_id != next_profile_id or previous_content_pack_id != next_content_pack_id:
            previous_manifest['release_status'] = 'accepted' if previous_manifest.get('frozen', False) else 'draft'
            previous_manifest['rollback_available'] = False
            previous_manifest['updated_at'] = now_iso()
            write_json(release_manifest_path(previous_profile_id, previous_content_pack_id), previous_manifest)
    next_manifest = get_release_status(next_profile_id, next_content_pack_id)
    next_manifest['release_status'] = 'active'
    next_manifest['activated_at'] = now_iso()
    next_manifest['rollback_available'] = True
    if next_manifest.get('balance_release'):
        next_manifest['activated_as_current_release'] = True
    next_manifest['updated_at'] = now_iso()
    write_json(release_manifest_path(next_profile_id, next_content_pack_id), next_manifest)


def ensure_balance_release_gate(profile_id: str, content_pack_id: str) -> None:
    manifest = get_release_status(profile_id, content_pack_id)
    if not manifest.get('balance_release', False):
        return
    if not manifest.get('playable_balance_gate_pass', False):
        raise SystemExit('balance release blocked: playable_balance_gate_pass is false')


def ensure_playable_hardening_gate(profile_id: str, content_pack_id: str) -> None:
    manifest = get_release_status(profile_id, content_pack_id)
    if not manifest.get('playable_hardening', False):
        return
    if not manifest.get('target_gate_pass', False):
        raise SystemExit('playable hardening blocked: target_gate_pass is false')
    if not manifest.get('smoke_pass', False):
        raise SystemExit('playable hardening blocked: smoke_pass is false')


def load_balance_release_evaluation_report(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    path = BALANCE_RELEASE_DIR / 'balance_release_evaluation_report.json'
    if not path.exists():
        return {'report_path': '', 'playable_balance_gate_pass': False}
    payload = read_json(path)
    if str(payload.get('balanced_pack_id', '')) != content_pack_id:
        return {'report_path': '', 'playable_balance_gate_pass': False}
    if str(payload.get('source_profile_id', profile_id)) != profile_id:
        return {'report_path': '', 'playable_balance_gate_pass': False}
    return {'report_path': to_relative(path), **payload}


def load_playable_hardening_evaluation_report(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    path = PLAYABLE_HARDENING_DIR / 'hardened_candidates_evaluation_report.json'
    if not path.exists():
        return {'report_path': '', 'target_gate_pass': False}
    payload = read_json(path)
    if str(payload.get('fast_hardened_pack_id', '')) == content_pack_id:
        return {'report_path': to_relative(path), 'target_gate_pass': bool(payload.get('fast_target_gate_pass', False)), **payload}
    if str(payload.get('bossrush_hardened_pack_id', '')) == content_pack_id:
        return {'report_path': to_relative(path), 'target_gate_pass': bool(payload.get('bossrush_target_gate_pass', False)), **payload}
    return {'report_path': '', 'target_gate_pass': False}


def load_playable_hardening_smoke_report(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    for name in ['fast_hardened_smoke_report.json', 'bossrush_hardened_smoke_report.json']:
        path = PLAYABLE_HARDENING_DIR / name
        if not path.exists():
            continue
        payload = read_json(path)
        if str(payload.get('mechanic_profile_id', profile_id)) == profile_id and str(payload.get('content_pack_id', '')) == content_pack_id:
            return {'report_path': to_relative(path), **payload}
    return {'report_path': '', 'smoke_pass': False}


def ensure_pack_resolver_entry(channel: str, validated: dict[str, Any]) -> None:
    if not PACK_RESOLVER_PATH.exists():
        return
    resolver = read_json(PACK_RESOLVER_PATH)
    entries = resolver.get('entries', [])
    target = next((
        entry for entry in entries
        if str(entry.get('mechanic_profile_id', '')) == str(validated.get('mechanic_profile_id', ''))
        and str(entry.get('content_pack_id', '')) == str(validated.get('content_pack_id', ''))
    ), None)
    if not target:
        raise SystemExit('release channel blocked: missing pack resolver entry')
    if not bool(target.get('resolver_entry_valid', False)):
        raise SystemExit('release channel blocked: invalid pack resolver entry')


def read_active_profile() -> dict[str, Any]:
    path = RUNTIME_DIR / 'active_profile.json'
    if not path.exists():
        return {}
    return read_json(path)


def active_profile_matches(profile_id: str, content_pack_id: str, active_profile: dict[str, Any] | None = None) -> bool:
    payload = active_profile or read_active_profile()
    return (
        str(payload.get('active_mechanic_profile_id', '')) == profile_id
        and str(payload.get('active_content_pack_id', '')) == content_pack_id
    )


def load_pack_detail(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    path = DETAILS_DIR / f'pack_{profile_id}__{content_pack_id}.json'
    if not path.exists():
        detail_lib.main()
    if not path.exists():
        raise SystemExit('pack detail not found')
    return read_json(path)


def load_review_notes(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    path = review_notes_path(profile_id, content_pack_id)
    if path.exists():
        return read_json(path)
    return {
        'mechanic_profile_id': profile_id,
        'content_pack_id': content_pack_id,
        'review_status': 'pending',
        'recommended_action': 'safe_to_test',
        'reviewer': '',
        'summary': '',
    }


def read_validation_report(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    summary = switch_lib.validate_profile_ready(profile_id, content_pack_id)
    return read_json(ROOT / str(summary.get('validation_report_path', '')))


def read_release_channel(channel: str, required: bool = False) -> dict[str, Any]:
    path = release_channel_path(channel)
    if not path.exists():
        if required:
            raise SystemExit(f'{channel}_release.json not found')
        return {}
    return read_json(path)


def release_channel_path(channel: str) -> Path:
    if channel not in {'current', 'candidate', 'fallback'}:
        raise SystemExit(f'invalid release channel: {channel}')
    return RELEASE_CHANNELS_DIR / f'{channel}_release.json'


def release_manifest_path(profile_id: str, content_pack_id: str) -> Path:
    return RELEASE_DIR / f'release_manifest_{profile_id}__{content_pack_id}.json'


def release_report_path(profile_id: str, content_pack_id: str) -> Path:
    return RELEASE_DIR / f'release_report_{profile_id}__{content_pack_id}.md'


def review_notes_path(profile_id: str, content_pack_id: str) -> Path:
    return REVIEW_NOTES_DIR / f'{profile_id}__{content_pack_id}.json'


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def to_relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding='utf-8'))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
