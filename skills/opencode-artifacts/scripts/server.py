#!/usr/bin/env python3
"""Static server: 127.0.0.1 only, serves only under /<ARTIFACTS_SECRET>/, no listing, no dotfiles, no traversal."""
import http.server, os, sys
from urllib.parse import urlsplit, unquote
ROOT = os.path.realpath(sys.argv[1]); PORT = int(sys.argv[2])
SECRET = os.environ.get('ARTIFACTS_SECRET', ''); PREFIX = f'/{SECRET}' if SECRET else ''
class H(http.server.SimpleHTTPRequestHandler):
    def __init__(s, *a, **k): super().__init__(*a, directory=ROOT, **k)
    def list_directory(s, path): s.send_error(404); return None
    def send_head(s):
        u = unquote(urlsplit(s.path).path)
        if u == PREFIX:
            s.send_response(301); s.send_header('Location', PREFIX + '/'); s.end_headers(); return None
        if not u.startswith(PREFIX + '/'): s.send_error(404); return None
        s.path = s.path[len(PREFIX):]
        p = os.path.realpath(s.translate_path(s.path))
        if not p.startswith(ROOT) or any(x.startswith('.') for x in u.split('/')):
            s.send_error(404); return None
        return super().send_head()
    def end_headers(s):
        for k, v in (('X-Content-Type-Options', 'nosniff'), ('Referrer-Policy', 'no-referrer'),
                     ('Cache-Control', 'no-store'), ('X-Robots-Tag', 'noindex')): s.send_header(k, v)
        super().end_headers()
    def log_message(s, *a): pass
http.server.ThreadingHTTPServer(('127.0.0.1', PORT), H).serve_forever()
