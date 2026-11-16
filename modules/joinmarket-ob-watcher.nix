{ config, lib, pkgs, ... }:

with lib;
let
  options.services.joinmarket-ob-watcher = {
    enable = mkEnableOption "JoinMarket orderbook watcher";
    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "HTTP server address.";
    };
    port = mkOption {
      type = types.port;
      default = 62601;
      description = "HTTP server port.";
    };
    dataDir = mkOption {
      readOnly = true;
      default = "/var/lib/joinmarket-ob-watcher";
      description = "The data directory for JoinMarket orderbook watcher.";
    };
    settings = mkOption {
      type = with types; attrsOf anything;
      example = {
        LOGGING = {
          console_log_level = "DEBUG";
        };
      };
      description = ''
        Joinmarket settings.
        See here for possible options:
        https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/v0.9.12/src/jmclient/configure.py
      '';
    };
    user = mkOption {
      type = types.str;
      default = "joinmarket-ob-watcher";
      description = "The user as which to run JoinMarket.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run JoinMarket.";
    };
    # This option is only used by netns-isolation.
    # Tor is always enabled.
    tor.enforce = nbLib.tor.enforce;
  };

  cfg = config.services.joinmarket-ob-watcher;
  nbLib = config.nix-bitcoin.lib;
  nbPkgs = config.nix-bitcoin.pkgs;
  secretsDir = config.nix-bitcoin.secretsDir;

  inherit (config.services) bitcoind;
  torAddress = config.services.tor.client.socksListenAddress;
  socks5Settings = {
    socks5 = true;
    socks5_host = torAddress.addr;
    socks5_port = torAddress.port;
  };
in {
  inherit options;

  config = mkIf cfg.enable {
    services.bitcoind.rpc.users.joinmarket-ob-watcher = {
      passwordHMACFromFile = true;
      rpcwhitelist = bitcoind.rpc.users.public.rpcwhitelist ++ [
        "listwallets"
      ];
    };

    # Joinmarket is Tor-only
    services.tor = {
      enable = true;
      client.enable = true;
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    # The watcher is independent of the retired JoinMarket wallet integration.
    # Messaging sections must be explicit: upstream removes their defaults.
    services.joinmarket-ob-watcher.settings = {
      BLOCKCHAIN = {
        blockchain_source = bitcoind.makeNetworkName "bitcoin-rpc" "regtest";
        network = bitcoind.makeNetworkName "mainnet" "testnet";
        rpc_host = nbLib.address bitcoind.rpc.address;
        rpc_port = bitcoind.rpc.port;
        rpc_user = bitcoind.rpc.users.joinmarket-ob-watcher.name;
        rpc_wallet_file = "";
      };
      "MESSAGING:onion" = socks5Settings // {
        type = "onion";
        tor_control_host = "unix:/run/tor/control";
        tor_control_port = 9051;
        onion_serving_host = "127.0.0.1";
        onion_serving_port = 5222;
        hidden_service_dir = "";
        directory_nodes = "satoshi2vcg5e2ept7tjkzlkpomkobqmgtsjzegg6wipnoajadissead.onion:5222,jmarketxf5wc4aldf3slm5u6726zsky52bqnfv6qyxe5hnafgly6yuyd.onion:5222,coinjointovy3eq5fjygdwpkbcdx63d7vd4g32mw7y553uj3kjjzkiqd.onion:5222,nakamotourflxwjnjpnrk7yc2nhkf6r62ed4gdfxmmn5f4saw5q5qoyd.onion:5222,odpwaf67rs5226uabcamvypg3y4bngzmfk7255flcdodesqhsvkptaid.onion:5222";
      };
      "MESSAGING:hackint" = socks5Settings // {
        host = "ncwkrwxpq2ikcngxq3dy2xctuheniggtqeibvgofixpzvrwpa77tozqd.onion";
        channel = "joinmarket-pit";
        port = 6667;
        usessl = false;
      };
    };

    systemd.services.joinmarket-ob-watcher = rec {
      wantedBy = [ "multi-user.target" ];
      requires = [ "tor.service" "bitcoind.service" ];
      after = requires ++ [ "nix-bitcoin-secrets.target" ];
      # The service writes to HOME/.config/matplotlib
      environment.HOME = cfg.dataDir;
      preStart = ''
        {
          cat ${builtins.toFile "joinmarket-ob-watcher.cfg" ((generators.toINI {}) cfg.settings)}
          echo
          echo '[BLOCKCHAIN]'
          echo "rpc_password = $(cat ${secretsDir}/bitcoin-rpcpassword-joinmarket-ob-watcher)"
        } > '${cfg.dataDir}/joinmarket.cfg'
      '';
      serviceConfig = nbLib.defaultHardening // rec {
        StateDirectory = "joinmarket-ob-watcher";
        StateDirectoryMode = "770";
        WorkingDirectory = cfg.dataDir; # The service creates dir 'logs' in the working dir
        User = cfg.user;
        ExecStart = ''
          ${nbPkgs.joinmarket}/bin/jm-ob-watcher --datadir=${cfg.dataDir} \
            --host=${cfg.address} --port=${toString cfg.port}
        '';
        SystemCallFilter = nbLib.defaultHardening.SystemCallFilter ++ [ "mbind" ] ;
        Restart = "on-failure";
        RestartSec = "10s";
      } // nbLib.allowedIPAddresses cfg.tor.enforce;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
    };
    users.groups.${cfg.group} = {};

    nix-bitcoin.secrets = {
      bitcoin-rpcpassword-joinmarket-ob-watcher.user = cfg.user;
      bitcoin-HMAC-joinmarket-ob-watcher.user = bitcoind.user;
    };
    nix-bitcoin.generateSecretsCmds.joinmarket-ob-watcher = ''
      makeBitcoinRPCPassword joinmarket-ob-watcher
    '';
  };
}
