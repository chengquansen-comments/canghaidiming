#!/usr/bin/env python3
"""Generate Content Engine v0.6b content package report from manifest."""

from __future__ import annotations

import argparse
import csv
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

from content_package_manifest_generator import MANIFEST_FIELDS, MANIFEST_FILENAME


REPORT_FILENAME = "generated_content_package_report.md"
REQUIRED_STATUS_ORDER = ["SOURCE_ONLY", "NOT_RUN", "PASS", "WARN", "FAIL"]
MANUAL_REVIEW_TYPES = {"reward_plan", "narrative_plan", "route_gate_plan", "generated_table"}


@dataclass(frozen=True)
class ArtifactRow:
    artifact_id: str
    artifact_type: str
    source_stage: str
    row_count: int
    validator_status: str
    is_runtime_ready: bool
    export_scope: str
    export_blockers: tuple[str, ...]
    depends_on_artifacts: tuple[str, ...]

    @classmethod
    def from_row(cls, row: dict[str, str]) -> "ArtifactRow":
        return cls(
            artifact_id=require_value(row, "artifact_id"),
            artifact_type=require_value(row, "artifact_type"),
            source_stage=require_value(row, "source_stage"),
            row_count=as_int(require_value(row, "row_count"), "row_count"),
            validator_status=require_value(row, "validator_status"),
            is_runtime_ready=as_bool(require_value(row, "is_runtime_ready")),
            export_scope=require_value(row, "export_scope"),
            export_blockers=tuple(split_csv_tokens(row.get("export_blockers", ""))),
            depends_on_artifacts=tuple(split_csv_tokens(row.get("depends_on_artifacts", ""))),
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate Content Engine v0.6b content package report.")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--out", default=f"data/design/{REPORT_FILENAME}")
    return parser.parse_args()


def require_value(row: dict[str, str], field_name: str) -> str:
    value = (row.get(field_name) or "").strip()
    if not value:
        raise ValueError(f"Manifest row is missing required field: {field_name}")
    return value


def as_int(value: str, field_name: str) -> int:
    try:
        return int(value)
    except ValueError as exc:
        raise ValueError(f"Manifest field {field_name} must be an integer, got: {value!r}") from exc


def as_bool(value: str) -> bool:
    lowered = value.strip().lower()
    if lowered in {"1", "true", "yes"}:
        return True
    if lowered in {"0", "false", "no"}:
        return False
    raise ValueError(f"Manifest field is_runtime_ready must be true/false, got: {value!r}")


def split_csv_tokens(value: str) -> list[str]:
    return [part.strip() for part in value.split(",") if part.strip()]


def read_manifest(path: Path) -> list[ArtifactRow]:
    if not path.exists():
        raise FileNotFoundError(f"Missing required manifest: {path}")

    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        fieldnames = reader.fieldnames or []
        missing = [field for field in MANIFEST_FIELDS if field not in fieldnames]
        if missing:
            raise ValueError("Manifest is missing required columns: " + ", ".join(missing))
        rows = [ArtifactRow.from_row(row) for row in reader]

    if not rows:
        raise ValueError(f"Manifest is empty: {path}")
    return rows


def count_runtime_ready(rows: list[ArtifactRow]) -> int:
    return sum(1 for row in rows if row.is_runtime_ready)


def blocked_rows(rows: list[ArtifactRow]) -> list[ArtifactRow]:
    return [row for row in rows if not row.is_runtime_ready and row.export_blockers]


def manual_review_rows(rows: list[ArtifactRow]) -> list[ArtifactRow]:
    selected: list[ArtifactRow] = []
    seen: set[str] = set()
    for row in rows:
        needs_review = (
            (row.validator_status == "NOT_RUN" and row.export_scope == "future_runtime")
            or row.artifact_type in MANUAL_REVIEW_TYPES
        )
        if needs_review and row.artifact_id not in seen:
            selected.append(row)
            seen.add(row.artifact_id)
    return selected


def status_counts(rows: list[ArtifactRow]) -> Counter[str]:
    return Counter(row.validator_status for row in rows)


def blocker_counts(rows: list[ArtifactRow]) -> Counter[str]:
    counts: Counter[str] = Counter()
    for row in rows:
        counts.update(row.export_blockers)
    return counts


def render_top_summary(rows: list[ArtifactRow], manifest_path: Path) -> list[str]:
    return [
        "# Content Package Report",
        "",
        f"- Package version: v0.6a",
        f"- Source manifest: {manifest_path.as_posix()}",
        f"- Artifact count: {len(rows)}",
        f"- Runtime ready artifacts: {count_runtime_ready(rows)}",
        f"- Blocked artifacts: {len(blocked_rows(rows))}",
        "",
    ]


def render_executive_summary(rows: list[ArtifactRow]) -> list[str]:
    lines = [
        "## 2. Executive Summary",
        "",
        "- Current package state: design-layer package only.",
        "- Runtime exporter status: not implemented.",
        "- Runtime consumption rule: all generated design tables should remain outside runtime until validator orchestration and manual approval are in place.",
    ]
    if any(row.validator_status == "NOT_RUN" for row in rows):
        lines.append("- Validator status note: validator_status may be NOT_RUN because v0.6a manifest generation did not re-run validators.")
    else:
        lines.append("- Validator status note: manifest contains explicit validator outcomes for all artifacts.")
    lines.append("- Next phase recommendation: finish report-driven review and validator orchestration before starting runtime exporter work.")
    lines.append("")
    return lines


def render_artifact_inventory(rows: list[ArtifactRow]) -> list[str]:
    lines = [
        "## 3. Artifact Inventory",
        "",
        "| Artifact | Type | Stage | Rows | Validator | Runtime Ready | Export Scope |",
        "|---|---|---|---:|---|---|---|",
    ]
    for row in rows:
        lines.append(
            f"| {row.artifact_id} | {row.artifact_type} | {row.source_stage} | {row.row_count} | {row.validator_status} | {'true' if row.is_runtime_ready else 'false'} | {row.export_scope} |"
        )
    lines.append("")
    return lines


def render_dependency_graph(rows: list[ArtifactRow]) -> list[str]:
    lines = ["## 4. Dependency Graph", ""]
    for row in rows:
        deps = ", ".join(row.depends_on_artifacts) if row.depends_on_artifacts else "none"
        lines.append(f"- {row.artifact_id}")
        lines.append(f"  - depends on: {deps}")
    lines.append("")
    return lines


def render_validator_status_summary(rows: list[ArtifactRow]) -> list[str]:
    counts = status_counts(rows)
    lines = [
        "## 5. Validator Status Summary",
        "",
        "| Status | Count |",
        "|---|---:|",
    ]
    for status in REQUIRED_STATUS_ORDER:
        lines.append(f"| {status} | {counts.get(status, 0)} |")
    extra_statuses = sorted(status for status in counts if status not in REQUIRED_STATUS_ORDER)
    for status in extra_statuses:
        lines.append(f"| {status} | {counts[status]} |")
    lines.extend(
        [
            "",
            "NOT_RUN does not mean invalid. It means the manifest generator did not re-run validators.",
            "",
        ]
    )
    return lines


def render_runtime_ready_candidates(rows: list[ArtifactRow]) -> list[str]:
    runtime_ready = [row for row in rows if row.is_runtime_ready]
    lines = ["### 6.1 Runtime-ready candidates", ""]
    if not runtime_ready:
        lines.append("No runtime-ready artifacts in this package.")
        lines.append("")
        return lines
    for row in runtime_ready:
        lines.append(f"- {row.artifact_id}")
    lines.append("")
    return lines


def render_blocked_artifacts(rows: list[ArtifactRow]) -> list[str]:
    blocked = blocked_rows(rows)
    lines = [
        "### 6.2 Blocked artifacts",
        "",
        "| Artifact | Export Scope | Blockers |",
        "|---|---|---|",
    ]
    for row in blocked:
        lines.append(f"| {row.artifact_id} | {row.export_scope} | {', '.join(row.export_blockers)} |")
    if not blocked:
        lines.append("| none | none | none |")
    lines.append("")
    return lines


def render_manual_review_candidates(rows: list[ArtifactRow]) -> list[str]:
    candidates = manual_review_rows(rows)
    lines = [
        "### 6.3 Manual-review candidates",
        "",
        "These artifacts need manual review or validator orchestration before runtime export remains thinkable:",
        "",
    ]
    for row in candidates:
        lines.append(
            f"- {row.artifact_id}: validator_status={row.validator_status}, type={row.artifact_type}, export_scope={row.export_scope}"
        )
    if not candidates:
        lines.append("- none")
    lines.append("")
    return lines


def render_export_readiness(rows: list[ArtifactRow]) -> list[str]:
    lines = ["## 6. Export Readiness", ""]
    lines.extend(render_runtime_ready_candidates(rows))
    lines.extend(render_blocked_artifacts(rows))
    lines.extend(render_manual_review_candidates(rows))
    return lines


def render_runtime_export_blockers(rows: list[ArtifactRow]) -> list[str]:
    counts = blocker_counts(rows)
    lines = [
        "## 7. Runtime Export Blockers",
        "",
        "| Blocker | Count |",
        "|---|---:|",
    ]
    for blocker in sorted(counts):
        lines.append(f"| {blocker} | {counts[blocker]} |")
    lines.append("")
    return lines


def render_risk_notes(rows: list[ArtifactRow]) -> list[str]:
    lines = ["## 8. Risk Notes", ""]
    if any(row.validator_status == "NOT_RUN" for row in rows):
        lines.append("- validators were not run as part of manifest generation.")
    if all(not row.is_runtime_ready for row in rows):
        lines.append("- no artifact should be consumed by runtime exporter yet.")
    if any(row.artifact_type == "narrative_plan" for row in rows):
        lines.append("- narrative plan contains skeleton keys only, not final prose.")
    if any(row.artifact_type == "route_gate_plan" for row in rows):
        lines.append("- route gate plan is design-layer only, not runtime route logic.")
    if any(row.artifact_type == "generated_table" and row.source_stage in {"v0.4a", "v0.4b"} for row in rows):
        lines.append("- card pool and enemy deck sets are design-layer content, not CardData runtime records.")
    lines.append("")
    return lines


def render_suggested_next_steps() -> list[str]:
    return [
        "## 9. Suggested Next Steps",
        "",
        "- v0.6c: validator orchestration.",
        "- v0.6c detail: run all existing validators through one orchestration entrypoint.",
        "- v0.6c detail: update manifest validator_status fields or generate a validator status summary artifact.",
        "- v0.6d: content package approval and manual review.",
        "- v0.6d detail: manually confirm exportable artifacts and mark approved_for_export in a future controlled layer.",
        "- v0.7: runtime exporter.",
        "- v0.7 detail: only read manifest/report, only export approved + PASS artifacts, and never scan data/design/generated_*.tsv directly.",
        "",
    ]


def build_report(rows: list[ArtifactRow], manifest_path: Path) -> str:
    lines: list[str] = []
    lines.extend(render_top_summary(rows, manifest_path))
    lines.extend(render_executive_summary(rows))
    lines.extend(render_artifact_inventory(rows))
    lines.extend(render_dependency_graph(rows))
    lines.extend(render_validator_status_summary(rows))
    lines.extend(render_export_readiness(rows))
    lines.extend(render_runtime_export_blockers(rows))
    lines.extend(render_risk_notes(rows))
    lines.extend(render_suggested_next_steps())
    return "\n".join(lines).rstrip() + "\n"


def write_report(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def main() -> int:
    try:
        args = parse_args()
        design_dir = Path(args.design_dir)
        out_path = Path(args.out)
        manifest_path = design_dir / MANIFEST_FILENAME

        rows = read_manifest(manifest_path)
        report = build_report(rows, manifest_path)
        write_report(out_path, report)
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}")
        return 1

    print(f"Wrote {out_path} with {len(rows)} artifacts from {manifest_path}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
