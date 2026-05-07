#!/usr/bin/env python3
"""Generate runtime manifest/checksum/rollback reports for Content Engine v0.8c."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

from runtime_exporter import ALLOWED_RUNTIME_FILENAMES, RUNTIME_DIR, WRITE_RESULT_TSV


MANIFEST_JSON = "runtime_manifest.json"
MANIFEST_REPORT_TSV = "generated_runtime_export_manifest_report.tsv"
MANIFEST_REPORT_MD = "generated_runtime_export_manifest_report.md"
ROLLBACK_REPORT_MD = "generated_runtime_export_rollback_report.md"
MANIFEST_VERSION = "v0.8c"
GENERATED_BY = "tools/content_engine/runtime_export_manifest.py"
RUNTIME_PREFIX = "data/runtime/content_engine/"
RESTRICTED_PREFIXES = ("scripts/", "scenes/", "data/story_battles/")
REPORT_FIELDS = [
    "runtime_domain",
    "artifact_id",
    "runtime_path",
    "file_exists",
    "file_size_bytes",
    "sha256",
    "schema_fingerprint",
    "content_fingerprint",
    "record_count",
    "field_count",
    "manifest_status",
    "blocked_reason",
    "notes",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate runtime manifest/checksum/rollback reports.")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--runtime-dir", default=str(RUNTIME_DIR))
    parser.add_argument("--write-result", default=f"data/design/{WRITE_RESULT_TSV}")
    parser.add_argument("--out-manifest", default=f"data/runtime/content_engine/{MANIFEST_JSON}")
    parser.add_argument("--out-report", default=f"data/design/{MANIFEST_REPORT_TSV}")
    parser.add_argument("--out-report-md", default=f"data/design/{MANIFEST_REPORT_MD}")
    parser.add_argument("--out-rollback-md", default=f"data/design/{ROLLBACK_REPORT_MD}")
    return parser.parse_args()


def require_file(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(f"Missing required input: {path}")


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def parse_non_negative_int(value: object, *, field_name: str, row_key: str) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{row_key}: {field_name} must be integer, got {value!r}") from exc
    if parsed < 0:
        raise ValueError(f"{row_key}: {field_name} must be non-negative, got {parsed}")
    return parsed


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_runtime_path(runtime_path: str, runtime_dir: Path) -> Path:
    path_obj = Path(runtime_path)
    if path_obj.is_absolute():
        raise ValueError(f"runtime_path must be relative: {runtime_path}")
    if not runtime_path.startswith(RUNTIME_PREFIX):
        raise ValueError(f"runtime_path must be under {RUNTIME_PREFIX}: {runtime_path}")
    if any(runtime_path.startswith(prefix) for prefix in RESTRICTED_PREFIXES):
        raise ValueError(f"runtime_path points to restricted prefix: {runtime_path}")
    if path_obj.parent.as_posix() != runtime_dir.as_posix():
        raise ValueError(f"runtime_path parent must equal {runtime_dir}: {runtime_path}")
    if path_obj.name not in ALLOWED_RUNTIME_FILENAMES:
        raise ValueError(f"runtime_path file is not allowlisted: {runtime_path}")
    return path_obj


def load_runtime_payload(runtime_file: Path) -> dict[str, object]:
    with runtime_file.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict):
        raise ValueError(f"Runtime file must be JSON object: {runtime_file}")
    return payload


def build_manifest_and_report(write_rows: list[dict[str, str]], runtime_dir: Path, write_result_path: Path):
    written_rows = [row for row in write_rows if (row.get("actual_write_status") or "").strip() == "written"]
    failed_rows = [row for row in write_rows if (row.get("actual_write_status") or "").strip() == "failed_validation"]
    if len(written_rows) != 2:
        raise ValueError(f"write result must contain exactly 2 written rows, got {len(written_rows)}")
    if failed_rows:
        raise ValueError(f"write result failed_validation must be 0, got {len(failed_rows)}")

    files: list[dict[str, object]] = []
    report_rows: list[dict[str, str]] = []

    for row in written_rows:
        domain = (row.get("runtime_domain") or "").strip()
        artifact_id = (row.get("artifact_id") or "").strip()
        row_key = f"{domain}/{artifact_id}"
        runtime_path = (row.get("planned_runtime_path") or "").strip()
        path_obj = validate_runtime_path(runtime_path, runtime_dir)
        runtime_file = Path(runtime_path)
        exists = runtime_file.exists()

        blocked_reason = ""
        notes = (row.get("notes") or "").strip()
        manifest_status = "registered"
        file_size = ""
        file_sha = ""
        schema_fingerprint = (row.get("schema_fingerprint") or "").strip()
        content_fingerprint = (row.get("content_fingerprint") or "").strip()
        record_count = ""
        field_count = ""

        if not exists:
            manifest_status = "blocked"
            blocked_reason = "runtime_file_missing"
            notes = f"{notes} runtime_file_missing".strip()
        else:
            payload = load_runtime_payload(runtime_file)
            file_size_int = runtime_file.stat().st_size
            file_sha = sha256_file(runtime_file)
            file_size = str(file_size_int)
            payload_schema = str(payload.get("schema_fingerprint") or "")
            payload_content = str(payload.get("content_fingerprint") or "")
            if schema_fingerprint != payload_schema or content_fingerprint != payload_content:
                manifest_status = "blocked"
                blocked_reason = "fingerprint_mismatch"
            schema_fingerprint = payload_schema
            content_fingerprint = payload_content
            record_count_int = parse_non_negative_int(payload.get("record_count", 0), field_name="record_count", row_key=row_key)
            field_count_int = parse_non_negative_int(payload.get("field_count", 0), field_name="field_count", row_key=row_key)
            record_count = str(record_count_int)
            field_count = str(field_count_int)

            files.append(
                {
                    "runtime_domain": str(payload.get("runtime_domain") or domain),
                    "artifact_id": str(payload.get("artifact_id") or artifact_id),
                    "runtime_path": runtime_path,
                    "file_name": path_obj.name,
                    "file_size_bytes": file_size_int,
                    "sha256": file_sha,
                    "schema_fingerprint": payload_schema,
                    "content_fingerprint": payload_content,
                    "record_count": record_count_int,
                    "field_count": field_count_int,
                    "export_version": str(payload.get("export_version") or ""),
                    "generated_at": str(payload.get("generated_at") or ""),
                    "source_design_path": str(payload.get("source_design_path") or ""),
                }
            )

        report_rows.append(
            {
                "runtime_domain": domain,
                "artifact_id": artifact_id,
                "runtime_path": runtime_path,
                "file_exists": "true" if exists else "false",
                "file_size_bytes": file_size,
                "sha256": file_sha,
                "schema_fingerprint": schema_fingerprint,
                "content_fingerprint": content_fingerprint,
                "record_count": record_count,
                "field_count": field_count,
                "manifest_status": manifest_status,
                "blocked_reason": blocked_reason,
                "notes": notes,
            }
        )

    files_sorted = sorted(files, key=lambda item: str(item["file_name"]))
    report_sorted = sorted(report_rows, key=lambda item: item["runtime_path"])

    manifest = {
        "manifest_version": MANIFEST_VERSION,
        "generated_by": GENERATED_BY,
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "source_write_result_path": write_result_path.as_posix(),
        "runtime_root": runtime_dir.as_posix(),
        "allowed_runtime_files": sorted(ALLOWED_RUNTIME_FILENAMES),
        "files": files_sorted,
    }

    return manifest, report_sorted


def write_report_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=REPORT_FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_report_md(path: Path, rows: list[dict[str, str]]) -> None:
    registered = [row for row in rows if row["manifest_status"] == "registered"]
    blocked = [row for row in rows if row["manifest_status"] == "blocked"]
    lines = [
        "# Runtime Export Manifest Report",
        "",
        f"- Rows: {len(rows)}",
        f"- Registered: {len(registered)}",
        f"- Blocked: {len(blocked)}",
        "",
        "## Manifest Rows",
        "",
        "| Runtime Domain | Artifact ID | Runtime Path | Exists | File Size | Manifest Status | Blocked Reason |",
        "|---|---|---|---|---|---|---|",
    ]
    for row in rows:
        lines.append(
            f"| {row['runtime_domain']} | {row['artifact_id']} | {row['runtime_path']} | {row['file_exists']} | {row['file_size_bytes']} | {row['manifest_status']} | {row['blocked_reason']} |"
        )
    lines.append("")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def write_rollback_md(path: Path, manifest: dict[str, object]) -> None:
    files = manifest.get("files", [])
    runtime_paths = [str(item.get("runtime_path") or "") for item in files if isinstance(item, dict)]
    lines = [
        "# Runtime Export Rollback Report",
        "",
        "## Runtime Files Written",
        "",
    ]
    for runtime_path in runtime_paths:
        lines.append(f"- {runtime_path}")
    lines.extend(
        [
            "",
            "## Rollback Steps",
            "",
            "删除以下文件即可回滚本次 runtime content 写入：",
            "",
        ]
    )
    for runtime_path in runtime_paths:
        lines.append(f"- {runtime_path}")
    lines.extend(
        [
            "",
            "`runtime_manifest.json` 是否必要：",
            "- 对于严格回滚到 v0.8b 写入前状态，建议一并删除 `data/runtime/content_engine/runtime_manifest.json`。",
            "- 如果只想保留审计记录，可保留 manifest，但它将描述已删除文件并在 validator 中失败。",
            "",
            "## Re-run Commands",
            "",
            "回滚后可按顺序重新执行：",
            "",
            "1. no-write: `python3 tools/content_engine/runtime_exporter.py`",
            "2. no-write validator: `python3 tools/content_engine/runtime_exporter_validator.py`",
            "3. guarded-write: `python3 tools/content_engine/runtime_exporter.py --write-runtime --confirm-runtime-export`",
            "4. guarded-write validator: `python3 tools/content_engine/runtime_exporter_validator.py --allow-runtime-files`",
            "5. manifest: `python3 tools/content_engine/runtime_export_manifest.py`",
            "6. manifest validator: `python3 tools/content_engine/runtime_export_manifest_validator.py`",
            "",
            "## Scope Boundary",
            "",
            "当前 rollback 流程只涉及 runtime content files，不涉及 Godot loader（当前尚未接入 loader）。",
            "",
        ]
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    try:
        args = parse_args()
        runtime_dir = Path(args.runtime_dir)
        write_result_path = Path(args.write_result)
        out_manifest = Path(args.out_manifest)
        out_report = Path(args.out_report)
        out_report_md = Path(args.out_report_md)
        out_rollback_md = Path(args.out_rollback_md)

        require_file(write_result_path)
        write_rows = read_tsv(write_result_path)

        for required_file in sorted(ALLOWED_RUNTIME_FILENAMES):
            require_file(runtime_dir / required_file)

        manifest, report_rows = build_manifest_and_report(write_rows, runtime_dir, write_result_path)

        out_manifest.parent.mkdir(parents=True, exist_ok=True)
        out_manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        write_report_tsv(out_report, report_rows)
        write_report_md(out_report_md, report_rows)
        write_rollback_md(out_rollback_md, manifest)
    except (FileNotFoundError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}")
        return 1

    print(f"Wrote {out_manifest}, {out_report}, {out_report_md}, and {out_rollback_md}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
