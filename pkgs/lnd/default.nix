{ lnd, fetchFromGitHub }:

# TODO-EXTERNAL: Remove this override once the pinned nixpkgs provides
# lnd >= 0.21.8-beta. Upstream has published the signed tag, but not a GitHub
# release yet. The tag points to 59dd7908b33710b511c960d848ecb24c47916c3a.
# https://github.com/lightningnetwork/lnd/tree/v0.21.8-beta
# https://github.com/lightningnetwork/lnd/blob/v0.21.8-beta/docs/release-notes/release-notes-0.21.8.md
lnd.overrideAttrs (finalAttrs: _: {
  version = "0.21.8-beta";

  src = fetchFromGitHub {
    owner = "lightningnetwork";
    repo = "lnd";
    rev = "v${finalAttrs.version}";
    hash = "sha256-cWBNYM9PnsQ6/lThlINPfWvwNly8ixoYkWTXJBsbHvk=";
  };

  vendorHash = "sha256-gcKnoxS0M26Jv1guEzQSUtGVr5I+8EBSrzRVU0pE1fU=";
})
