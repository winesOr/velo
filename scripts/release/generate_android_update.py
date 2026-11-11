#!/usr/bin/env python3
"""Generate the Android self-update manifest from the exact release APK."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from pubspec_version import parse_pubspec_version


PACKAGE_NAME = "com.wines.velo"
APK_NAME = "velo-android-universal.apk"


def release_version(pubspec: Path, tag: str) -> tuple[str, int]:
    full_version, build = parse_pubspec_version(pubspec.read_text(encoding="utf-8"))
    version = full_version.split("+", 1)[0]
    if tag not in {f"v{version}", f"v{full_version}"}:
        raise ValueError("release tag must equal v<pubspec version> or v<version>+<build>")
    build_number = int(build)
    if not 0 < build_number <= 2147483647:
        raise ValueError("Android build number must be a positive signed 32-bit integer")
    return version, build_number


def inspect_apk(apkanalyzer: Path, apk: Path, version: str, build: int) -> None:
    expected = {"application-id": PACKAGE_NAME, "version-name": version, "version-code": str(build)}
    for key, value in expected.items():
        actual = subprocess.check_output(
            [str(apkanalyzer), "manifest", key, str(apk)], text=True
        ).strip()
        if actual != value:
            raise ValueError(f"APK {key} does not match the release metadata")


def write_manifest(apk: Path, output: Path, version: str, build: int) -> Path:
    if not apk.is_file() or apk.stat().st_size == 0:
        raise ValueError("release APK must be a nonempty regular file")
    output.mkdir(parents=True, exist_ok=True)
    target = output / APK_NAME
    if apk.resolve() != target.resolve():
        shutil.copyfile(apk, target)
    digest = hashlib.sha256()
    with target.open("rb") as package:
        for chunk in iter(lambda: package.read(1024 * 1024), b""):
            digest.update(chunk)
    manifest = {
        "schemaVersion": 1,
        "version": version,
        "buildNumber": build,
        "packageName": PACKAGE_NAME,
        "assets": [{"name": APK_NAME, "abi": "universal", "sha256": digest.hexdigest(), "size": target.stat().st_size}],
    }
    path = output / "velo-update.json"
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pubspec", type=Path, default=Path("pubspec.yaml"))
    parser.add_argument("--tag", required=True)
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--apk", type=Path)
    parser.add_argument("--apkanalyzer", type=Path)
    parser.add_argument("--output", type=Path, default=Path("build/android-release"))
    args = parser.parse_args()
    try:
        version, build = release_version(args.pubspec, args.tag)
        if args.validate_only:
            print(f"Validated Android release {version}+{build}")
            return 0
        if args.apk is None or args.apkanalyzer is None:
            raise ValueError("--apk and --apkanalyzer are required to generate release assets")
        inspect_apk(args.apkanalyzer, args.apk, version, build)
        print(write_manifest(args.apk, args.output, version, build))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Android release failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
