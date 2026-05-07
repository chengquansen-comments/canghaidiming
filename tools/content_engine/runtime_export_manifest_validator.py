#!/usr/bin/env python3
"""验证 Content Engine v0.8c 的 runtime manifest/checksum/rollback 输出。"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from dataclasses import dataclass, field
from pathlib import Path

from runtime_export_manifest import (
    MANIFEST_JSON,
    MANIFEST_REPORT_MD,
    MANIFEST_REPORT_TSV,
    REPORT_FIELDS,
    ROLLBACK_REPORT_MD,
)
from runtime_exporter import ALLOWED_RUNTIME_FILENAMES, RUNTIME_DIR, WRITE_RESULT_FIELDS, WRITE_RESULT_TSV


RESTRICTED_PREFIXES = ("scripts/", "scenes/", "data/story_battles/")
OPTIONAL_RUNTIME_FILES = {"runtime_loader_config.json"}


@dataclass
class ValidationReport:
    passes: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    failures: list[str] = field(default_factory=list)

    def pass_(self, message: str) -> None:
        self.passes.append(message)

    def warn(self, message: str) -> None:
        self.warnings.append(message)

    def fail(self, message: str) -> None:
        self.failures.append(message)

    def ok(self) -> bool:
        return not self.failures

    def format(self) -> str:
        lines: list[str] = []
        lines.extend([f"PASS: {item}" for item in self.passes])
        lines.extend([f"WARN: {item}" for item in self.warnings])
        lines.extend([f"FAIL: {item}" for item in self.failures])
        lines.append("RESULT: PASS" if self.ok() else "RESULT: FAIL")
        return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate runtime manifest outputs.")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--runtime-dir", default=str(RUNTIME_DIR))
    parser.add_argument("--manifest", default=f"data/runtime/content_engine/{MANIFEST_JSON}")
    parser.add_argument("--write-result", default=f"data/design/{WRITE_RESULT_TSV}")
    parser.add_argument("--report", default=f"data/design/{MANIFEST_REPORT_TSV}")
    parser.add_argument("--report-md", default=f"data/design/{MANIFEST_REPORT_MD}")
    parser.add_argument("--rollback-md", default=f"data/design/{ROLLBACK_REPORT_MD}")
    return parser.parse_args()


def read_tsv(path: Path, required_fields: list[str]) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        fieldnames = reader.fieldnames or []
        missing = [field for field in required_fields if field not in fieldnames]
        if missing:
            raise ValueError(f"{path} is missing required columns: " + ", ".join(missing))
        return list(reader)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_non_negative_int(value: object, *, field_name: str, row_key: str) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{row_key}: {field_name} must be integer, got {value!r}") from exc
    if parsed < 0:
        raise ValueError(f"{row_key}: {field_name} must be non-negative, got {parsed}")
    return parsed


def validate_write_result(path: Path, report: ValidationReport) -> list[dict[str, str]]:
    rows = read_tsv(path, WRITE_RESULT_FIELDS)
    written = [row for row in rows if (row.get("actual_write_status") or "").strip() == "written"]
    failed = [row for row in rows if (row.get("actual_write_status") or "").strip() == "failed_validation"]
    if len(written) != 2:
        report.fail(f"write_result written count must be 2, got {len(written)}")
    else:
        report.pass_("write_result written count is 2.")
    if failed:
        report.fail(f"write_result failed_validation count must be 0, got {len(failed)}")
    else:
        report.pass_("write_result failed_validation count is 0.")
    return rows


def validate_runtime_directory(runtime_dir: Path, report: ValidationReport) -> None:
    if not runtime_dir.exists() or not runtime_dir.is_dir():
        report.fail(f"runtime directory missing: {runtime_dir}")
        return
    names = {entry.name for entry in runtime_dir.iterdir() if entry.is_file()}
    allowed = set(ALLOWED_RUNTIME_FILENAMES) | {MANIFEST_JSON} | OPTIONAL_RUNTIME_FILES
    extra = names - allowed
    if extra:
        report.fail("runtime directory has extra files: " + ", ".join(sorted(extra)))
    missing = allowed - names
    if missing:
        report.fail("runtime directory missing required files: " + ", ".join(sorted(missing)))
    if not extra and not missing:
        report.pass_("runtime directory contains only allowlisted files (including optional config).")


def validate_manifest(
    manifest_path: Path,
    runtime_dir: Path,
    write_rows: list[dict[str, str]],
    report_rows: list[dict[str, str]],
    report: ValidationReport,
) -> None:
    if not manifest_path.exists():
        report.fail(f"Missing manifest: {manifest_path}")
        return

    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        report.fail(f"manifest JSON parse failed: {exc}")
        return

    if not isinstance(manifest, dict):
        report.fail("manifest must be JSON object")
        return

    files = manifest.get("files")
    if not isinstance(files, list):
        report.fail("manifest.files must be a list")
        return

    allowed_list = manifest.get("allowed_runtime_files")
    if sorted(ALLOWED_RUNTIME_FILENAMES) != sorted(allowed_list or []):
        report.fail("manifest.allowed_runtime_files mismatch")

    if len(files) != 2:
        report.fail(f"manifest files count must be 2, got {len(files)}")

    write_written_map = {
        (row["runtime_domain"], row["artifact_id"]): row
        for row in write_rows
        if (row.get("actual_write_status") or "").strip() == "written"
    }
    report_map = {(row["runtime_domain"], row["artifact_id"]): row for row in report_rows}

    listed_files: set[str] = set()
    for item in files:
        if not isinstance(item, dict):
            report.fail("manifest.files entries must be objects")
            continue
        domain = str(item.get("runtime_domain") or "")
        artifact_id = str(item.get("artifact_id") or "")
        row_key = f"{domain}/{artifact_id}"
        runtime_path = str(item.get("runtime_path") or "")
        path_obj = Path(runtime_path)
        if path_obj.is_absolute():
            report.fail(f"manifest runtime_path must be relative: {row_key}")
            continue
        if path_obj.parent.as_posix() != runtime_dir.as_posix():
            report.fail(f"manifest runtime_path not under runtime dir: {row_key}")
        if any(runtime_path.startswith(prefix) for prefix in RESTRICTED_PREFIXES):
            report.fail(f"manifest runtime_path points restricted prefix: {row_key}")

        file_name = str(item.get("file_name") or "")
        if file_name not in ALLOWED_RUNTIME_FILENAMES:
            report.fail(f"manifest file_name not allowlisted: {row_key}")
            continue
        listed_files.add(file_name)

        runtime_file = runtime_dir / file_name
        if not runtime_file.exists():
            report.fail(f"runtime file missing: {runtime_file}")
            continue

        try:
            payload = json.loads(runtime_file.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            report.fail(f"runtime file JSON parse failed: {runtime_file} ({exc})")
            continue

        actual_sha = sha256_file(runtime_file)
        actual_size = runtime_file.stat().st_size
        if str(item.get("sha256") or "") != actual_sha:
            report.fail(f"sha256 mismatch: {row_key}")
        if parse_non_negative_int(item.get("file_size_bytes", -1), field_name="file_size_bytes", row_key=row_key) != actual_size:
            report.fail(f"file_size_bytes mismatch: {row_key}")

        payload_schema = str(payload.get("schema_fingerprint") or "")
        payload_content = str(payload.get("content_fingerprint") or "")
        if str(item.get("schema_fingerprint") or "") != payload_schema:
            report.fail(f"manifest schema_fingerprint mismatch with runtime JSON: {row_key}")
        if str(item.get("content_fingerprint") or "") != payload_content:
            report.fail(f"manifest content_fingerprint mismatch with runtime JSON: {row_key}")

        record_count = parse_non_negative_int(item.get("record_count", -1), field_name="record_count", row_key=row_key)
        field_count = parse_non_negative_int(item.get("field_count", -1), field_name="field_count", row_key=row_key)
        payload_record_count = parse_non_negative_int(payload.get("record_count", -1), field_name="payload.record_count", row_key=row_key)
        payload_field_count = parse_non_negative_int(payload.get("field_count", -1), field_name="payload.field_count", row_key=row_key)
        if record_count != payload_record_count:
            report.fail(f"record_count mismatch: {row_key}")
        if field_count != payload_field_count:
            report.fail(f"field_count mismatch: {row_key}")

        if (domain, artifact_id) not in write_written_map:
            report.fail(f"manifest row is not present in write_result written rows: {row_key}")
        if (domain, artifact_id) not in report_map:
            report.fail(f"manifest row is not present in manifest report rows: {row_key}")

    if listed_files != set(ALLOWED_RUNTIME_FILENAMES):
        report.fail(
            "manifest listed files mismatch: "
            f"expected={sorted(ALLOWED_RUNTIME_FILENAMES)} actual={sorted(listed_files)}"
        )
    else:
        report.pass_("manifest lists exactly card_pool.json and battle_reward.json.")


def validate_report_files(report_tsv: Path, report_md: Path, rollback_md: Path, report: ValidationReport) -> list[dict[str, str]]:
    if not report_tsv.exists():
        report.fail(f"Missing manifest report TSV: {report_tsv}")
        return []
    rows = read_tsv(report_tsv, REPORT_FIELDS)
    if len(rows) != 2:
        report.fail(f"manifest report TSV rows must be 2, got {len(rows)}")

    if not report_md.exists():
        report.fail(f"Missing manifest report MD: {report_md}")
    else:
        text = report_md.read_text(encoding="utf-8")
        for section in ["Runtime 导出 Manifest 报告", "Manifest 明细"]:
            if section not in text:
                report.fail(f"manifest report markdown missing section: {section}")

    if not rollback_md.exists():
        report.fail(f"Missing rollback report MD: {rollback_md}")
    else:
        text = rollback_md.read_text(encoding="utf-8")
        for token in [
            "已写入 Runtime 文件",
            "回滚步骤",
            "runtime_manifest.json",
            "no-write",
            "guarded-write",
            "重跑命令",
            "尚未接入 loader",
        ]:
            if token not in text:
                report.fail(f"rollback report missing required content: {token}")

    return rows


def main() -> int:
    args = parse_args()
    report = ValidationReport()

    runtime_dir = Path(args.runtime_dir)
    manifest_path = Path(args.manifest)
    write_result_path = Path(args.write_result)
    report_tsv = Path(args.report)
    report_md = Path(args.report_md)
    rollback_md = Path(args.rollback_md)

    try:
        write_rows = validate_write_result(write_result_path, report)
        validate_runtime_directory(runtime_dir, report)
        report_rows = validate_report_files(report_tsv, report_md, rollback_md, report)
        validate_manifest(manifest_path, runtime_dir, write_rows, report_rows, report)
    except ValueError as exc:
        report.fail(str(exc))

    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
