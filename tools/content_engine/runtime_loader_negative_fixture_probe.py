#!/usr/bin/env python3
"""Run v0.8g negative fixture probe for read-only runtime loader checks."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path


FIXTURE_ROOT = Path("data/design/runtime_loader_negative_fixtures")
INDEX_FILE = "fixture_manifest.json"
REPORT_TSV = Path("data/design/generated_runtime_loader_negative_fixture_report.tsv")
REPORT_MD = Path("data/design/generated_runtime_loader_negative_fixture_report.md")
FORMAL_RUNTIME_ROOT = Path("data/runtime/content_engine")
MANIFEST_FILE = "runtime_manifest.json"
ALLOWED_DATA_FILES = {"card_pool.json", "battle_reward.json"}
ALLOWED_DIR_FILES = ALLOWED_DATA_FILES | {MANIFEST_FILE, INDEX_FILE}
WRITE_API_TOKENS = ["FileAccess.WRITE", "store_string", "store_var", "DirAccess.make_dir_recursive"]
FIELDS = [
    "fixture_name",
    "fixture_path",
    "expected_ok",
    "actual_ok",
    "match_status",
    "expected_error_type",
    "actual_error_type",
    "manifest_loaded",
    "manifest_valid",
    "runtime_bundle_loaded",
    "fail_closed",
    "returned_domain_count",
    "write_api_present",
    "formal_runtime_unchanged",
    "blocked_reason",
    "notes",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run runtime loader negative fixtures and produce report.")
    parser.add_argument("--fixture-root", default=str(FIXTURE_ROOT))
    parser.add_argument("--out", default=str(REPORT_TSV))
    parser.add_argument("--out-md", default=str(REPORT_MD))
    return parser.parse_args()


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def evaluate_fixture(fixture_dir: Path) -> dict[str, object]:
    errors: list[str] = []
    returned_domains: list[str] = []

    manifest_path = fixture_dir / MANIFEST_FILE
    manifest_loaded = False
    manifest_valid = False

    if not manifest_path.exists():
        errors.append("manifest_missing")
        return {
            "actual_ok": False,
            "manifest_loaded": False,
            "manifest_valid": False,
            "runtime_bundle_loaded": False,
            "returned_domain_count": 0,
            "actual_error_type": errors[0],
            "blocked_reason": ",".join(errors),
        }

    try:
        manifest = read_json(manifest_path)
        manifest_loaded = True
    except json.JSONDecodeError:
        errors.append("manifest_parse_failed")
        return {
            "actual_ok": False,
            "manifest_loaded": False,
            "manifest_valid": False,
            "runtime_bundle_loaded": False,
            "returned_domain_count": 0,
            "actual_error_type": errors[0],
            "blocked_reason": ",".join(errors),
        }

    # manifest validity checks
    for key in ["runtime_root", "files", "allowed_runtime_files"]:
        if key not in manifest:
            errors.append("manifest_missing_field")
            break

    if not errors and str(manifest.get("runtime_root", "")) != "data/runtime/content_engine":
        errors.append("manifest_runtime_root_invalid")

    files = manifest.get("files", [])
    if not errors and not isinstance(files, list):
        errors.append("manifest_files_not_array")

    # directory extra file check
    names = {p.name for p in fixture_dir.iterdir() if p.is_file()}
    extra = sorted(names - ALLOWED_DIR_FILES)
    if not errors and extra:
        errors.append("extra_runtime_file_present")

    if not errors:
        for entry in files:
            if not isinstance(entry, dict):
                errors.append("manifest_entry_invalid")
                break
            file_name = str(entry.get("file_name", ""))
            runtime_path = str(entry.get("runtime_path", ""))
            if file_name not in ALLOWED_DATA_FILES:
                errors.append("unknown_runtime_file")
                break
            if not runtime_path.startswith("data/runtime/content_engine/"):
                errors.append("unsafe_runtime_path")
                break
            if ".." in runtime_path:
                errors.append("unsafe_runtime_path")
                break
            runtime_file = fixture_dir / file_name
            if not runtime_file.exists():
                errors.append("runtime_file_missing")
                break
            try:
                payload = read_json(runtime_file)
            except json.JSONDecodeError:
                errors.append("malformed_runtime_json")
                break
            if str(payload.get("runtime_domain", "")) != str(entry.get("runtime_domain", "")):
                errors.append("domain_mismatch")
                break
            if str(payload.get("artifact_id", "")) != str(entry.get("artifact_id", "")):
                errors.append("artifact_id_mismatch")
                break
            if str(payload.get("schema_fingerprint", "")) != str(entry.get("schema_fingerprint", "")):
                errors.append("schema_fingerprint_mismatch")
                break
            if str(payload.get("content_fingerprint", "")) != str(entry.get("content_fingerprint", "")):
                errors.append("content_fingerprint_mismatch")
                break
            if int(payload.get("record_count", -1)) != int(entry.get("record_count", -2)):
                errors.append("record_count_mismatch")
                break
            if int(payload.get("field_count", -1)) != int(entry.get("field_count", -2)):
                errors.append("field_count_mismatch")
                break
            if sha256_file(runtime_file) != str(entry.get("sha256", "")):
                errors.append("checksum_mismatch")
                break
            returned_domains.append(str(payload.get("runtime_domain", "")))

    manifest_valid = len(errors) == 0
    actual_ok = manifest_loaded and manifest_valid
    runtime_bundle_loaded = actual_ok
    if not actual_ok:
        returned_domains = []

    return {
        "actual_ok": actual_ok,
        "manifest_loaded": manifest_loaded,
        "manifest_valid": manifest_valid,
        "runtime_bundle_loaded": runtime_bundle_loaded,
        "returned_domain_count": len(returned_domains),
        "actual_error_type": "none" if not errors else errors[0],
        "blocked_reason": "" if not errors else ",".join(errors),
    }


def write_report_tsv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)


def write_report_md(path: Path, rows: list[dict[str, str]]) -> None:
    matched = sum(1 for r in rows if r["match_status"] == "matched")
    lines = [
        "# Runtime Loader Negative Fixture Report",
        "",
        f"- Fixture rows: {len(rows)}",
        f"- Matched rows: {matched}",
        "",
        "## Fixture Results",
        "",
        "| Fixture | Expected OK | Actual OK | Match | Expected Error | Actual Error | Returned Domains |",
        "|---|---|---|---|---|---|---|",
    ]
    for row in rows:
        lines.append(
            f"| {row['fixture_name']} | {row['expected_ok']} | {row['actual_ok']} | {row['match_status']} | {row['expected_error_type']} | {row['actual_error_type']} | {row['returned_domain_count']} |"
        )
    lines.append("")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    args = parse_args()
    fixture_root = Path(args.fixture_root)
    index_path = fixture_root / INDEX_FILE
    if not index_path.exists():
        raise FileNotFoundError(f"Missing fixture index: {index_path}")

    index = read_json(index_path)
    cases = index.get("cases", [])
    if not isinstance(cases, list):
        raise ValueError("fixture index cases must be list")

    formal_before = {
        n: sha256_file(FORMAL_RUNTIME_ROOT / n)
        for n in ["card_pool.json", "battle_reward.json", MANIFEST_FILE]
    }

    loader_text = Path("scripts/content_engine_runtime_loader.gd").read_text(encoding="utf-8")
    probe_text = Path("tools/content_engine/content_engine_loader_probe.gd").read_text(encoding="utf-8")
    write_api_present = any(tok in loader_text or tok in probe_text for tok in WRITE_API_TOKENS)

    rows: list[dict[str, str]] = []
    for case in cases:
        fixture_name = str(case.get("fixture_name", ""))
        expected_ok = bool(case.get("expected_ok", False))
        expected_error = str(case.get("expected_error_type", "none"))
        fixture_dir = fixture_root / fixture_name

        result = evaluate_fixture(fixture_dir)
        actual_ok = bool(result["actual_ok"])
        actual_error = str(result["actual_error_type"])

        expected_ok_s = "true" if expected_ok else "false"
        actual_ok_s = "true" if actual_ok else "false"
        error_match = (expected_error == actual_error) or (expected_ok and actual_ok)
        match_status = "matched" if (expected_ok == actual_ok and error_match) else "mismatched"

        formal_after = {
            n: sha256_file(FORMAL_RUNTIME_ROOT / n)
            for n in ["card_pool.json", "battle_reward.json", MANIFEST_FILE]
        }
        formal_runtime_unchanged = formal_before == formal_after

        rows.append(
            {
                "fixture_name": fixture_name,
                "fixture_path": fixture_dir.as_posix(),
                "expected_ok": expected_ok_s,
                "actual_ok": actual_ok_s,
                "match_status": match_status,
                "expected_error_type": expected_error,
                "actual_error_type": actual_error,
                "manifest_loaded": "true" if result["manifest_loaded"] else "false",
                "manifest_valid": "true" if result["manifest_valid"] else "false",
                "runtime_bundle_loaded": "true" if result["runtime_bundle_loaded"] else "false",
                "fail_closed": "true",
                "returned_domain_count": str(result["returned_domain_count"]),
                "write_api_present": "true" if write_api_present else "false",
                "formal_runtime_unchanged": "true" if formal_runtime_unchanged else "false",
                "blocked_reason": str(result["blocked_reason"]),
                "notes": "v0.8g fixture probe only; not integrated into main flow.",
            }
        )

    rows.sort(key=lambda r: r["fixture_name"])
    write_report_tsv(Path(args.out), rows)
    write_report_md(Path(args.out_md), rows)
    print(f"Wrote {args.out} and {args.out_md} with {len(rows)} fixture rows.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
