#!/usr/bin/env python3
"""Generate Content Engine v0.7d runtime export diff report (design-layer only)."""

from __future__ import annotations

import argparse
import csv
import hashlib
from dataclasses import dataclass
from pathlib import Path

from runtime_export_approval_overlay import OUTPUT_TSV as OVERLAY_TSV


OUTPUT_TSV = "generated_runtime_export_diff_report.tsv"
OUTPUT_MD = "generated_runtime_export_diff_report.md"
OUTPUT_FIELDS = [
    "runtime_domain",
    "artifact_id",
    "would_export",
    "planned_runtime_path",
    "export_action",
    "source_design_path",
    "planned_record_count",
    "planned_field_count",
    "schema_fingerprint",
    "content_fingerprint",
    "risk_level",
    "diff_status",
    "blocked_reason",
    "notes",
]
ALLOWED_ACTIONS = {"planned_create", "planned_update", "planned_skip", "blocked"}
ALLOWED_DIFF_STATUS = {"new_runtime_file_planned", "existing_runtime_file_would_change", "no_change", "blocked", "unsafe_path"}
ALLOWED_RISK_LEVEL = {"low", "medium", "high"}
RUNTIME_PREFIX = "data/runtime/content_engine/"
RESTRICTED_PREFIXES = ("scripts/", "scenes/", "data/story_battles/")


@dataclass(frozen=True)
class OverlayRow:
    runtime_domain: str
    source_artifacts: tuple[str, ...]
    would_export: bool
    blocked: bool
    blocked_reasons: str
    notes: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate runtime export diff report from approval overlay.")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--overlay", default=f"data/design/{OVERLAY_TSV}")
    parser.add_argument("--out", default=f"data/design/{OUTPUT_TSV}")
    parser.add_argument("--out-md", default=f"data/design/{OUTPUT_MD}")
    return parser.parse_args()


def parse_bool(value: str) -> bool:
    lowered = (value or "").strip().lower()
    if lowered in {"true", "1", "yes"}:
        return True
    if lowered in {"false", "0", "no"}:
        return False
    raise ValueError(f"Invalid bool value: {value!r}")


def split_csv(value: str) -> tuple[str, ...]:
    return tuple(part.strip() for part in (value or "").split(",") if part.strip())


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def require_file(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(f"Missing required input: {path}")


def load_overlay_rows(rows: list[dict[str, str]]) -> list[OverlayRow]:
    result: list[OverlayRow] = []
    for row in rows:
        result.append(
            OverlayRow(
                runtime_domain=(row.get("runtime_domain") or "").strip(),
                source_artifacts=split_csv(row.get("source_artifacts", "")),
                would_export=parse_bool(row.get("would_export", "false")),
                blocked=parse_bool(row.get("blocked", "true")),
                blocked_reasons=(row.get("blocked_reasons") or "").strip(),
                notes=(row.get("notes") or "").strip(),
            )
        )
    return result


def source_design_paths(source_artifacts: tuple[str, ...]) -> tuple[str, ...]:
    return tuple(f"data/design/{artifact_id}.tsv" for artifact_id in source_artifacts)


def count_tsv(path: Path) -> tuple[int, int]:
    if not path.exists():
        return 0, 0
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        rows = list(reader)
        return len(rows), len(reader.fieldnames or [])


def build_fingerprint(parts: list[str]) -> str:
    digest = hashlib.sha256()
    digest.update("|".join(parts).encode("utf-8"))
    return digest.hexdigest()


def infer_risk(runtime_domain: str) -> str:
    if runtime_domain in {"enemy_deck", "package_manifest"}:
        return "high"
    if runtime_domain in {"operation_node", "narrative_node", "route_gate"}:
        return "medium"
    return "low"


def planned_runtime_path(runtime_domain: str) -> str:
    return f"{RUNTIME_PREFIX}{runtime_domain}.json"


def unsafe_path(path_value: str) -> bool:
    if not path_value.startswith(RUNTIME_PREFIX):
        return True
    return any(path_value.startswith(prefix) for prefix in RESTRICTED_PREFIXES)


def build_rows(design_dir: Path, overlay_rows: list[OverlayRow]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for item in overlay_rows:
        artifact_id = ",".join(item.source_artifacts)
        src_paths = source_design_paths(item.source_artifacts)
        src_abs_paths = [design_dir.parent / path for path in src_paths]
        total_records = 0
        total_fields = 0
        for path in src_abs_paths:
            records, fields = count_tsv(path)
            total_records += records
            total_fields += fields

        runtime_path = planned_runtime_path(item.runtime_domain)
        is_unsafe = unsafe_path(runtime_path)
        blocked = item.blocked or is_unsafe or not item.would_export
        if is_unsafe:
            export_action = "blocked"
            diff_status = "unsafe_path"
            blocked_reason = "unsafe_path"
        elif item.would_export:
            export_action = "planned_create"
            diff_status = "new_runtime_file_planned"
            blocked_reason = ""
        else:
            export_action = "blocked"
            diff_status = "blocked"
            blocked_reason = item.blocked_reasons or "blocked_by_overlay"

        schema_fp = build_fingerprint([item.runtime_domain, artifact_id, runtime_path, str(total_fields)])
        content_fp = build_fingerprint([artifact_id, str(total_records), ",".join(src_paths)])
        rows.append(
            {
                "runtime_domain": item.runtime_domain,
                "artifact_id": artifact_id,
                "would_export": "true" if item.would_export else "false",
                "planned_runtime_path": runtime_path,
                "export_action": export_action,
                "source_design_path": ",".join(src_paths),
                "planned_record_count": str(total_records),
                "planned_field_count": str(total_fields),
                "schema_fingerprint": schema_fp,
                "content_fingerprint": content_fp,
                "risk_level": infer_risk(item.runtime_domain),
                "diff_status": diff_status,
                "blocked_reason": blocked_reason,
                "notes": item.notes,
            }
        )
    return rows


def write_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUTPUT_FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_md(path: Path, rows: list[dict[str, str]]) -> None:
    planned = [row for row in rows if row["would_export"] == "true"]
    blocked = [row for row in rows if row["export_action"] == "blocked"]
    lines = [
        "# Runtime Export Diff Report",
        "",
        "- Stage: v0.7d runtime export diff report",
        "- Runtime export implemented: no",
        "- Runtime files written: 0",
        f"- Records: {len(rows)}",
        f"- Planned export candidates: {len(planned)}",
        f"- Blocked records: {len(blocked)}",
        "",
        "## Diff Summary",
        "",
        "| Runtime Domain | Artifact ID | Would Export | Planned Runtime Path | Export Action | Diff Status |",
        "|---|---|---|---|---|---|",
    ]
    for row in rows:
        lines.append(
            f"| {row['runtime_domain']} | {row['artifact_id']} | {row['would_export']} | {row['planned_runtime_path']} | {row['export_action']} | {row['diff_status']} |"
        )
    lines.extend(["", "## Planned Candidates", ""])
    if not planned:
        lines.append("No planned runtime export candidates.")
    else:
        lines.extend(["| Runtime Domain | Artifact ID | Planned Runtime Path |", "|---|---|---|"])
        for row in planned:
            lines.append(f"| {row['runtime_domain']} | {row['artifact_id']} | {row['planned_runtime_path']} |")
    lines.extend(
        [
            "",
            "## Safety Notes",
            "",
            "- This is a design-layer diff report only.",
            "- planned_runtime_path is a planning target and does not mean files are written.",
            "- data/runtime/content_engine/ is not created in v0.7d.",
            "- Runtime exporter implementation remains out of scope.",
            "",
        ]
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    try:
        args = parse_args()
        design_dir = Path(args.design_dir)
        overlay_path = Path(args.overlay)
        out_tsv = Path(args.out)
        out_md = Path(args.out_md)
        require_file(overlay_path)
        overlay_rows = load_overlay_rows(read_tsv(overlay_path))
        rows = build_rows(design_dir, overlay_rows)
        write_tsv(out_tsv, rows)
        write_md(out_md, rows)
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}")
        return 1
    print(f"Wrote {out_tsv} and {out_md} with {len(rows)} diff report rows.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
