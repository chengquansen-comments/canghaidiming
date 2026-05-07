#!/usr/bin/env python3
"""Validate Content Engine v0.6a content package manifest (design-layer only)."""

from __future__ import annotations

import argparse
import csv
import hashlib
from dataclasses import dataclass, field
from pathlib import Path

from content_package_manifest_generator import (
    ARTIFACT_SPECS,
    CORE_ARTIFACT_IDS,
    MANIFEST_FIELDS,
    MANIFEST_FILENAME,
    MANIFEST_ID,
    PACKAGE_VERSION,
)


SPEC_BY_ID = {spec.artifact_id: spec for spec in ARTIFACT_SPECS}
DEPENDENCY_RULES = {
    "generated_route_gate_plan": {
        "generated_narrative_node_plan",
        "generated_operation_node_plan",
        "generated_battle_reward_plan",
    },
    "generated_enemy_deck_sets": {
        "generated_enemy_deck_skeleton",
        "generated_card_pool",
    },
    "generated_battle_reward_plan": {
        "generated_enemy_deck_sets",
        "generated_route_progression_curve",
    },
    "generated_operation_node_plan": {
        "generated_operation_node_requirement",
    },
    "generated_narrative_node_plan": {
        "generated_operation_node_plan",
        "generated_battle_reward_plan",
    },
}


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
        lines.extend([f"PASS: {message}" for message in self.passes])
        lines.extend([f"WARN: {message}" for message in self.warnings])
        lines.extend([f"FAIL: {message}" for message in self.failures])
        lines.append("RESULT: PASS" if self.ok() else "RESULT: FAIL")
        return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate Content Engine v0.6a content package manifest.")
    parser.add_argument("--design-dir", default="data/design")
    return parser.parse_args()


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def count_rows(path: Path) -> int:
    return len(read_tsv(path))


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def as_int(value: str, default: int = 0) -> int:
    try:
        return int((value or "").strip())
    except ValueError:
        return default


def as_bool(value: str) -> bool:
    return (value or "").strip().lower() in {"1", "true", "yes"}


def split_csv_tokens(value: str) -> set[str]:
    return {part.strip() for part in (value or "").split(",") if part.strip()}


def validate(design_dir: Path) -> ValidationReport:
    report = ValidationReport()
    manifest_path = design_dir / MANIFEST_FILENAME
    if not manifest_path.exists():
        report.fail(f"Missing required file: {manifest_path}")
        return report
    report.pass_(f"Found {manifest_path}")

    rows = read_tsv(manifest_path)
    if not rows:
        report.fail(f"{MANIFEST_FILENAME} is empty.")
        return report

    validate_columns(rows, report)
    validate_manifest_constants(rows, report)
    id_map = validate_artifact_coverage(rows, report)
    validate_core_paths_and_hashes(id_map, report)
    validate_validator_status(id_map, report)
    validate_runtime_ready(id_map, report)
    validate_export_blockers(id_map, report)
    validate_dependency_integrity(id_map, report)
    validate_script_paths(id_map, report)
    return report


def validate_columns(rows: list[dict[str, str]], report: ValidationReport) -> None:
    first_keys = list(rows[0].keys())
    if first_keys == MANIFEST_FIELDS:
        report.pass_("Manifest column order matches v0.6a specification.")
    else:
        report.fail("Manifest columns do not match required v0.6a field order.")


def validate_manifest_constants(rows: list[dict[str, str]], report: ValidationReport) -> None:
    bad_manifest = [row.get("artifact_id", "") for row in rows if row.get("manifest_id") != MANIFEST_ID]
    bad_version = [row.get("artifact_id", "") for row in rows if row.get("package_version") != PACKAGE_VERSION]
    if bad_manifest:
        report.fail("Rows with invalid manifest_id: " + ", ".join(sorted(bad_manifest)))
    else:
        report.pass_(f"All rows use manifest_id={MANIFEST_ID}.")
    if bad_version:
        report.fail("Rows with invalid package_version: " + ", ".join(sorted(bad_version)))
    else:
        report.pass_(f"All rows use package_version={PACKAGE_VERSION}.")


def validate_artifact_coverage(rows: list[dict[str, str]], report: ValidationReport) -> dict[str, dict[str, str]]:
    artifact_ids = [row.get("artifact_id", "") for row in rows]
    duplicates = sorted({artifact_id for artifact_id in artifact_ids if artifact_ids.count(artifact_id) > 1 and artifact_id})
    if duplicates:
        report.fail("Duplicate artifact_id values detected: " + ", ".join(duplicates))
    else:
        report.pass_("artifact_id values are unique.")

    missing = sorted(CORE_ARTIFACT_IDS - set(artifact_ids))
    if missing:
        report.fail("Missing required core artifacts: " + ", ".join(missing))
    else:
        report.pass_("Manifest includes all 13 core artifacts.")

    extras = sorted(set(artifact_ids) - CORE_ARTIFACT_IDS)
    if extras:
        report.warn("Manifest includes extra non-core artifacts: " + ", ".join(extras))

    return {row.get("artifact_id", ""): row for row in rows if row.get("artifact_id", "")}


def validate_core_paths_and_hashes(
    id_map: dict[str, dict[str, str]],
    report: ValidationReport,
) -> None:
    for artifact_id, row in sorted(id_map.items()):
        artifact_path = Path(row.get("artifact_path", ""))
        if not artifact_path.exists():
            report.fail(f"artifact_path does not exist for {artifact_id}: {artifact_path}")
            continue

        actual_row_count = count_rows(artifact_path)
        manifest_row_count = as_int(row.get("row_count", ""), -1)
        if manifest_row_count == actual_row_count:
            report.pass_(f"row_count matches for {artifact_id}.")
        else:
            report.fail(
                f"row_count mismatch for {artifact_id}: manifest={manifest_row_count}, actual={actual_row_count}."
            )

        actual_checksum = sha256_file(artifact_path)
        manifest_checksum = (row.get("checksum_sha256") or "").strip()
        if manifest_checksum == actual_checksum:
            report.pass_(f"checksum_sha256 matches for {artifact_id}.")
        else:
            report.fail(f"checksum_sha256 mismatch for {artifact_id}.")


def validate_validator_status(
    id_map: dict[str, dict[str, str]],
    report: ValidationReport,
) -> None:
    for artifact_id, spec in sorted(SPEC_BY_ID.items()):
        row = id_map.get(artifact_id)
        if row is None:
            continue
        status = (row.get("validator_status") or "").strip()
        if spec.artifact_type == "source_config":
            if status == "SOURCE_ONLY":
                report.pass_(f"source_config validator_status is SOURCE_ONLY for {artifact_id}.")
            else:
                report.warn(f"source_config validator_status for {artifact_id} is {status}, expected SOURCE_ONLY.")
            continue
        if status == "FAIL":
            report.fail(f"Generated artifact must not be FAIL in manifest: {artifact_id}")
        else:
            report.pass_(f"Generated artifact validator_status is acceptable for {artifact_id}: {status or 'EMPTY'}.")


def validate_runtime_ready(
    id_map: dict[str, dict[str, str]],
    report: ValidationReport,
) -> None:
    for artifact_id, spec in sorted(SPEC_BY_ID.items()):
        if spec.artifact_type == "source_config":
            continue
        row = id_map.get(artifact_id)
        if row is None:
            continue
        ready = as_bool(row.get("is_runtime_ready", "false"))
        notes = (row.get("notes") or "").lower()
        if ready and "runtime_ready_exception" not in notes:
            report.fail(f"Generated artifact should not be runtime-ready yet: {artifact_id}")
        else:
            report.pass_(f"is_runtime_ready is correctly blocked for {artifact_id}.")


def validate_export_blockers(
    id_map: dict[str, dict[str, str]],
    report: ValidationReport,
) -> None:
    for artifact_id, spec in sorted(SPEC_BY_ID.items()):
        if spec.artifact_type == "source_config":
            continue
        row = id_map.get(artifact_id)
        if row is None:
            continue
        blockers = split_csv_tokens(row.get("export_blockers", ""))
        if blockers:
            report.pass_(f"export_blockers is populated for {artifact_id}.")
        else:
            report.fail(f"Generated artifact must declare export_blockers: {artifact_id}")


def validate_dependency_integrity(
    id_map: dict[str, dict[str, str]],
    report: ValidationReport,
) -> None:
    known_ids = set(id_map.keys())
    for artifact_id, row in sorted(id_map.items()):
        deps = split_csv_tokens(row.get("depends_on_artifacts", ""))
        missing = sorted(deps - known_ids)
        if missing:
            report.fail(f"{artifact_id} depends on unknown artifacts: {', '.join(missing)}")
        else:
            report.pass_(f"depends_on_artifacts references resolve for {artifact_id}.")

    for artifact_id, required_deps in sorted(DEPENDENCY_RULES.items()):
        row = id_map.get(artifact_id)
        if row is None:
            continue
        deps = split_csv_tokens(row.get("depends_on_artifacts", ""))
        missing = sorted(required_deps - deps)
        if missing:
            report.fail(f"{artifact_id} is missing required dependencies: {', '.join(missing)}")
        else:
            report.pass_(f"Required dependency rule satisfied for {artifact_id}.")


def validate_script_paths(
    id_map: dict[str, dict[str, str]],
    report: ValidationReport,
) -> None:
    for artifact_id, row in sorted(id_map.items()):
        generator_script = (row.get("generator_script") or "").strip()
        validator_script = (row.get("validator_script") or "").strip()

        if generator_script and generator_script != "manual_source":
            if Path(generator_script).exists():
                report.pass_(f"generator_script exists for {artifact_id}.")
            else:
                report.fail(f"generator_script does not exist for {artifact_id}: {generator_script}")

        if validator_script:
            if Path(validator_script).exists():
                report.pass_(f"validator_script exists for {artifact_id}.")
            else:
                report.fail(f"validator_script does not exist for {artifact_id}: {validator_script}")

def main() -> int:
    args = parse_args()
    design_dir = Path(args.design_dir)
    report = validate(design_dir)
    print(report.format())
    return 0 if report.ok() else 1


if __name__ == "__main__":
    raise SystemExit(main())
