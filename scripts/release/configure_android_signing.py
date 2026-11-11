#!/usr/bin/env python3
"""Configure a release Android signing key from CI environment variables."""

from __future__ import annotations

import base64
import binascii
import os
from pathlib import Path
import re
import sys
from typing import Mapping


REQUIRED_ENV = (
    "ANDROID_KEYSTORE_BASE64",
    "ANDROID_STORE_PASSWORD",
    "ANDROID_KEY_PASSWORD",
    "ANDROID_KEY_ALIAS",
    "ANDROID_SIGNING_CERT_SHA256",
)


def normalize_certificate_sha256(value: str) -> str:
    compact = re.sub(r"[\s:]", "", value).lower()
    if not re.fullmatch(r"[0-9a-f]{64}", compact):
        raise ValueError("ANDROID_SIGNING_CERT_SHA256 must contain 64 hexadecimal digits")
    return compact


def _properties_value(value: str) -> str:
    encoded = value.encode("utf-16-be")
    return "".join(
        "\\u" + encoded[index:index + 2].hex()
        for index in range(0, len(encoded), 2)
    )


def configure(root: Path, env: Mapping[str, str]) -> str:
    missing = [name for name in REQUIRED_ENV if not env.get(name)]
    if missing:
        raise ValueError("Missing required signing secrets: " + ", ".join(missing))
    if env["ANDROID_KEY_ALIAS"].lower() == "androiddebugkey":
        raise ValueError("A debug signing key cannot be used for releases")
    certificate_sha256 = normalize_certificate_sha256(
        env["ANDROID_SIGNING_CERT_SHA256"]
    )
    encoded_key = "".join(env["ANDROID_KEYSTORE_BASE64"].split())
    try:
        keystore = base64.b64decode(encoded_key, validate=True)
    except (binascii.Error, ValueError) as error:
        raise ValueError("ANDROID_KEYSTORE_BASE64 is not valid base64") from error
    if not keystore:
        raise ValueError("ANDROID_KEYSTORE_BASE64 decodes to an empty keystore")

    umask = os.umask(0o077)
    try:
        android_dir = root / "android"
        app_dir = android_dir / "app"
        app_dir.mkdir(parents=True, exist_ok=True)
        keystore_path = app_dir / "upload-keystore.jks"
        keystore_path.write_bytes(keystore)
        keystore_path.chmod(0o600)
        properties = {
            "storeFile": "upload-keystore.jks",
            "storePassword": env["ANDROID_STORE_PASSWORD"],
            "keyPassword": env["ANDROID_KEY_PASSWORD"],
            "keyAlias": env["ANDROID_KEY_ALIAS"],
        }
        properties_path = android_dir / "key.properties"
        properties_path.write_text(
            "".join(
                f"{key}={_properties_value(value)}\n"
                for key, value in properties.items()
            ),
            encoding="utf-8",
        )
        properties_path.chmod(0o600)
    finally:
        os.umask(umask)
    return certificate_sha256


def main() -> int:
    try:
        configure(Path.cwd(), os.environ)
    except (OSError, UnicodeError, ValueError) as error:
        print(f"Android signing configuration failed: {error}", file=sys.stderr)
        return 1
    print("Configured Android release signing")
    return 0


if __name__ == "__main__":
    sys.exit(main())
