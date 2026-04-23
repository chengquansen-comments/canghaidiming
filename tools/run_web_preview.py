#!/usr/bin/env python3
from __future__ import annotations

import argparse
import http.server
import socketserver
from pathlib import Path


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
    }

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def log_message(self, format: str, *args) -> None:
        return


class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", default=".", help="directory to serve")
    parser.add_argument("--host", default="127.0.0.1", help="host to bind")
    parser.add_argument("--port", type=int, default=8060, help="port to serve on")
    args = parser.parse_args()

    root = Path(args.dir).resolve()
    if not root.exists() or not root.is_dir():
        raise SystemExit(f"Directory not found: {root}")

    handler = lambda *handler_args, **handler_kwargs: QuietHandler(
        *handler_args,
        directory=str(root),
        **handler_kwargs,
    )

    with ReusableTCPServer((args.host, args.port), handler) as httpd:
        print(f"Serving {root} at http://{args.host}:{args.port}")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nStopping server")


if __name__ == "__main__":
    main()
