"""Serve the fixture page and its revisions through a GET-only gateway."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import re
import sys
from urllib.error import URLError
from urllib.parse import parse_qs, urlencode, urlsplit
from urllib.request import ProxyHandler, build_opener


def approved_target(request_target, page_id):
    target = urlsplit(request_target)
    values = parse_qs(target.query, keep_blank_values=True)
    if any(len(items) != 1 for items in values.values()):
        return None
    params = {key: items[0] for key, items in values.items()}
    if target.path == "/index.php" and set(params) == {"oldid"}:
        if re.fullmatch(r"[1-9][0-9]{0,4}", params["oldid"]):
            return "/index.php?" + urlencode(params)
    if target.path != "/api.php":
        return None
    expected = {"action": "query", "prop": "revisions", "format": "json", "formatversion": "2"}
    if any(params.get(key) != value for key, value in expected.items()):
        return None
    extra = {key: value for key, value in params.items() if key not in expected}
    if extra == {"pageids": page_id, "rvprop": "ids|timestamp", "rvlimit": "100"}:
        return "/api.php?" + urlencode(params)
    if (set(extra) == {"revids", "rvprop", "rvslots"} and extra["rvslots"] == "main"
            and extra["rvprop"] == "ids|timestamp|content" and re.fullmatch(r"[1-9][0-9]{0,4}", extra["revids"])):
        return "/api.php?" + urlencode(params)
    return None


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        target = approved_target(self.path, self.server.page_id)
        if target is None:
            self.send_error(404)
            return
        try:
            with build_opener(ProxyHandler({})).open("http://127.0.0.1:8833" + target, timeout=8) as response:
                data = response.read(2_000_001)
                media = response.headers.get("Content-Type", "application/octet-stream")
        except URLError:
            self.send_error(502)
            return
        if len(data) > 2_000_000:
            self.send_error(502)
            return
        self.send_response(200)
        self.send_header("Content-Type", media)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)


if __name__ == "__main__":
    with ThreadingHTTPServer(("127.0.0.1", 8834), Handler) as server:
        server.page_id = sys.argv[1]
        server.serve_forever()
