# Fast regression tests for the LND MPTCP mitigations.
# Run: nix eval --impure --json --file test/lnd-config.nix
let
  flake = builtins.getFlake (toString ./..);
  inherit (flake.inputs.nixpkgs) lib;
  evaluate = extra: (lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      flake.nixosModules.default
      {
        system.stateVersion = "26.05";
        services.lnd.enable = lib.mkDefault true;
      }
      extra
    ];
  }).config;
  check = extra:
    let config = evaluate extra; in
    assert config.boot.kernel.sysctl."net.mptcp.enabled" == 0;
    assert config.systemd.services.lnd.environment.GODEBUG == "multipathtcp=0";
    true;
in {
  default = check {};

  # The module and the flake package must both use the tag-only update.
  pinnedVersion =
    let
      packages = flake.legacyPackages.x86_64-linux;
      config = evaluate {};
    in
    assert lib.versionAtLeast packages.lnd.version "0.21.8-beta";
    assert config.services.lnd.package == packages.pinned.lnd;
    assert config.services.lnd.package == packages.lnd;
    true;

  disabled =
    let config = evaluate { services.lnd.enable = false; }; in
    assert !(config.boot.kernel.sysctl ? "net.mptcp.enabled");
    assert !(config.systemd.services ? lnd);
    true;

  # A consumer's package override must not remove the service mitigation.
  customPackage = check ({ pkgs, ... }: {
    services.lnd.package = pkgs.writeShellScriptBin "lnd" "exit 0";
  });

  netns =
    let config = evaluate { nix-bitcoin.netns-isolation.enable = true; }; in
    assert config.systemd.services.lnd.serviceConfig.NetworkNamespacePath == "/var/run/netns/nb-lnd";
    check { nix-bitcoin.netns-isolation.enable = true; };

  # Operators can override these defaults, e.g. after patching the kernel.
  # Overriding GODEBUG replaces the whole string, so retain multipathtcp=0
  # when adding unrelated Go settings on an unpatched kernel.
  overrides =
    let config = evaluate {
      boot.kernel.sysctl."net.mptcp.enabled" = 1;
      systemd.services.lnd.environment.GODEBUG = "multipathtcp=0,gctrace=1";
    }; in
    assert config.boot.kernel.sysctl."net.mptcp.enabled" == 1;
    assert config.systemd.services.lnd.environment.GODEBUG == "multipathtcp=0,gctrace=1";
    true;
}
