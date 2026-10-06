"""Shared pytest fixtures: a live mock server, HTTPS only, on an ephemeral
local port, isolated per test so scenario switches in one test never leak
into another.
"""
from __future__ import annotations

import os
import ssl
import sys
import threading
import urllib.error
import urllib.request

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import server as server_module  # noqa: E402
import scenarios  # noqa: E402
import tls_setup  # noqa: E402
from vehicle_data import MOCK_VIN  # noqa: E402

HOST = "127.0.0.1"


class LiveMock:
    def __init__(self, base_url: str):
        self.base_url = base_url

    def request(self, method: str, path: str, *, api_key="test-key", body=None,
                raw_body: bytes | None = None, headers=None, scenario=None):
        url = self.base_url + path
        req_headers = dict(headers or {})
        if api_key is not None:
            req_headers["X-API-Key"] = api_key
        if scenario is not None:
            req_headers["X-Mock-Scenario"] = scenario
        data = raw_body
        if body is not None:
            import json as _json
            data = _json.dumps(body).encode("utf-8")
            req_headers.setdefault("Content-Type", "application/json")
        req = urllib.request.Request(url, data=data, headers=req_headers, method=method)
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        try:
            resp = urllib.request.urlopen(req, timeout=5, context=ctx)
            return resp.getcode(), dict(resp.headers.items()), resp.read()
        except urllib.error.HTTPError as exc:
            return exc.code, dict(exc.headers.items()), exc.read()


@pytest.fixture(scope="session")
def mock_tls_dir(tmp_path_factory):
    # Isolated from mock/tls/ so the test suite never depends on - or
    # pollutes - a developer's already-generated certificates.
    return str(tmp_path_factory.mktemp("mock-tls"))


@pytest.fixture(scope="session")
def live_mock(mock_tls_dir):
    httpd = server_module.MockServer((HOST, 0), server_module.Handler, log_requests=False)
    cert, key, _ca = tls_setup.ensure_certs(mock_tls_dir)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(cert, key)
    httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
    port = httpd.socket.getsockname()[1]

    thread = threading.Thread(target=httpd.serve_forever, daemon=True)
    thread.start()

    yield LiveMock(f"https://{HOST}:{port}")

    httpd.shutdown()
    httpd.server_close()


@pytest.fixture(autouse=True)
def reset_scenario():
    """Every test starts from a clean 'default' global scenario state."""
    scenarios.set_global("default")
    yield
    scenarios.set_global("default")


@pytest.fixture
def vin():
    return MOCK_VIN
