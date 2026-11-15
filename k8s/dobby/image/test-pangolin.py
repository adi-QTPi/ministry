#!/usr/bin/env python3
"""Local tests for preview authentication configuration."""
import importlib.machinery
import importlib.util
import json
import pathlib
import tempfile
import unittest
from unittest.mock import patch

import yaml

source = pathlib.Path(__file__).with_name("pangolin.py")
if not source.exists():
    source = pathlib.Path("/usr/local/bin/dobby-pangolin")
loader = importlib.machinery.SourceFileLoader("pangolin", str(source))
spec = importlib.util.spec_from_loader(loader.name, loader)
pangolin = importlib.util.module_from_spec(spec)
loader.exec_module(pangolin)


def configured(root):
    pangolin.seed(root)
    data = yaml.safe_load(pangolin.TEMPLATE)
    data.update(preview_url="https://hq-previews.example.test", auth_url="https://hq-preview-auth.example.test")
    data["smtp"].update(host="localhost", port=1465, **{"from": "sender@example.test"})
    (root / "settings.yaml").write_text(yaml.safe_dump(data))
    return data


class ConfigTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name) / "pangolin"

    def test_seed_preserves_settings_allowlist_and_secret(self):
        configured(self.root)
        (self.root / "allowed-emails.txt").write_text("friend@example.test\n")
        before = {p.name: p.read_bytes() for p in self.root.iterdir() if p.is_file()}
        pangolin.seed(self.root)
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.root.iterdir() if p.is_file()})
        for name in before:
            self.assertEqual((self.root / name).stat().st_mode & 0o777, 0o600)

    def test_unconfigured_boot_is_locked(self):
        pangolin.seed(self.root)
        self.assertEqual(pangolin.emails(self.root), [])
        with self.assertRaises(ValueError):
            pangolin.settings(self.root)

    def test_empty_allowlist_disables_resource(self):
        data = configured(self.root)
        resource = pangolin.blueprint(data, [])["public-resources"]["dobby-previews"]
        self.assertFalse(resource["enabled"])
        self.assertFalse(resource["auth"]["sso-enabled"])

    def test_exact_emails_only(self):
        configured(self.root)
        (self.root / "allowed-emails.txt").write_text("# approved\nFriend@Example.Test\nfriend@example.test\n")
        self.assertEqual(pangolin.emails(self.root), ["friend@example.test"])
        for invalid in ("*@example.test", "friend@example.test other@example.test", "friend@example", "x@evil.test/path"):
            (self.root / "allowed-emails.txt").write_text(invalid)
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                pangolin.emails(self.root)

    def test_invalid_origins_and_sessions_rejected(self):
        data = configured(self.root)
        for url in ("http://host.test", "https://user:pass@host.test", "https://host.test/path", "https://host.test:6100", "https://host.test?x=1"):
            with self.subTest(url=url), self.assertRaises(ValueError):
                pangolin.origin(url)
        for key, value in (("auth_url", data["preview_url"]), ("auth_url", "https://auth.other.test"), ("session_hours", 0)):
            changed = {**data, key: value}
            (self.root / "settings.yaml").write_text(yaml.safe_dump(changed))
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                pangolin.settings(self.root)

    def test_smtp_requires_tls(self):
        data = configured(self.root)
        data["smtp"]["secure"] = False
        (self.root / "settings.yaml").write_text(yaml.safe_dump(data))
        with self.assertRaises(ValueError):
            pangolin.settings(self.root)

    def test_internal_ports_outside_preview_range(self):
        data = configured(self.root)
        state = json.loads((self.root / "admin.json").read_text())
        config = pangolin.runtime_config(data, state)
        for name, port in config["server"].items():
            if name.endswith("_port"):
                self.assertFalse(3000 <= port <= 5999)
        self.assertFalse(config["flags"]["enable_integration_api"])

    def test_sync_rejects_unsuccessful_blueprint(self):
        data = configured(self.root)
        api = pangolin.Api(data["auth_url"])
        with patch.object(api, "call", side_effect=[{}, {"orgs": [{"orgId": "dobby"}]}, {"succeeded": False}, {}]):
            with self.assertRaises(ValueError):
                api.sync(data, {"email": "admin@example.test", "password": "unused"}, ["friend@example.test"])


if __name__ == "__main__":
    unittest.main()
