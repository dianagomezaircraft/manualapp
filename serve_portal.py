#!/usr/bin/env python3
"""
Sofema reverse proxy for ARTS Client Portal iframe embeds.

Local:
  python serve_portal.py
  # site + proxy together (two ports):
  SERVE_STATIC=1 python serve_portal.py
  open http://localhost:8080/portal.html

Render (free, one service — site + proxy on same URL):
  Start command: python serve_portal.py
  Env:
    PROXY_PUBLIC_ORIGIN=https://YOUR-SERVICE.onrender.com
    ALLOWED_FRAME_ORIGINS=https://YOUR-SERVICE.onrender.com,https://manualapp-6af05.web.app,https://manualapp-6af05.firebaseapp.com,http://localhost:8080
  Open: https://YOUR-SERVICE.onrender.com/portal.html

Flutter web (Firebase) must be listed in ALLOWED_FRAME_ORIGINS so the iframe can load.
"""

from __future__ import annotations

import http.client
import json
import os
import re
import socketserver
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, unquote, urlparse

# ── Config (Render sets PORT) ───────────────────────────────────────────────
PORT = int(os.environ.get("PORT", "8081"))
HOST = os.environ.get("HOST", "0.0.0.0")
PUBLIC_ORIGIN = (
    os.environ.get("PROXY_PUBLIC_ORIGIN")
    or os.environ.get("RENDER_EXTERNAL_URL")
    or f"http://localhost:{PORT}"
).rstrip("/")
PARSED_PUBLIC = urlparse(PUBLIC_ORIGIN)
PUBLIC_HOST = PARSED_PUBLIC.netloc  # e.g. localhost:8081 or app.onrender.com
IS_HTTPS = PUBLIC_ORIGIN.startswith("https:")

_DEFAULT_FRAME_ORIGINS = (
    f"{PUBLIC_ORIGIN},"
    "https://manualapp-6af05.web.app,https://manualapp-6af05.firebaseapp.com,"
    "http://localhost:8080,http://127.0.0.1:8080,"
    "http://localhost:8081,http://127.0.0.1:8081,"
    "http://localhost:*,http://127.0.0.1:*"
)
ALLOWED_FRAME_ORIGINS = [
    o.strip().rstrip("/")
    for o in os.environ.get("ALLOWED_FRAME_ORIGINS", _DEFAULT_FRAME_ORIGINS).split(",")
    if o.strip()
]
if PUBLIC_ORIGIN not in ALLOWED_FRAME_ORIGINS:
    ALLOWED_FRAME_ORIGINS.insert(0, PUBLIC_ORIGIN)

SERVE_STATIC = os.environ.get("SERVE_STATIC", "0") == "1"
SITE_PORT = int(os.environ.get("SITE_PORT", "8080"))
# On Render (or SERVE_SITE=1), serve the ARTS HTML/CSS/assets from this same process.
SERVE_SITE = (
    os.environ.get("SERVE_SITE", "0") == "1"
    or bool(os.environ.get("RENDER"))
    or bool(os.environ.get("RENDER_EXTERNAL_URL"))
)

UPSTREAM = "sofemaaviation.com"
API_UPSTREAM = "api.sofemaaviation.com"
UPSTREAM_ORIGIN = f"https://{UPSTREAM}"
API_ORIGIN = f"https://{API_UPSTREAM}"
API_PREFIX = "/__api"
SITE_ROOT = os.path.dirname(os.path.abspath(__file__))

_LOCALHOST_RE = re.compile(r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$", re.I)

HOP_BY_HOP = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade",
    "host",
    "content-length",
}


def rewrite_location(value: str, is_api: bool) -> str:
    if not value:
        return value
    if value.startswith(API_ORIGIN):
        return PUBLIC_ORIGIN + API_PREFIX + value[len(API_ORIGIN) :]
    if value.startswith(UPSTREAM_ORIGIN):
        return PUBLIC_ORIGIN + value[len(UPSTREAM_ORIGIN) :]
    if value.startswith("//" + API_UPSTREAM):
        return PUBLIC_ORIGIN + API_PREFIX + value[len("//" + API_UPSTREAM) :]
    if value.startswith("//" + UPSTREAM):
        return PUBLIC_ORIGIN + value[len("//" + UPSTREAM) :]
    if is_api and value.startswith("/"):
        return API_PREFIX + value
    return value


def rewrite_set_cookie(value: str) -> str:
    """Host-only cookies on the proxy origin. Cross-site iframe needs SameSite=None; Secure."""
    parts = []
    for part in value.split(";"):
        item = part.strip()
        lower = item.lower()
        if lower.startswith("domain="):
            continue
        if lower.startswith("secure"):
            continue
        if lower.startswith("samesite="):
            continue
        parts.append(item)

    if IS_HTTPS:
        # Firebase / Netlify (parent) → Render proxy (iframe) is cross-site
        parts.append("SameSite=None")
        parts.append("Secure")
    else:
        parts.append("SameSite=Lax")
    return "; ".join(parts)


def rewrite_csp(value: str) -> str:
    bits = [b.strip() for b in value.split(";") if b.strip()]
    kept = [b for b in bits if not b.lower().startswith("frame-ancestors")]
    return "; ".join(kept)


def origin_allowed(origin: str | None) -> bool:
    if not origin:
        return False
    o = origin.rstrip("/")
    if _LOCALHOST_RE.match(o) and any(
        a.endswith("://localhost:*") or a.endswith("://127.0.0.1:*")
        for a in ALLOWED_FRAME_ORIGINS
    ):
        return True
    return o in {a.rstrip("/") for a in ALLOWED_FRAME_ORIGINS if not a.endswith(":*")}


def frame_ancestors_header(request_origin: str | None = None) -> str:
    if not IS_HTTPS:
        # Local proxy: Flutter web uses a random localhost port.
        return "frame-ancestors *"
    origins: list[str] = []
    for allowed in ALLOWED_FRAME_ORIGINS:
        if allowed.endswith(":*"):
            continue
        origins.append(allowed)
    if request_origin and origin_allowed(request_origin):
        origins.append(request_origin.rstrip("/"))
    return "frame-ancestors 'self' " + " ".join(dict.fromkeys(origins))


def cors_origin_for(request_origin: str | None) -> str | None:
    if origin_allowed(request_origin):
        return request_origin.rstrip("/")  # type: ignore[union-attr]
    if not request_origin and ALLOWED_FRAME_ORIGINS:
        first = ALLOWED_FRAME_ORIGINS[0]
        return first.replace(":*", "")
    return None


def rewrite_body(content_type: str, data: bytes) -> bytes:
    if not data:
        return data
    ct = (content_type or "").lower()
    if not any(
        t in ct
        for t in (
            "text/html",
            "text/css",
            "javascript",
            "ecmascript",
            "json",
            "text/x-component",
            "text/plain",
        )
    ):
        return data
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return data

    # Softema Axios baseURL is https://api.sofemaaviation.com/api
    text = text.replace(API_ORIGIN, PUBLIC_ORIGIN + API_PREFIX)
    text = text.replace(f"//{API_UPSTREAM}", f"//{PUBLIC_HOST}{API_PREFIX}")
    text = text.replace(UPSTREAM_ORIGIN, PUBLIC_ORIGIN)
    text = text.replace(f"//{UPSTREAM}", f"//{PUBLIC_HOST}")
    text = text.replace(f'"{UPSTREAM}"', f'"{PUBLIC_HOST}"')
    text = text.replace(f'"{API_UPSTREAM}"', f'"{PUBLIC_HOST}{API_PREFIX}"')
    return text.encode("utf-8")


class SofemaProxyHandler(SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt: str, *args) -> None:
        print(f"[sofema :{PORT}] " + fmt % args)

    def do_POST(self):
        raw_path = (self.path or "/").split("?", 1)[0]
        if raw_path in ("/__auth_bridge", "/__session_boot"):
            self._auth_bridge()
            return
        self._proxy()

    def do_GET(self):
        raw_path = unquote((self.path or "/").split("?", 1)[0])
        if raw_path in ("/__auth_bridge", "/__session_boot"):
            self.send_error(405, "Use POST")
            return
        if SERVE_SITE and self._try_serve_site(raw_path):
            return
        self._proxy()

    def do_HEAD(self):
        raw_path = unquote((self.path or "/").split("?", 1)[0])
        if SERVE_SITE and self._try_serve_site(raw_path):
            return
        self._proxy()

    def do_PUT(self):
        self._proxy()

    def do_PATCH(self):
        self._proxy()

    def do_DELETE(self):
        self._proxy()

    def _try_serve_site(self, raw_path: str) -> bool:
        """Serve local ARTS files when present; otherwise fall through to Softema proxy."""
        if raw_path.startswith(("/__api", "/__auth_bridge", "/__session_boot", "/health")):
            return False
        rel = raw_path.lstrip("/") or "index.html"
        if any(part == ".." for part in rel.split("/")):
            return False
        full = os.path.normpath(os.path.join(SITE_ROOT, rel.replace("/", os.sep)))
        if not full.startswith(SITE_ROOT) or not os.path.isfile(full):
            return False
        self.directory = SITE_ROOT
        if self.command == "GET":
            SimpleHTTPRequestHandler.do_GET(self)
        else:
            SimpleHTTPRequestHandler.do_HEAD(self)
        return True

    def _parse_form_or_json(self, body: bytes, content_type: str) -> dict:
        content_type = (content_type or "").lower()
        if "application/json" in content_type:
            payload = json.loads(body.decode("utf-8") or "{}")
            return payload if isinstance(payload, dict) else {}
        form = parse_qs(body.decode("utf-8"), keep_blank_values=True)
        return {key: (values[0] if values else "") for key, values in form.items()}

    def _session_boot_html(self, access_token: str, refresh_token: str, next_path: str) -> bytes:
        safe_access = json.dumps(access_token)
        safe_refresh = json.dumps(refresh_token or "")
        safe_next = json.dumps(PUBLIC_ORIGIN + next_path)
        return f"""<!doctype html>
<html><head><meta charset="utf-8"><title>Signing in…</title></head>
<body style="font-family:sans-serif;padding:40px;background:#0A1628;color:#E8E0CC">
<p>Signing you in to Sofema…</p>
<script>
(function () {{
  var accessToken = {safe_access};
  var refreshToken = {safe_refresh};
  var next = {safe_next};
  function setCookie(name, value) {{
    if (!value) return;
    document.cookie = name + '=' + encodeURIComponent(value) + '; path=/; SameSite=Lax';
  }}
  try {{
    localStorage.setItem('accessToken', accessToken);
    localStorage.setItem('refreshToken', refreshToken);
    localStorage.setItem('access_token', accessToken);
    localStorage.setItem('refresh_token', refreshToken);
    sessionStorage.setItem('accessToken', accessToken);
    sessionStorage.setItem('refreshToken', refreshToken);
    setCookie('accessToken', accessToken);
    setCookie('refreshToken', refreshToken);
    setCookie('access_token', accessToken);
    setCookie('refresh_token', refreshToken);
  }} catch (e) {{}}
  location.replace(next);
}})();
</script>
</body></html>""".encode(
            "utf-8"
        )

    def _auth_bridge(self) -> None:
        """Boot Softema session in the iframe, then redirect to dashboard."""
        body = self._read_body()
        try:
            payload = self._parse_form_or_json(body, self.headers.get("Content-Type", ""))
        except Exception:  # noqa: BLE001
            self.send_error(400, "Invalid auth payload")
            return

        next_path = str(payload.get("next") or "/dashboard")
        if not next_path.startswith("/"):
            next_path = "/dashboard"

        access_token = str(
            payload.get("accessToken")
            or payload.get("access_token")
            or payload.get("token")
            or ""
        ).strip()
        refresh_token = str(
            payload.get("refreshToken") or payload.get("refresh_token") or ""
        ).strip()

        set_cookies: list[str] = []

        # If tokens were not provided, authenticate with Softema using login/password.
        if not access_token:
            login = str(payload.get("login") or "").strip()
            password = str(payload.get("password") or "")
            if not login or not password:
                self.send_error(400, "Missing credentials or tokens")
                return

            auth_body = json.dumps({"login": login, "password": password}).encode("utf-8")
            headers = {
                "Content-Type": "application/json",
                "Accept": "application/json",
                "Host": API_UPSTREAM,
                "Accept-Encoding": "identity",
            }
            try:
                conn = http.client.HTTPSConnection(API_UPSTREAM, timeout=60)
                conn.request("POST", "/api/v1/auth", body=auth_body, headers=headers)
                upstream = conn.getresponse()
                status = upstream.status
                raw = upstream.read()
                set_cookies = [
                    value
                    for key, value in upstream.getheaders()
                    if key.lower() == "set-cookie"
                ]
                conn.close()
            except Exception as exc:  # noqa: BLE001
                msg = f"Auth bridge error: {exc}".encode()
                self.send_response(502)
                self.send_header("Content-Type", "text/plain; charset=utf-8")
                self.send_header("Content-Length", str(len(msg)))
                self.end_headers()
                self.wfile.write(msg)
                return

            if status >= 400:
                html = (
                    "<!doctype html><html><body style='font-family:sans-serif;padding:40px;"
                    "background:#F5F4F0;color:#2D2D2A'>"
                    "<h2 style='color:#0A1628'>Sign-in failed</h2>"
                    "<p>Sofema rejected these credentials. Go back and try again.</p>"
                    "</body></html>"
                ).encode("utf-8")
                self.send_response(status)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(html)))
                self.send_header(
                    "Content-Security-Policy",
                    frame_ancestors_header(self.headers.get("Origin")),
                )
                self.end_headers()
                self.wfile.write(html)
                return

            try:
                auth_json = json.loads(raw.decode("utf-8") or "{}")
            except Exception:  # noqa: BLE001
                auth_json = {}
            if isinstance(auth_json, dict):
                access_token = str(
                    auth_json.get("accessToken")
                    or auth_json.get("access_token")
                    or auth_json.get("token")
                    or ""
                ).strip()
                refresh_token = str(
                    auth_json.get("refreshToken") or auth_json.get("refresh_token") or ""
                ).strip()

        if not access_token:
            self.send_error(502, "Auth succeeded but no access token was returned")
            return

        html = self._session_boot_html(access_token, refresh_token, next_path)
        self.send_response(200)
        for cookie in set_cookies:
            if cookie:
                self.send_header("Set-Cookie", rewrite_set_cookie(cookie))
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(html)))
        self.send_header(
            "Content-Security-Policy",
            frame_ancestors_header(self.headers.get("Origin")),
        )
        self.end_headers()
        self.wfile.write(html)

    def do_OPTIONS(self):
        origin = cors_origin_for(self.headers.get("Origin"))
        self.send_response(204)
        if origin:
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Access-Control-Allow-Credentials", "true")
            self.send_header("Vary", "Origin")
        self.send_header(
            "Access-Control-Allow-Methods",
            "GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD",
        )
        self.send_header(
            "Access-Control-Allow-Headers",
            self.headers.get(
                "Access-Control-Request-Headers", "Content-Type, Authorization"
            ),
        )
        self.send_header("Access-Control-Max-Age", "86400")
        self.end_headers()

    def _read_body(self) -> bytes:
        length = int(self.headers.get("Content-Length", "0") or 0)
        return self.rfile.read(length) if length else b""

    def _proxy(self) -> None:
        raw_path = self.path or "/"
        # Health check for Render + portal probe
        if raw_path in ("/healthz", "/health"):
            body = b"ok"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            allow_origin = cors_origin_for(self.headers.get("Origin"))
            if allow_origin:
                self.send_header("Access-Control-Allow-Origin", allow_origin)
                self.send_header("Access-Control-Allow-Credentials", "true")
                self.send_header("Vary", "Origin")
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(body)
            return

        is_api = raw_path.startswith(API_PREFIX + "/") or raw_path == API_PREFIX
        if is_api:
            upstream_host = API_UPSTREAM
            path = raw_path[len(API_PREFIX) :] or "/"
        else:
            upstream_host = UPSTREAM
            path = raw_path

        body = self._read_body()
        request_origin = self.headers.get("Origin")

        headers = {}
        for key, value in self.headers.items():
            if key.lower() in HOP_BY_HOP:
                continue
            if key.lower() == "origin" and value:
                headers["Origin"] = UPSTREAM_ORIGIN
                continue
            if key.lower() == "referer" and value:
                ref = value.replace(PUBLIC_ORIGIN + API_PREFIX, API_ORIGIN)
                ref = ref.replace(PUBLIC_ORIGIN, UPSTREAM_ORIGIN)
                headers["Referer"] = ref
                continue
            headers[key] = value
        headers["Host"] = upstream_host
        headers["Accept-Encoding"] = "identity"

        try:
            conn = http.client.HTTPSConnection(upstream_host, timeout=60)
            conn.request(self.command, path, body=body or None, headers=headers)
            upstream = conn.getresponse()
            raw = upstream.read()
        except Exception as exc:  # noqa: BLE001
            msg = f"Proxy error contacting {upstream_host}: {exc}".encode()
            self.send_response(502)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(msg)
            return

        content_type = upstream.getheader("Content-Type", "")
        data = rewrite_body(content_type, raw)

        self.send_response(upstream.status)
        for key, value in upstream.getheaders():
            lk = key.lower()
            if lk in HOP_BY_HOP or lk in ("content-length", "content-encoding"):
                continue
            if lk == "location":
                self.send_header(key, rewrite_location(value, is_api))
                continue
            if lk == "set-cookie":
                self.send_header(key, rewrite_set_cookie(value))
                continue
            if lk == "content-security-policy":
                rewritten = rewrite_csp(value)
                if rewritten:
                    self.send_header(key, rewritten)
                continue
            if lk in ("x-frame-options", "content-security-policy-report-only"):
                continue
            if lk.startswith("access-control-"):
                continue
            self.send_header(key, value)

        if not is_api:
            self.send_header(
                "Content-Security-Policy",
                frame_ancestors_header(request_origin),
            )

        allow_origin = cors_origin_for(request_origin)
        if allow_origin:
            self.send_header("Access-Control-Allow-Origin", allow_origin)
            self.send_header("Access-Control-Allow-Credentials", "true")
            self.send_header("Vary", "Origin")

        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(data)
        conn.close()


class PortalHandler(SimpleHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        print(f"[arts   :{SITE_PORT}] " + fmt % args)


def main() -> None:
    socketserver.TCPServer.allow_reuse_address = True

    proxy = ThreadingHTTPServer((HOST, PORT), SofemaProxyHandler)

    print("=" * 60)
    print("ARTS Sofema proxy ready")
    print(f"  Listen:         {HOST}:{PORT}")
    print(f"  Public origin:  {PUBLIC_ORIGIN}")
    print(f"  Frame allow:    {', '.join(ALLOWED_FRAME_ORIGINS)}")
    print(f"  Health:         {PUBLIC_ORIGIN}/healthz")
    print(f"  Softema login:  {PUBLIC_ORIGIN}/login")
    print(f"  Softema API:    {PUBLIC_ORIGIN}{API_PREFIX}/api/...")
    print(f"  Session boot:   {PUBLIC_ORIGIN}/__session_boot")
    if SERVE_SITE:
        print(f"  ARTS site:      {PUBLIC_ORIGIN}/portal.html  (same process)")
    if SERVE_STATIC:
        print(f"  Static site:    http://127.0.0.1:{SITE_PORT}/portal.html")
    print("  Stop with Ctrl+C")
    print("=" * 60)

    if SERVE_STATIC:
        site = ThreadingHTTPServer(("127.0.0.1", SITE_PORT), PortalHandler)
        threading.Thread(target=site.serve_forever, daemon=True).start()

    try:
        proxy.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down…")
    finally:
        proxy.shutdown()


if __name__ == "__main__":
    main()
