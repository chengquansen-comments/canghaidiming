#!/usr/bin/env python3
"""Generate Content Engine v0.7b runtime export dry-run outputs."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path

from content_package_approval_generator import APPROVAL_TSV
from content_package_manifest_generator import MANIFEST_FILENAME
from content_validator_orchestrator import SUMMARY_TSV
from runtime_schema_proposal_generator import OUTPUT_TSV as SCHEMA_TSV


OUTPUT_TSV = "generated_runtime_export_dry_run.tsv"
OUTPUT_MD = "generated_runtime_export_dry_run.md"
OUTPUT_FIELDS = [
    "dry_run_id",
    "runtime_domain",
    "runtime_artifact_name",
    "target_path",
    "source_artifacts",
    "required_approval_status",
    "required_validator_status",
    "requires_waiver_clearance",
    "approval_check",
    "validator_check",
    "waiver_check",
    "schema_check",
    "export_allowed_now",
    "would_export",
    "blocked",
    "block_reasons",
    "source_schema_ids",
    "source_approval_ids",
    "source_validator_ids",
    "notes",
]

RUNTIME_DOMAINS = [
    "enemy_deck",
    "card_pool",
    "battle_reward",
    "operation_node",
    "narrative_node",
    "route_gate",
    "package_manifest",
]
TARGET_PREFIX = "data/runtime/content_engine/"


@dataclass(frozen=True)
class SchemaRow:
    schema_id: str
    runtime_domain: str
    runtime_artifact_name: str
    target_path: str
    source_artifacts: tuple[str, ...]
    required_approval_status: str
    required_validator_status: str
    requires_waiver_clearance: bool
    export_allowed_now: bool
    notes: str


@dataclass(frozen=True)
class ApprovalRow:
    approval_id: str
    artifact_id: str
    approval_status: str
    approved_for_export: bool
    waiver_flags: tuple[str, ...]


@dataclass(frozen=True)
class ValidatorRow:
    validator_id: str
    status: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate Content Engine v0.7b runtime export dry-run.")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--out", default=f"data/design/{OUTPUT_TSV}")
    parser.add_argument("--out-md", default=f"data/design/{OUTPUT_MD}")
    parser.add_argument(
        "--runtime-exporter-implemented",
        action="store_true",
        help="Future extension switch. v0.7b default remains false.",
    )
    return parser.parse_args()


def parse_bool(value: str) -> bool:
    lowered = (value or "").strip().lower()
    if lowered in {"true", "1", "yes"}:
        return True
    if lowered in {"false", "0", "no"}:
        return False
    raise ValueError(f"Invalid boolean value: {value!r}")


def split_csv(value: str) -> tuple[str, ...]:
    return tuple(part.strip() for part in (value or "").split(",") if part.strip())


def require_file(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(f"Missing required input: {path}")


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def load_manifest_ids(rows: list[dict[str, str]]) -> set[str]:
    ids: set[str] = set()
    for row in rows:
        artifact_id = (row.get("artifact_id") or "").strip()
        if artifact_id:
            ids.add(artifact_id)
    return ids


def load_approval_map(rows: list[dict[str, str]]) -> dict[str, ApprovalRow]:
    approvals: dict[str, ApprovalRow] = {}
    for row in rows:
        artifact_id = (row.get("artifact_id") or "").strip()
        if not artifact_id:
            continue
        approvals[artifact_id] = ApprovalRow(
            approval_id=(row.get("approval_id") or "").strip(),
            artifact_id=artifact_id,
            approval_status=(row.get("approval_status") or "").strip(),
            approved_for_export=parse_bool(row.get("approved_for_export", "false")),
            waiver_flags=split_csv(row.get("waiver_flags", "")),
        )
    return approvals


def choose_validator_status(existing: str, incoming: str) -> str:
    order = {"FAIL": 3, "WARN": 2, "PASS": 1}
    if not existing:
        return incoming
    if order.get(incoming, 0) > order.get(existing, 0):
        return incoming
    return existing


def load_validator_map(rows: list[dict[str, str]]) -> dict[str, list[ValidatorRow]]:
    mapping: dict[str, list[ValidatorRow]] = {}
    status_seen: dict[tuple[str, str], str] = {}
    for row in rows:
        validator_id = (row.get("validator_id") or "").strip()
        status = (row.get("status") or "").strip()
        targets = split_csv(row.get("target_artifact_id", ""))
        for artifact_id in targets:
            key = (artifact_id, validator_id)
            chosen = choose_validator_status(status_seen.get(key, ""), status)
            status_seen[key] = chosen
    for (artifact_id, validator_id), status in status_seen.items():
        mapping.setdefault(artifact_id, []).append(ValidatorRow(validator_id=validator_id, status=status))
    return mapping


def load_schema_rows(rows: list[dict[str, str]]) -> list[SchemaRow]:
    grouped: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        schema_id = (row.get("schema_id") or "").strip()
        if not schema_id:
            continue
        grouped.setdefault(schema_id, []).append(row)

    result: list[SchemaRow] = []
    for schema_id in sorted(grouped):
        first = grouped[schema_id][0]
        result.append(
            SchemaRow(
                schema_id=schema_id,
                runtime_domain=(first.get("runtime_domain") or "").strip(),
                runtime_artifact_name=(first.get("runtime_artifact_name") or "").strip(),
                target_path=(first.get("target_path") or "").strip(),
                source_artifacts=split_csv(first.get("source_artifacts", "")),
                required_approval_status=(first.get("required_approval_status") or "").strip(),
                required_validator_status=(first.get("required_validator_status") or "").strip(),
                requires_waiver_clearance=parse_bool(first.get("requires_waiver_clearance", "false")),
                export_allowed_now=parse_bool(first.get("export_allowed_now", "false")),
                notes=(first.get("notes") or "").strip(),
            )
        )
    return result


def evaluate_approval_check(schema: SchemaRow, approvals: dict[str, ApprovalRow]) -> tuple[str, list[str], list[str]]:
    missing = [artifact_id for artifact_id in schema.source_artifacts if artifact_id not in approvals]
    if missing:
        approval_ids = [approvals[artifact_id].approval_id for artifact_id in schema.source_artifacts if artifact_id in approvals]
        return "FAIL", missing, sorted(set(approval_ids))

    bad_rows = [
        row
        for row in (approvals[artifact_id] for artifact_id in schema.source_artifacts)
        if row.approval_status != schema.required_approval_status or not row.approved_for_export
    ]
    if bad_rows:
        approval_ids = sorted({row.approval_id for row in bad_rows if row.approval_id})
        return "FAIL", [], approval_ids

    approval_ids = sorted({approvals[artifact_id].approval_id for artifact_id in schema.source_artifacts if approvals[artifact_id].approval_id})
    return "PASS", [], approval_ids


def evaluate_validator_check(schema: SchemaRow, validator_map: dict[str, list[ValidatorRow]]) -> tuple[str, list[str], list[str]]:
    statuses: list[str] = []
    validator_ids: set[str] = set()
    missing: list[str] = []
    for artifact_id in schema.source_artifacts:
        rows = validator_map.get(artifact_id, [])
        if not rows:
            missing.append(artifact_id)
            continue
        for row in rows:
            statuses.append(row.status)
            validator_ids.add(row.validator_id)

    if missing:
        return "NOT_FOUND", missing, sorted(validator_ids)
    if any(status == "FAIL" for status in statuses):
        return "FAIL", [], sorted(validator_ids)
    if any(status == "WARN" for status in statuses):
        return "WARN", [], sorted(validator_ids)
    if statuses and all(status == schema.required_validator_status for status in statuses):
        return "PASS", [], sorted(validator_ids)
    return "FAIL", [], sorted(validator_ids)


def evaluate_waiver_check(schema: SchemaRow, approvals: dict[str, ApprovalRow]) -> str:
    if not schema.requires_waiver_clearance:
        return "NOT_REQUIRED"
    for artifact_id in schema.source_artifacts:
        row = approvals.get(artifact_id)
        if row is None:
            return "FAIL"
        if row.approval_status != "approved":
            return "FAIL"
        if row.waiver_flags:
            return "FAIL"
    return "PASS"


def evaluate_schema_check(schema: SchemaRow) -> str:
    if not schema.schema_id:
        return "FAIL"
    if schema.runtime_domain not in RUNTIME_DOMAINS:
        return "FAIL"
    if not schema.runtime_artifact_name:
        return "FAIL"
    if not schema.target_path:
        return "FAIL"
    if not schema.source_artifacts:
        return "FAIL"
    if schema.required_approval_status != "approved":
        return "FAIL"
    if schema.required_validator_status != "PASS":
        return "FAIL"
    return "PASS"


def runtime_exporter_implemented(enabled_flag: bool) -> bool:
    return enabled_flag


def build_block_reasons(
    schema: SchemaRow,
    manifest_ids: set[str],
    approvals: dict[str, ApprovalRow],
    approval_check: str,
    validator_check: str,
    waiver_check: str,
    schema_check: str,
    exporter_ready: bool,
) -> list[str]:
    reasons: list[str] = []
    for artifact_id in schema.source_artifacts:
        if artifact_id not in manifest_ids:
            reasons.append("source_artifact_missing_in_manifest")
            break

    if approval_check == "FAIL":
        reasons.append("approval_not_granted")
        if any(artifact_id not in approvals for artifact_id in schema.source_artifacts):
            reasons.append("approval_record_missing")
        if any(
            artifact_id in approvals and not approvals[artifact_id].approved_for_export for artifact_id in schema.source_artifacts
        ):
            reasons.append("approved_for_export_false")

    if validator_check == "WARN":
        reasons.append("validator_warning_unresolved")
    if validator_check in {"FAIL", "NOT_FOUND"}:
        reasons.append("validator_not_pass")

    if waiver_check == "FAIL":
        reasons.append("waiver_required")

    if schema_check == "FAIL":
        reasons.append("runtime_schema_proposal_only")

    if not schema.export_allowed_now:
        reasons.append("export_allowed_now_false")

    if not exporter_ready:
        reasons.append("runtime_exporter_not_implemented")

    if not reasons:
        reasons.append("runtime_schema_proposal_only")
    return sorted(set(reasons))


def build_dry_run_rows(
    schemas: list[SchemaRow],
    manifest_ids: set[str],
    approvals: dict[str, ApprovalRow],
    validator_map: dict[str, list[ValidatorRow]],
    exporter_ready: bool,
) -> list[dict[str, str]]:
    by_domain = {schema.runtime_domain: schema for schema in schemas}
    rows: list[dict[str, str]] = []
    for domain in RUNTIME_DOMAINS:
        schema = by_domain.get(domain)
        if schema is None:
            rows.append(
                {
                    "dry_run_id": f"dry_run_{domain}",
                    "runtime_domain": domain,
                    "runtime_artifact_name": "",
                    "target_path": "",
                    "source_artifacts": "",
                    "required_approval_status": "approved",
                    "required_validator_status": "PASS",
                    "requires_waiver_clearance": "false",
                    "approval_check": "FAIL",
                    "validator_check": "NOT_FOUND",
                    "waiver_check": "NOT_REQUIRED",
                    "schema_check": "FAIL",
                    "export_allowed_now": "false",
                    "would_export": "false",
                    "blocked": "true",
                    "block_reasons": "runtime_schema_proposal_only,export_allowed_now_false,runtime_exporter_not_implemented",
                    "source_schema_ids": "",
                    "source_approval_ids": "",
                    "source_validator_ids": "",
                    "notes": "Missing schema proposal row for runtime domain.",
                }
            )
            continue

        approval_check, missing_approval_artifacts, source_approval_ids = evaluate_approval_check(schema, approvals)
        validator_check, missing_validator_artifacts, source_validator_ids = evaluate_validator_check(schema, validator_map)
        waiver_check = evaluate_waiver_check(schema, approvals)
        schema_check = evaluate_schema_check(schema)
        block_reasons = build_block_reasons(
            schema=schema,
            manifest_ids=manifest_ids,
            approvals=approvals,
            approval_check=approval_check,
            validator_check=validator_check,
            waiver_check=waiver_check,
            schema_check=schema_check,
            exporter_ready=exporter_ready,
        )
        would_export = (
            schema_check == "PASS"
            and schema.export_allowed_now
            and approval_check == "PASS"
            and validator_check == "PASS"
            and waiver_check in {"PASS", "NOT_REQUIRED"}
            and schema.target_path.startswith(TARGET_PREFIX)
            and exporter_ready
        )

        note_parts = [schema.notes]
        if missing_approval_artifacts:
            note_parts.append("Missing approval rows: " + ",".join(sorted(missing_approval_artifacts)))
        if missing_validator_artifacts:
            note_parts.append("Missing validator rows: " + ",".join(sorted(missing_validator_artifacts)))

        rows.append(
            {
                "dry_run_id": f"dry_run_{domain}",
                "runtime_domain": domain,
                "runtime_artifact_name": schema.runtime_artifact_name,
                "target_path": schema.target_path,
                "source_artifacts": ",".join(schema.source_artifacts),
                "required_approval_status": schema.required_approval_status,
                "required_validator_status": schema.required_validator_status,
                "requires_waiver_clearance": "true" if schema.requires_waiver_clearance else "false",
                "approval_check": approval_check,
                "validator_check": validator_check,
                "waiver_check": waiver_check,
                "schema_check": schema_check,
                "export_allowed_now": "true" if schema.export_allowed_now else "false",
                "would_export": "true" if would_export else "false",
                "blocked": "false" if would_export else "true",
                "block_reasons": ",".join(block_reasons),
                "source_schema_ids": schema.schema_id,
                "source_approval_ids": ",".join(source_approval_ids),
                "source_validator_ids": ",".join(source_validator_ids),
                "notes": " ".join(part for part in note_parts if part),
            }
        )
    return rows


def write_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUTPUT_FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def aggregate_block_reasons(rows: list[dict[str, str]]) -> list[tuple[str, int]]:
    counts: dict[str, int] = {}
    for row in rows:
        for reason in split_csv(row.get("block_reasons", "")):
            counts[reason] = counts.get(reason, 0) + 1
    return sorted(counts.items(), key=lambda item: (-item[1], item[0]))


def write_md(path: Path, rows: list[dict[str, str]], runtime_export_implemented: bool) -> None:
    would_export_rows = [row for row in rows if row["would_export"] == "true"]
    blocked_rows = [row for row in rows if row["blocked"] == "true"]
    reason_counts = aggregate_block_reasons(rows)

    lines = [
        "# Runtime Export Dry Run",
        "",
        f"- Runtime export implemented: {'yes' if runtime_export_implemented else 'no'}",
        "- Runtime files written: 0",
        f"- Runtime domains checked: {len(rows)}",
        f"- Would export: {len(would_export_rows)}",
        f"- Blocked: {len(blocked_rows)}",
        "",
        "## Dry Run Summary",
        "",
        "| Runtime Domain | Artifact | Target Path | Would Export | Blocked | Reasons |",
        "|---|---|---|---|---|---|",
    ]
    for row in rows:
        lines.append(
            f"| {row['runtime_domain']} | {row['runtime_artifact_name']} | {row['target_path']} | {row['would_export']} | {row['blocked']} | {row['block_reasons']} |"
        )

    lines.extend(["", "## Export Candidates", ""])
    if not would_export_rows:
        lines.append("No runtime export candidates.")
    else:
        lines.extend(
            [
                "| Runtime Domain | Artifact | Target Path |",
                "|---|---|---|",
            ]
        )
        for row in would_export_rows:
            lines.append(f"| {row['runtime_domain']} | {row['runtime_artifact_name']} | {row['target_path']} |")

    lines.extend(
        [
            "",
            "## Blocked Runtime Artifacts",
            "",
            "| Runtime Domain | Artifact | Block Reasons |",
            "|---|---|---|",
        ]
    )
    for row in blocked_rows:
        lines.append(f"| {row['runtime_domain']} | {row['runtime_artifact_name']} | {row['block_reasons']} |")

    lines.extend(
        [
            "",
            "## Decision Rules",
            "",
            "- approved_for_export=true required",
            "- approval_status=approved required",
            "- validator_status=PASS required",
            "- waiver clearance required for WARN sources",
            "- export_allowed_now=true required",
            "- runtime exporter implementation required",
            "",
            "## Current Blocking Summary",
            "",
            "| Block Reason | Count |",
            "|---|---:|",
        ]
    )
    for reason, count in reason_counts:
        lines.append(f"| {reason} | {count} |")

    lines.extend(
        [
            "",
            "## Safety Notes",
            "",
            "- This dry-run does not write runtime files.",
            "- Runtime exporter must not directly scan data/design/generated_*.tsv.",
            "- Runtime exporter must read manifest + approval + validator summary + schema proposal.",
            "- Design-layer card pool is not CardData runtime data.",
            "- Narrative skeleton is not final prose.",
            "- Route gate plan is not Godot route logic.",
            "",
            "## Next Steps",
            "",
            "1. v0.7c manual approval overlay or approval update",
            "2. v0.7d runtime export dry-run with approved sample",
            "3. v0.8 runtime exporter implementation only after approved PASS artifacts exist",
            "",
        ]
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    try:
        args = parse_args()
        design_dir = Path(args.design_dir)
        out_tsv = Path(args.out)
        out_md = Path(args.out_md)

        manifest_path = design_dir / MANIFEST_FILENAME
        validator_path = design_dir / SUMMARY_TSV
        approval_path = design_dir / APPROVAL_TSV
        schema_path = design_dir / SCHEMA_TSV
        for path in [manifest_path, validator_path, approval_path, schema_path]:
            require_file(path)

        manifest_ids = load_manifest_ids(read_tsv(manifest_path))
        approval_map = load_approval_map(read_tsv(approval_path))
        validator_map = load_validator_map(read_tsv(validator_path))
        schemas = load_schema_rows(read_tsv(schema_path))
        exporter_ready = runtime_exporter_implemented(args.runtime_exporter_implemented)

        rows = build_dry_run_rows(schemas, manifest_ids, approval_map, validator_map, exporter_ready)
        write_tsv(out_tsv, rows)
        write_md(out_md, rows, exporter_ready)

        approved_for_export_count = sum(1 for row in approval_map.values() if row.approved_for_export)
        would_export_count = sum(1 for row in rows if row["would_export"] == "true")
        if approved_for_export_count == 0 and would_export_count > 0:
            print(
                "WARN: dry-run produced would_export=true while approved_for_export count is 0; current phase should remain blocked."
            )
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}")
        return 1

    print(f"Wrote {out_tsv} and {out_md} with {len(rows)} runtime dry-run rows.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
