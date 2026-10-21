# Dependency audit — 2026-10-21

Scope: the maintained `tompro/nix-bitcoin` repository. Production/staging host
configuration and deployed versions are not present here. This update does not
restart services or deploy to any host.

## Updated

| Dependency | Previous | Updated | Reason |
| --- | --- | --- | --- |
| BTCPay Server | 2.4.4 | 2.4.5 | SSRF protection, Lightning/LNURL and authorization hardening |
| NBXplorer | 2.6.10 | 2.6.19 | Authentication hardening, Core 30+ legacy RPC compatibility, Liquid indexing and recovery fixes |
| Core Lightning | 26.06.8 | 26.06.9 | Security fixes and gossip throttling regression fix; upstream strongly recommends upgrading |
| LND (via nixpkgs-unstable) | 0.21.3-beta | 0.21.4-beta | HTLC/channel-transition and invoice validation fixes |
| CDK | 0.18.1 | 0.18.2 | LND payment validation/rounding, persisted quote state and dependency security fixes |
| Bitcoin Knots (via nixpkgs-unstable) | 29.4.1.knots20260508 | 29.4.2.knots20260508 | Channel refresh |
| CLBOSS (via nixpkgs-unstable) | 0.17.0 | 0.17.2 | Channel refresh |
| Fulcrum (via nixpkgs-unstable) | 2.1.2 | 2.1.3 | Channel refresh |

Both root nixpkgs inputs were refreshed within their existing channels
(`nixos-26.05` and `nixpkgs-unstable`) to 2026-10-20 revisions. CDK stays on the
0.18 series; its transitive inputs remain those selected by its upstream lock.
NBXplorer now has a local package because nixpkgs still supplies 2.6.10.
NuGet dependency locks were regenerated for both .NET applications.

Sources:
- [BTCPay 2.4.5](https://github.com/btcpayserver/btcpayserver/releases/tag/v2.4.5)
- [NBXplorer changes](https://github.com/dgarage/NBXplorer/compare/v2.6.10...v2.6.19)
- [CLN 26.06.9](https://github.com/ElementsProject/lightning/releases/tag/v26.06.9)
- [LND 0.21.4](https://github.com/lightningnetwork/lnd/releases/tag/v0.21.4-beta)
- [CDK 0.18.2](https://github.com/cashubtc/cdk/releases/tag/v0.18.2)

## Deployment considerations

- **BTCPay 2.4.5 blocks private outbound destinations by default**, including
  Lightning connections, LNURL, webhooks and invoice notification URLs. This is
  relevant to NixOS, not only Docker. The module permits only the configured
  LND REST host and port through `ssrfexceptions`, including netns and IPv6.
  Unix-socket CLN connections need no exception. Other private integrations
  require separately reviewed, narrow operator configuration; do not allow
  entire private networks as a workaround. Review upstream's changed refund
  permissions and public invoice visibility as well.
- Back up BTCPay/NBXplorer PostgreSQL databases before upgrading. Test existing
  stores, Lightning payments, webhooks, plugins and Liquid wallets on staging.
- The LND 0.21.4 release explicitly says **there are no database migrations in
  this release**. Nevertheless keep current wallet/channel backups, use a
  graceful restart in a maintenance window, and verify peers, channels and
  pending HTLCs afterward. This is not permission to downgrade arbitrary LND
  databases.
- CDK's existing 0.17 → 0.18 migration warning still applies to older mints;
  preserve data-directory backups. Validate both LND and CLN payment backends.
- The infrastructure repository must update its `nix-bitcoin` input after merge.
  Any explicit production LND 0.21.3 overrides must be bumped (source and vendor
  hashes included) or removed in favor of the tested 0.21.4 package. Overrides
  take precedence over this repository's refreshed package.
- Confirm actual production/staging executables and running service versions;
  lockfile versions alone do not prove deployment. No remote verification was
  performed as part of this repository update.

## Follow-ups, not silently bundled

These pins were checked against upstream releases but require their own changes
and targeted tests. They are **not** declared safe merely because this PR leaves
versions unchanged.

| Pin | Available | Follow-up |
| --- | --- | --- |
| RTL 0.15.8 | [0.15.14](https://github.com/Ride-The-Lightning/RTL/releases/tag/v0.15.14) | High priority for enabled deployments: multi-node isolation, session/CSRF, backup correctness and runtime dependency fixes. Regenerate node dependencies/assets and test CLN/LND UI integration. |
| JoinMarket 0.9.11 | [0.9.12](https://github.com/JoinMarket-Org/joinmarket-clientserver/releases/tag/v0.9.12) | Important commitment-checking fix against taker DoS/snooping. Upstream is archived and warns against continued use without independent security confidence; audit dependencies and plan migration before deployment. |
| lndinit 0.1.3-beta | [0.1.36-beta](https://github.com/lightninglabs/lndinit/releases/tag/v0.1.36-beta) | Large gap; validate wallet initialization/seed handling and current LND compatibility, not just the build. |
| trustedcoin 0.8.6 | [0.8.7](https://github.com/nbd-wtf/trustedcoin/releases/tag/v0.8.7) | Explorer retry/request-body and bad-status handling fixes; test plugin against current CLN. |
| c-lightning-REST 0.10.7 | [0.10.8](https://github.com/Ride-The-Lightning/c-lightning-REST/releases/tag/v0.10.8) | Final release only adds deprecation notices. Project is archived with no further security fixes; migrate consumers to CLN's maintained REST interface rather than relying on a cosmetic version bump. |
| Bitcoin Core 29.2 compatibility package | 31.1 current release | This is explicitly the separate `bitcoind_29` package, not the default. Default Core is already 31.1. Review consumers before retiring or changing the compatibility pin. |

lnurl-mint 0.12.2, mempool 3.3.1, extra-container 0.14, and default Bitcoin Core
31.1 already match the latest upstream releases/tags checked in this audit.
flake-utils remains unchanged. This is an application/input audit, not a full
transitive dependency vulnerability scan or a security certification.

## Validation

Fast configuration regression checks:

```sh
nix eval --impure --json --file test/btcpayserver-config.nix
nix flake check --no-build --all-systems
```

The configuration checks cover IPv4, IPv6, wildcard bind addresses, a custom
endpoint, network namespaces, CLN and no-Lightning configurations. They ensure
LND's URL and its exact SSRF exception agree. The BTCPay VM test also checks the
rendered service configuration alongside existing startup, macaroon access,
HTTP, Liquid and PostgreSQL statistics checks.

Package builds and VM test results are recorded in the PR; evaluation alone is
not a successful service test. ARM packages are evaluated, not executed here.
