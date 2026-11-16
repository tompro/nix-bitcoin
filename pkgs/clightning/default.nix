{ clightning, fetchurl }:

# TODO-EXTERNAL: Remove this override once nixpkgs provides clightning >= 26.06.10.
# Security update: fixes dual funding/splicing, on-chain HTLC resolution, gossip
# resource limits, runes/commando, plugin hooks, remote crashes and more.
# https://github.com/ElementsProject/lightning/releases/tag/v26.06.10
#
# The src hash matches SHA256SUMS-v26.06.10, verified against daywalker90's
# signature (8A079421A871D0B1083511937AB4802ED5A639F3, upstream SECURITY.md).
clightning.overrideAttrs (finalAttrs: prev: {
  version = "26.06.10";

  src = fetchurl {
    url = "https://github.com/ElementsProject/lightning/releases/download/v${finalAttrs.version}/clightning-v${finalAttrs.version}.zip";
    hash = "sha256-SRRWHm0QjazKAYPX5rOxwiTFgFl93Ls5cpnvWw/MMjA=";
  };

  # devtools/blockreplace.py is invoked directly by doc/Makefile but is not
  # executable in the release zip.
  postPatch = (prev.postPatch or "") + ''
    chmod +x devtools/blockreplace.py
    patchShebangs devtools/blockreplace.py
  '';
})
