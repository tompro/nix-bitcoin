# Changelog

Release notes for the maintained `tompro/nix-bitcoin` fork. Historical upstream
releases remain at https://github.com/fort-nix/nix-bitcoin/releases.

## [Unreleased]

### Added
- `services.lnurl-mint.fees.addressMsat` for LUD-26 username registration fees,
  defaulting to zero (free registration).
- Tag-triggered draft GitHub Releases with reviewed changelog entries and
  generated PR/contributor notes. See [the release process](docs/releases.md).

### Changed
- Pin lnurl-mint to post-0.13.1 commit `a1d8ea4`, including the cached-Python
  packaging and CA-trust fixes. Its full test suite checks the actual default
  certificate bundle before relaxing the Nix-only certifi version constraint.
- Emit upstream's canonical `FEE_PPM` setting. Existing `fees.percentPpm` remains
  unchanged; legacy `extraSettings.FEE_PERCENT_PPM` is translated with a warning.
  When both raw names are set, `FEE_PPM` takes precedence.
- Refresh the existing nixpkgs channels: Bitcoin Core 32.1, LND 0.21.6-beta,
  Lightning Loop 0.35.2-beta, and the updated system CA/runtime packages.
- Update CDK 0.18.2 to 0.18.3 for SQLite transaction cleanup fixes.
- Update RTL 0.15.15 to 0.15.16 for cookie-path and dependency hardening; patch
  its post-release follow-redirects advisory (GHSA-mrwp-f3q8-3g9p) with 1.16.2.
- Keep electrs on the compatible stable package (0.11.0), including in the
  update helper; 0.12 requires separate REST integration and an index rebuild.

### Upgrade notes
- Back up databases and wallet/channel state before deployment. Bitcoin Core
  moves from 31.1 to 32.1, a major upgrade; review its RPC and PSBT changes.
  Rebuilding its txindex into the new format affects downgrades.
- LND 0.21.6 mitigates the demonstrated MPTCP exploit path for CVE-2026-98432.
  It does not fix the underlying kernel vulnerability: update the host kernel
  and reboot. Updating this flake alone does not update a consumer's kernel.
- lnurl-mint 0.13 changes the LUD-26 wallet registration protocol and derivation
  format. Wallet clients must support it. Existing legacy registrations retain
  their old derivation until explicitly migrated; consult the upstream README.
- CDK's existing 0.17-to-0.18 migration requirements still apply to older mints.
- Bitcoin Core 29.x is end-of-life. The explicitly named `bitcoind_29`
  compatibility package is retained, not silently upgraded.
- NBXplorer 2.6.22, mempool 3.3.2/Node 26, HWI 3.2.0, and electrs 0.12 remain
  follow-ups, not part of this update. Knots' newer consensus-rule changes are
  not included automatically.
