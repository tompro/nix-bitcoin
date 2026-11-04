# Fee-schema and backwards-compatibility checks without building a VM.
# Run: nix eval --impure --json --file test/lnurl-mint-config.nix
let
  flake = builtins.getFlake (toString ./..);
  inherit (flake.inputs.nixpkgs) lib;
  check = { settings ? {}, expected, deprecated ? false }:
    let
      system = lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          flake.nixosModules.default
          {
            system.stateVersion = "26.05";
            services.lnd.enable = true;
            services.lnurl-mint = {
              enable = true;
              mintUrl = "https://mint.example.com";
            } // settings;
          }
        ];
      };
      env = system.config.systemd.services.lnurl-mint.environment;
      actual = lib.getAttrs [ "BASE_FEE_MSAT" "FEE_PPM" "ADDRESS_FEE_MSAT" ] env;
      warned = builtins.any (lib.hasInfix "FEE_PERCENT_PPM is deprecated") system.config.warnings;
    in
      assert lib.assertMsg (actual == expected) "Unexpected mint fees: ${builtins.toJSON actual}";
      assert lib.assertMsg (!(env ? FEE_PERCENT_PPM)) "Legacy fee name leaked into the environment";
      assert lib.assertMsg (warned == deprecated) "Unexpected legacy fee warning";
      true;
  defaults = { BASE_FEE_MSAT = "1000"; FEE_PPM = "0"; ADDRESS_FEE_MSAT = "0"; };
in {
  defaultFees = check { expected = defaults; };
  nonzeroFees = check {
    settings.fees = { baseMsat = 2000; percentPpm = 2500; addressMsat = 50000; };
    expected = { BASE_FEE_MSAT = "2000"; FEE_PPM = "2500"; ADDRESS_FEE_MSAT = "50000"; };
  };
  legacyOverride = check {
    settings = { fees.percentPpm = 2500; extraSettings.FEE_PERCENT_PPM = 3500; };
    expected = defaults // { FEE_PPM = "3500"; };
    deprecated = true;
  };
  canonicalOverride = check {
    settings = { fees.percentPpm = 2500; extraSettings.FEE_PPM = 4500; };
    expected = defaults // { FEE_PPM = "4500"; };
  };
  canonicalWins = check {
    settings.extraSettings = { FEE_PERCENT_PPM = 3500; FEE_PPM = 4500; };
    expected = defaults // { FEE_PPM = "4500"; };
    deprecated = true;
  };
  legacyStringOverride = check {
    settings.extraSettings.FEE_PERCENT_PPM = "3500";
    expected = defaults // { FEE_PPM = "3500"; };
    deprecated = true;
  };
  addressOverride = check {
    settings = { fees.addressMsat = 50000; extraSettings.ADDRESS_FEE_MSAT = 75000; };
    expected = defaults // { ADDRESS_FEE_MSAT = "75000"; };
  };
}
