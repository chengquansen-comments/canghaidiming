#!/usr/bin/env python3
"""Run Godot headless probe for v0.8f loader scaffold and write design report."""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
from pathlib import Path


OUTPUT_TSV = "generated_runtime_loader_godot_probe_report.tsv"
OUTPUT_MD = "generated_runtime_loader_godot_probe_report.md"
OUTPUT_FIELDS = [
    "probe_script",
    "loader_script",
    "godot_exit_code",
    "probe_ok",
    "manifest_loaded",
    "manifest_valid",
    "runtime_bundle_loaded",
    "loaded_domain_count",
    "loaded_domains",
    "error_count",
    "manifest_first",
    "direct_runtime_read_disallowed",
    "fail_closed",
    "write_api_present",
    "integration_status",
    "blocked_reason",
    "notes",
]
BEGIN_MARKER = "CONTENT_ENGINE_LOADER_PROBE_JSON_BEGIN"
END_MARKER = "CONTENT_ENGINE_LOADER_PROBE_JSON_END"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run Godot loader probe and build report.")
    parser.add_argument("--godot-cmd", default="godot")
    parser.add_argument("--probe-script", default="tools/content_engine/content_engine_loader_probe.gd")
    parser.add_argument("--loader-script", default="scripts/content_engine_runtime_loader.gd")
    parser.add_argument("--out", default=f"data/design/{OUTPUT_TSV}")
    parser.add_argument("--out-md", default=f"data/design/{OUTPUT_MD}")
    return parser.parse_args()


def parse_probe_payload(stdout: str) -> dict[str, object]:
    start = stdout.find(BEGIN_MARKER)
    end = stdout.find(END_MARKER)
    if start < 0 or end < 0 or end <= start:
        raise ValueError("probe output missing JSON markers")
    content = stdout[start + len(BEGIN_MARKER):end].strip()
    payload = json.loads(content)
    if not isinstance(payload, dict):
        raise ValueError("probe payload must be JSON object")
    return payload


def bool_text(flag: object) -> str:
    return "true" if bool(flag) else "false"


def build_row(args: argparse.Namespace, exit_code: int, payload: dict[str, object], blocked_reason: str, notes: str) -> dict[str, str]:
    domains = payload.get("loaded_domains", [])
    if not isinstance(domains, list):
        domains = []
    domains_sorted = sorted(str(item) for item in domains)
    error_count = int(payload.get("error_count", 0)) if str(payload.get("error_count", "0")).isdigit() else 0
    return {
        "probe_script": args.probe_script,
        "loader_script": args.loader_script,
        "godot_exit_code": str(exit_code),
        "probe_ok": bool_text(payload.get("probe_ok", False)),
        "manifest_loaded": bool_text(payload.get("manifest_loaded", False)),
        "manifest_valid": bool_text(payload.get("manifest_valid", False)),
        "runtime_bundle_loaded": bool_text(payload.get("runtime_bundle_loaded", False)),
        "loaded_domain_count": str(len(domains_sorted)),
        "loaded_domains": ",".join(domains_sorted),
        "error_count": str(error_count),
        "manifest_first": bool_text(payload.get("manifest_first", False)),
        "direct_runtime_read_disallowed": bool_text(payload.get("direct_runtime_read_disallowed", False)),
        "fail_closed": bool_text(payload.get("fail_closed", False)),
        "write_api_present": bool_text(payload.get("write_api_present", False)),
        "integration_status": str(payload.get("integration_status", "unknown")),
        "blocked_reason": blocked_reason,
        "notes": notes,
    }


def write_tsv(path: Path, row: dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUTPUT_FIELDS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerow(row)


def write_md(path: Path, row: dict[str, str]) -> None:
    lines = [
        "# Runtime Loader Godot Probe Report",
        "",
        "- Stage: v0.8f headless-only loader probe",
        f"- probe_ok: {row['probe_ok']}",
        f"- godot_exit_code: {row['godot_exit_code']}",
        f"- loaded_domains: {row['loaded_domains']}",
        f"- blocked_reason: {row['blocked_reason']}",
        "",
        "## Probe Row",
        "",
        "| Probe Script | Loader Script | Manifest Loaded | Manifest Valid | Runtime Bundle Loaded | Loaded Domain Count | Error Count | Integration Status |",
        "|---|---|---|---|---|---|---|---|",
        (
            f"| {row['probe_script']} | {row['loader_script']} | {row['manifest_loaded']} | {row['manifest_valid']} | "
            f"{row['runtime_bundle_loaded']} | {row['loaded_domain_count']} | {row['error_count']} | {row['integration_status']} |"
        ),
        "",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    args = parse_args()
    cmd = [args.godot_cmd, "--headless", "--path", ".", "--script", args.probe_script]

    proc = subprocess.run(cmd, capture_output=True, text=True)
    blocked_reason = ""
    notes = "v0.8f probe is headless-only and not integrated into main battle flow."
    payload: dict[str, object]

    try:
        payload = parse_probe_payload(proc.stdout)
    except (ValueError, json.JSONDecodeError) as exc:
        blocked_reason = f"probe_output_parse_failed:{exc}"
        payload = {
            "probe_ok": False,
            "manifest_loaded": False,
            "manifest_valid": False,
            "runtime_bundle_loaded": False,
            "loaded_domains": [],
            "error_count": 1,
            "manifest_first": True,
            "direct_runtime_read_disallowed": True,
            "fail_closed": True,
            "write_api_present": False,
            "integration_status": "not_integrated",
        }

    if proc.returncode != 0:
        blocked_reason = (blocked_reason + "," if blocked_reason else "") + f"godot_exit_nonzero:{proc.returncode}"
    if not bool(payload.get("probe_ok", False)) and "probe_not_ok" not in blocked_reason:
        blocked_reason = (blocked_reason + "," if blocked_reason else "") + "probe_not_ok"

    row = build_row(args, proc.returncode, payload, blocked_reason, notes)
    write_tsv(Path(args.out), row)
    write_md(Path(args.out_md), row)

    print(f"Wrote {args.out} and {args.out_md}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
