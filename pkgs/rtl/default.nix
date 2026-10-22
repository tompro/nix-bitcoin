{ lib
, stdenvNoCC
, nodejs_22
, nodejs-slim_22
, fetchNodeModules
, fetchurl
, makeWrapper
}:
# RTL 0.15.15 requires the October 2026 Node.js security fixes.
assert lib.assertMsg (lib.versionAtLeast nodejs-slim_22.version "22.23.4")
  "RTL requires Node.js >= 22.23.4. Update nixpkgs or enable nix-bitcoin.useVersionLockedPkgs.";
let self = stdenvNoCC.mkDerivation {
  pname = "rtl";
  version = "0.15.15";

  src = fetchurl {
    url = "https://github.com/Ride-The-Lightning/RTL/archive/refs/tags/v${self.version}.tar.gz";
    hash = "sha256-q/13bU6KCdczKoVuETVEu5NPREoZSkiHvCpMtwTaKnU=";
  };

  passthru = {
    nodejs = nodejs_22;
    nodejsRuntime = nodejs-slim_22;

    nodeModules = fetchNodeModules {
      inherit (self) src nodejs;
      # TODO-EXTERNAL: Remove `npmFlags` when no longer required
      # See: https://github.com/Ride-The-Lightning/RTL/issues/1182
      npmFlags = "--legacy-peer-deps";
      hash = "sha256-GlN7MFGO2I5khCiU43RL9OfIhdVieLgiYk3KiFtr4pY=";
    };
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  phases = "unpackPhase patchPhase checkPhase installPhase";

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    export HOME=$TMPDIR
    ln -s ${self.nodeModules}/lib/node_modules node_modules
    ${self.nodejs}/bin/node --test test/backend/*.test.mjs
    runHook postCheck
  '';

  # `src` already contains the precompiled frontend and backend.
  # Copy all files required for packaging, like in
  # https://github.com/Ride-The-Lightning/RTL/blob/master/dockerfiles/Dockerfile
  installPhase = ''
    dest=$out/lib/node_modules/rtl
    mkdir -p $dest
    cp -r \
      rtl.js \
      package.json \
      frontend \
      backend \
      ${self.nodeModules}/lib/node_modules \
      $dest

    makeWrapper ${self.nodejsRuntime}/bin/node "$out/bin/rtl" \
      --add-flags "$dest/rtl.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "A web interface for LND, c-lightning and Eclair";
    homepage = "https://github.com/Ride-The-Lightning/RTL";
    license = licenses.mit;
    maintainers = with maintainers; [ nixbitcoin erikarvstedt ];
    platforms = platforms.unix;
  };
}; in self
