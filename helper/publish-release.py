"""Publish a calendar-tagged release after successful master CI."""

import json
import os
import re
import subprocess
from collections.abc import Callable
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Any

TAG = re.compile(r"v([0-9]{4})\.([0-9]{2})\.([0-9]{2})\.([1-9][0-9]*)")


def calendar_tag(tag: str) -> bool:
    match = TAG.fullmatch(tag)
    if not match:
        return False
    try:
        date(*map(int, match.groups()[:3]))
    except ValueError:
        return False
    return True


def eligible(run: dict[str, Any], repository: str) -> bool:
    sha = run.get("head_sha")
    return (
        run.get("name") == "nix-bitcoin tests"
        and run.get("status") == "completed"
        and run.get("conclusion") == "success"
        and run.get("event") == "push"
        and run.get("head_branch") == "master"
        and (run.get("head_repository") or {}).get("full_name") == repository
        and isinstance(sha, str)
        and re.fullmatch(r"[0-9a-f]{40}", sha) is not None
    )


def choose_tag(
    commit: str, today: date, tags: dict[str, str], releases: dict[str, dict[str, Any]],
    ancestor: Callable[[str, str], bool],
) -> str | None:
    """Reuse unfinished tags; never duplicate a release or supersede a newer commit."""
    tags = {tag: sha for tag, sha in tags.items() if calendar_tag(tag)}
    matching = [tag for tag, sha in tags.items() if sha == commit]
    if any(tag in releases for tag in matching):
        return None
    if any(
        tag in releases and not releases[tag]["draft"] and sha != commit and ancestor(commit, sha)
        for tag, sha in tags.items()
    ):
        return None
    if matching:
        return min(matching)
    prefix = f"v{today:%Y.%m.%d}."
    counters = [int(tag.removeprefix(prefix)) for tag in tags if tag.startswith(prefix)]
    return prefix + str(max(counters, default=0) + 1)


def command(*args: str) -> str:
    return subprocess.check_output(args, text=True).strip()


def api(path: str, *args: str, paginate: bool = False) -> Any:
    flags = ("--paginate", "--slurp") if paginate else ()
    return json.loads(command("gh", "api", path, *flags, *args))


def is_ancestor(older: str, newer: str) -> bool:
    result = subprocess.run(["git", "merge-base", "--is-ancestor", older, newer], check=False)
    if result.returncode not in (0, 1):
        raise RuntimeError("Unable to check commit ancestry")
    return result.returncode == 0


def load_tags() -> dict[str, str]:
    tags = command("git", "tag", "--list").splitlines()
    return {
        tag: command("git", "rev-parse", "--verify", f"refs/tags/{tag}^{{commit}}")
        for tag in tags if calendar_tag(tag)
    }


def publish(run: dict[str, Any], repository: str, today: date) -> str | None:
    commit = run["head_sha"]
    if not is_ancestor(commit, "origin/master"):
        raise RuntimeError("The tested commit is not on master")
    tags = load_tags()
    pages = api(f"repos/{repository}/releases?per_page=100", paginate=True)
    releases = {release["tag_name"]: release for page in pages for release in page}
    tag = choose_tag(commit, today, tags, releases, is_ancestor)
    if tag is None:
        print("Commit already released or included in a newer published release; nothing to do.")
        return None
    path = f"repos/{repository}/git/refs"
    if tag not in tags:
        ref = api(path, "--method", "POST", "-f", f"ref=refs/tags/{tag}", "-f", f"sha={commit}")
    else:
        ref = api(f"repos/{repository}/git/ref/tags/{tag}")
    # Ref creation fails on collisions rather than moving a tag. Also check
    # an unfinished tag remotely before reusing it after a publishing failure.
    if ref["object"]["type"] != "commit" or ref["object"]["sha"] != commit:
        raise RuntimeError("Release tag does not point directly to the tested commit")
    command(
        "gh", "release", "create", tag, "--repo", repository,
        "--verify-tag", "--target", commit, "--generate-notes", "--latest",
        "--title", f"nix-bitcoin {tag}",
        "--notes", f"Upgrade guidance: https://github.com/{repository}/blob/{commit}/docs/releases.md",
    )
    print(f"Published {tag} for tested commit {commit}")
    return tag


def main() -> None:
    repository = os.environ["GITHUB_REPOSITORY"]
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text(encoding="utf-8"))
    run = event.get("workflow_run") or {}
    if not eligible(run, repository):
        print("Not a successful master push CI run from this repository; skipping release.")
        return
    # Recheck GitHub's current run state, including reruns, before any writes.
    checked = api(f"repos/{repository}/actions/runs/{int(run['id'])}")
    if not eligible(checked, repository) or checked["head_sha"] != run["head_sha"]:
        raise RuntimeError("CI run is no longer successful for the expected commit")
    publish(checked, repository, datetime.now(UTC).date())


if __name__ == "__main__":
    main()
