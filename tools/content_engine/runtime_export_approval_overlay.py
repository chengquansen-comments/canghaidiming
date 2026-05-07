#!/usr/bin/env python3
"""Generate Content Engine v0.7c runtime export approval overlay outputs."""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path

from runtime_export_dry_run import OUTPUT_TSV as DRY_RUN_TSV


APPROVAL_TSV = "runtime_export_approval.tsv"
OUTPUT_TSV = "generated_runtime_export_approval_overlay.tsv"
OUTPUT_MD = "generated_runtime_export_approval_overlay.md"
APPROVAL_FIELDS = [
    "runtime_domain",
    "artifact_id",
    "validator_status",
    "approval_status",
    "approved_for_export",
    "waiver_flags",
    "waiver_status",
    "approved_by",
    "approved_at",
    "approval_notes",
]
OUTPUT_FIELDS = [
    "overlay_id",
    "dry_run_id",
    "runtime_domain",
    "runtime_artifact_name",
    "target_path",
    "source_artifacts",
    "approval_records_found",
    "approval_records_expected",
    "would_export",
    "blocked",
    "blocked_reasons",
    "approved_source_artifacts",
    "blocked_source_artifacts",
    "unknown_approval_records",
    "notes",
]
ALLOWED_APPROVAL_STATUS = {"pending", "approved", "rejected"}
ALLOWED_WAIVER_STATUS = {"none", "pending", "cleared", "rejected", "unresolved"}
PASS_STATUS = "PASS"


@dataclass(frozen=True)
class ApprovalRecord:
    runtime_domain: str
    artifact_id: str
    validator_status: str
    approval_status: str
    approved_for_export: bool
    waiver_flags: tuple[str, ...]
    waiver_status: str
    approved_by: str
    approved_at: str
    approval_notes: str


@dataclass(frozen=True)
class DryRunDomain:
    dry_run_id: str
    runtime_domain: str
    runtime_artifact_name: str
    target_path: str
    source_artifacts: tuple[str, ...]
    notes: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate runtime export manual approval overlay.")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--approval-tsv", default=f"data/design/{APPROVAL_TSV}")
    parser.add_argument("--out", default=f"data/design/{OUTPUT_TSV}")
    parser.add_argument("--out-md", default=f"data/design/{OUTPUT_MD}")
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


def load_dry_run_rows(rows: list[dict[str, str]]) -> list[DryRunDomain]:
    result: list[DryRunDomain] = []
    for row in rows:
        result.append(
            DryRunDomain(
                dry_run_id=(row.get("dry_run_id") or "").strip(),
                runtime_domain=(row.get("runtime_domain") or "").strip(),
                runtime_artifact_name=(row.get("runtime_artifact_name") or "").strip(),
                target_path=(row.get("target_path") or "").strip(),
                source_artifacts=split_csv(row.get("source_artifacts", "")),
                notes=(row.get("notes") or "").strip(),
            )
        )
    return result


def load_approval_records(rows: list[dict[str, str]]) -> dict[tuple[str, str], ApprovalRecord]:
    records: dict[tuple[str, str], ApprovalRecord] = {}
    for row in rows:
        runtime_domain = (row.get("runtime_domain") or "").strip()
        artifact_id = (row.get("artifact_id") or "").strip()
        record = ApprovalRecord(
            runtime_domain=runtime_domain,
            artifact_id=artifact_id,
            validator_status=(row.get("validator_status") or "").strip(),
            approval_status=(row.get("approval_status") or "").strip(),
            approved_for_export=parse_bool(row.get("approved_for_export", "false")),
            waiver_flags=split_csv(row.get("waiver_flags", "")),
            waiver_status=(row.get("waiver_status") or "").strip(),
            approved_by=(row.get("approved_by") or "").strip(),
            approved_at=(row.get("approved_at") or "").strip(),
            approval_notes=(row.get("approval_notes") or "").strip(),
        )
        records[(runtime_domain, artifact_id)] = record
    return records


def expected_pairs(dry_run_rows: list[DryRunDomain]) -> set[tuple[str, str]]:
    pairs: set[tuple[str, str]] = set()
    for row in dry_run_rows:
        for artifact_id in row.source_artifacts:
            pairs.add((row.runtime_domain, artifact_id))
    return pairs


def reasons_for_record(record: ApprovalRecord) -> set[str]:
    reasons: set[str] = set()
    if record.approval_status not in ALLOWED_APPROVAL_STATUS:
        reasons.add("approval_status_not_approved")
    elif record.approval_status != "approved":
        reasons.add("approval_status_not_approved")
        reasons.add("not_manually_approved")

    if record.validator_status != PASS_STATUS:
        reasons.add("validator_status_not_pass")

    if not record.approved_for_export:
        reasons.add("approved_for_export_not_true")

    if record.waiver_flags:
        reasons.add("waiver_flags_present")

    if record.waiver_status in {"pending", "unresolved", "rejected"}:
        reasons.add("waiver_not_cleared")
    elif record.waiver_status not in ALLOWED_WAIVER_STATUS:
        reasons.add("waiver_not_cleared")

    if record.approved_for_export and record.approval_status == "approved":
        if not record.approved_by or not record.approved_at:
            reasons.add("not_manually_approved")

    return reasons


def evaluate_domain(
    dry_run: DryRunDomain, records: dict[tuple[str, str], ApprovalRecord]
) -> tuple[bool, list[str], list[str], list[str]]:
    reasons: set[str] = set()
    approved_sources: list[str] = []
    blocked_sources: list[str] = []
    found_count = 0
    for artifact_id in dry_run.source_artifacts:
        key = (dry_run.runtime_domain, artifact_id)
        record = records.get(key)
        if record is None:
            reasons.add("approval_record_missing")
            blocked_sources.append(artifact_id)
            continue
        found_count += 1
        record_reasons = reasons_for_record(record)
        if record_reasons:
            reasons.update(record_reasons)
            blocked_sources.append(artifact_id)
        else:
            approved_sources.append(artifact_id)

    would_export = bool(dry_run.source_artifacts) and not reasons and found_count == len(dry_run.source_artifacts)
    return would_export, sorted(reasons), sorted(approved_sources), sorted(blocked_sources)


def build_rows(dry_run_rows: list[DryRunDomain], approval_rows: list[dict[str, str]]) -> list[dict[str, str]]:
    records = load_approval_records(approval_rows)
    known_pairs = expected_pairs(dry_run_rows)
    orphan_by_domain: dict[str, list[str]] = {}
    for (domain, artifact_id), record in records.items():
        if (domain, artifact_id) in known_pairs:
            continue
        orphan_by_domain.setdefault(domain, []).append(artifact_id)
        if "orphan" not in record.approval_notes.lower() and "unknown" not in record.approval_notes.lower():
            orphan_by_domain.setdefault(domain, []).append(f"{artifact_id}:not_marked")

    rows: list[dict[str, str]] = []
    for dry_run in dry_run_rows:
        would_export, reasons, approved_sources, blocked_sources = evaluate_domain(dry_run, records)
        unknown_records = sorted(set(orphan_by_domain.get(dry_run.runtime_domain, [])))
        if unknown_records:
            reasons.append("approval_record_unknown_to_dry_run")
        reason_list = sorted(set(reasons))
        if not would_export and not reason_list:
            reason_list = ["not_manually_approved"]
        rows.append(
            {
                "overlay_id": f"overlay_{dry_run.runtime_domain}",
                "dry_run_id": dry_run.dry_run_id,
                "runtime_domain": dry_run.runtime_domain,
                "runtime_artifact_name": dry_run.runtime_artifact_name,
                "target_path": dry_run.target_path,
                "source_artifacts": ",".join(dry_run.source_artifacts),
                "approval_records_found": str(
                    sum(1 for artifact_id in dry_run.source_artifacts if (dry_run.runtime_domain, artifact_id) in records)
                ),
                "approval_records_expected": str(len(dry_run.source_artifacts)),
                "would_export": "true" if would_export and not unknown_records else "false",
                "blocked": "false" if would_export and not unknown_records else "true",
                "blocked_reasons": ",".join(reason_list),
                "approved_source_artifacts": ",".join(approved_sources),
                "blocked_source_artifacts": ",".join(blocked_sources),
                "unknown_approval_records": ",".join(unknown_records),
                "notes": dry_run.notes,
            }
        )
    return rows


def write_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUTPUT_FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def aggregate_reasons(rows: list[dict[str, str]]) -> list[tuple[str, int]]:
    counts: dict[str, int] = {}
    for row in rows:
        for reason in split_csv(row.get("blocked_reasons", "")):
            counts[reason] = counts.get(reason, 0) + 1
    return sorted(counts.items(), key=lambda item: (-item[1], item[0]))


def write_md(path: Path, rows: list[dict[str, str]]) -> None:
    would_export_rows = [row for row in rows if row["would_export"] == "true"]
    blocked_rows = [row for row in rows if row["blocked"] == "true"]
    reason_counts = aggregate_reasons(rows)
    lines = [
        "# Runtime Export Approval Overlay",
        "",
        "- Overlay stage: v0.7c manual approval overlay",
        "- Runtime export implemented: no",
        "- Runtime files written: 0",
        f"- Runtime domains checked: {len(rows)}",
        f"- Would export: {len(would_export_rows)}",
        f"- Blocked: {len(blocked_rows)}",
        "",
        "## Overlay Summary",
        "",
        "| Runtime Domain | Artifact | Would Export | Blocked | Block Reasons |",
        "|---|---|---|---|---|",
    ]
    for row in rows:
        lines.append(
            f"| {row['runtime_domain']} | {row['runtime_artifact_name']} | {row['would_export']} | {row['blocked']} | {row['blocked_reasons']} |"
        )
    lines.extend(["", "## Overlay Candidates", ""])
    if not would_export_rows:
        lines.append("No overlay candidates.")
    else:
        lines.extend(["| Runtime Domain | Artifact | Source Artifacts |", "|---|---|---|"])
        for row in would_export_rows:
            lines.append(
                f"| {row['runtime_domain']} | {row['runtime_artifact_name']} | {row['source_artifacts']} |"
            )
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
        lines.append(
            f"| {row['runtime_domain']} | {row['runtime_artifact_name']} | {row['blocked_reasons']} |"
        )
    lines.extend(["", "## Blocking Summary", "", "| Block Reason | Count |", "|---|---:|"])
    for reason, count in reason_counts:
        lines.append(f"| {reason} | {count} |")
    lines.extend(
        [
            "",
            "## Safety Notes",
            "",
            "- This overlay does not write runtime files.",
            "- This stage is manual approval overlay only, not runtime exporter.",
            "- Runtime exporter remains out of scope until later stage.",
            "",
        ]
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    try:
        args = parse_args()
        design_dir = Path(args.design_dir)
        dry_run_path = design_dir / DRY_RUN_TSV
        approval_path = Path(args.approval_tsv)
        out_tsv = Path(args.out)
        out_md = Path(args.out_md)
        require_file(dry_run_path)
        require_file(approval_path)
        dry_run_rows = load_dry_run_rows(read_tsv(dry_run_path))
        approval_rows = read_tsv(approval_path)
        rows = build_rows(dry_run_rows, approval_rows)
        write_tsv(out_tsv, rows)
        write_md(out_md, rows)
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}")
        return 1
    print(f"Wrote {out_tsv} and {out_md} with {len(rows)} overlay rows.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
