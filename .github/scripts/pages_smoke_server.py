from __future__ import annotations

import argparse
import mimetypes
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse


def resolve_path(root: Path, request_path: str) -> tuple[Path | None, int]:
    parsed = urlparse(request_path)
    path = unquote(parsed.path)
    relative = path.lstrip("/")

    if path.endswith("/"):
        candidate = root / relative / "index.html"
        if candidate.is_file():
            return candidate, HTTPStatus.OK

    direct = root / relative
    if direct.is_file():
        return direct, HTTPStatus.OK

    html_candidate = root / f"{relative}.html"
    if relative and html_candidate.is_file():
        return html_candidate, HTTPStatus.OK

    index_candidate = root / relative / "index.html"
    if relative and index_candidate.is_file():
        return index_candidate, HTTPStatus.OK

    not_found = root / "404.html"
    if not_found.is_file():
        return not_found, HTTPStatus.NOT_FOUND

    return None, HTTPStatus.NOT_FOUND


class PagesSmokeRequestHandler(BaseHTTPRequestHandler):
    server_version = "PagesSmokeServer/1.0"

    def do_GET(self) -> None:
        self._serve_request(send_body=True)

    def do_HEAD(self) -> None:
        self._serve_request(send_body=False)

    def log_message(self, format: str, *args: object) -> None:
        return

    def _serve_request(self, *, send_body: bool) -> None:
        root = Path(self.server.root)
        file_path, status = resolve_path(root, self.path)

        if file_path is None:
            body = b"Not Found"
            self.send_response(status)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if send_body:
                self.wfile.write(body)
            return

        body = file_path.read_bytes()
        content_type, _ = mimetypes.guess_type(str(file_path))
        self.send_response(status)
        self.send_header("Content-Type", content_type or "application/octet-stream")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()

        if send_body:
            self.wfile.write(body)


def main() -> None:
    parser = argparse.ArgumentParser(description="Serve static pages with Cloudflare Pages-like route resolution for smoke tests.")
    parser.add_argument("--root", default=".", help="Site root to serve")
    parser.add_argument("--host", default="127.0.0.1", help="Host to bind")
    parser.add_argument("--port", type=int, default=8788, help="Port to bind")
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), PagesSmokeRequestHandler)
    server.root = str(Path(args.root).resolve())
    server.serve_forever()


if __name__ == "__main__":
    main()