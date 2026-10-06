"""Generates a local CA and server certificate for the mock's HTTPS listener.

US-051: the Connect IQ simulator refuses plain http:// with
-1001 SECURE_CONNECTION_REQUIRED, so the mock needs TLS. There is no
standard-library way to *create* certificates (`ssl` can only load them), so
this shells out to the system `openssl` binary - present on every dev
machine and in the project's container image - rather than adding a
dependency like `cryptography` just for a one-time local bootstrap.

Everything lands in mock/tls/, which is gitignored (see mock/tls/README.md,
the one file in that directory that IS committed). Certificates are
generated once, on first run, and reused after that.
"""
from __future__ import annotations

import os
import subprocess
import sys

TLS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tls")

CA_KEY = "ca.key"
CA_CRT = "ca.crt"
SERVER_KEY = "server.key"
SERVER_CRT = "server.crt"


def _run(args: list[str]) -> None:
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(
            f"openssl command failed: {' '.join(args)}\n{result.stderr}"
        )


def ensure_certs(tls_dir: str = TLS_DIR) -> tuple[str, str, str]:
    """Returns (server_crt_path, server_key_path, ca_crt_path).

    Generates a CA + server certificate pair the first time this is called
    against a given directory; reuses them on every call after that.
    """
    os.makedirs(tls_dir, exist_ok=True)
    ca_key = os.path.join(tls_dir, CA_KEY)
    ca_crt = os.path.join(tls_dir, CA_CRT)
    server_key = os.path.join(tls_dir, SERVER_KEY)
    server_crt = os.path.join(tls_dir, SERVER_CRT)

    if all(os.path.exists(p) for p in (ca_key, ca_crt, server_key, server_crt)):
        return server_crt, server_key, ca_crt

    if _which("openssl") is None:
        raise RuntimeError(
            "openssl not found on PATH. It is required once, to generate the "
            "mock's local TLS certificates into mock/tls/. Install it (e.g. "
            "apt install openssl) and run mock/run.sh again."
        )

    server_csr = os.path.join(tls_dir, "server.csr")
    ext_file = os.path.join(tls_dir, "server.ext")
    ca_srl = os.path.join(tls_dir, "ca.srl")

    print("mock: generating local CA and server certificate into mock/tls/ ...", file=sys.stderr)

    # 1. A local CA, self-signed, used only to sign this mock's server cert.
    _run([
        "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
        "-keyout", ca_key, "-out", ca_crt, "-days", "3650",
        "-subj", "/CN=Skoda Connect Watch Mock CA",
    ])

    # 2. A server key + certificate signing request for localhost.
    _run([
        "openssl", "req", "-newkey", "rsa:2048", "-nodes",
        "-keyout", server_key, "-out", server_csr,
        "-subj", "/CN=localhost",
    ])

    # 3. Subject Alternative Names: what the Connect IQ simulator and curl
    # both actually check when they connect to 127.0.0.1 or localhost.
    with open(ext_file, "w", encoding="utf-8") as fh:
        fh.write("subjectAltName=DNS:localhost,IP:127.0.0.1\n")

    # 4. Sign the CSR with the local CA.
    _run([
        "openssl", "x509", "-req", "-in", server_csr,
        "-CA", ca_crt, "-CAkey", ca_key, "-CAcreateserial",
        "-out", server_crt, "-days", "825", "-extfile", ext_file,
    ])

    for tmp in (server_csr, ext_file, ca_srl):
        try:
            os.remove(tmp)
        except FileNotFoundError:
            pass

    return server_crt, server_key, ca_crt


def _which(name: str) -> str | None:
    for directory in os.environ.get("PATH", "").split(os.pathsep):
        candidate = os.path.join(directory, name)
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    return None
