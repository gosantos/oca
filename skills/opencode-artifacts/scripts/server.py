#!/usr/bin/env python3
"""Static server: 127.0.0.1 only, serves only under /<ARTIFACTS_SECRET>/, no listing, no dotfiles, no traversal.
The site root itself is never served (404), so a stray index.html can't become a public listing.
Performance: HTTP/1.1 keep-alive, Content-Length, TCP_NODELAY and cached gzip for text assets."""

import gzip, http.server, io, os, re, socket, sys, threading
from urllib.parse import urlsplit, unquote

ROOT = os.path.realpath(sys.argv[1])
PORT = int(sys.argv[2])
SECRET = os.environ.get("ARTIFACTS_SECRET", "").strip()
PUBLIC = os.environ.get("ARTIFACTS_PUBLIC") == "1"
# Fail closed: a missing or malformed secret must never widen the served paths.
if not PUBLIC and not re.fullmatch(r"[0-9a-f]{64}", SECRET):
    sys.exit(
        "ERROR: ARTIFACTS_SECRET must be 64 lowercase hex chars (or set ARTIFACTS_PUBLIC=1)"
    )
PREFIX = "" if PUBLIC else f"/{SECRET}"
T = {
    ".html": "text/html; charset=utf-8",
    ".css": "text/css",
    ".js": "text/javascript",
    ".json": "application/json",
    ".svg": "image/svg+xml",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".webp": "image/webp",
    ".csv": "text/csv",
}
GZ = {".html", ".css", ".js", ".json", ".svg", ".csv"}
MAX_GZIP = 1 << 20
CACHE = {}
LOCK = threading.Lock()


class H(http.server.SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def __init__(s, *a, **k):
        super().__init__(*a, directory=ROOT, **k)

    def setup(s):
        super().setup()
        try:
            s.connection.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        except OSError:
            pass

    def list_directory(s, path):
        s.send_error(404)
        return None

    def send_head(s):
        u = unquote(urlsplit(s.path).path)
        if not PUBLIC and u == PREFIX:
            s.send_response(301)
            s.send_header("Location", PREFIX + "/")
            s.end_headers()
            return None
        if not u.startswith(PREFIX + "/"):
            s.send_error(404)
            return None
        s.path = s.path[len(PREFIX) :]
        if urlsplit(s.path).path == "/" or any(x.startswith(".") for x in u.split("/")):
            s.send_error(404)
            return None
        p = os.path.realpath(s.translate_path(s.path))
        if os.path.isdir(p):
            p = os.path.join(p, "index.html")
        if not p.startswith(ROOT) or not os.path.isfile(p):
            s.send_error(404)
            return None
        ext = os.path.splitext(p)[1].lower()
        ctype = T.get(ext, "application/octet-stream")
        st = os.stat(p)
        gz = None
        if (
            ext in GZ
            and st.st_size <= MAX_GZIP
            and "gzip" in s.headers.get("Accept-Encoding", "")
        ):
            key = (p, st.st_mtime_ns, st.st_size)
            with LOCK:
                gz = CACHE.get(key)
            if gz is None:
                with open(p, "rb") as fh:
                    gz = gzip.compress(fh.read(), 6)
                with LOCK:
                    if len(CACHE) > 256:
                        CACHE.clear()
                    CACHE[key] = gz
        s.send_response(200)
        s.send_header("Content-Type", ctype)
        if gz is not None:
            s.send_header("Content-Encoding", "gzip")
            s.send_header("Vary", "Accept-Encoding")
            s.send_header("Content-Length", str(len(gz)))
            s.end_headers()
            return io.BytesIO(gz)
        s.send_header("Content-Length", str(st.st_size))
        s.end_headers()
        return open(p, "rb")

    def end_headers(s):
        for k, v in (
            ("X-Content-Type-Options", "nosniff"),
            ("Referrer-Policy", "no-referrer"),
            ("Cache-Control", "no-store"),
            ("X-Robots-Tag", "noindex"),
            ("X-Frame-Options", "DENY"),
            ("Content-Security-Policy", "frame-ancestors 'none'"),
        ):
            s.send_header(k, v)
        super().end_headers()

    def log_message(s, *a):
        pass


class S(http.server.ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True
    request_queue_size = 128


S(("127.0.0.1", PORT), H).serve_forever()
