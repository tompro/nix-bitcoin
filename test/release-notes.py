"""Offline tests for release tag validation and changelog extraction."""

import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "release_notes", Path(__file__).resolve().parents[1] / "helper" / "release-notes.py"
)
assert spec is not None and spec.loader is not None
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
release_notes = module.release_notes


class ReleaseNotesTests(unittest.TestCase):
    def test_extracts_only_requested_release(self):
        changelog = """# Changelog

## [Unreleased]
Future work.

## [0.1.0] - 2026-11-04
### Changed
Reviewed changes.

### Upgrade notes
Back up before deployment.

## [0.0.139]
Older changes.
"""
        self.assertEqual(
            release_notes("v0.1.0", changelog),
            "### Changed\nReviewed changes.\n\n### Upgrade notes\nBack up before deployment.\n",
        )

    def test_accepts_last_section(self):
        self.assertEqual(release_notes("v1.2.3", "## [1.2.3]\nFixes.\n"), "Fixes.\n")

    def test_rejects_unreleased_only(self):
        with self.assertRaises(ValueError):
            release_notes("v0.1.0", "## [Unreleased]\nNot reviewed for release.\n")

    def test_rejects_missing_empty_or_duplicate_sections(self):
        for changelog in [
            "# Changelog\n",
            "## [0.1.0]\n\n## [0.0.139]\nOld.\n",
            "## [0.1.0]\nFirst.\n## [0.1.0]\nSecond.\n",
        ]:
            with self.subTest(changelog=changelog), self.assertRaises(ValueError):
                release_notes("v0.1.0", changelog)

    def test_rejects_invalid_tags(self):
        for tag in ["0.1.0", "v01.2.3", "v1.02.3", "v1.2.03", "v1.2", "v1.2.3-rc1", "v1.2.3;echo bad"]:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                release_notes(tag, "## [0.1.0]\nChanges.\n")


if __name__ == "__main__":
    unittest.main()
