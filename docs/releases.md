# Releases for this fork

This is the release process for **tompro/nix-bitcoin**, not the archived
fort-nix repository. Releases are explicit maintainer decisions, not automatic
version bumps on every merge. Adding this workflow does not publish a release.

## Prepare and tag

1. Choose an unused stable version tag `vMAJOR.MINOR.PATCH` (no leading zeroes).
   Choose the first fork version deliberately; this workflow does not infer it
   from the archived project's last release. Prerelease tags are not supported
   by this initial workflow.
2. In `CHANGELOG.md`, move the reviewed `[Unreleased]` entries into a heading
   such as `## [0.1.0] - YYYY-MM-DD`, and add a new `[Unreleased]` section above
   it. The version is an example, not a version selected by this change. Keep
   migration, backup, and operator-action notes in the release section.
3. Merge that preparation PR into `master` and wait for the entire
   **nix-bitcoin tests** workflow to succeed on that exact commit.
4. Fetch and check out the tested commit, review the changes, then create and
   push a signed annotated tag using your own maintainer signing identity:

   ```sh
   git fetch origin master --tags
   git switch --detach origin/master
   git status --short  # must be clean
   # Replace the example version with the version prepared in CHANGELOG.md.
   version=0.1.0
   python3 helper/release-notes.py "v$version"
   git tag -s "v$version" -m "nix-bitcoin v$version"
   git verify-tag "v$version"
   git push origin "refs/tags/v$version"
   ```

   Never move or overwrite a published release tag. If something is wrong,
   prepare a new version. Repository owners should restrict `v*` tag creation,
   updates, and deletion using a GitHub tag ruleset.

## Review and publish

[The release workflow](../.github/workflows/release.yml) checks that:

- the tag is a stable version with an exact, nonempty changelog section;
- its commit belongs to `master`;
- the existing CI workflow succeeded on that exact commit via a `master` push.

It then creates a **draft GitHub Release** for the existing tag, combining the
reviewed changelog section with GitHub's generated PR/contributor notes. The
workflow uses the repository's `GITHUB_TOKEN`; no personal access token or
private signing key is uploaded to Actions. It does not verify the tag against
a configured maintainer public key; tag signing and local signature review are
maintainer responsibilities, separate from the CI/ancestry checks above.

Review the draft in GitHub Releases and publish it manually when ready. Drafts
are not public releases and do not become `releases/latest` until published.
If the tag was pushed before CI finished, wait for successful CI and rerun the
failed release workflow. Reruns leave existing releases unchanged.

## Consumers and signature compatibility

Flake consumers can pin a published tag explicitly:

```nix
inputs.nix-bitcoin.url = "github:tompro/nix-bitcoin/v0.1.0"; # example version
```

The legacy `helper/push-release.sh`, `helper/fetch-release`, and deployment
shell updater still target **fort-nix/nix-bitcoin**. Their signed `nar-hash.txt`
assets trust the archived project's specific maintainer key. The new workflow
does **not** create those assets, replace that key, or claim compatibility with
that updater. Use an explicit fork flake input for these releases; establishing
an independently verified fork signing key and migrating the legacy updater
would be a separate security change. A GitHub Release and Nix's content hash do
not substitute for independent maintainer-signature verification.
