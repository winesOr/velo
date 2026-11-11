import base64
import os
from pathlib import Path
import stat
import tempfile
import unittest

from configure_android_signing import configure


CERT = "a" * 64
SECRETS = {
    "ANDROID_KEYSTORE_BASE64": base64.b64encode(b"keystore fixture").decode(),
    "ANDROID_STORE_PASSWORD": "store pass",
    "ANDROID_KEY_PASSWORD": "key:pass",
    "ANDROID_KEY_ALIAS": "release",
    "ANDROID_SIGNING_CERT_SHA256": CERT,
}


class AndroidSigningConfigurationTest(unittest.TestCase):
    def test_requires_all_release_secrets(self):
        with tempfile.TemporaryDirectory() as directory:
            for name in SECRETS:
                env = dict(SECRETS)
                env.pop(name)
                with self.subTest(name=name), self.assertRaisesRegex(ValueError, name):
                    configure(Path(directory), env)

    def test_rejects_debug_alias_invalid_certificate_and_invalid_keystore(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for key, value, message in (
                ("ANDROID_KEY_ALIAS", "AndroidDebugKey", "debug signing key"),
                ("ANDROID_SIGNING_CERT_SHA256", "not-a-digest", "64 hexadecimal"),
                ("ANDROID_KEYSTORE_BASE64", "not base64", "valid base64"),
            ):
                env = dict(SECRETS)
                env[key] = value
                with self.subTest(key=key), self.assertRaisesRegex(ValueError, message):
                    configure(root, env)

    def test_writes_private_signing_files_with_escaped_properties(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertEqual(CERT, configure(root, SECRETS))
            keystore = root / "android/app/upload-keystore.jks"
            properties = root / "android/key.properties"
            self.assertEqual(b"keystore fixture", keystore.read_bytes())
            self.assertEqual(0o600, stat.S_IMODE(os.stat(keystore).st_mode))
            self.assertEqual(0o600, stat.S_IMODE(os.stat(properties).st_mode))
            encoded = properties.read_text(encoding="utf-8")
            self.assertIn("storeFile=", encoded)
            self.assertIn("\\u", encoded)
            self.assertNotIn("store pass", encoded)
            self.assertNotIn("key:pass", encoded)


if __name__ == "__main__":
    unittest.main()
