# Run: nix eval --impure --json --file test/joinmarket-ob-watcher-config.nix
let
  flake = builtins.getFlake (toString ./..);
  inherit (flake.inputs.nixpkgs) lib;
  evaluate = extra: (lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      flake.nixosModules.default
      {
        system.stateVersion = "26.05";
        services.bitcoind.enable = true;
        services.joinmarket-ob-watcher.enable = true;
      }
      extra
    ];
  }).config;
  defaults = evaluate {};
  custom = evaluate {
    services.joinmarket.settings."MESSAGING:custom" = {
      type = "irc";
      host = "irc.example.org";
      port = 6697;
      usessl = true;
    };
  };
  messaging = settings: lib.filterAttrs (name: _: lib.hasPrefix "MESSAGING:" name) settings;
  check = config:
    let
      watcher = config.services.joinmarket-ob-watcher.settings;
      joinmarket = config.services.joinmarket.settings;
    in
      assert messaging watcher == messaging joinmarket;
      assert watcher.BLOCKCHAIN.rpc_user == config.services.bitcoind.rpc.users.joinmarket-ob-watcher.name;
      assert watcher.BLOCKCHAIN.rpc_wallet_file == "";
      builtins.deepSeq watcher true;
in {
  defaultNetworks = assert builtins.attrNames (messaging defaults.services.joinmarket-ob-watcher.settings)
    == [ "MESSAGING:hackint" "MESSAGING:onion" ]; check defaults;
  customNetworks = assert custom.services.joinmarket-ob-watcher.settings ? "MESSAGING:custom"; check custom;
}
