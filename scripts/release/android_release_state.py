#!/usr/bin/env python3
"""Find the maximum Android build number across all published stable releases."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

from validate_android_release import manifest_build


MANIFEST_NAME = "velo-update.json"
_BUILD_TAG = re.compile(r"\+(?P<build>[1-9][0-9]*)$")


def flatten_release_pages(value: object) -> list[dict]:
    if not isinstance(value, list):
        raise ValueError("GitHub releases response must be a JSON array")
    releases: list[dict] = []
    for item in value:
        if isinstance(item, list):
            releases.extend(flatten_release_pages(item))
        elif isinstance(item, dict):
            releases.append(item)
        else:
            raise ValueError("GitHub releases response contains a non-object entry")
    return releases


def stable_releases(releases: list[dict]) -> list[dict]:
    return [
        release
        for release in releases
        if release.get("draft") is not True
        and release.get("prerelease") is not True
    ]


def manifest_asset(release: dict) -> dict | None:
    assets = release.get("assets")
    if not isinstance(assets, list):
        raise ValueError(f"{release.get('tag_name', '<unknown>')}: invalid assets list")
    matches = [
        asset
        for asset in assets
        if isinstance(asset, dict) and asset.get("name") == MANIFEST_NAME
    ]
    if len(matches) > 1:
        raise ValueError(
            f"{release.get('tag_name', '<unknown>')}: ambiguous {MANIFEST_NAME} asset"
        )
    return matches[0] if matches else None


def max_release_build(
    releases: list[dict], manifests_by_tag: dict[str, Path]
) -> int:
    builds = []
    for release in stable_releases(releases):
        tag = release.get("tag_name")
        if not isinstance(tag, str) or not tag:
            raise ValueError(
                f"{tag or '<unknown>'}: stable release has no tag_name"
            )
        if manifest_asset(release) is not None:
            if tag not in manifests_by_tag:
                raise ValueError(f"{tag}: downloaded update manifest is missing")
            builds.append(manifest_build(manifests_by_tag[tag]))
            continue
        tag_match = _BUILD_TAG.search(tag)
        if tag_match is not None:
            builds.append(int(tag_match.group("build")))
    return max(builds, default=0)


def _run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, check=True, capture_output=True, text=True)


def fetch_max_release_build(repository: str) -> int:
    response = _run(
        "gh",
        "api",
        "--paginate",
        "--slurp",
        f"repos/{repository}/releases?per_page=100",
    )
    releases = stable_releases(
        flatten_release_pages(json.loads(response.stdout or "[]"))
    )
    with tempfile.TemporaryDirectory(prefix="velo-android-releases-") as directory:
        root = Path(directory)
        manifests_by_tag: dict[str, Path] = {}
        for index, release in enumerate(releases):
            if manifest_asset(release) is None:
                continue
            tag = release.get("tag_name")
            if not isinstance(tag, str) or not tag:
                raise ValueError("Stable release with update manifest has no tag_name")
            output_dir = root / str(index)
            output_dir.mkdir()
            _run(
                "gh",
                "release",
                "download",
                tag,
                "--repo",
                repository,
                "--pattern",
                MANIFEST_NAME,
                "--dir",
                str(output_dir),
                "--clobber",
            )
            manifests_by_tag[tag] = output_dir / MANIFEST_NAME
        return max_release_build(releases, manifests_by_tag)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    args = parser.parse_args(argv)
    try:
        print(fetch_max_release_build(args.repository))
    except (
        OSError,
        UnicodeError,
        ValueError,
        json.JSONDecodeError,
        subprocess.CalledProcessError,
    ) as error:
        print(f"Android release state lookup failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
