"""Exercise packaged RTL authentication, CSRF and both Lightning backends."""
import hashlib
import http.cookiejar
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Any


class Session:
    def __init__(self, base_url: str):
        self.base_url = base_url
        self.cookies = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(self.cookies))
        self.token: str | None = None

    def request(self, path: str, body: dict[str, object] | None = None, csrf: bool = True) -> tuple[int, Any]:
        headers = {}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        if body is not None:
            headers["Content-Type"] = "application/json"
            if csrf:
                for cookie in self.cookies:
                    if cookie.name == "XSRF-TOKEN":
                        headers["X-XSRF-TOKEN"] = urllib.parse.unquote(cookie.value or "")
        request = urllib.request.Request(
            self.base_url + path,
            data=None if body is None else json.dumps(body).encode(),
            headers=headers,
        )
        try:
            response = self.opener.open(request, timeout=30)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            data: Any = response.read().decode()
            if "application/json" in response.headers.get("Content-Type", ""):
                data = json.loads(data)
            assert response.status is not None
            return response.status, data

    def login(self):
        status, page = self.request("/")
        assert status == 200 and "<rtl-app" in page
        status, body = self.request("/api/authenticate", {
            "authenticateWith": "PASSWORD",
            "authenticationValue": hashlib.sha256(b"a").hexdigest(),
        })
        assert status == 200, body
        self.token = body["token"]


base_url = sys.argv[1]
first, second = Session(base_url), Session(base_url)
assert first.request("/api/lnd/getinfo")[0] == 401
first.request("/")
assert first.request("/api/authenticate", {}, csrf=False)[0] == 403
first.login()
second.login()
status, config = first.request("/api/conf")
assert status == 200
nodes = config["nodes"]
# RTL accepts the historical CLT spelling in configuration and normalizes
# the selected node to CLN internally.
def implementation_of(node):
    return {"CLT": "CLN"}.get(node["lnImplementation"], node["lnImplementation"])


assert {implementation_of(node) for node in nodes} >= {"LND", "CLN"}
selected = {}
for session, implementation in [(first, "LND"), (second, "CLN")]:
    index = next(node["index"] for node in nodes if implementation_of(node) == implementation)
    status, body = session.request(f"/api/conf/updateSelNode/{index}/-1")
    assert status == 200, body
    selected[implementation] = index

# Switching one session must not redirect another session's node requests.
for session, implementation, key in [(first, "lnd", "identity_pubkey"), (second, "cln", "id")]:
    status, info = session.request(f"/api/{implementation}/getinfo")
    assert status == 200 and info.get(key), info
assert first.request("/api/cln/getinfo")[0] == 409
assert second.request("/api/lnd/getinfo")[0] == 409
assert first.request("/api/conf")[1]["selectedNodeIndex"] == selected["LND"]
assert second.request("/api/conf")[1]["selectedNodeIndex"] == selected["CLN"]
assert first.request("/api/conf/updateSelNode/999/-1")[0] == 404
assert Session(base_url).request("/api/conf")[0] == 200
assert first.request("/api/authenticate/logout", {}, csrf=False)[0] == 403
assert first.request("/api/authenticate/logout", {}) == (200, {"loggedout": True})
print("RTL authentication, CSRF, LND/CLN getinfo and session isolation passed")
