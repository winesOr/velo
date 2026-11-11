import json
from pathlib import Path
import tempfile
import unittest

from validate_android_release import (
    extract_certificate_sha256,
    manifest_build,
    normalize_certificate_sha256,
    require_current_main,
    require_newer_build,
    validate_certificate_sha256,
)


CERT = "a" * 64
MAIN = "b" * 40
ROOT = Path(__file__).resolve().parents[2]


class AndroidReleaseValidationTest(unittest.TestCase):
    def test_certificate_digest_requires_one_expected_signer(self):
        output = f"Signer #1 certificate SHA-256 digest: {CERT.upper()}\n"
        self.assertEqual(CERT, extract_certificate_sha256(output))
        colon_separated = ":".join(
            CERT[index:index + 2] for index in range(0, 64, 2)
        )
        self.assertEqual(CERT, normalize_certificate_sha256(colon_separated))
        validate_certificate_sha256(output, CERT)
        with self.assertRaisesRegex(ValueError, "does not match"):
            validate_certificate_sha256(output, "c" * 64)
        with self.assertRaisesRegex(ValueError, "exactly one"):
            extract_certificate_sha256(f"{output}{output}")

    def test_release_build_must_strictly_increase(self):
        require_newer_build(2, None)
        require_newer_build(2, 1)
        with self.assertRaisesRegex(ValueError, "greater than"):
            require_newer_build(2, 2)
        with self.assertRaisesRegex(ValueError, "greater than"):
            require_newer_build(1, 2)

    def test_workflow_sha_must_equal_origin_main(self):
        require_current_main(MAIN, MAIN.upper())
        with self.assertRaisesRegex(ValueError, "no longer"):
            require_current_main(MAIN, "c" * 40)
        with self.assertRaisesRegex(ValueError, "valid Git"):
            require_current_main("", MAIN)

    def test_release_workflows_use_global_concurrency_and_event_repository_trust(self):
        build_workflow = (ROOT / ".github/workflows/build.yml").read_text(encoding="utf-8")
        release_workflow = (ROOT / ".github/workflows/android-release.yml").read_text(encoding="utf-8")

        validate_job = build_workflow.split("jobs:", 1)[1].split(
            "build-android:", 1
        )[0]
        self.assertNotIn("github.repository == 'edde746/plezy'", validate_job)
        self.assertIn("group: android-release\n", release_workflow)
        self.assertNotIn("android-release-${{ inputs.release_tag }}", release_workflow)
        self.assertNotIn("/releases/latest", release_workflow)
        self.assertEqual(2, release_workflow.count("android_release_state.py"))
        for workflow in (build_workflow, release_workflow):
            self.assertIn("configure_android_signing.py", workflow)
            self.assertIn("ANDROID_SIGNING_CERT_SHA256", workflow)
        self.assertIn("--verify-signature-only", build_workflow)
        self.assertIn("CN=Android Debug", build_workflow)

    def test_manifest_build_is_positive_integer(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "velo-update.json"
            path.write_text(json.dumps({"buildNumber": 9}), encoding="utf-8")
            self.assertEqual(9, manifest_build(path))
            path.write_text(json.dumps({"buildNumber": "9"}), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "invalid buildNumber"):
                manifest_build(path)

    def test_install_permission_is_opt_in_for_github_builds_only(self):
        main_manifest = (ROOT / "android/app/src/main/AndroidManifest.xml").read_text(encoding="utf-8")
        github_manifest = (ROOT / "android/app/src/github/AndroidManifest.xml").read_text(encoding="utf-8")
        build_script = (ROOT / "android/app/build.gradle.kts").read_text(encoding="utf-8")
        release_workflow = (ROOT / ".github/workflows/android-release.yml").read_text(encoding="utf-8")
        build_workflow = (ROOT / ".github/workflows/build.yml").read_text(encoding="utf-8")

        self.assertNotIn("REQUEST_INSTALL_PACKAGES", main_manifest)
        self.assertIn("REQUEST_INSTALL_PACKAGES", github_manifest)
        self.assertIn("VELO_ANDROID_GITHUB_UPDATE_BUILD", build_script)
        for workflow in (release_workflow, build_workflow):
            self.assertIn("VELO_ANDROID_GITHUB_UPDATE_BUILD", workflow)


if __name__ == "__main__":
    unittest.main()
