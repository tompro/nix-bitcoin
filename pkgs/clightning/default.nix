{ clightning, fetchurl }:

# TODO-EXTERNAL: Remove this override once nixpkgs provides clightning >= 26.06.8
# (checked 2026-10: nixpkgs master, nixos-unstable and release-26.05 are still
# at 26.04.1, no bump PR open).
#
# Security update: clightning 26.06.7 and 26.06.8 fix several responsibly
# disclosed vulnerabilities. Upstream strongly recommends upgrading.
# https://github.com/ElementsProject/lightning/releases/tag/v26.06.8
#
# The src hash matches the PGP-signed SHA256SUMS-v26.06.8 release file.
clightning.overrideAttrs (finalAttrs: prev: {
  version = "26.06.8";

  src = fetchurl {
    url = "https://github.com/ElementsProject/lightning/releases/download/v${finalAttrs.version}/clightning-v${finalAttrs.version}.zip";
    hash = "sha256-KAnE9qul6SgxfZhX+/9bKSMrXnme104RUIcqm/Ed4CU=";
  };

  # devtools/blockreplace.py is invoked directly by doc/Makefile but is not
  # executable in the release zip.
  postPatch = (prev.postPatch or "") + ''
    chmod +x devtools/blockreplace.py
    patchShebangs devtools/blockreplace.py
  '';
})
