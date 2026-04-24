#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from html.parser import HTMLParser
import os
from pathlib import Path
import shutil
import socketserver
import subprocess
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

from run_web_preview import QuietHandler

REQUIRED_FILES = ["index.html", "manifest.json", "checksums.txt"]
REQUIRED_SUFFIXES = [".js", ".wasm", ".pck"]
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8060
HTTP_TIMEOUT_SECONDS = 20.0
RETRY_DELAY_SECONDS = 0.2
HTTP_RETRIES = 30
BROWSER_VIRTUAL_TIME_BUDGET_MS = 20000


class IndexAssetParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.script_sources: list[str] = []
        self.canvas_ids: set[str] = set()
        self.button_ids: set[str] = set()

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attr_map = dict(attrs)
        if tag == "script" and attr_map.get("src"):
            self.script_sources.append(attr_map["src"])
        if tag == "canvas" and attr_map.get("id"):
            self.canvas_ids.add(attr_map["id"])
        if tag == "button" and attr_map.get("id"):
            self.button_ids.add(attr_map["id"])


class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def request_url(url: str, method: str = "GET") -> bytes:
    request = urllib.request.Request(url, method=method)
    last_error: Exception | None = None
    for _attempt in range(HTTP_RETRIES):
        try:
            with urllib.request.urlopen(request, timeout=HTTP_TIMEOUT_SECONDS) as response:
                return response.read()
        except urllib.error.URLError as error:
            last_error = error
            time.sleep(RETRY_DELAY_SECONDS)
    raise SystemExit(f"Unable to fetch {url}: {last_error}")


def validate_index_page(base_url: str) -> None:
    body = request_url(f"{base_url}/index.html").decode("utf-8", errors="replace")
    require("沧海嘀鸣 · Web 版" in body, "index.html missing Web shell title")
    require("开始加载" in body, "index.html missing start button text")
    require("$GODOT_CONFIG" not in body and "$GODOT_URL" not in body, "index.html still contains unresolved Godot shell placeholders")

    parser = IndexAssetParser()
    parser.feed(body)
    require("canvas" in parser.canvas_ids, "index.html missing canvas#canvas")
    require("start-btn" in parser.button_ids, "index.html missing button#start-btn")
    require(parser.script_sources, "index.html missing script tags")

    for src in parser.script_sources:
        if src.startswith("http://") or src.startswith("https://"):
            continue
        resolved = urllib.parse.urljoin(f"{base_url}/index.html", src)
        request_url(resolved, method="HEAD")


def chrome_candidates() -> list[str]:
    configured = [
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "google-chrome",
        "chromium",
        "chromium-browser",
    ]
    env_value = "CANGHAI_WEB_SMOKE_CHROME"
    if env_value in os.environ and os.environ[env_value]:
        configured.insert(0, os.environ[env_value])
    return configured


def find_chrome() -> str | None:
    for candidate in chrome_candidates():
        if Path(candidate).is_absolute():
            if Path(candidate).exists():
                return candidate
            continue
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
    return None


def maybe_run_browser_smoke(base_url: str) -> None:
    chrome = find_chrome()
    if chrome is None:
        print("[web-bundle] browser smoke skipped: Chrome/Chromium not found")
        return

    smoke_url = f"{base_url}/index.html?autostart=1&smoke_test=1&smoke_battle=1"
    try:
        result = subprocess.run(
            [
                chrome,
                "--headless=new",
                "--disable-gpu",
                "--virtual-time-budget=%d" % BROWSER_VIRTUAL_TIME_BUDGET_MS,
                "--dump-dom",
                smoke_url,
            ],
            check=False,
            capture_output=True,
            text=True,
            timeout=HTTP_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired as error:
        raise SystemExit(f"Browser smoke timed out: {error}") from error

    require(result.returncode == 0, "Browser smoke failed to launch Chrome/Chromium")
    dom = result.stdout
    require('data-web-smoke="boot-started"' in dom or 'data-web-smoke="boot-succeeded"' in dom, "Browser smoke did not trigger Web shell startup")
    require('data-web-smoke="boot-failed"' not in dom, "Browser smoke reported boot failure")
    if 'data-web-smoke-battle="battle-ready"' in dom:
        print("[web-bundle] browser smoke reached visual battle entry")
        return
    if 'data-web-smoke="boot-succeeded"' in dom:
        print("[web-bundle] browser smoke reached engine boot; battle marker not retained in DOM snapshot")
        return
    print("[web-bundle] browser smoke triggered shell startup; headless DOM snapshot did not observe battle marker")


def build_handler(root: Path):
    def _handler(*handler_args, **handler_kwargs):
        return QuietHandler(*handler_args, directory=str(root), **handler_kwargs)

    return _handler


def run_http_smoke(root: Path, host: str, port: int) -> None:
    handler = build_handler(root)
    with ReusableTCPServer((host, port), handler) as httpd:
        thread = threading.Thread(target=httpd.serve_forever, daemon=True)
        thread.start()
        try:
            base_url = f"http://{host}:{port}"
            validate_index_page(base_url)
            maybe_run_browser_smoke(base_url)
        finally:
            httpd.shutdown()
            httpd.server_close()
            thread.join(timeout=2.0)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle_dir", nargs="?", default="build/web")
    parser.add_argument("--zip", dest="zip_path", default=None)
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    args = parser.parse_args()

    root = Path(args.bundle_dir).resolve()
    require(root.exists() and root.is_dir(), f"Bundle directory not found: {root}")

    for name in REQUIRED_FILES:
        require((root / name).exists(), f"Missing required file: {name}")

    for suffix in REQUIRED_SUFFIXES:
        require(any(p.suffix == suffix for p in root.iterdir() if p.is_file()), f"Missing required bundle suffix: {suffix}")

    manifest_path = root / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest_files = manifest.get("files", [])
    require(isinstance(manifest_files, list) and manifest_files, "Manifest files list is empty")

    manifest_names = set()
    for item in manifest_files:
        name = item.get("name")
        size_bytes = item.get("size_bytes")
        require(isinstance(name, str) and name != "", "Manifest contains invalid file name")
        path = root / name
        require(path.exists(), f"Manifest references missing file: {name}")
        require(path.stat().st_size == size_bytes, f"Manifest size mismatch for: {name}")
        manifest_names.add(name)

    checksum_path = root / "checksums.txt"
    checksum_lines = [line.strip() for line in checksum_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    require(checksum_lines, "checksums.txt is empty")

    checksum_names = set()
    for line in checksum_lines:
        parts = line.split("  ", 1)
        require(len(parts) == 2, f"Invalid checksum line: {line}")
        expected_hash, name = parts
        if name.endswith(".zip") and args.zip_path:
            path = Path(args.zip_path).resolve()
        else:
            path = root / name
        require(path.exists(), f"Checksum references missing file: {name}")
        actual_hash = sha256_file(path)
        require(actual_hash == expected_hash, f"Checksum mismatch for: {name}")
        checksum_names.add(name)

    require(manifest_names.issubset(checksum_names), "Not all manifest files are covered by checksums")
    if args.zip_path:
        zip_name = Path(args.zip_path).name
        require(zip_name in checksum_names, f"Zip output missing from checksums: {zip_name}")

    run_http_smoke(root, args.host, args.port)
    print(f"[web-bundle] smoke test passed: {root}")


if __name__ == "__main__":
    main()
