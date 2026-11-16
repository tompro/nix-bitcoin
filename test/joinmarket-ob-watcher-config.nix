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
        nix-bitcoin.secretsSetupMethod = "manual";
        boot.loader.grub.enable = false;
        fileSystems."/" = { device = "none"; fsType = "tmpfs"; };
        services.bitcoind.enable = true;
        services.joinmarket-ob-watcher.enable = true;
      }
      extra
    ];
  }).config;
  defaults = evaluate {};
  custom = evaluate {
    services.joinmarket-ob-watcher.settings."MESSAGING:custom" = {
      type = "irc";
      host = "irc.example.org";
      port = 6697;
      usessl = true;
    };
  };
  isolated = evaluate {
    nix-bitcoin.netns-isolation.enable = true;
  };
  messaging = settings: lib.filterAttrs (name: _: lib.hasPrefix "MESSAGING:" name) settings;
  check = config:
    let
      watcher = config.services.joinmarket-ob-watcher.settings;
    in
      assert watcher.BLOCKCHAIN.rpc_user == config.services.bitcoind.rpc.users.joinmarket-ob-watcher.name;
      assert watcher.BLOCKCHAIN.rpc_wallet_file == "";
      assert watcher.BLOCKCHAIN.rpc_host == config.services.bitcoind.rpc.address;
      assert watcher."MESSAGING:onion".socks5_host == config.services.tor.client.socksListenAddress.addr;
      assert watcher."MESSAGING:hackint".socks5_port == config.services.tor.client.socksListenAddress.port;
      assert !(config.systemd.services ? joinmarket);
      assert !(config.systemd.services ? joinmarket-yieldgenerator);
      assert !(config.security.wrappers ? netns-exec);
      assert lib.all (a: a.assertion) config.assertions;
      builtins.deepSeq watcher true;
in {
  defaultNetworks = assert builtins.attrNames (messaging defaults.services.joinmarket-ob-watcher.settings)
    == [ "MESSAGING:hackint" "MESSAGING:onion" ]; check defaults;
  customNetworks = assert custom.services.joinmarket-ob-watcher.settings."MESSAGING:custom".host == "irc.example.org";
    check custom;
  netns = assert !(isolated.nix-bitcoin.netns-isolation.services ? joinmarket); check isolated;
}
