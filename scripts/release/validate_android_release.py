#!/usr/bin/env python3
"""Validate release ordering, source revision, and Android signing continuity."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
import sys


_SHA256 = re.compile(r"^[0-9a-fA-F]{64}$")
_GIT_SHA = re.compile(r"^[0-9a-fA-F]{40,64}$")
_APKSIGNER_CERT_SHA256 = re.compile(
    r"certificate SHA-256 digest:\s*([0-9a-fA-F:]+)", re.IGNORECASE
)


def normalize_certificate_sha256(value: str) -> str:
    compact = re.sub(r"[\s:]", "", value).lower()
    if not _SHA256.fullmatch(compact):
        raise ValueError("signing certificate SHA-256 must contain 64 hexadecimal digits")
    return compact


def extract_certificate_sha256(apksigner_output: str) -> str:
    matches = _APKSIGNER_CERT_SHA256.findall(apksigner_output)
    if len(matches) != 1:
        raise ValueError(
            "expected exactly one signer certificate SHA-256 digest in apksigner output"
        )
    return normalize_certificate_sha256(matches[0])


def validate_certificate_sha256(apksigner_output: str, expected_sha256: str) -> None:
    actual = extract_certificate_sha256(apksigner_output)
    expected = normalize_certificate_sha256(expected_sha256)
    if actual != expected:
        raise ValueError(
            "release APK signing certificate does not match the configured continuity fingerprint"
        )


def require_current_main(github_sha: str, origin_main_sha: str) -> None:
    if not _GIT_SHA.fullmatch(github_sha) or not _GIT_SHA.fullmatch(origin_main_sha):
        raise ValueError("workflow and origin/main must resolve to valid Git commit IDs")
    if github_sha.lower() != origin_main_sha.lower():
        raise ValueError("workflow SHA is no longer the current origin/main commit")


def require_newer_build(candidate_build: int, latest_build: int | None) -> None:
    if candidate_build <= 0:
        raise ValueError("candidate build number must be positive")
    if latest_build is not None and candidate_build <= latest_build:
        raise ValueError(
            f"candidate build {candidate_build} must be greater than latest release build {latest_build}"
        )


def manifest_build(path: Path) -> int:
    data = json.loads(path.read_text(encoding="utf-8"))
    build = data.get("buildNumber") if isinstance(data, dict) else None
    if not isinstance(build, int) or build <= 0:
        raise ValueError(f"{path}: invalid buildNumber")
    return build


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate-manifest", type=Path)
    parser.add_argument("--latest-manifest", type=Path)
    parser.add_argument("--latest-build", type=int)
    parser.add_argument("--github-sha")
    parser.add_argument("--origin-main-sha")
    parser.add_argument("--apksigner-output", type=Path)
    parser.add_argument("--expected-cert-sha256")
    parser.add_argument("--verify-signature-only", action="store_true")
    args = parser.parse_args(argv)
    try:
        cert_args = (args.apksigner_output is not None, args.expected_cert_sha256 is not None)
        if cert_args[0] != cert_args[1]:
            raise ValueError(
                "--apksigner-output and --expected-cert-sha256 must be provided together"
            )
        if args.apksigner_output is not None:
            validate_certificate_sha256(
                args.apksigner_output.read_text(encoding="utf-8"),
                args.expected_cert_sha256,
            )
        if args.verify_signature_only:
            if not cert_args[0]:
                raise ValueError(
                    "--verify-signature-only requires apksigner output and certificate fingerprint"
                )
            print("Validated Android release signer continuity")
            return 0

        if args.candidate_manifest is None or not args.github_sha or not args.origin_main_sha:
            raise ValueError(
                "--candidate-manifest, --github-sha, and --origin-main-sha are required"
            )
        if args.latest_manifest is not None and args.latest_build is not None:
            raise ValueError("--latest-manifest and --latest-build are mutually exclusive")
        require_current_main(args.github_sha, args.origin_main_sha)
        require_newer_build(
            manifest_build(args.candidate_manifest),
            manifest_build(args.latest_manifest)
            if args.latest_manifest is not None
            else args.latest_build,
        )
    except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
        print(f"Android release validation failed: {error}", file=sys.stderr)
        return 1
    print("Validated Android release ordering, source revision, and signer continuity")
    return 0


if __name__ == "__main__":
    sys.exit(main())
