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

from tools.aigc_battle import build_aigc_review_workspace as review_lib
from tools.aigc_battle import switch_active_profile as switch_lib

RELEASE_DIR = ROOT / 'data' / 'aigc_battle' / 'release'
REVIEW_NOTES_DIR = ROOT / 'data' / 'aigc_battle' / 'review_notes'
DETAILS_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'details'
REVIEW_DIR = ROOT / 'data' / 'aigc_battle' / 'generated' / 'review'


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description='aigc release gate')
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ['freeze', 'mark-release-candidate', 'archive', 'report', 'status']:
        sp = sub.add_parser(name)
        sp.add_argument('--profile', required=True)
        sp.add_argument('--pack', required=True)
    args = parser.parse_args(argv[1:])
    if args.command == 'freeze':
        payload = freeze_pack(args.profile, args.pack)
    elif args.command == 'mark-release-candidate':
        payload = mark_release_candidate(args.profile, args.pack)
    elif args.command == 'archive':
        payload = archive_pack(args.profile, args.pack)
    elif args.command == 'report':
        payload = generate_release_report(args.profile, args.pack)
    else:
        payload = get_release_status(args.profile, args.pack)
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0


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
    manifest['updated_at'] = now_iso()
    write_json(release_manifest_path(profile_id, content_pack_id), manifest)
    return manifest


def mark_release_candidate(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    manifest = get_release_status(profile_id, content_pack_id)
    if not manifest.get('frozen', False):
        raise SystemExit('mark release candidate blocked: pack is not frozen')
    manifest['release_status'] = 'release_candidate'
    manifest['updated_at'] = now_iso()
    write_json(release_manifest_path(profile_id, content_pack_id), manifest)
    return manifest


def archive_pack(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    manifest = get_release_status(profile_id, content_pack_id)
    manifest['release_status'] = 'archived'
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
    load_pack_detail(profile_id, content_pack_id)
    notes = load_review_notes(profile_id, content_pack_id)
    report_path = review_lib.review_report_md_path(profile_id, content_pack_id)
    detail_path = DETAILS_DIR / f'pack_{profile_id}__{content_pack_id}.json'
    detail = read_json(detail_path)
    is_active = bool(detail.get('is_active_pack', False))
    return {
        'mechanic_profile_id': profile_id,
        'content_pack_id': content_pack_id,
        'release_status': 'active' if is_active else 'draft',
        'frozen': False,
        'frozen_at': '',
        'review_status': notes.get('review_status', 'pending'),
        'review_notes_path': to_relative(review_notes_path(profile_id, content_pack_id)),
        'runtime_manifest_path': str(detail.get('runtime_manifest_path', '')),
        'validation_report_path': str(switch_lib.resolve_validation_report_path(profile_id, content_pack_id if detail.get('pack_storage_mode') == 'profile_pack_dir' else None).relative_to(ROOT).as_posix()),
        'review_report_path': to_relative(report_path),
        'release_report_path': to_relative(release_report_path(profile_id, content_pack_id)) if release_report_path(profile_id, content_pack_id).exists() else '',
        'created_at': now_iso(),
        'updated_at': now_iso(),
    }


def load_pack_detail(profile_id: str, content_pack_id: str) -> dict[str, Any]:
    path = DETAILS_DIR / f'pack_{profile_id}__{content_pack_id}.json'
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
