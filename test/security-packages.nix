# Run: nix eval --impure --json --file test/security-packages.nix
let
  flake = builtins.getFlake (toString ./..);
  inherit (flake.inputs.nixpkgs) lib;
  # Check every metadata entry, including platforms not built by this flake.
  dotnet = import ../pkgs/btcpayserver/dotnet-packages.nix {
    buildAspNetCore = lib.id;
    buildNetRuntime = lib.id;
    buildNetSdk = lib.id;
    fetchNupkg = lib.id;
  };
  checkSdk = sdk:
    assert lib.all (p: p.version == "10.0.15") (
      sdk.commonPackages ++ lib.concatLists (builtins.attrValues sdk.hostPackages)
      ++ lib.concatLists (builtins.attrValues sdk.targetPackages)
    );
    assert sdk.runtime.version == "10.0.15";
    assert sdk.aspnetcore.version == "10.0.15";
    true;
  checkSystem = system:
    let
      packages = flake.lib.mkNbPkgs { inherit system; };
      btcpay = packages.btcpayserver;
      config = (lib.nixosSystem {
        inherit system;
        modules = [ flake.nixosModules.default { system.stateVersion = "26.05"; } ];
      }).config;
    in
      assert lib.versionAtLeast btcpay.dotnet-runtime.version "10.0.15";
      assert lib.any (p: (p.version or "") == "10.0.404") btcpay.nativeBuildInputs;
      assert packages.pinned.btcpayserver == btcpay;
      assert config.nix-bitcoin.pkgs.btcpayserver == btcpay;
      assert lib.versionAtLeast packages.clightning.version "26.06.10";
      assert packages.pinned.clightning == packages.clightning;
      assert config.services.clightning.package == packages.clightning;
      assert packages.clnrest.src == packages.clightning.src;
      true;
in {
  dotnetMetadata = assert dotnet.release_10_0 == "10.0.15";
    assert dotnet.sdk_10_0.version == "10.0.404";
    assert dotnet.sdk_10_0_1xx.version == "10.0.115";
    checkSdk dotnet.sdk_10_0 && checkSdk dotnet.sdk_10_0_1xx;
  packages = assert lib.all checkSystem flake.lib.supportedSystems; true;
}
