{ clightning, fetchurl }:

# TODO-EXTERNAL: Remove this override once nixpkgs provides clightning >= 26.06.9
# (checked 2026-10: nixpkgs master, nixos-unstable and release-26.05 are still
# at 26.04.1, no bump PR open).
#
# Security update: 26.06.9 fixes vulnerabilities in channel reestablishment,
# splicing, HTLC/onion handling, runes and more, plus a gossip regression in
# 26.06.8. Upstream strongly recommends upgrading.
# https://github.com/ElementsProject/lightning/releases/tag/v26.06.9
#
# The src hash matches the SHA256SUMS-v26.06.9 release file.
clightning.overrideAttrs (finalAttrs: prev: {
  version = "26.06.9";

  src = fetchurl {
    url = "https://github.com/ElementsProject/lightning/releases/download/v${finalAttrs.version}/clightning-v${finalAttrs.version}.zip";
    hash = "sha256-rDextsQbbGDPBt2M11APH6sEQRzy87wSaDjYyvq0U40=";
  };

  # devtools/blockreplace.py is invoked directly by doc/Makefile but is not
  # executable in the release zip.
  postPatch = (prev.postPatch or "") + ''
    chmod +x devtools/blockreplace.py
    patchShebangs devtools/blockreplace.py
  '';
})
