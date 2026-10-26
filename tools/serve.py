"""Local dev server that never lets the browser cache files, so every change shows up on refresh.
Serves web/ (what Netlify publishes). Run from the repo root:  python tools/serve.py   → http://localhost:8080 (and http://<laptop-ip>:8080 on the phone)
"""
import functools
import http.server
import socketserver


class NoCache(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                      ".js": "text/javascript", ".webmanifest": "application/manifest+json"}

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


socketserver.ThreadingTCPServer.allow_reuse_address = True
with socketserver.ThreadingTCPServer(("0.0.0.0", 8080), functools.partial(NoCache, directory="web")) as httpd:
    print("Mitra dev server on http://localhost:8080")
    httpd.serve_forever()
