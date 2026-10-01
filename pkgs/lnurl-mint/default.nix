{ pkgs
, src # the lnurl-mint source (flake input, non-flake)
}:

let
  inherit (pkgs) lib;
  python3Packages = pkgs.python3.pkgs;

  # not in nixpkgs (lnbits' BOLT11 codec) - pinned to the same version and
  # hash as lnurl-mint's uv.lock. Its upstream `requires-python = "<3.13"`
  # cap is conservative (lnurl-mint's whole test suite passes against it on
  # 3.13/3.14), so it's relaxed here rather than failing nixpkgs'
  # interpreter-version check.
  bolt11 = python3Packages.buildPythonPackage rec {
    pname = "bolt11";
    version = "2.2.0";
    pyproject = true;

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-Es2dDT6w8IxQWxg08hYwNpl0wd47nDm5q9SN3Q0aREs=";
    };

    postPatch = ''
      sed -i 's/>=3.10,<3.13/>=3.10/' pyproject.toml
    '';

    build-system = [ python3Packages.hatchling ];

    dependencies = with python3Packages; [
      click
      base58
      coincurve
      bech32
      bitstring
    ];

    # upstream tests want pytest-cov and friends; skipped - lnurl-mint's own
    # suite exercises bolt11 thoroughly (every fake invoice is one)
    doCheck = false;

    meta = {
      description = "A library for encoding and decoding BOLT11 payment requests";
      homepage = "https://github.com/lnbits/bolt11";
      license = lib.licenses.mit;
    };
  };
  # not in nixpkgs and not buildable in the nix sandbox (it links Bitcoin
  # Core's own script interpreter, compiled from a vendored source tree via
  # CMake/Boost - see github:lnurlcash/kernel). It ships as a prebuilt,
  # per-arch manylinux wheel (pure ctypes: one `.so` loaded at import time,
  # no CPython C-API surface), so fetch that wheel straight from PyPI
  # instead - same sha256 as lnurl-mint's uv.lock. autoPatchelfHook rewires
  # the `.so`'s dynamic loader from the manylinux image's glibc to
  # nixpkgs' (it links only libstdc++/libm/libgcc_s/libpthread/libc - no
  # libpython, so no wrapping needed beyond that). Mirrors upstream's own
  # nix/package.nix.
  lnurlcashKernelWheels = {
    x86_64-linux = {
      url = "https://files.pythonhosted.org/packages/ab/f1/a265669f3dcf6b7cc93f76f25b1df2f71431d26a91d24b874931561a83b7/lnurlcash_kernel-0.1.0-py3-none-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl";
      # sha256, same as uv.lock (hex, not SRI, to avoid a lossy base64 transcription)
      sha256 = "b01f5142af4081fa5b1ea649800e6c8f718b5d944dfb36f7398c69ac6804e351";
    };
    aarch64-linux = {
      url = "https://files.pythonhosted.org/packages/08/88/77ee8b229ec7a39487f6690c91120d539e7b79e930c2ee5a4fd77f5add77/lnurlcash_kernel-0.1.0-py3-none-manylinux_2_27_aarch64.manylinux_2_28_aarch64.whl";
      sha256 = "cbfcdca96d2a71b8d872d063b571f94d876fc8f375cef6d87b911da805377dbf";
    };
  };

  lnurlcashKernel =
    let
      wheel =
        lnurlcashKernelWheels.${pkgs.stdenv.hostPlatform.system}
          or (throw "lnurlcash-kernel: no prebuilt wheel for ${pkgs.stdenv.hostPlatform.system}");
    in
    python3Packages.buildPythonPackage {
      pname = "lnurlcash-kernel";
      version = "0.1.0";
      format = "wheel";

      src = pkgs.fetchurl { inherit (wheel) url sha256; };

      nativeBuildInputs = [ pkgs.autoPatchelfHook ];
      buildInputs = [ pkgs.stdenv.cc.cc.lib ];

      pythonImportsCheck = [ "lnurlcashkernel" ];

      meta = {
        description = "Verify LUD-25 note (taproot key- and script-path) spends with Bitcoin Core's own script interpreter";
        license = lib.licenses.mit;
        platforms = [
          "x86_64-linux"
          "aarch64-linux"
        ];
      };
    };

  # /docs (swagger-ui) is self-hosted since v0.3.0, but the assets are
  # gitignored upstream - they are neither in the git tree nor in the wheel
  # (hatchling excludes gitignored files). Fetch them separately, same as
  # upstream's own nix/package.nix does.
  swaggerUiVersion = "5.32.13";
  swaggerUiBundle = pkgs.fetchurl {
    url = "https://cdn.jsdelivr.net/npm/swagger-ui-dist@${swaggerUiVersion}/swagger-ui-bundle.js";
    hash = "sha256-Xzvl2c9AzdYNyg2v6vh0P9hY0bO7cXu9rr9yATA/Y9c=";
  };
  swaggerUiCss = pkgs.fetchurl {
    url = "https://cdn.jsdelivr.net/npm/swagger-ui-dist@${swaggerUiVersion}/swagger-ui.css";
    hash = "sha256-nmF9msCvsOQwwRoXNm3oYk23zjTJnr0pdEPwBIzjCJk=";
  };
in
python3Packages.buildPythonApplication rec {
  pname = "lnurl-mint";
  # keep in sync with the lnurl-mint flake input's release tag (flake.nix)
  version = "0.12.1";
  pyproject = true;

  inherit src;

  patches = [
    # tests/test_lnurlcash.py: the four pay_delay tests race their
    # concurrent request against FakeNode's payment sleep - under
    # build-farm load the main thread loses that window and the note is
    # already spent/restored before the "pending" assertion (seen as
    # test_pending_note_rejects_concurrent_operations /
    # test_pending_note_is_released_if_the_payment_fails failing in CI).
    # The fake payment is gated on an event the test sets after its
    # concurrent response, making the pending window deterministic.
    # Also covers the two /w?p= lookup tests with the identical race.
    # NOTE: the gate patches router_module.pay_invoice, not
    # node.pay_invoice - conftest's node fixture wires the fake in as
    # router_module.pay_invoice (a bound method captured at fixture
    # setup), so patching the instance attribute never enters the call
    # path (an earlier revision of this patch did exactly that and the
    # tests kept flaking).
    ./pending-note-test-races.patch

    # The same fixed-sleep-window race in the remaining three tests that
    # probe a mid-flight melt: test_verify.py's genuinely-pending report
    # (0.3s window), test_poc_f2_pending_info_leak.py's async-gather probe
    # (0.5s), test_auth_data_hunter_poc.py's f3 (2.0s). Same gate
    # mechanism (router_module.pay_invoice, same reason as above); f2
    # additionally polls notes.pending_melts() instead of trusting a
    # fixed 0.05s sleep for the melt to reach mark_pending.
    ./pending-window-test-races.patch
  ];

  postPatch = ''
    # into the source tree, so the checkPhase tests covering /docs find them
    cp ${swaggerUiBundle} lnurl_mint/static/swagger-ui-bundle.js
    cp ${swaggerUiCss} lnurl_mint/static/swagger-ui.css

    # test_verify_census_melt_direction sleeps a fixed 50ms for the
    # background melt to reach its pay_invoice call before establishing the
    # RPC-census baseline - too tight on a loaded CI runner (the late
    # pay_invoice then leaks into the first asserted delta). Wait until the
    # call is actually observed instead (bounded at 10s).
    substituteInPlace tests/test_poc_rpc_census.py \
      --replace-fail \
        'time.sleep(0.05)' \
        'for _ in range(200):
            if census.deltas().get("pay_invoice"):
                break
            time.sleep(0.05)'
  '';

  # the fetched source has no .git for hatch-vcs to derive a version from
  env.SETUPTOOLS_SCM_PRETEND_VERSION = version;

  build-system = with python3Packages; [
    hatchling
    hatch-vcs
  ];

  dependencies = with python3Packages; [
    fastapi
    uvicorn
    # uvicorn's [standard] extras, spelled out (nixpkgs doesn't propagate
    # extras)
    httptools
    uvloop
    watchfiles
    websockets
    pyyaml
    python-dotenv
    bolt11
    httpx
    pydantic-settings
    qrcode
    bech32
    coincurve
    # LUD-25: every note spend (ck1/cw1) is verified by Bitcoin Core's own
    # interpreter (see lnurl_mint/spend.py). websockets was already below
    # via uvicorn's [standard] extras; it is a direct dependency since
    # v0.10.0 (NIP-57 zap receipts, see lnurl_mint/nostr.py).
    lnurlcashKernel
  ];

  # nixpkgs ships a fastapi newer than lnurl-mint's <0.116 pin - relax the
  # metadata bound and let the checkPhase's full test suite adjudicate
  # compatibility (it passes)
  pythonRelaxDeps = [ "fastapi" ];

  nativeBuildInputs = [ pkgs.makeWrapper ];

  # no [project.scripts] upstream - the app is served by uvicorn; wrap it so
  # the module has a single entry point to exec. The wrapper captures the
  # build-time PYTHONPATH (the full dependency closure) plus this package's
  # own site-packages.
  postInstall = ''
    makeWrapper ${lib.getExe python3Packages.uvicorn} $out/bin/lnurl-mint \
      --add-flags "lnurl_mint.server:app" \
      --prefix PYTHONPATH : "$out/${pkgs.python3.sitePackages}:$PYTHONPATH"

    # hatchling excludes the gitignored swagger-ui assets from the wheel -
    # install them alongside the package or /docs 500s at runtime
    cp ${swaggerUiBundle} $out/${pkgs.python3.sitePackages}/lnurl_mint/static/swagger-ui-bundle.js
    cp ${swaggerUiCss} $out/${pkgs.python3.sitePackages}/lnurl_mint/static/swagger-ui.css
  '';

  nativeCheckInputs = [ python3Packages.pytest ];

  # conftest.py isolates itself (throwaway sqlite, dummy dotenv, testserver
  # BASE_URL, FakeNode) - the suite needs no network and no further setup.
  # `python -m pytest` rather than the bare console script: the test modules
  # do `from tests.conftest import ...`, which needs the repo root on
  # sys.path, which only the -m form adds
  checkPhase = ''
    runHook preCheck
    python -m pytest
    runHook postCheck
  '';

  passthru = {
    inherit bolt11 lnurlcashKernel;
  };

  meta = {
    description = "Minimal lnurlcash (LUD-25, Lightning bearer assets) mint - LUD-03/LUD-06 only";
    homepage = "https://github.com/dni/lnurl-mint";
    license = lib.licenses.mit;
    mainProgram = "lnurl-mint";
    platforms = lib.platforms.linux;
  };
}
