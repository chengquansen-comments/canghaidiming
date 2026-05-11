#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.aigc_battle import build_aigc_content_index as index_lib
from tools.aigc_battle import build_aigc_detail_views as detail_lib
from tools.aigc_battle import build_aigc_review_workspace as review_lib
from tools.aigc_battle import snapshot_content_pack as snapshot_lib
from tools.aigc_battle import switch_active_profile as switch_lib
from tools.aigc_battle import aigc_release_gate as release_lib

TOOLS_DIR = ROOT / 'tools' / 'aigc_battle'
GENERATED_DIR = ROOT / 'data' / 'aigc_battle' / 'generated'
FACTORY_LOCK_PATH = GENERATED_DIR / 'factory.lock'
FACTORY_LOG_DIR = GENERATED_DIR / 'factory_logs'


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description='aigc pack factory')
    sub = parser.add_subparsers(dest='command', required=True)
    build = sub.add_parser('build')
    build.add_argument('--profile', required=True)

    snap = sub.add_parser('snapshot')
    snap.add_argument('--profile', required=True)
    snap.add_argument('--pack-id', required=True)
    snap.add_argument('--force', action='store_true')

    bfs = sub.add_parser('build-from-snapshot')
    bfs.add_argument('--profile', required=True)
    bfs.add_argument('--snapshot', required=True)
    bfs.add_argument('--pack-id', required=True)
    bfs.add_argument('--force', action='store_true')

    bft = sub.add_parser('build-from-telemetry')
    bft.add_argument('--profile', required=True)
    bft.add_argument('--pack-id', required=True)
    bft.add_argument('--force', action='store_true')

    bfl = sub.add_parser('build-from-llm')
    bfl.add_argument('--profile', required=True)
    bfl.add_argument('--pack-id', required=True)
    bfl.add_argument('--force', action='store_true')

    bfrt = sub.add_parser('build-from-real-telemetry')
    bfrt.add_argument('--profile', required=True)
    bfrt.add_argument('--pack-id', required=True)
    bfrt.add_argument('--force', action='store_true')

    exp_prompt = sub.add_parser('export-llm-prompt')
    exp_prompt.add_argument('--profile', required=True)
    exp_prompt.add_argument('--pack', required=True)

    imp_candidates = sub.add_parser('import-llm-candidates')
    imp_candidates.add_argument('--profile', required=True)
    imp_candidates.add_argument('--input', required=True)

    diff_candidates = sub.add_parser('diff-llm-candidates')
    diff_candidates.add_argument('--profile', required=True)
    diff_candidates.add_argument('--pack', required=True)

    build_ai = sub.add_parser('build-ai-pack')
    build_ai.add_argument('--profile', required=True)
    build_ai.add_argument('--pack-id', required=True)

    val = sub.add_parser('validate')
    val.add_argument('--profile', required=True)
    val.add_argument('--pack')

    exp = sub.add_parser('export')
    exp.add_argument('--profile', required=True)
    exp.add_argument('--pack')

    sub.add_parser('refresh-review')
    args = parser.parse_args(argv[1:])

    if args.command == 'build':
        result = run_action('build', args.profile, '', lambda log: build_root_pack(args.profile, log))
    elif args.command == 'snapshot':
        result = run_action('snapshot', args.profile, args.pack_id, lambda log: snapshot_pack(args.profile, args.pack_id, args.force, log))
    elif args.command == 'build-from-snapshot':
        result = run_action('build_from_snapshot', args.profile, args.pack_id, lambda log: build_from_snapshot(args.profile, args.snapshot, args.pack_id, args.force, log))
    elif args.command == 'build-from-telemetry':
        result = run_action('build_from_telemetry', args.profile, args.pack_id, lambda log: build_from_telemetry(args.profile, args.pack_id, args.force, log))
    elif args.command == 'build-from-llm':
        result = run_action('build_from_llm', args.profile, args.pack_id, lambda log: build_from_llm(args.profile, args.pack_id, args.force, log))
    elif args.command == 'build-from-real-telemetry':
        result = run_action('build_from_real_telemetry', args.profile, args.pack_id, lambda log: build_from_real_telemetry(args.profile, args.pack_id, args.force, log))
    elif args.command == 'export-llm-prompt':
        result = run_action('export_llm_prompt', args.profile, args.pack, lambda log: export_llm_prompt(args.profile, args.pack, log))
    elif args.command == 'import-llm-candidates':
        result = run_action('import_llm_candidates', args.profile, '', lambda log: import_llm_candidates(args.profile, args.input, log))
    elif args.command == 'diff-llm-candidates':
        result = run_action('diff_llm_candidates', args.profile, args.pack, lambda log: diff_llm_candidates(args.profile, args.pack, log))
    elif args.command == 'build-ai-pack':
        result = run_action('build_ai_pack', args.profile, args.pack_id, lambda log: build_ai_pack(args.profile, args.pack_id, log))
    elif args.command == 'validate':
        result = run_action('validate', args.profile, args.pack or '', lambda log: validate_pack(args.profile, args.pack, log))
    elif args.command == 'export':
        result = run_action('export', args.profile, args.pack or '', lambda log: export_pack(args.profile, args.pack, log))
    else:
        result = run_action('refresh_review', 'global', '', lambda log: refresh_review(log))
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def run_action(action: str, profile_id: str, pack_id: str, fn) -> dict[str, Any]:
    FACTORY_LOG_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    log_path = FACTORY_LOG_DIR / f'{timestamp}_{action}_{profile_id}_{pack_id or "root"}.json'
    log: dict[str, Any] = {
        'timestamp': datetime.now(timezone.utc).isoformat(),
        'action': action,
        'profile_id': profile_id,
        'pack_id': pack_id,
        'status': 'running',
        'steps': [],
    }
    try:
        with factory_lock():
            payload = fn(log)
        log['status'] = 'ok'
        log['result'] = payload
    except Exception as exc:
        log['status'] = 'failed'
        log['error'] = str(exc)
        write_json(log_path, log)
        if isinstance(exc, SystemExit):
            raise
        raise SystemExit(str(exc))
    write_json(log_path, log)
    return {'ok': True, 'factory_log_path': to_relative(log_path), 'result': log.get('result', {})}


def build_root_pack(profile_id: str, log: dict[str, Any]) -> dict[str, Any]:
    switch_lib.ensure_safe_id(profile_id, 'profile_id')
    run_step(log, [sys.executable, str(TOOLS_DIR / 'build_content_for_profile.py'), profile_id])
    run_step(log, [sys.executable, str(TOOLS_DIR / 'validate_content_pack.py'), profile_id])
    run_step(log, [sys.executable, str(TOOLS_DIR / 'export_runtime_manifest.py'), profile_id])
    refresh_review(log)
    return {'profile_id': profile_id, 'pack_storage_mode': 'profile_root'}


def snapshot_pack(profile_id: str, pack_id: str, force: bool, log: dict[str, Any]) -> dict[str, Any]:
    ensure_pack_write_allowed(profile_id, pack_id, force)
    summary = snapshot_lib.snapshot_content_pack(profile_id, pack_id, force=force)
    log['steps'].append({'type': 'python_call', 'name': 'snapshot_content_pack', 'pack_id': pack_id})
    refresh_review(log)
    return summary


def build_from_snapshot(profile_id: str, snapshot_path: str, pack_id: str, force: bool, log: dict[str, Any]) -> dict[str, Any]:
    ensure_pack_write_allowed(profile_id, pack_id, force)
    approved = approved_snapshot_path(profile_id, snapshot_path)
    run_step(log, [sys.executable, str(TOOLS_DIR / 'build_content_for_profile.py'), profile_id, '--use-snapshot', str(approved)])
    run_step(log, [sys.executable, str(TOOLS_DIR / 'validate_content_pack.py'), profile_id])
    run_step(log, [sys.executable, str(TOOLS_DIR / 'export_runtime_manifest.py'), profile_id])
    summary = snapshot_lib.snapshot_content_pack(profile_id, pack_id, force=force)
    refresh_review(log)
    return {'snapshot_source': to_relative(approved), 'snapshot_summary': summary}


def build_from_telemetry(profile_id: str, pack_id: str, force: bool, log: dict[str, Any]) -> dict[str, Any]:
    snapshot_path = switch_lib.resolve_generated_dir(profile_id) / 'sequence_balance_snapshot.json'
    if not snapshot_path.exists():
        raise SystemExit('telemetry snapshot not found')
    return build_from_snapshot(profile_id, str(snapshot_path), pack_id, force, log)


def build_from_llm(profile_id: str, pack_id: str, force: bool, log: dict[str, Any]) -> dict[str, Any]:
    ensure_pack_write_allowed(profile_id, pack_id, force)
    run_step(log, [sys.executable, str(TOOLS_DIR / 'import_llm_candidates.py'), profile_id])
    run_step(log, [sys.executable, str(TOOLS_DIR / 'validate_content_pack.py'), profile_id])
    run_step(log, [sys.executable, str(TOOLS_DIR / 'export_runtime_manifest.py'), profile_id])
    summary = snapshot_lib.snapshot_content_pack(profile_id, pack_id, force=force)
    refresh_review(log)
    return summary


def build_from_real_telemetry(profile_id: str, pack_id: str, force: bool, log: dict[str, Any]) -> dict[str, Any]:
    ensure_pack_write_allowed(profile_id, pack_id, force)
    snapshot_path = switch_lib.resolve_generated_dir(profile_id) / 'real_telemetry_snapshot.json'
    if not snapshot_path.exists():
        raise SystemExit('real telemetry snapshot not found')
    run_step(log, [sys.executable, str(TOOLS_DIR / 'build_content_for_profile.py'), profile_id, '--use-real-telemetry-snapshot', str(snapshot_path)])
    run_step(log, [sys.executable, str(TOOLS_DIR / 'validate_content_pack.py'), profile_id])
    run_step(log, [sys.executable, str(TOOLS_DIR / 'export_runtime_manifest.py'), profile_id])
    summary = snapshot_lib.snapshot_content_pack(profile_id, pack_id, force=force)
    refresh_review(log)
    return {
        'real_telemetry_snapshot_path': to_relative(snapshot_path),
        'snapshot_summary': summary,
        'rebuild_uses_real_telemetry': True,
    }


def export_llm_prompt(profile_id: str, content_pack_id: str, log: dict[str, Any]) -> dict[str, Any]:
    run_step(log, [sys.executable, str(TOOLS_DIR / 'export_llm_generation_prompt.py'), '--profile', profile_id, '--pack', content_pack_id])
    return {'prompt_exported': True}


def import_llm_candidates(profile_id: str, input_path: str, log: dict[str, Any]) -> dict[str, Any]:
    run_step(log, [sys.executable, str(TOOLS_DIR / 'import_llm_production_candidates.py'), '--profile', profile_id, '--input', input_path])
    return {'candidate_imported': True}


def diff_llm_candidates(profile_id: str, content_pack_id: str, log: dict[str, Any]) -> dict[str, Any]:
    run_step(log, [sys.executable, str(TOOLS_DIR / 'diff_llm_candidates.py'), '--profile', profile_id, '--pack', content_pack_id])
    return {'candidate_diff_ready': True}


def build_ai_pack(profile_id: str, pack_id: str, log: dict[str, Any]) -> dict[str, Any]:
    ensure_pack_write_allowed(profile_id, pack_id, False)
    run_step(log, [sys.executable, str(TOOLS_DIR / 'build_ai_content_pack.py'), '--profile', profile_id, '--pack-id', pack_id])
    return {'ai_pack_built': True, 'pack_id': pack_id}


def validate_pack(profile_id: str, pack_id: str | None, log: dict[str, Any]) -> dict[str, Any]:
    args = [sys.executable, str(TOOLS_DIR / 'validate_content_pack.py'), profile_id]
    generated_dir = resolve_target_generated_dir(profile_id, pack_id)
    if pack_id:
        args.extend(['--generated-dir', str(generated_dir)])
    run_step(log, args)
    return {'generated_dir': to_relative(generated_dir), 'validated': True}


def export_pack(profile_id: str, pack_id: str | None, log: dict[str, Any]) -> dict[str, Any]:
    args = [sys.executable, str(TOOLS_DIR / 'export_runtime_manifest.py'), profile_id]
    generated_dir = resolve_target_generated_dir(profile_id, pack_id)
    if pack_id:
        args.extend(['--generated-dir', str(generated_dir)])
    run_step(log, args)
    return {'generated_dir': to_relative(generated_dir), 'exported': True}


def refresh_review(log: dict[str, Any]) -> dict[str, Any]:
    run_step(log, [sys.executable, str(TOOLS_DIR / 'build_aigc_content_index.py')])
    run_step(log, [sys.executable, str(TOOLS_DIR / 'build_aigc_detail_views.py')])
    run_step(log, [sys.executable, str(TOOLS_DIR / 'build_aigc_content_index.py')])
    run_step(log, [sys.executable, str(TOOLS_DIR / 'build_aigc_review_workspace.py')])
    return {'review_workspace_path': to_relative(review_lib.WORKSPACE_JSON)}


def run_step(log: dict[str, Any], cmd: list[str]) -> None:
    completed = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True)
    log['steps'].append({
        'type': 'command',
        'cmd': cmd,
        'returncode': completed.returncode,
        'stdout': completed.stdout,
        'stderr': completed.stderr,
    })
    if completed.returncode != 0:
        raise SystemExit((completed.stderr or completed.stdout or 'factory step failed').strip())


def resolve_target_generated_dir(profile_id: str, pack_id: str | None) -> Path:
    return switch_lib.resolve_generated_dir(profile_id, pack_id if pack_id else None)


def approved_snapshot_path(profile_id: str, snapshot_path: str) -> Path:
    candidate = Path(snapshot_path).resolve()
    generated_root = switch_lib.resolve_generated_dir(profile_id).resolve()
    if not candidate.exists():
        raise SystemExit('snapshot path not found')
    if generated_root not in candidate.parents and candidate != generated_root:
        raise SystemExit('snapshot path is not approved')
    if candidate.name != 'sequence_balance_snapshot.json':
        raise SystemExit('snapshot path is not approved')
    return candidate


def ensure_pack_write_allowed(profile_id: str, pack_id: str, force: bool) -> None:
    switch_lib.ensure_safe_id(profile_id, 'profile_id')
    switch_lib.ensure_safe_id(pack_id, 'pack_id')
    release_status = release_lib.get_release_status(profile_id, pack_id) if release_lib.release_manifest_path(profile_id, pack_id).exists() else {}
    if release_status.get('release_status') == 'archived':
        raise SystemExit('pack write blocked: archived pack')
    target_dir = switch_lib.resolve_generated_dir(profile_id, pack_id)
    if target_dir.exists() and not force:
        raise SystemExit('pack already exists')


@contextmanager
def factory_lock():
    GENERATED_DIR.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(str(FACTORY_LOCK_PATH), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError as exc:
        raise SystemExit('factory lock exists') from exc
    try:
        os.write(fd, str(os.getpid()).encode('utf-8'))
        os.close(fd)
        yield
    finally:
        try:
            FACTORY_LOCK_PATH.unlink()
        except FileNotFoundError:
            pass


def to_relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
