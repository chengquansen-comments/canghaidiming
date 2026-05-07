#!/usr/bin/env python3
"""Generate Content Engine v0.6d content package approval gate tables."""

from __future__ import annotations

import argparse
import csv
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

from content_package_manifest_generator import MANIFEST_FIELDS, MANIFEST_FILENAME
from content_validator_orchestrator import SUMMARY_TSV


APPROVAL_FIELDS = [
    "approval_id",
    "package_version",
    "artifact_id",
    "artifact_path",
    "artifact_type",
    "source_stage",
    "validator_status",
    "validator_warning_count",
    "validator_error_count",
    "approval_status",
    "approved_for_export",
    "approval_required",
    "approval_reason",
    "risk_level",
    "export_scope",
    "export_blockers",
    "required_actions",
    "waiver_flags",
    "source_manifest_checksum",
    "source_validator_log_path",
    "notes",
]
APPROVAL_TSV = "generated_content_package_approval.tsv"
APPROVAL_MD = "generated_content_package_approval_report.md"
PACKAGE_VERSION = "v0.6d"


@dataclass(frozen=True)
class ManifestArtifact:
    artifact_id: str
    artifact_path: str
    artifact_type: str
    source_stage: str
    checksum_sha256: str
    export_scope: str
    export_blockers: tuple[str, ...]


@dataclass(frozen=True)
class ValidatorInfo:
    status: str
    warning_count: int
    error_count: int
    log_path: str
    notes: str


@dataclass(frozen=True)
class ApprovalRow:
    approval_id: str
    package_version: str
    artifact_id: str
    artifact_path: str
    artifact_type: str
    source_stage: str
    validator_status: str
    validator_warning_count: int
    validator_error_count: int
    approval_status: str
    approved_for_export: bool
    approval_required: bool
    approval_reason: str
    risk_level: str
    export_scope: str
    export_blockers: tuple[str, ...]
    required_actions: tuple[str, ...]
    waiver_flags: tuple[str, ...]
    source_manifest_checksum: str
    source_validator_log_path: str
    notes: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate Content Engine v0.6d content package approval table.")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--out", default=f"data/design/{APPROVAL_TSV}")
    parser.add_argument("--out-md", default=f"data/design/{APPROVAL_MD}")
    return parser.parse_args()


def read_manifest(path: Path) -> list[ManifestArtifact]:
    if not path.exists():
        raise FileNotFoundError(f"Missing required manifest: {path}")
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        fieldnames = reader.fieldnames or []
        missing = [field for field in MANIFEST_FIELDS if field not in fieldnames]
        if missing:
            raise ValueError("Manifest is missing required columns: " + ", ".join(missing))
        rows: list[ManifestArtifact] = []
        for row in reader:
            rows.append(
                ManifestArtifact(
                    artifact_id=require_value(row, "artifact_id"),
                    artifact_path=require_value(row, "artifact_path"),
                    artifact_type=require_value(row, "artifact_type"),
                    source_stage=require_value(row, "source_stage"),
                    checksum_sha256=require_value(row, "checksum_sha256"),
                    export_scope=require_value(row, "export_scope"),
                    export_blockers=tuple(split_csv(row.get("export_blockers", ""))),
                )
            )
    if not rows:
        raise ValueError(f"Manifest is empty: {path}")
    return rows


def read_validator_summary(path: Path) -> dict[str, ValidatorInfo]:
    if not path.exists():
        raise FileNotFoundError(f"Missing required validator summary: {path}")
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        mapping: dict[str, ValidatorInfo] = {}
        for row in reader:
            status = require_value(row, "status")
            warning_count = as_int(require_value(row, "warning_count"), "warning_count")
            error_count = as_int(require_value(row, "error_count"), "error_count")
            log_path = require_value(row, "log_path")
            notes = (row.get("notes") or "").strip()
            targets = split_csv(require_value(row, "target_artifact_id"))
            for artifact_id in targets:
                mapping[artifact_id] = ValidatorInfo(status, warning_count, error_count, log_path, notes)
    if not mapping:
        raise ValueError(f"Validator summary is empty: {path}")
    return mapping


def require_value(row: dict[str, str], field_name: str) -> str:
    value = (row.get(field_name) or "").strip()
    if not value:
        raise ValueError(f"Missing required field: {field_name}")
    return value


def as_int(value: str, field_name: str) -> int:
    try:
        return int(value)
    except ValueError as exc:
        raise ValueError(f"Field {field_name} must be integer, got: {value!r}") from exc


def split_csv(value: str) -> list[str]:
    return [part.strip() for part in value.split(",") if part.strip()]


def determine_validator_info(artifact: ManifestArtifact, validators: dict[str, ValidatorInfo]) -> tuple[str, int, int, str, str]:
    info = validators.get(artifact.artifact_id)
    if info is not None:
        return info.status, info.warning_count, info.error_count, info.log_path, ""
    if artifact.artifact_type == "source_config":
        fallback = validators.get("generated_battle_slot_plan")
        log_path = fallback.log_path if fallback is not None else ""
        return "SOURCE_ONLY", 0, 0, log_path, "No direct validator row; source config reviewed indirectly via progression_validator."
    return "NOT_VALIDATED", 0, 0, "", "No direct validator mapping found in generated_validator_summary.tsv."


def determine_approval_status(validator_status: str, artifact: ManifestArtifact) -> str:
    if validator_status == "FAIL":
        return "blocked"
    if validator_status == "WARN":
        return "waiver_required"
    if validator_status == "PASS":
        return "pending_review"
    if validator_status == "SOURCE_ONLY":
        return "pending_review" if artifact.artifact_type == "source_config" else "blocked"
    return "blocked"


def determine_risk_level(artifact: ManifestArtifact, validator_status: str) -> str:
    if validator_status == "FAIL":
        return "blocked"
    if validator_status == "WARN":
        return "high"
    if artifact.artifact_id == "progression_numeric_config_v1_3":
        return "medium"
    if artifact.artifact_id in {
        "generated_battle_slot_plan",
        "generated_enemy_deck_requirement",
        "generated_route_progression_curve",
        "generated_operation_node_requirement",
    }:
        return "low"
    if artifact.artifact_id in {"generated_card_pool", "generated_enemy_deck_sets", "generated_enemy_deck_skeleton"}:
        return "high"
    if artifact.artifact_id in {"generated_narrative_node_plan", "generated_route_gate_plan"}:
        return "high"
    return "medium"


def determine_approval_reason(artifact: ManifestArtifact, validator_status: str) -> str:
    if validator_status == "WARN":
        return "validator_warn_requires_manual_waiver"
    if validator_status == "FAIL":
        return "validator_fail_blocks_export"
    if validator_status == "SOURCE_ONLY":
        return "source_config_requires_manual_review"
    if validator_status in {"NOT_VALIDATED", "NOT_RUN"}:
        return "design_layer_only"
    if validator_status == "PASS":
        return "validator_pass_but_runtime_schema_not_defined"
    return "runtime_exporter_not_implemented"


def build_export_blockers(artifact: ManifestArtifact, validator_status: str) -> tuple[str, ...]:
    blockers = list(artifact.export_blockers)
    extras = ["approval_not_granted"]
    if validator_status == "WARN":
        extras.append("validator_warning_unresolved")
    if "runtime_schema_not_defined" not in blockers:
        extras.append("runtime_schema_not_defined")
    if "runtime_exporter_not_implemented" not in blockers:
        extras.append("runtime_exporter_not_implemented")
    if "needs_manual_review" not in blockers:
        extras.append("needs_manual_review")
    for blocker in extras:
        if blocker not in blockers:
            blockers.append(blocker)
    return tuple(blockers)


def build_required_actions(artifact: ManifestArtifact, validator_status: str) -> tuple[str, ...]:
    actions = ["manual_review_required", "define_runtime_schema", "add_runtime_export_mapping", "approve_before_v0_7"]
    if validator_status == "WARN":
        actions.append("resolve_validator_warning")
        actions.append("manual_waiver_required")
    if artifact.artifact_id in {"generated_card_pool", "generated_enemy_deck_sets"}:
        actions.append("sampler_validation_required")
    deduped: list[str] = []
    for action in actions:
        if action not in deduped:
            deduped.append(action)
    return tuple(deduped)


def build_waiver_flags(validator_status: str) -> tuple[str, ...]:
    return ("waiver_required",) if validator_status == "WARN" else ()


def build_notes(base_note: str, validator_info: ValidatorInfo | None, artifact: ManifestArtifact) -> str:
    notes: list[str] = []
    if base_note:
        notes.append(base_note)
    if validator_info is not None and validator_info.notes:
        notes.append(f"Validator summary note: {validator_info.notes}.")
    if artifact.artifact_type in {"narrative_plan", "route_gate_plan", "generated_table", "reward_plan"}:
        notes.append("Design-layer artifact only; runtime export still requires explicit approval gate and exporter implementation.")
    return " ".join(notes)


def build_rows(manifest_rows: list[ManifestArtifact], validators: dict[str, ValidatorInfo]) -> list[ApprovalRow]:
    rows: list[ApprovalRow] = []
    for artifact in manifest_rows:
        validator_info = validators.get(artifact.artifact_id)
        status, warn_count, err_count, log_path, base_note = determine_validator_info(artifact, validators)
        approval_status = determine_approval_status(status, artifact)
        rows.append(
            ApprovalRow(
                approval_id=f"approval_{artifact.artifact_id}",
                package_version=PACKAGE_VERSION,
                artifact_id=artifact.artifact_id,
                artifact_path=artifact.artifact_path,
                artifact_type=artifact.artifact_type,
                source_stage=artifact.source_stage,
                validator_status=status,
                validator_warning_count=warn_count,
                validator_error_count=err_count,
                approval_status=approval_status,
                approved_for_export=False,
                approval_required=True,
                approval_reason=determine_approval_reason(artifact, status),
                risk_level=determine_risk_level(artifact, status),
                export_scope=artifact.export_scope,
                export_blockers=build_export_blockers(artifact, status),
                required_actions=build_required_actions(artifact, status),
                waiver_flags=build_waiver_flags(status),
                source_manifest_checksum=artifact.checksum_sha256,
                source_validator_log_path=log_path,
                notes=build_notes(base_note, validator_info, artifact),
            )
        )
    return rows


def write_tsv(path: Path, rows: list[ApprovalRow]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=APPROVAL_FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    "approval_id": row.approval_id,
                    "package_version": row.package_version,
                    "artifact_id": row.artifact_id,
                    "artifact_path": row.artifact_path,
                    "artifact_type": row.artifact_type,
                    "source_stage": row.source_stage,
                    "validator_status": row.validator_status,
                    "validator_warning_count": str(row.validator_warning_count),
                    "validator_error_count": str(row.validator_error_count),
                    "approval_status": row.approval_status,
                    "approved_for_export": "true" if row.approved_for_export else "false",
                    "approval_required": "true" if row.approval_required else "false",
                    "approval_reason": row.approval_reason,
                    "risk_level": row.risk_level,
                    "export_scope": row.export_scope,
                    "export_blockers": ",".join(row.export_blockers),
                    "required_actions": ",".join(row.required_actions),
                    "waiver_flags": ",".join(row.waiver_flags),
                    "source_manifest_checksum": row.source_manifest_checksum,
                    "source_validator_log_path": row.source_validator_log_path,
                    "notes": row.notes,
                }
            )


def build_report(rows: list[ApprovalRow]) -> str:
    counts = Counter(row.approval_status for row in rows)
    lines = [
        "# Content Package Approval Report",
        "",
        f"- Package version: {PACKAGE_VERSION}",
        f"- Artifact count: {len(rows)}",
        f"- Approved for export count: {sum(1 for row in rows if row.approved_for_export)}",
        f"- Pending review count: {counts.get('pending_review', 0)}",
        f"- Waiver required count: {counts.get('waiver_required', 0)}",
        f"- Blocked count: {counts.get('blocked', 0)}",
        "",
        "## Approval Summary",
        "",
        "| Status | Count |",
        "|---|---:|",
    ]
    for status in ["approved", "pending_review", "waiver_required", "blocked", "rejected"]:
        lines.append(f"| {status} | {counts.get(status, 0)} |")
    lines.extend([
        "",
        "## Artifact Approval Table",
        "",
        "| Artifact | Validator | Approval | Risk | Approved for Export | Required Actions |",
        "|---|---|---|---|---|---|",
    ])
    for row in rows:
        lines.append(
            f"| {row.artifact_id} | {row.validator_status} | {row.approval_status} | {row.risk_level} | {'true' if row.approved_for_export else 'false'} | {', '.join(row.required_actions)} |"
        )
    lines.extend([
        "",
        "## Waiver Required",
        "",
        "- generated_enemy_deck_skeleton",
        "- generated_enemy_deck_sets",
        "- WARN artifact cannot enter runtime export without manual waiver.",
        "",
        "## Runtime Export Rule",
        "",
        "- v0.7 runtime exporter must only consume approved_for_export=true artifacts.",
        "- Current v0.6d generator does not approve any artifact automatically.",
        "- Runtime exporter must not directly scan data/design/generated_*.tsv.",
        "",
    ])
    return "\n".join(lines)


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def main() -> int:
    try:
        args = parse_args()
        design_dir = Path(args.design_dir)
        out_path = Path(args.out)
        out_md = Path(args.out_md)
        manifest_rows = read_manifest(design_dir / MANIFEST_FILENAME)
        validators = read_validator_summary(design_dir / SUMMARY_TSV)
        rows = build_rows(manifest_rows, validators)
        write_tsv(out_path, rows)
        write_text(out_md, build_report(rows))
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}")
        return 1

    print(f"Wrote {out_path} and {out_md} with {len(rows)} artifacts.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
