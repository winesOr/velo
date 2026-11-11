import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from generate_android_update import APK_NAME, inspect_apk, release_version, write_manifest


class AndroidUpdateManifestTest(unittest.TestCase):
    def test_tag_must_match_version_and_build(self):
        with tempfile.TemporaryDirectory() as directory:
            pubspec = Path(directory) / "pubspec.yaml"
            pubspec.write_text("name: plezy\nversion: 2.23.23+4205\n", encoding="utf-8")
            self.assertEqual(("2.23.23", 4205), release_version(pubspec, "v2.23.23+4205"))
            self.assertEqual(("2.23.23", 4205), release_version(pubspec, "v2.23.23"))
            for tag in ("v2.23.23+4204", "v2.23.24", "v2.23.23; touch /tmp/pwned", "../v2.23.23"):
                with self.subTest(tag=tag), self.assertRaises(ValueError):
                    release_version(pubspec, tag)

    def test_manifest_hashes_the_exact_downloaded_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            apk = root / "release.apk"
            payload = b"a signed APK fixture\x00\xff"
            apk.write_bytes(payload)
            path = write_manifest(apk, root / "output", "2.23.23", 4205)
            manifest = json.loads(path.read_text())
            self.assertEqual(4205, manifest["buildNumber"])
            self.assertEqual("com.wines.velo", manifest["packageName"])
            self.assertEqual(1, manifest["schemaVersion"])
            self.assertEqual(
                [{"name": APK_NAME, "abi": "universal", "sha256": hashlib.sha256(payload).hexdigest(), "size": len(payload)}],
                manifest["assets"],
            )
            self.assertEqual(payload, (path.parent / APK_NAME).read_bytes())

    def test_rejects_apk_whose_built_version_differs(self):
        with patch("generate_android_update.subprocess.check_output", side_effect=["com.wines.velo\n", "2.23.23\n", "4204\n"]):
            with self.assertRaisesRegex(ValueError, "version-code"):
                inspect_apk(Path("apkanalyzer"), Path("app.apk"), "2.23.23", 4205)

    def test_rejects_different_application(self):
        with patch("generate_android_update.subprocess.check_output", return_value="com.other.application\n"):
            with self.assertRaisesRegex(ValueError, "application-id"):
                inspect_apk(Path("apkanalyzer"), Path("app.apk"), "2.23.23", 4205)


if __name__ == "__main__":
    unittest.main()
