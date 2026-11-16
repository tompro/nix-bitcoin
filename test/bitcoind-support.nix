# Run: nix eval --impure --json --file test/bitcoind-support.nix
let
  flake = builtins.getFlake (toString ./..);
  inherit (flake.inputs.nixpkgs) lib;
  evaluate = extra: (lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      flake.nixosModules.default
      {
        system.stateVersion = "26.05";
        nix-bitcoin.secretsSetupMethod = "manual";
        boot.loader.grub.enable = false;
        fileSystems."/" = { device = "none"; fsType = "tmpfs"; };
        services.bitcoind.enable = lib.mkDefault true;
      }
      extra
    ];
  }).config;
  failures = config: map (a: a.message) (lib.filter (a: !a.assertion) config.assertions);
  withPackage = attrs: evaluate ({ config, ... }: {
    services.bitcoind.package = config.nix-bitcoin.pkgs.bitcoind.overrideAttrs
      (attrs // { __intentionallyOverridingVersion = true; });
  });
  rejects = fragment: config: lib.any (lib.hasInfix fragment) (failures config);
in {
  supported = assert failures (evaluate {}) == []; true;
  core30 = assert failures (withPackage { version = "30.2"; }) == []; true;
  core29 = assert rejects "older than 30" (withPackage { version = "29.5"; }); true;
  core29Disabled = assert failures (evaluate ({ config, ... }: {
    services.bitcoind.enable = false;
    services.bitcoind.package = config.nix-bitcoin.pkgs.bitcoind.overrideAttrs {
      version = "29.5";
      __intentionallyOverridingVersion = true;
    };
  })) == []; true;
  knotsName = assert rejects "Knots" (withPackage { pname = "bitcoind-knots"; version = "32.1"; }); true;
  knotsVersion = assert rejects "Knots" (withPackage { version = "30.2.knots20260508"; }); true;
  retiredWallet = assert rejects "JoinMarket wallet" (evaluate { services.joinmarket.enable = true; }); true;
  retiredYieldGenerator = assert rejects "JoinMarket wallet"
    (evaluate { services.joinmarket.yieldgenerator.enable = true; }); true;
  retiredSettings = assert rejects "JoinMarket wallet"
    (evaluate { services.joinmarket.settings."MESSAGING:custom".host = "example.org"; }); true;
  retiredNetnsHelper = assert rejects "netns-exec"
    (evaluate { nix-bitcoin.netns-isolation.allowedUser = "operator"; }); true;
  exports = assert lib.all (system:
    let
      packages = flake.lib.mkNbPkgs { inherit system; };
    in
      !(packages ? bitcoind_29)
      && !(packages.modulesPkgs ? bitcoind_29)
      && !(packages ? bitcoind-knots)
      && !(packages ? netns-exec)
      && !(packages.pinned ? bitcoind-knots)
      && !(packages.modulesPkgs ? bitcoind-knots)
      && !(flake.packages.${system} ? bitcoind_29)
      && !(flake.packages.${system} ? bitcoind-knots)
      && !(flake.lib.test.scenarios ? joinmarket)
      && !(flake.lib.test.scenarios ? joinmarket-bitcoind-29)
  ) flake.lib.supportedSystems; true;
}
