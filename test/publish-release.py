"""Offline release-policy tests: all publishing calls are mocked."""

import copy
import importlib.util
import json
import os
import tempfile
import unittest
from datetime import date
from pathlib import Path
from typing import Any
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "publish_release", Path(__file__).resolve().parents[1] / "helper" / "publish-release.py"
)
assert spec is not None and spec.loader is not None
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

REPO = "tompro/nix-bitcoin"
SHA = "a" * 40
OTHER = "b" * 40
TODAY = date(2026, 11, 4)
TAG = "v2026.11.04.1"
RUN: dict[str, Any] = {
    "id": 123,
    "name": "nix-bitcoin tests",
    "status": "completed",
    "conclusion": "success",
    "event": "push",
    "head_branch": "master",
    "head_repository": {"full_name": REPO},
    "head_sha": SHA,
}


class ReleasePolicyTests(unittest.TestCase):
    def choose(self, tags=None, releases=None, ancestor=lambda *_: False):
        return module.choose_tag(SHA, TODAY, tags or {}, releases or {}, ancestor)

    def test_only_successful_master_push_is_eligible(self):
        self.assertTrue(module.eligible(RUN, REPO))
        for field, value in [
            ("name", "other workflow"), ("status", "in_progress"),
            ("conclusion", "failure"), ("conclusion", "cancelled"),
            ("event", "pull_request"), ("event", "workflow_dispatch"),
            ("head_branch", "feature"), ("head_repository", None),
            ("head_repository", {"full_name": "someone/fork"}),
            ("head_sha", None), ("head_sha", "not-a-commit"),
        ]:
            with self.subTest(field=field, value=value):
                changed = copy.deepcopy(RUN)
                changed[field] = value
                self.assertFalse(module.eligible(changed, REPO))

    def test_calendar_tag_validation(self):
        for tag in [TAG, "v2026.11.04.10", "v2028.02.29.1"]:
            self.assertTrue(module.calendar_tag(tag))
        for tag in ["v0.1.0", "v2026.11.04.0", "v2026.11.04.01", "v2026.02.29.1", "v2026.13.01.1"]:
            self.assertFalse(module.calendar_tag(tag))

    def test_first_release_uses_utc_date_and_counter(self):
        self.assertEqual(self.choose(), TAG)

    def test_multiple_releases_use_numeric_counter(self):
        tags = {"v2026.11.04.2": OTHER, "v2026.11.04.10": OTHER, "v2026.11.03.999": OTHER}
        self.assertEqual(self.choose(tags), "v2026.11.04.11")

    def test_old_or_invalid_tag_formats_are_ignored(self):
        self.assertEqual(self.choose({"v0.0.139": OTHER, "v2026.11.04.bad": OTHER}), TAG)

    def test_retry_reuses_unfinished_tag_even_on_a_later_day(self):
        old_tag = "v2026.11.03.2"
        self.assertEqual(self.choose({old_tag: SHA}), old_tag)

    def test_rerun_does_not_duplicate_or_modify_existing_release(self):
        for draft in [True, False]:
            with self.subTest(draft=draft):
                self.assertIsNone(self.choose({TAG: SHA}, {TAG: {"draft": draft}}))

    def test_late_older_ci_does_not_replace_newer_published_release(self):
        self.assertIsNone(self.choose({TAG: OTHER}, {TAG: {"draft": False}}, lambda a, b: a == SHA and b == OTHER))

    def test_newer_commit_can_be_released(self):
        self.assertEqual(
            self.choose({TAG: OTHER}, {TAG: {"draft": False}}, lambda a, b: a == OTHER and b == SHA),
            "v2026.11.04.2",
        )

    def test_publish_targets_tested_sha_and_is_not_a_draft(self):
        ref = {"object": {"type": "commit", "sha": SHA}}
        with patch.object(module, "is_ancestor", return_value=True), \
             patch.object(module, "load_tags", return_value={}), \
             patch.object(module, "api", side_effect=[[[]], ref]) as api, \
             patch.object(module, "command", return_value="") as command:
            self.assertEqual(module.publish(RUN, REPO, TODAY), TAG)
            api.assert_any_call(
                f"repos/{REPO}/git/refs", "--method", "POST", "-f", f"ref=refs/tags/{TAG}", "-f", f"sha={SHA}"
            )
            args = command.call_args.args
            self.assertEqual(args[:4], ("gh", "release", "create", TAG))
            self.assertEqual(args[args.index("--target") + 1], SHA)
            for flag in ["--verify-tag", "--generate-notes", "--latest"]:
                self.assertIn(flag, args)
            self.assertNotIn("--draft", args)
            self.assertNotIn("--notes-file", args)

    def test_partial_failure_retry_does_not_create_another_tag(self):
        ref = {"object": {"type": "commit", "sha": SHA}}
        with patch.object(module, "is_ancestor", return_value=True), \
             patch.object(module, "load_tags", return_value={TAG: SHA}), \
             patch.object(module, "api", side_effect=[[[]], ref]) as api, \
             patch.object(module, "command", return_value=""):
            self.assertEqual(module.publish(RUN, REPO, TODAY), TAG)
            api.assert_called_with(f"repos/{REPO}/git/ref/tags/{TAG}")
            self.assertEqual(api.call_count, 2)

    def test_ref_mismatch_or_creation_failure_never_publishes(self):
        for response in [{"object": {"type": "commit", "sha": OTHER}}, RuntimeError("tag collision")]:
            with self.subTest(response=response), \
                 patch.object(module, "is_ancestor", return_value=True), \
                 patch.object(module, "load_tags", return_value={}), \
                 patch.object(module, "api", side_effect=[[[]], response]), \
                 patch.object(module, "command") as command:
                with self.assertRaises(RuntimeError):
                    module.publish(RUN, REPO, TODAY)
                command.assert_not_called()

    def test_commit_outside_master_never_publishes(self):
        with patch.object(module, "is_ancestor", return_value=False), patch.object(module, "api") as api:
            with self.assertRaises(RuntimeError):
                module.publish(RUN, REPO, TODAY)
            api.assert_not_called()

    def test_ineligible_event_has_no_api_calls(self):
        with tempfile.TemporaryDirectory() as tmp:
            event = Path(tmp) / "event.json"
            event.write_text(json.dumps({"workflow_run": RUN | {"event": "pull_request"}}), encoding="utf-8")
            with patch.dict(os.environ, {"GITHUB_REPOSITORY": REPO, "GITHUB_EVENT_PATH": str(event)}), \
                 patch.object(module, "api") as api, patch.object(module, "publish") as publish:
                module.main()
                api.assert_not_called()
                publish.assert_not_called()

    def test_successful_live_ci_uses_utc_and_tested_commit(self):
        with tempfile.TemporaryDirectory() as tmp:
            event = Path(tmp) / "event.json"
            event.write_text(json.dumps({"workflow_run": RUN}), encoding="utf-8")
            with patch.dict(os.environ, {"GITHUB_REPOSITORY": REPO, "GITHUB_EVENT_PATH": str(event)}), \
                 patch.object(module, "api", return_value=RUN), \
                 patch.object(module, "datetime") as clock, patch.object(module, "publish") as publish:
                clock.now.return_value.date.return_value = TODAY
                module.main()
                clock.now.assert_called_once_with(module.UTC)
                publish.assert_called_once_with(RUN, REPO, TODAY)

    def test_live_ci_recheck_blocks_a_failed_rerun(self):
        with tempfile.TemporaryDirectory() as tmp:
            event = Path(tmp) / "event.json"
            event.write_text(json.dumps({"workflow_run": RUN}), encoding="utf-8")
            failed = RUN | {"conclusion": "failure"}
            with patch.dict(os.environ, {"GITHUB_REPOSITORY": REPO, "GITHUB_EVENT_PATH": str(event)}), \
                 patch.object(module, "api", return_value=failed), patch.object(module, "publish") as publish:
                with self.assertRaises(RuntimeError):
                    module.main()
                publish.assert_not_called()


if __name__ == "__main__":
    unittest.main()
