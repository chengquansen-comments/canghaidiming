#!/usr/bin/env python3
"""Generate Godot loader preflight report (analysis only) for Content Engine v0.8d."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path

from runtime_export_manifest import MANIFEST_JSON, MANIFEST_REPORT_TSV
from runtime_exporter import ALLOWED_RUNTIME_FILENAMES, RUNTIME_DIR


OUTPUT_TSV = "generated_runtime_loader_preflight_report.tsv"
OUTPUT_MD = "generated_runtime_loader_preflight_report.md"
OUTPUT_FIELDS = [
    "runtime_domain",
    "artifact_id",
    "runtime_path",
    "manifest_status",
    "json_parse_status",
    "checksum_status",
    "schema_fingerprint_status",
    "content_fingerprint_status",
    "proposed_loader_scope",
    "proposed_read_mode",
    "proposed_failure_mode",
    "proposed_fallback_source",
    "proposed_godot_touchpoints",
    "risk_level",
    "loader_ready",
    "blocked_reason",
    "notes",
]
RUNTIME_PREFIX = "data/runtime/content_engine/"
RUNTIME_ALLOWED_SET = set(ALLOWED_RUNTIME_FILENAMES)
FALLBACK_BY_DOMAIN = {
    "card_pool": "fallback_to_existing_card_data_or_design_source",
    "battle_reward": "fallback_to_existing_reward_design_source",
}
TOUCHPOINTS = "future_touchpoint_only:scripts/card_data.gd,scripts/battle_state_machine.gd,scripts/combat_resolver.gd"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate runtime loader preflight report (no Godot code changes).")
    parser.add_argument("--runtime-dir", default=str(RUNTIME_DIR))
    parser.add_argument("--manifest", default=f"data/runtime/content_engine/{MANIFEST_JSON}")
    parser.add_argument("--manifest-report", default=f"data/design/{MANIFEST_REPORT_TSV}")
    parser.add_argument("--card-pool", default="data/runtime/content_engine/card_pool.json")
    parser.add_argument("--battle-reward", default="data/runtime/content_engine/battle_reward.json")
    parser.add_argument("--out", default=f"data/design/{OUTPUT_TSV}")
    parser.add_argument("--out-md", default=f"data/design/{OUTPUT_MD}")
    return parser.parse_args()


def require_file(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(f"Missing required input: {path}")


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def check_runtime_dir(runtime_dir: Path) -> tuple[bool, str]:
    if not runtime_dir.exists() or not runtime_dir.is_dir():
        return False, "runtime_dir_missing"
    file_names = {entry.name for entry in runtime_dir.iterdir() if entry.is_file()}
    allowed = RUNTIME_ALLOWED_SET | {MANIFEST_JSON}
    extra = sorted(file_names - allowed)
    if extra:
        return False, f"extra_runtime_files:{','.join(extra)}"
    required = sorted(allowed - file_names)
    if required:
        return False, f"missing_runtime_files:{','.join(required)}"
    return True, ""


def parse_manifest(path: Path) -> dict[str, object]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("runtime_manifest.json must be object")
    return payload


def index_manifest_report(rows: list[dict[str, str]]) -> dict[tuple[str, str], dict[str, str]]:
    return {((row.get("runtime_domain") or "").strip(), (row.get("artifact_id") or "").strip()): row for row in rows}


def evaluate_file_entry(
    item: dict[str, object],
    manifest_report_index: dict[tuple[str, str], dict[str, str]],
    runtime_dir_ok: bool,
    runtime_dir_blocked: str,
) -> dict[str, str]:
    runtime_domain = str(item.get("runtime_domain") or "")
    artifact_id = str(item.get("artifact_id") or "")
    runtime_path = str(item.get("runtime_path") or "")
    fallback = FALLBACK_BY_DOMAIN.get(runtime_domain, "fallback_to_existing_design_source")

    manifest_status = "registered"
    json_parse_status = "ok"
    checksum_status = "matched"
    schema_status = "matched"
    content_status = "matched"
    blocked_reasons: list[str] = []

    path_obj = Path(runtime_path)
    if path_obj.is_absolute() or path_obj.parent.as_posix() != RUNTIME_DIR.as_posix() or path_obj.name not in RUNTIME_ALLOWED_SET:
        blocked_reasons.append("runtime_path_not_allowlisted")

    runtime_file = Path(runtime_path)
    runtime_payload: dict[str, object] | None = None
    if not runtime_file.exists():
        json_parse_status = "missing"
        checksum_status = "mismatch"
        schema_status = "mismatch"
        content_status = "mismatch"
        blocked_reasons.append("runtime_file_missing")
    else:
        try:
            runtime_payload = json.loads(runtime_file.read_text(encoding="utf-8"))
            if not isinstance(runtime_payload, dict):
                raise ValueError("runtime payload must be object")
        except (json.JSONDecodeError, ValueError):
            json_parse_status = "parse_failed"
            checksum_status = "mismatch"
            schema_status = "mismatch"
            content_status = "mismatch"
            blocked_reasons.append("runtime_json_parse_failed")

    manifest_sha = str(item.get("sha256") or "")
    if runtime_payload is not None:
        actual_sha = sha256_file(runtime_file)
        if manifest_sha != actual_sha:
            checksum_status = "mismatch"
            blocked_reasons.append("checksum_mismatch")

        manifest_schema = str(item.get("schema_fingerprint") or "")
        manifest_content = str(item.get("content_fingerprint") or "")
        payload_schema = str(runtime_payload.get("schema_fingerprint") or "")
        payload_content = str(runtime_payload.get("content_fingerprint") or "")
        if manifest_schema != payload_schema:
            schema_status = "mismatch"
            blocked_reasons.append("schema_fingerprint_mismatch")
        if manifest_content != payload_content:
            content_status = "mismatch"
            blocked_reasons.append("content_fingerprint_mismatch")

    report_row = manifest_report_index.get((runtime_domain, artifact_id))
    if report_row is None:
        manifest_status = "missing_in_manifest_report"
        blocked_reasons.append("manifest_report_row_missing")
    else:
        manifest_status = (report_row.get("manifest_status") or "").strip() or "unknown"
        if manifest_status != "registered":
            blocked_reasons.append(f"manifest_status_{manifest_status}")

    if runtime_domain not in FALLBACK_BY_DOMAIN:
        blocked_reasons.append("fallback_source_not_defined")

    if not runtime_dir_ok:
        blocked_reasons.append(runtime_dir_blocked)

    all_checks_ok = (
        runtime_dir_ok
        and runtime_domain in FALLBACK_BY_DOMAIN
        and manifest_status == "registered"
        and json_parse_status == "ok"
        and checksum_status == "matched"
        and schema_status == "matched"
        and content_status == "matched"
        and runtime_path.startswith(RUNTIME_PREFIX)
        and Path(runtime_path).name in RUNTIME_ALLOWED_SET
    )

    loader_ready = "true" if all_checks_ok else "false"
    proposed_loader_scope = "runtime_data_probe" if all_checks_ok else "blocked"
    proposed_read_mode = "manifest_first" if all_checks_ok else "blocked"
    proposed_failure_mode = "fail_closed" if all_checks_ok else "fallback_to_existing_design_data"

    blocked_reason = "" if loader_ready == "true" else ",".join(sorted(set(blocked_reasons)))
    risk_level = "low" if loader_ready == "true" else "medium"

    notes = (
        "v0.8d preflight only; future loader integration must remain manifest-first and read-only."
        if loader_ready == "true"
        else "v0.8d preflight blocked; use fallback and keep existing design/runtime sources."
    )

    return {
        "runtime_domain": runtime_domain,
        "artifact_id": artifact_id,
        "runtime_path": runtime_path,
        "manifest_status": manifest_status,
        "json_parse_status": json_parse_status,
        "checksum_status": checksum_status,
        "schema_fingerprint_status": schema_status,
        "content_fingerprint_status": content_status,
        "proposed_loader_scope": proposed_loader_scope,
        "proposed_read_mode": proposed_read_mode,
        "proposed_failure_mode": proposed_failure_mode,
        "proposed_fallback_source": fallback,
        "proposed_godot_touchpoints": TOUCHPOINTS,
        "risk_level": risk_level,
        "loader_ready": loader_ready,
        "blocked_reason": blocked_reason,
        "notes": notes,
    }


def write_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUTPUT_FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_md(path: Path, rows: list[dict[str, str]]) -> None:
    ready = [row for row in rows if row["loader_ready"] == "true"]
    blocked = [row for row in rows if row["loader_ready"] == "false"]
    lines = [
        "# Runtime Loader Preflight Report",
        "",
        "- Stage: v0.8d loader preflight (analysis only)",
        f"- Records: {len(rows)}",
        f"- loader_ready=true: {len(ready)}",
        f"- blocked: {len(blocked)}",
        "",
        "## Preflight Rows",
        "",
        "| Runtime Domain | Artifact ID | Manifest Status | JSON Parse | Checksum | Schema FP | Content FP | Read Mode | Failure Mode | Loader Ready | Blocked Reason |",
        "|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    for row in rows:
        lines.append(
            f"| {row['runtime_domain']} | {row['artifact_id']} | {row['manifest_status']} | {row['json_parse_status']} | {row['checksum_status']} | {row['schema_fingerprint_status']} | {row['content_fingerprint_status']} | {row['proposed_read_mode']} | {row['proposed_failure_mode']} | {row['loader_ready']} | {row['blocked_reason']} |"
        )
    lines.extend(
        [
            "",
            "## Scope Boundary",
            "",
            "- v0.8d is preflight only and does not implement any Godot loader.",
            "- proposed_godot_touchpoints are future_touchpoint_only suggestions.",
            "- No .gd runtime files are created or modified in this stage.",
            "",
        ]
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    try:
        args = parse_args()
        runtime_dir = Path(args.runtime_dir)
        manifest_path = Path(args.manifest)
        manifest_report_path = Path(args.manifest_report)
        card_pool_path = Path(args.card_pool)
        battle_reward_path = Path(args.battle_reward)
        out_tsv = Path(args.out)
        out_md = Path(args.out_md)

        for required_path in [manifest_path, manifest_report_path, card_pool_path, battle_reward_path]:
            require_file(required_path)

        runtime_dir_ok, runtime_dir_blocked = check_runtime_dir(runtime_dir)
        manifest = parse_manifest(manifest_path)
        manifest_files = manifest.get("files")
        if not isinstance(manifest_files, list):
            raise ValueError("runtime_manifest.json files must be list")

        manifest_report_rows = read_tsv(manifest_report_path)
        manifest_report_index = index_manifest_report(manifest_report_rows)

        rows: list[dict[str, str]] = []
        for item in manifest_files:
            if not isinstance(item, dict):
                raise ValueError("runtime_manifest.json contains non-object file entry")
            rows.append(evaluate_file_entry(item, manifest_report_index, runtime_dir_ok, runtime_dir_blocked))

        rows = sorted(rows, key=lambda row: row["runtime_path"])
        write_tsv(out_tsv, rows)
        write_md(out_md, rows)
    except (FileNotFoundError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}")
        return 1

    print(f"Wrote {out_tsv} and {out_md} with {len(rows)} preflight rows.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
