#!/usr/bin/env nix-shell
#! nix-shell -i bash -p gnupg gnused jq curl
set -euo pipefail

# Use this to start a debug shell at the location of this statement
# . "${BASH_SOURCE[0]%/*}/../../helper/start-bash-session.sh"

version=3.3.1
# You can also specify a rev instead:
# rev=57eddac7f0b99b4fe84d91c0f4a50a4f7ccfe55f
owner=mempool
repo=https://github.com/$owner/mempool

cd "${BASH_SOURCE[0]%/*}"

updateSrc() {
    TMPDIR="$(mktemp -d /tmp/mempool.XXX)"
    trap 'rm -rf $TMPDIR' EXIT

    # Fetch and verify source
    src=$TMPDIR/src
    mkdir -p "$src"
    if [[ -v rev ]]; then
        # Fetch revision
        git -C "$src" init
        git -C "$src" fetch --depth 1 "$repo" "$rev:src"
        git -C "$src" checkout src
    else
        tag=v$version
        # Fetch and GPG-verify version tag
        git clone --depth 1 --branch "$tag" -c advice.detachedHead=false $repo "$src"
        git -C "$src" checkout tags/$tag
        export GNUPGHOME=$TMPDIR
        # Expected release signing keys (full primary key fingerprints):
        # - wiz <wiz@mempool.space> (keyserver)
        # - mononaut <mononaut@mempool.space>
        #   (not on keyservers; published at https://github.com/mononaut.gpg)
        expectedSigners="913C5FF1F579B66CA10378DBA394E332255A6173 523B596A78BB8495AA2EC45ABFD16BE592A9CD8D"
        gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 913C5FF1F579B66CA10378DBA394E332255A6173 2> /dev/null
        curl -fsSL https://github.com/mononaut.gpg | gpg --import 2> /dev/null
        # Fail closed unless every expected signer key is present in the keyring
        for fpr in $expectedSigners; do
            if ! gpg --batch --with-colons --list-keys 2> /dev/null \
               | awk -F: -v fpr="$fpr" '$1 == "fpr" && $10 == fpr { found = 1 } END { exit !found }'; then
                echo "Error: expected release signing key $fpr is not in the keyring" >&2
                exit 1
            fi
        done
        # Verify the tag and compare the actual signer fingerprint exactly.
        # --raw prints the machine-readable gpg status lines to stderr.
        if ! gpgStatus=$(git -C "$src" verify-tag --raw $tag 2>&1); then
            echo "Error: tag $tag has no valid signature" >&2
            exit 1
        fi
        signerFpr=$(echo "$gpgStatus" | sed -nE 's/^\[GNUPG:\] VALIDSIG ([0-9A-F]{40}) .*/\1/p')
        if [[ ! $signerFpr ]]; then
            echo "Error: could not extract signer fingerprint for tag $tag" >&2
            exit 1
        fi
        if [[ " $expectedSigners " != *" $signerFpr "* ]]; then
            echo "Error: tag $tag was signed by unexpected key $signerFpr" >&2
            echo "Expected one of: $expectedSigners" >&2
            exit 1
        fi
        echo "Tag $tag verified: signed by expected key $signerFpr"
        rev=$tag
    fi
    rm -rf "$src"/.git
    hash=$(nix hash path "$src")

    sed -i "
      s|\bversion = .*;|version = \"$version\";|
      s|\bowner = .*;|owner = \"$owner\";|
      /fetchFromGitHub/,/hash/ s|\bhash = .*;|hash = \"$hash\";|
    " default.nix
}

updateNodeModulesHash() {
    component=$1
    echo
    echo "Fetching node modules for mempool-$component"
    ../../helper/update-fixed-output-derivation.sh ./default.nix mempool-"$component".nodeModules "sourceRoot.*$component"
}

updateFrontendAssets() {
  . ./frontend-assets-update.sh
  echo
  echo "Fetching frontend assets"
  ../../helper/update-fixed-output-derivation.sh ./default.nix mempool-frontend.assets "frontendAssets"
}

updateRustGbtCargoDeps() {
    echo
    echo "Fetching rust-gbt cargo deps"
    ../../helper/update-fixed-output-derivation.sh ./default.nix mempool-rust-gbt.cargoDeps "fetchCargoVendor"
}

if [[ $# == 0 ]]; then
    # Each of these can be run separately
    updateSrc
    updateFrontendAssets
    updateNodeModulesHash backend
    updateNodeModulesHash frontend
    updateRustGbtCargoDeps
else
    "$@"
fi
