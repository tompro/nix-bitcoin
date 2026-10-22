{ lib
, stdenvNoCC
, nodejs_22
, nodejs-slim_22
, fetchNodeModules
, fetchurl
, makeWrapper
, rsync
}:
let self = stdenvNoCC.mkDerivation {
  pname = "clightning-rest";
  version = "0.10.8";

  src = fetchurl {
    url = "https://github.com/Ride-The-Lightning/c-lightning-REST/archive/refs/tags/v${self.version}.tar.gz";
    hash = "sha256-/T/BuuRNG0bLMPJWtYiCQcuLlnr/yPb5maWsDn1PgEE=";
  };

  passthru = {
    nodejs = nodejs_22;
    nodejsRuntime = nodejs-slim_22;

    nodeModules = fetchNodeModules {
      inherit (self) src nodejs;
      hash = "sha256-p2boUyUwkVgesVSDRGgWf2rK+IPr33aSG7CYEF1zVsc=";
    };
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  phases = "unpackPhase patchPhase installPhase";

  installPhase = ''
    dest=$out/lib/node_modules/clightning-rest
    mkdir -p $dest
    ${rsync}/bin/rsync -a --inplace * ${self.nodeModules}/lib/node_modules \
      --exclude=/{screenshots,'*.Dockerfile'} \
      $dest

    makeWrapper ${self.nodejsRuntime}/bin/node "$out/bin/cl-rest" \
      --add-flags "$dest/cl-rest.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "REST API for C-Lightning";
    homepage = "https://github.com/Ride-The-Lightning/c-lightning-REST";
    license = licenses.mit;
    maintainers = with maintainers; [ nixbitcoin erikarvstedt ];
    platforms = platforms.unix;
  };
}; in self
