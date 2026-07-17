#!/usr/bin/env python3
"""RFC 6238 TOTP code generator.

Reads a JSON array of {id, secret, digits, period, algo} from stdin
(secret is base32, algo one of SHA1/SHA256/SHA512), writes a JSON
array of {id, code} for the current time step to stdout.
"""
import base64
import hashlib
import hmac
import json
import struct
import sys
import time

ALGOS = {
    "SHA1": hashlib.sha1,
    "SHA256": hashlib.sha256,
    "SHA512": hashlib.sha512,
}


def totp(secret_b32, digits=6, period=30, algo="SHA1", at=None):
    padded = secret_b32.strip().upper().replace(" ", "")
    padded += "=" * (-len(padded) % 8)
    key = base64.b32decode(padded)
    counter = int((at if at is not None else time.time()) // period)
    msg = struct.pack(">Q", counter)
    digest = hmac.new(key, msg, ALGOS.get(algo, hashlib.sha1)).digest()
    offset = digest[-1] & 0x0F
    code_int = struct.unpack(">I", digest[offset:offset + 4])[0] & 0x7FFFFFFF
    code = str(code_int % (10 ** digits))
    return code.zfill(digits)


def main():
    entries = json.load(sys.stdin)
    out = []
    for e in entries:
        try:
            code = totp(
                e["secret"],
                digits=int(e.get("digits", 6)),
                period=int(e.get("period", 30)),
                algo=e.get("algo", "SHA1"),
            )
            out.append({"id": e["id"], "code": code})
        except Exception:
            out.append({"id": e["id"], "code": ""})
    json.dump(out, sys.stdout)


if __name__ == "__main__":
    main()
