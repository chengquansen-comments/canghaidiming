#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import switch_active_profile as switch_lib

RUNTIME_DIR = ROOT / 'data' / 'aigc_battle' / 'runtime'


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description='safe external active profile/content pack switch')
    parser.add_argument('legacy_profile_id', nargs='?')
    parser.add_argument('--profile')
    parser.add_argument('--pack')
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--restore')
    parser.add_argument('--list', action='store_true')
    parser.add_argument('--rollback', action='store_true')
    args = parser.parse_args(argv[1:])

    if args.list:
        print_list()
        return 0

    if args.rollback:
        result = switch_lib.rollback_active_profile(switch_source='external_cli_rollback')
        active_profile = read_json(RUNTIME_DIR / 'active_profile.json')
        print_summary({**result.get('summary', {}), **active_profile}, dry_run=False)
        print('rollback complete')
        return 0

    target_profile = args.restore or args.profile or args.legacy_profile_id
    target_pack = args.pack
    if not target_profile:
        parser.error('profile_id is required unless --list is used')

    summary = switch_lib.validate_profile_ready(target_profile, target_pack)
    if args.dry_run:
        print_summary(summary, dry_run=True)
        return 0

    switch_lib.switch_active_profile(target_profile, target_pack, switch_source='external_cli')
    active_profile = read_json(RUNTIME_DIR / 'active_profile.json')
    if active_profile.get('active_mechanic_profile_id') != target_profile:
        raise SystemExit('active profile verification failed after switch')
    if active_profile.get('active_content_pack_id') != summary.get('content_pack_id'):
        raise SystemExit('active content pack verification failed after switch')
    print_summary({**summary, **active_profile}, dry_run=False)
    print('建议重新生成索引: python3 tools/aigc_battle/build_aigc_content_index.py')
    return 0


def print_list() -> None:
    for profile_id in switch_lib.list_profile_ids():
        rows = [switch_lib.get_switchability(profile_id, None)]
        packs_dir = switch_lib.resolve_generated_dir(profile_id) / 'packs'
        if packs_dir.exists():
            for pack_dir in sorted(path for path in packs_dir.iterdir() if path.is_dir()):
                rows.append(switch_lib.get_switchability(profile_id, pack_dir.name))
        for row in rows:
            status = 'READY' if row.get('switchable') else f"BLOCKED: {'; '.join(row.get('switch_block_reasons', []))}"
            print(f"{profile_id}\t{row.get('content_pack_id','')}\t{row.get('pack_storage_mode','')}\t{status}")


def print_summary(summary: dict[str, Any], dry_run: bool) -> None:
    prefix = 'dry-run ok' if dry_run else 'switched active pack'
    print(f"{prefix}: {summary.get('mechanic_profile_id', summary.get('active_mechanic_profile_id', ''))}")
    print(f"active_mechanic_profile_id: {summary.get('active_mechanic_profile_id', summary.get('mechanic_profile_id', ''))}")
    print(f"active_content_pack_id: {summary.get('active_content_pack_id', summary.get('content_pack_id', ''))}")
    print(f"runtime_manifest_path: {summary.get('runtime_manifest_path', '')}")
    print(f"ready_for_runtime_export: {str(summary.get('ready_for_runtime_export', False)).lower()}")
    print(f"sequence_balance_pass: {str(summary.get('sequence_balance_pass', False)).lower()}")
    print(f"runtime_primitives: {json.dumps(summary.get('runtime_primitives', []), ensure_ascii=False)}")


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding='utf-8'))


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
