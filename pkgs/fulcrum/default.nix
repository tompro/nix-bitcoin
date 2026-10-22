{ fulcrum, fetchFromGitHub }:

# Remove this override once nixpkgs-unstable provides Fulcrum >= 2.1.4.
# https://github.com/cculianu/Fulcrum/releases/tag/v2.1.4
fulcrum.overrideAttrs (finalAttrs: _prev: {
  version = "2.1.4";
  src = fetchFromGitHub {
    owner = "cculianu";
    repo = "Fulcrum";
    tag = "v${finalAttrs.version}";
    hash = "sha256-YfID94tmNTg+BqEEAmB3if+gNCNrU3NamTOMVfjXAMY=";
  };
})
