{
  lib,
  buildDotnetModule,
  fetchFromGitHub,
  dotnetCorePackages,
  altcoinSupport ? false,
}:

let
  # TODO-EXTERNAL: Remove once the locked nixpkgs provides .NET >= 10.0.14.
  # BTCPay Server's framework-dependent build needs the patched runtime as well
  # as the application update to fix CVE-2026-111497 (Brotli decoder).
  dotnet = dotnetCorePackages.buildDotnetSdk ./dotnet-packages.nix;
in
buildDotnetModule rec {
  pname = "btcpayserver";
  version = "2.4.7";

  src = fetchFromGitHub {
    owner = "btcpayserver";
    repo = "btcpayserver";
    tag = "v${version}";
    hash = "sha256-8yVWNpxwXE4yDBX0aN2OgJkrJGBfKgj75pFletRtL7E=";
  };

  projectFile = "BTCPayServer/BTCPayServer.csproj";
  nugetDeps = ./deps.json;

  dotnet-sdk = dotnet.sdk_10_0;
  dotnet-runtime = dotnet.aspnetcore_10_0;

  buildType = if altcoinSupport then "Altcoins-Release" else "Release";

  # macOS has a case-insensitive filesystem, so these two can be the same file
  postFixup = ''
    mv $out/bin/{BTCPayServer,btcpayserver} || :
  '';

  meta = {
    description = "Self-hosted, open-source cryptocurrency payment processor";
    homepage = "https://btcpayserver.org";
    changelog = "https://github.com/btcpayserver/btcpayserver/blob/v${version}/Changelog.md";
    maintainers = with lib.maintainers; [
      kcalvinalvin
      erikarvstedt
    ];
    license = lib.licenses.mit;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
