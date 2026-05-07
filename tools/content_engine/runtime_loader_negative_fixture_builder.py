#!/usr/bin/env python3
"""Build v0.8g negative-case fixtures for runtime loader validation."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path


FIXTURE_ROOT = Path("data/design/runtime_loader_negative_fixtures")
RUNTIME_ROOT = Path("data/runtime/content_engine")
MANIFEST_FILE = "runtime_manifest.json"
ALLOWED_FILES = ["card_pool.json", "battle_reward.json", MANIFEST_FILE]
INDEX_FILE = "fixture_manifest.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build runtime loader negative fixtures under data/design/.")
    parser.add_argument("--fixture-root", default=str(FIXTURE_ROOT))
    parser.add_argument("--runtime-root", default=str(RUNTIME_ROOT))
    return parser.parse_args()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, obj: object) -> None:
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def copy_bundle(dst: Path, runtime_root: Path) -> None:
    dst.mkdir(parents=True, exist_ok=True)
    for file_name in ALLOWED_FILES:
        shutil.copy2(runtime_root / file_name, dst / file_name)


def build_fixture(root: Path, name: str, runtime_root: Path) -> Path:
    fixture_dir = root / name
    if fixture_dir.exists():
        shutil.rmtree(fixture_dir)
    copy_bundle(fixture_dir, runtime_root)
    return fixture_dir


def main() -> int:
    args = parse_args()
    fixture_root = Path(args.fixture_root)
    runtime_root = Path(args.runtime_root)

    for required in ALLOWED_FILES:
        if not (runtime_root / required).exists():
            raise FileNotFoundError(f"Missing formal runtime file: {runtime_root / required}")

    if fixture_root.exists():
        shutil.rmtree(fixture_root)
    fixture_root.mkdir(parents=True, exist_ok=True)

    manifest_original = read_json(runtime_root / MANIFEST_FILE)
    files = manifest_original.get("files", [])
    if not isinstance(files, list) or len(files) != 2:
        raise ValueError("Formal runtime manifest must contain exactly two files")

    cases: list[dict[str, object]] = []

    # 1. valid_control
    build_fixture(fixture_root, "valid_control", runtime_root)
    cases.append({"fixture_name": "valid_control", "expected_ok": True, "expected_error_type": "none"})

    # 2. missing_manifest_field
    d = build_fixture(fixture_root, "missing_manifest_field", runtime_root)
    m = read_json(d / MANIFEST_FILE)
    m.pop("runtime_root", None)
    write_json(d / MANIFEST_FILE, m)
    cases.append({"fixture_name": "missing_manifest_field", "expected_ok": False, "expected_error_type": "manifest_missing_field"})

    # 3. checksum_mismatch
    d = build_fixture(fixture_root, "checksum_mismatch", runtime_root)
    m = read_json(d / MANIFEST_FILE)
    m["files"][0]["sha256"] = "0" * 64
    write_json(d / MANIFEST_FILE, m)
    cases.append({"fixture_name": "checksum_mismatch", "expected_ok": False, "expected_error_type": "checksum_mismatch"})

    # 4. schema_fingerprint_mismatch
    d = build_fixture(fixture_root, "schema_fingerprint_mismatch", runtime_root)
    m = read_json(d / MANIFEST_FILE)
    m["files"][0]["schema_fingerprint"] = "bad_schema_fp"
    write_json(d / MANIFEST_FILE, m)
    cases.append({"fixture_name": "schema_fingerprint_mismatch", "expected_ok": False, "expected_error_type": "schema_fingerprint_mismatch"})

    # 5. content_fingerprint_mismatch
    d = build_fixture(fixture_root, "content_fingerprint_mismatch", runtime_root)
    m = read_json(d / MANIFEST_FILE)
    m["files"][0]["content_fingerprint"] = "bad_content_fp"
    write_json(d / MANIFEST_FILE, m)
    cases.append({"fixture_name": "content_fingerprint_mismatch", "expected_ok": False, "expected_error_type": "content_fingerprint_mismatch"})

    # 6. unknown_runtime_file
    d = build_fixture(fixture_root, "unknown_runtime_file", runtime_root)
    m = read_json(d / MANIFEST_FILE)
    m["files"].append(
        {
            "runtime_domain": "unknown",
            "artifact_id": "unknown_artifact",
            "runtime_path": "data/runtime/content_engine/unknown_runtime.json",
            "file_name": "unknown_runtime.json",
            "file_size_bytes": 1,
            "sha256": "0" * 64,
            "schema_fingerprint": "x",
            "content_fingerprint": "y",
            "record_count": 0,
            "field_count": 0,
            "export_version": "v0.8b",
            "generated_at": m.get("generated_at", ""),
            "source_design_path": "data/design/unknown.tsv",
        }
    )
    write_json(d / MANIFEST_FILE, m)
    cases.append({"fixture_name": "unknown_runtime_file", "expected_ok": False, "expected_error_type": "unknown_runtime_file"})

    # 7. extra_runtime_file_present
    d = build_fixture(fixture_root, "extra_runtime_file_present", runtime_root)
    (d / "extra_runtime.json").write_text("{}\n", encoding="utf-8")
    cases.append({"fixture_name": "extra_runtime_file_present", "expected_ok": False, "expected_error_type": "extra_runtime_file_present"})

    # 8. unsafe_runtime_path
    d = build_fixture(fixture_root, "unsafe_runtime_path", runtime_root)
    m = read_json(d / MANIFEST_FILE)
    m["files"][0]["runtime_path"] = "data/design/runtime_loader_negative_fixtures/outside.json"
    write_json(d / MANIFEST_FILE, m)
    cases.append({"fixture_name": "unsafe_runtime_path", "expected_ok": False, "expected_error_type": "unsafe_runtime_path"})

    # 9. malformed_runtime_json
    d = build_fixture(fixture_root, "malformed_runtime_json", runtime_root)
    (d / "card_pool.json").write_text("{ malformed", encoding="utf-8")
    cases.append({"fixture_name": "malformed_runtime_json", "expected_ok": False, "expected_error_type": "malformed_runtime_json"})

    # 10. domain_mismatch
    d = build_fixture(fixture_root, "domain_mismatch", runtime_root)
    payload = read_json(d / "card_pool.json")
    payload["runtime_domain"] = "wrong_domain"
    write_json(d / "card_pool.json", payload)
    cases.append({"fixture_name": "domain_mismatch", "expected_ok": False, "expected_error_type": "domain_mismatch"})

    # 11. record_count_mismatch
    d = build_fixture(fixture_root, "record_count_mismatch", runtime_root)
    payload = read_json(d / "card_pool.json")
    payload["record_count"] = int(payload.get("record_count", 0)) + 1
    write_json(d / "card_pool.json", payload)
    cases.append({"fixture_name": "record_count_mismatch", "expected_ok": False, "expected_error_type": "record_count_mismatch"})

    # 12. field_count_mismatch
    d = build_fixture(fixture_root, "field_count_mismatch", runtime_root)
    payload = read_json(d / "card_pool.json")
    payload["field_count"] = int(payload.get("field_count", 0)) + 1
    write_json(d / "card_pool.json", payload)
    cases.append({"fixture_name": "field_count_mismatch", "expected_ok": False, "expected_error_type": "field_count_mismatch"})

    # Index with baseline hashes of formal runtime files.
    baseline = {
        file_name: sha256_file(runtime_root / file_name)
        for file_name in ["card_pool.json", "battle_reward.json", MANIFEST_FILE]
    }
    index = {
        "fixture_root": fixture_root.as_posix(),
        "formal_runtime_root": runtime_root.as_posix(),
        "formal_runtime_sha256_before": baseline,
        "cases": cases,
    }
    write_json(fixture_root / INDEX_FILE, index)

    print(f"Built {len(cases)} fixtures under {fixture_root}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
