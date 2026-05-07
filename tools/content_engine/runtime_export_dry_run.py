#!/usr/bin/env python3
"""v1.1 runtime export dry-run：仅模拟导出决策，不写 runtime 文件。"""

from __future__ import annotations

import argparse
import csv
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path

FIELDS = [
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
OUTPUT_TSV = "generated_runtime_export_dry_run.tsv"
OUTPUT_MD = "generated_runtime_export_dry_run.md"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Runtime export dry-run only (no runtime file writes).")
    parser.add_argument("--design-dir", default="data/design")
    parser.add_argument("--out", default=f"data/design/{OUTPUT_TSV}")
    parser.add_argument("--out-md", default=f"data/design/{OUTPUT_MD}")
    return parser.parse_args()


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def to_bool(v: str) -> bool:
    return str(v).strip().lower() in {"1", "true", "yes"}


def split_csv(v: str) -> list[str]:
    return [x.strip() for x in str(v).split(",") if x.strip()]


def atomic_write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(text, encoding="utf-8")
    os.replace(tmp, path)


def write_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    os.replace(tmp, path)


def main() -> int:
    args = parse_args()
    design_dir = Path(args.design_dir)

    manifest_rows = read_tsv(design_dir / "generated_content_package_manifest.tsv")
    validator_rows = read_tsv(design_dir / "generated_validator_summary.tsv")
    approval_rows = read_tsv(design_dir / "generated_content_package_approval.tsv")
    schema_rows = read_tsv(design_dir / "generated_runtime_schema_proposal.tsv")

    manifest_ids = {r.get("artifact_id", "") for r in manifest_rows}
    approval_by_artifact = {r.get("artifact_id", ""): r for r in approval_rows}

    validator_by_artifact: dict[str, tuple[str, str]] = {}
    for row in validator_rows:
        validator_id = row.get("validator_id", "")
        status = row.get("status", "")
        for aid in split_csv(row.get("target_artifact_id", "")):
            validator_by_artifact[aid] = (validator_id, status)

    by_domain: dict[str, list[dict[str, str]]] = {}
    for row in schema_rows:
        domain = row.get("runtime_domain", "")
        by_domain.setdefault(domain, []).append(row)

    dry_run_id = f"dryrun-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}-{uuid.uuid4().hex[:8]}"
    rows: list[dict[str, str]] = []

    for domain, group in sorted(by_domain.items()):
        first = group[0]
        source_artifacts = split_csv(first.get("source_artifacts", ""))
        required_approval_status = first.get("required_approval_status", "approved")
        required_validator_status = first.get("required_validator_status", "PASS")
        requires_waiver_clearance = to_bool(first.get("requires_waiver_clearance", "false"))
        export_allowed_now = to_bool(first.get("export_allowed_now", "false"))

        source_schema_ids = sorted({r.get("schema_id", "") for r in group if r.get("schema_id", "")})

        source_approval_ids: list[str] = []
        source_validator_ids: list[str] = []
        block_reasons: list[str] = []

        approval_ok = True
        validator_ok = True
        waiver_ok = True
        schema_ok = True

        for aid in source_artifacts:
            if aid not in manifest_ids:
                block_reasons.append(f"manifest_missing:{aid}")
            ap = approval_by_artifact.get(aid)
            if ap is None:
                approval_ok = False
                block_reasons.append(f"approval_missing:{aid}")
            else:
                source_approval_ids.append(ap.get("approval_id", ""))
                if ap.get("approval_status", "") != required_approval_status:
                    approval_ok = False
                    block_reasons.append(f"approval_status:{aid}={ap.get('approval_status','')}")
                if not to_bool(ap.get("approved_for_export", "false")):
                    approval_ok = False
                    block_reasons.append(f"approved_for_export_false:{aid}")
                if requires_waiver_clearance and "waiver_required" in ap.get("waiver_flags", ""):
                    waiver_ok = False
                    block_reasons.append(f"waiver_required:{aid}")

            vid, vstatus = validator_by_artifact.get(aid, ("", ""))
            if vid:
                source_validator_ids.append(vid)
            if vstatus != required_validator_status:
                validator_ok = False
                block_reasons.append(f"validator_status:{aid}={vstatus or 'MISSING'}")

        if not export_allowed_now:
            schema_ok = False
            block_reasons.append("schema_export_allowed_now_false")

        would_export = approval_ok and validator_ok and waiver_ok and schema_ok and export_allowed_now
        blocked = not would_export

        rows.append(
            {
                "dry_run_id": dry_run_id,
                "runtime_domain": domain,
                "runtime_artifact_name": first.get("runtime_artifact_name", ""),
                "target_path": first.get("target_path", ""),
                "source_artifacts": ",".join(source_artifacts),
                "required_approval_status": required_approval_status,
                "required_validator_status": required_validator_status,
                "requires_waiver_clearance": "true" if requires_waiver_clearance else "false",
                "approval_check": "pass" if approval_ok else "fail",
                "validator_check": "pass" if validator_ok else "fail",
                "waiver_check": "pass" if waiver_ok else "fail",
                "schema_check": "pass" if schema_ok else "fail",
                "export_allowed_now": "true" if export_allowed_now else "false",
                "would_export": "true" if would_export else "false",
                "blocked": "true" if blocked else "false",
                "block_reasons": ",".join(sorted(set(block_reasons))) if block_reasons else "none",
                "source_schema_ids": ",".join(source_schema_ids),
                "source_approval_ids": ",".join(sorted(set(x for x in source_approval_ids if x))),
                "source_validator_ids": ",".join(sorted(set(x for x in source_validator_ids if x))),
                "notes": "dry_run_only;runtime_files_written=0;no_runtime_json_written",
            }
        )

    write_tsv(Path(args.out), rows)

    total = len(rows)
    would_export_count = sum(1 for r in rows if r["would_export"] == "true")
    blocked_count = sum(1 for r in rows if r["blocked"] == "true")

    md = [
        "# Runtime Export Dry Run",
        "",
        "## Dry Run Summary",
        "",
        f"- dry_run_id: {dry_run_id}",
        f"- runtime_domain_count: {total}",
        f"- would_export_count: {would_export_count}",
        f"- blocked_count: {blocked_count}",
        f"- runtime_files_written: 0",
        "",
        "## Export Candidates",
        "",
        "- 当前无可导出候选（would_export 全部为 false）。",
        "",
        "## Blocked Runtime Artifacts",
        "",
    ]
    for r in rows:
        md.append(f"- {r['runtime_domain']} -> {r['runtime_artifact_name']} (blocked={r['blocked']}, reasons={r['block_reasons']})")

    md.extend(
        [
            "",
            "## Decision Rules",
            "",
            "- 必须同时满足 approval_check=pass、validator_check=pass、waiver_check=pass、schema_check=pass。",
            "- 且 export_allowed_now=true 才会 would_export=true。",
            "",
            "## Current Blocking Summary",
            "",
            "- 当前 approval 表未给出 approved_for_export=true，且 schema export_allowed_now 仍为 false。",
            "- 因此本次 dry-run 全部 blocked，且不会写 runtime 文件。",
            "",
            "## Safety Notes",
            "",
            "- 本工具只做决策模拟，不创建 data/runtime，不写任何 runtime JSON。",
            "- 不改变 selected_reward、battle_state、combat_result 与任何正式奖励流程。",
            "",
            "## Next Steps",
            "",
            "- 补齐 approved_for_export 审批链路。",
            "- 在后续阶段实现真实 runtime exporter 前，继续保持 dry-run only。",
            "",
        ]
    )
    atomic_write_text(Path(args.out_md), "\n".join(md))

    print(f"Wrote {args.out} and {args.out_md}. domains={total} would_export={would_export_count} blocked={blocked_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
