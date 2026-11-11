import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from android_release_state import (
    fetch_max_release_build,
    flatten_release_pages,
    manifest_asset,
    max_release_build,
    stable_releases,
)


class AndroidReleaseStateTest(unittest.TestCase):
    def test_reads_every_stable_release_and_ignores_drafts_and_prereleases(self):
        pages = [
            [
                {
                    "tag_name": "v1+4",
                    "draft": False,
                    "prerelease": False,
                    "assets": [{"name": "velo-update.json"}],
                },
                {
                    "tag_name": "v9+9",
                    "draft": True,
                    "prerelease": False,
                    "assets": [{"name": "velo-update.json"}],
                },
            ],
            [
                {
                    "tag_name": "v2+8",
                    "draft": False,
                    "prerelease": True,
                    "assets": [{"name": "velo-update.json"}],
                },
                {
                    "tag_name": "v1+6",
                    "draft": False,
                    "prerelease": False,
                    "assets": [{"name": "velo-update.json"}],
                },
            ],
        ]
        releases = flatten_release_pages(pages)
        stable = stable_releases(releases)
        self.assertEqual(["v1+4", "v1+6"], [release["tag_name"] for release in stable])

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifests = {}
            for tag, build in (("v1+4", 4), ("v1+6", 6)):
                path = root / f"{build}.json"
                path.write_text(json.dumps({"buildNumber": build}), encoding="utf-8")
                manifests[tag] = path
            self.assertEqual(6, max_release_build(releases, manifests))

    def test_manifest_lookup_rejects_duplicate_update_assets(self):
        release = {
            "tag_name": "v1+2",
            "assets": [
                {"name": "velo-update.json"},
                {"name": "velo-update.json"},
            ],
        }
        with self.assertRaisesRegex(ValueError, "ambiguous"):
            manifest_asset(release)

    def test_no_stable_manifest_means_first_release(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(0, max_release_build([], {}))

    def test_legacy_full_tag_still_participates_in_monotonicity(self):
        releases = [
            {
                "tag_name": "v1.2.3+11",
                "draft": False,
                "prerelease": False,
                "assets": [],
            },
            {
                "tag_name": "v1.2.3",
                "draft": False,
                "prerelease": False,
                "assets": [],
            },
        ]
        self.assertEqual(11, max_release_build(releases, {}))

    def test_network_helper_checks_every_paginated_stable_release(self):
        releases = [
            [
                {
                    "tag_name": "v1+3",
                    "draft": False,
                    "prerelease": False,
                    "assets": [{"name": "velo-update.json"}],
                }
            ],
            [
                {
                    "tag_name": "v1+7",
                    "draft": False,
                    "prerelease": False,
                    "assets": [{"name": "velo-update.json"}],
                }
            ],
        ]

        def fake_run(*args):
            if args[1:3] == ("api", "--paginate"):
                return type("Result", (), {"stdout": json.dumps(releases)})()
            output_dir = Path(args[args.index("--dir") + 1])
            tag = args[3]
            build = 3 if tag == "v1+3" else 7
            (output_dir / "velo-update.json").write_text(
                json.dumps({"buildNumber": build}), encoding="utf-8"
            )
            return type("Result", (), {"stdout": ""})()

        with patch("android_release_state._run", side_effect=fake_run):
            self.assertEqual(7, fetch_max_release_build("winesOr/velo"))


if __name__ == "__main__":
    unittest.main()
