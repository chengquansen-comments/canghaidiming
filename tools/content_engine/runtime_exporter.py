#!/usr/bin/env python3
"""Content Engine v0.8b runtime exporter with guarded write mode."""

from __future__ import annotations

import argparse
import csv
import json
import os
from pathlib import Path
from datetime import datetime, timezone

from runtime_export_diff_report import OUTPUT_TSV as DIFF_REPORT_TSV


OUTPUT_TSV = "generated_runtime_exporter_plan.tsv"
OUTPUT_MD = "generated_runtime_exporter_plan.md"
WRITE_RESULT_TSV = "generated_runtime_exporter_write_result.tsv"
WRITE_RESULT_MD = "generated_runtime_exporter_write_result.md"
OUTPUT_FIELDS = [
    "runtime_domain",
    "artifact_id",
    "source_design_path",
    "planned_runtime_path",
    "export_mode",
    "export_action",
    "diff_status",
    "planned_record_count",
    "planned_field_count",
    "schema_fingerprint",
    "content_fingerprint",
    "write_enabled",
    "would_write",
    "actual_write_status",
    "blocked_reason",
    "notes",
]
WRITE_RESULT_FIELDS = [
    "runtime_domain",
    "artifact_id",
    "planned_runtime_path",
    "write_requested",
    "confirm_runtime_export",
    "write_enabled",
    "would_write",
    "actual_write_status",
    "bytes_written",
    "schema_fingerprint",
    "content_fingerprint",
    "blocked_reason",
    "notes",
]
RUNTIME_PREFIX = "data/runtime/content_engine/"
RUNTIME_DIR = Path("data/runtime/content_engine")
ALLOWED_RUNTIME_FILENAMES = {"card_pool.json", "battle_reward.json"}
RESTRICTED_PREFIXES = ("scripts/", "scenes/", "data/story_battles/")
ALLOWED_RISK = {"low", "medium"}
EXPORT_VERSION = "v0.8b"
GENERATED_BY = "tools/content_engine/runtime_exporter.py"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate v0.8b runtime exporter plan and guarded write result.")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--diff-report", default=f"data/design/{DIFF_REPORT_TSV}")
    parser.add_argument("--out", default=f"data/design/{OUTPUT_TSV}")
    parser.add_argument("--out-md", default=f"data/design/{OUTPUT_MD}")
    parser.add_argument("--write-result-out", default=f"data/design/{WRITE_RESULT_TSV}")
    parser.add_argument("--write-result-md", default=f"data/design/{WRITE_RESULT_MD}")
    parser.add_argument("--preview", action="store_true", help="Preview mode (default behavior).")
    parser.add_argument("--write-runtime", action="store_true", help="Enable guarded runtime write mode.")
    parser.add_argument(
        "--confirm-runtime-export",
        action="store_true",
        help="Required confirmation flag for runtime write mode.",
    )
    return parser.parse_args()


def parse_bool(value: str) -> bool:
    lowered = (value or "").strip().lower()
    if lowered in {"true", "1", "yes"}:
        return True
    if lowered in {"false", "0", "no"}:
        return False
    raise ValueError(f"Invalid bool value: {value!r}")


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def require_file(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(f"Missing required input: {path}")


def parse_non_negative_int(value: str, *, field_name: str, row_key: str) -> int:
    raw = (value or "").strip()
    try:
        parsed = int(raw)
    except ValueError as exc:
        raise ValueError(f"{row_key}: {field_name} must be an integer, got {raw!r}") from exc
    if parsed < 0:
        raise ValueError(f"{row_key}: {field_name} must be non-negative, got {parsed}")
    return parsed


def is_allowed_candidate(row: dict[str, str]) -> bool:
    row_key = f"{(row.get('runtime_domain') or '').strip()}/{(row.get('artifact_id') or '').strip()}"
    try:
        parse_non_negative_int(row.get("planned_record_count") or "0", field_name="planned_record_count", row_key=row_key)
        parse_non_negative_int(row.get("planned_field_count") or "0", field_name="planned_field_count", row_key=row_key)
    except ValueError:
        return False
    return (
        parse_bool(row.get("would_export", "false"))
        and (row.get("export_action") or "").strip() == "planned_create"
        and (row.get("diff_status") or "").strip() == "new_runtime_file_planned"
        and (row.get("risk_level") or "").strip() in ALLOWED_RISK
        and not (row.get("blocked_reason") or "").strip()
        and (row.get("planned_runtime_path") or "").strip().startswith(RUNTIME_PREFIX)
        and bool((row.get("schema_fingerprint") or "").strip())
        and bool((row.get("content_fingerprint") or "").strip())
    )


def validate_candidate_for_write(row: dict[str, str]) -> str:
    if not is_allowed_candidate(row):
        return (row.get("blocked_reason") or "").strip() or "not_export_candidate"
    planned_path = (row.get("planned_runtime_path") or "").strip()
    path_obj = Path(planned_path)
    if path_obj.is_absolute():
        return "planned_runtime_path_must_be_relative"
    if any(planned_path.startswith(prefix) for prefix in RESTRICTED_PREFIXES):
        return "planned_runtime_path_restricted_prefix"
    if path_obj.parent.as_posix() != RUNTIME_DIR.as_posix():
        return "planned_runtime_path_not_direct_child"
    if path_obj.name not in ALLOWED_RUNTIME_FILENAMES:
        return "runtime_filename_not_in_allowlist"
    row_key = f"{(row.get('runtime_domain') or '').strip()}/{(row.get('artifact_id') or '').strip()}"
    try:
        parse_non_negative_int(row.get("planned_record_count") or "0", field_name="planned_record_count", row_key=row_key)
        parse_non_negative_int(row.get("planned_field_count") or "0", field_name="planned_field_count", row_key=row_key)
    except ValueError:
        return "invalid_planned_count"
    if not (row.get("schema_fingerprint") or "").strip():
        return "missing_schema_fingerprint"
    if not (row.get("content_fingerprint") or "").strip():
        return "missing_content_fingerprint"
    return ""


def ensure_safe_runtime_target(planned_runtime_path: str) -> Path:
    planned = Path(planned_runtime_path)
    if planned.is_absolute():
        raise ValueError("planned_runtime_path must be relative")
    if planned.parent.as_posix() != RUNTIME_DIR.as_posix():
        raise ValueError("planned_runtime_path must be direct child of data/runtime/content_engine/")
    if planned.name not in ALLOWED_RUNTIME_FILENAMES:
        raise ValueError("planned_runtime_path filename is not in allowlist")
    runtime_root_resolved = RUNTIME_DIR.resolve()
    target_resolved = planned.resolve()
    if os.path.commonpath([str(runtime_root_resolved), str(target_resolved)]) != str(runtime_root_resolved):
        raise ValueError("planned_runtime_path escapes runtime directory")
    return planned


def build_runtime_payload(row: dict[str, str]) -> dict[str, object]:
    row_key = f"{row['runtime_domain']}/{row['artifact_id']}"
    planned_record_count = parse_non_negative_int(
        row.get("planned_record_count") or "0",
        field_name="planned_record_count",
        row_key=row_key,
    )
    planned_field_count = parse_non_negative_int(
        row.get("planned_field_count") or "0",
        field_name="planned_field_count",
        row_key=row_key,
    )
    return {
        "runtime_domain": row["runtime_domain"],
        "artifact_id": row["artifact_id"],
        "export_version": EXPORT_VERSION,
        "source_design_path": row["source_design_path"],
        "schema_fingerprint": row["schema_fingerprint"],
        "content_fingerprint": row["content_fingerprint"],
        "record_count": planned_record_count,
        "field_count": planned_field_count,
        "records": [],
        "generated_by": GENERATED_BY,
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "notes": "v0.8b writes guarded runtime scaffold content only; business records are not materialized in this stage.",
    }


def atomic_write_runtime_json(target: Path, payload: dict[str, object]) -> int:
    target.parent.mkdir(parents=True, exist_ok=True)
    temp_path = target.with_suffix(target.suffix + ".tmp")
    json_text = json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=False) + "\n"
    temp_path.write_text(json_text, encoding="utf-8")
    # Validate JSON is parseable before replacing target file.
    json.loads(temp_path.read_text(encoding="utf-8"))
    runtime_root_resolved = RUNTIME_DIR.resolve()
    target_resolved = target.resolve()
    if os.path.commonpath([str(runtime_root_resolved), str(target_resolved)]) != str(runtime_root_resolved):
        temp_path.unlink(missing_ok=True)
        raise ValueError("target path escapes runtime directory")
    os.replace(temp_path, target)
    return len(json_text.encode("utf-8"))


def build_rows(
    diff_rows: list[dict[str, str]],
    *,
    export_mode: str,
    write_requested: bool,
    confirm_runtime_export: bool,
) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    write_enabled = write_requested and confirm_runtime_export
    for row in diff_rows:
        allowed = is_allowed_candidate(row)
        validation_blocked_reason = validate_candidate_for_write(row)
        if write_requested and not confirm_runtime_export and allowed:
            write_blocked_reason = "missing_confirm_runtime_export"
        else:
            write_blocked_reason = validation_blocked_reason
        would_write = write_enabled and not write_blocked_reason
        if would_write:
            actual_status = "not_written"
        elif write_requested:
            actual_status = "blocked"
        else:
            actual_status = "not_written"
        blocked_reason = write_blocked_reason if (write_requested or not allowed) else ""
        rows.append(
            {
                "runtime_domain": (row.get("runtime_domain") or "").strip(),
                "artifact_id": (row.get("artifact_id") or "").strip(),
                "source_design_path": (row.get("source_design_path") or "").strip(),
                "planned_runtime_path": (row.get("planned_runtime_path") or "").strip(),
                "export_mode": export_mode,
                "export_action": "planned_create" if allowed else "blocked",
                "diff_status": (row.get("diff_status") or "").strip(),
                "planned_record_count": (row.get("planned_record_count") or "0").strip(),
                "planned_field_count": (row.get("planned_field_count") or "0").strip(),
                "schema_fingerprint": (row.get("schema_fingerprint") or "").strip(),
                "content_fingerprint": (row.get("content_fingerprint") or "").strip(),
                "write_enabled": "true" if write_enabled else "false",
                "would_write": "true" if would_write else "false",
                "actual_write_status": actual_status,
                "blocked_reason": blocked_reason,
                "notes": (row.get("notes") or "").strip(),
            }
        )
    return rows


def write_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=OUTPUT_FIELDS,
            delimiter="\t",
            lineterminator="\n",
            extrasaction="ignore",
        )
        writer.writeheader()
        writer.writerows(rows)


def write_md(
    path: Path,
    rows: list[dict[str, str]],
    *,
    write_runtime_requested: bool,
    confirm_runtime_export: bool,
) -> None:
    allowed = [row for row in rows if row["export_action"] == "planned_create"]
    blocked = [row for row in rows if row["export_action"] == "blocked"]
    write_enabled = write_runtime_requested and confirm_runtime_export
    written = [row for row in rows if row["actual_write_status"] == "written"]
    lines = [
        "# Runtime Exporter Plan",
        "",
        "- Stage: v0.8b guarded write mode",
        "- Runtime export implemented: guarded_write",
        f"- Runtime files written: {len(written)}",
        f"- Records: {len(rows)}",
        f"- Allowed candidates: {len(allowed)}",
        f"- Blocked records: {len(blocked)}",
        f"- write_runtime_requested: {str(write_runtime_requested).lower()}",
        f"- confirm_runtime_export: {str(confirm_runtime_export).lower()}",
        f"- write_enabled: {str(write_enabled).lower()}",
    ]
    if write_runtime_requested and not confirm_runtime_export:
        lines.append("- blocked_reason applied to writable candidates: missing_confirm_runtime_export")
    lines.extend(
        [
            "",
            "## Exporter Plan Summary",
            "",
            "| Runtime Domain | Artifact ID | Export Action | Would Write | Actual Write Status | Blocked Reason |",
            "|---|---|---|---|---|---|",
        ]
    )
    for row in rows:
        lines.append(
            f"| {row['runtime_domain']} | {row['artifact_id']} | {row['export_action']} | {row['would_write']} | {row['actual_write_status']} | {row['blocked_reason']} |"
        )
    lines.extend(
        [
            "",
            "## Safety Notes",
            "",
            "- Default no-write mode remains the safe default.",
            "- Runtime write requires both --write-runtime and --confirm-runtime-export.",
            "- Guarded write allowlist: card_pool.json, battle_reward.json.",
            "- Exporter does not modify scripts/, scenes/, data/story_battles/, or Godot runtime logic.",
            "",
        ]
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def execute_guarded_write(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    write_rows: list[dict[str, str]] = []
    for row in rows:
        result_row = {
            "runtime_domain": row["runtime_domain"],
            "artifact_id": row["artifact_id"],
            "planned_runtime_path": row["planned_runtime_path"],
            "write_requested": row["write_requested"],
            "confirm_runtime_export": row["confirm_runtime_export"],
            "write_enabled": row["write_enabled"],
            "would_write": row["would_write"],
            "actual_write_status": row["actual_write_status"],
            "bytes_written": "",
            "schema_fingerprint": row["schema_fingerprint"],
            "content_fingerprint": row["content_fingerprint"],
            "blocked_reason": row["blocked_reason"],
            "notes": row["notes"],
        }
        if row["would_write"] != "true":
            write_rows.append(result_row)
            continue
        try:
            target = ensure_safe_runtime_target(row["planned_runtime_path"])
            payload = build_runtime_payload(row)
            bytes_written = atomic_write_runtime_json(target, payload)
        except (OSError, ValueError, json.JSONDecodeError) as exc:
            result_row["actual_write_status"] = "failed_validation"
            result_row["blocked_reason"] = f"write_failed:{exc}"
            result_row["bytes_written"] = ""
            result_row["notes"] = f"{row['notes']} guarded_write_failed"
            row["actual_write_status"] = "failed_validation"
            row["blocked_reason"] = result_row["blocked_reason"]
            write_rows.append(result_row)
            continue
        result_row["actual_write_status"] = "written"
        result_row["bytes_written"] = str(bytes_written)
        row["actual_write_status"] = "written"
        row["blocked_reason"] = ""
        write_rows.append(result_row)
    return write_rows


def write_write_result_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=WRITE_RESULT_FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_write_result_md(path: Path, rows: list[dict[str, str]]) -> None:
    written = [row for row in rows if row["actual_write_status"] == "written"]
    blocked = [row for row in rows if row["actual_write_status"] == "blocked"]
    failed = [row for row in rows if row["actual_write_status"] == "failed_validation"]
    not_written = [row for row in rows if row["actual_write_status"] == "not_written"]
    lines = [
        "# Runtime Exporter Write Result",
        "",
        f"- Records: {len(rows)}",
        f"- written: {len(written)}",
        f"- blocked: {len(blocked)}",
        f"- failed_validation: {len(failed)}",
        f"- not_written: {len(not_written)}",
        "",
        "## Write Result Summary",
        "",
        "| Runtime Domain | Artifact ID | Would Write | Actual Write Status | Bytes Written | Blocked Reason |",
        "|---|---|---|---|---|---|",
    ]
    for row in rows:
        lines.append(
            f"| {row['runtime_domain']} | {row['artifact_id']} | {row['would_write']} | {row['actual_write_status']} | {row['bytes_written']} | {row['blocked_reason']} |"
        )
    lines.extend(
        [
            "",
            "## Notes",
            "",
            "- v0.8b writes guarded runtime scaffold content only.",
            "- Runtime records may be empty in this stage; business data mapping remains out of scope.",
            "",
        ]
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    try:
        args = parse_args()
        diff_report = Path(args.diff_report)
        out_tsv = Path(args.out)
        out_md = Path(args.out_md)
        write_result_out = Path(args.write_result_out)
        write_result_md = Path(args.write_result_md)
        require_file(diff_report)
        diff_rows = read_tsv(diff_report)
        rows = build_rows(
            diff_rows,
            export_mode="guarded_write" if args.write_runtime else "preview",
            write_requested=args.write_runtime,
            confirm_runtime_export=args.confirm_runtime_export,
        )
        for row in rows:
            row["write_requested"] = "true" if args.write_runtime else "false"
            row["confirm_runtime_export"] = "true" if args.confirm_runtime_export else "false"
        write_rows = execute_guarded_write(rows)
        write_tsv(out_tsv, rows)
        write_md(
            out_md,
            rows,
            write_runtime_requested=args.write_runtime,
            confirm_runtime_export=args.confirm_runtime_export,
        )
        write_write_result_tsv(write_result_out, write_rows)
        write_write_result_md(write_result_md, write_rows)
        if args.write_runtime and not args.confirm_runtime_export:
            print("write blocked: missing_confirm_runtime_export")
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}")
        return 1
    print(
        f"Wrote {out_tsv}, {out_md}, {write_result_out}, and {write_result_md} "
        f"with {len(rows)} exporter rows."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
