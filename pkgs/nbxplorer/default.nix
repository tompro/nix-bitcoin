{ lib, buildDotnetModule, fetchFromGitHub, dotnetCorePackages }:

# Keep authentication hardening and Bitcoin Core 30+ compatibility fixes until
# nixpkgs catches up: https://github.com/dgarage/NBXplorer/compare/v2.6.10...v2.6.19
buildDotnetModule rec {
  pname = "nbxplorer";
  version = "2.6.19";

  src = fetchFromGitHub {
    owner = "dgarage";
    repo = "NBXplorer";
    tag = "v${version}";
    hash = "sha256-xFPpLM6DqGNfm2JE4qKpxqaObjK+FN5IIn56z9oaDI8=";
  };

  projectFile = "NBXplorer/NBXplorer.csproj";
  nugetDeps = ./deps.json;
  dotnet-sdk = dotnetCorePackages.sdk_10_0;
  dotnet-runtime = dotnetCorePackages.aspnetcore_10_0;

  postFixup = ''
    mv $out/bin/{NBXplorer,nbxplorer} || :
  '';

  meta = {
    description = "Minimalist UTXO tracker for HD Cryptocurrency Wallets";
    homepage = "https://github.com/dgarage/NBXplorer";
    maintainers = with lib.maintainers; [ kcalvinalvin erikarvstedt ];
    license = lib.licenses.mit;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "nbxplorer";
  };
}
