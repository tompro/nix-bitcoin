# Fast regression tests for BTCPay's narrowly scoped SSRF exceptions.
# Run: nix eval --impure --json --file test/btcpayserver-config.nix
let
  flake = builtins.getFlake (toString ./..);
  inherit (flake.inputs.nixpkgs) lib;
  check = { backend ? "lnd", address ? "127.0.0.1", port ? 8080, netns ? false, expected }:
    let
      system = lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          flake.nixosModules.default
          {
            system.stateVersion = "26.05";
            services.btcpayserver = { enable = true; lightningBackend = backend; };
            services.lnd.restAddress = lib.mkIf (!netns) (lib.mkForce address);
            services.lnd.restPort = port;
            nix-bitcoin.netns-isolation.enable = netns;
          }
        ];
      };
      command = system.config.systemd.services.btcpayserver.serviceConfig.ExecStart;
      configFile = builtins.head (builtins.match ".*--conf=([^[:space:]]+).*" command);
      lines = lib.splitString "\n" (builtins.readFile configFile);
      exceptions = builtins.filter (lib.hasPrefix "ssrfexceptions=") lines;
    in
      assert lib.assertMsg (exceptions == expected) "Unexpected SSRF exceptions: ${builtins.toJSON exceptions}";
      assert lib.assertMsg (backend != "lnd" || builtins.any (lib.hasInfix "server=https://${lib.removePrefix "ssrfexceptions=" (builtins.head expected)}/;") lines) "LND URL and SSRF exception differ";
      true;
in {
  ipv4 = check { expected = [ "ssrfexceptions=127.0.0.1:8080" ]; };
  customEndpoint = check { address = "10.0.0.2"; port = 8081; expected = [ "ssrfexceptions=10.0.0.2:8081" ]; };
  wildcard = check { address = "0.0.0.0"; expected = [ "ssrfexceptions=127.0.0.1:8080" ]; };
  netns = check { netns = true; expected = [ "ssrfexceptions=169.254.1.14:8080" ]; };
  ipv6 = check { address = "::1"; expected = [ "ssrfexceptions=[::1]:8080" ]; };
  ipv6Wildcard = check { address = "::"; expected = [ "ssrfexceptions=[::1]:8080" ]; };
  clightning = check { backend = "clightning"; expected = []; };
  noLightning = check { backend = null; expected = []; };
}
