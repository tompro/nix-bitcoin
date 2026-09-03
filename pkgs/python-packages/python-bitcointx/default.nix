{ lib, buildPythonPackage, fetchFromGitHub, secp256k1 }:

buildPythonPackage rec {
  pname = "python-bitcointx";
  version = "1.1.5";
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "Simplexum";
    repo = "python-bitcointx";
    rev = "python-bitcointx-v${version}";
    hash = "sha256-KXndYEsJ8JRTiGojrKXmAEeGDlHrNGs5MtYs9XYiqMo=";
  };

  patches = [
    # Support libsecp256k1 v0.7, which renamed the `secp256k1_ec_privkey_*`
    # symbols to `secp256k1_ec_seckey_*`.
    # Vendored copy of https://github.com/Simplexum/python-bitcointx/pull/91
    # (vendored because fetchpatch normalization of the live PR diff is not
    # stable across environments). Remove when a release containing this fix
    # is packaged.
    ./libsecp256k1-0.7-compat.patch
  ];

  postPatch = ''
    for path in core/secp256k1.py tests/test_load_secp256k1.py; do
      substituteInPlace "bitcointx/$path" \
        --replace-fail "ctypes.util.find_library('secp256k1')" "'${secp256k1}/lib/libsecp256k1.so'"
    done
  '';

  pythonImportCheck = [
    "bitcointx"
  ];

  meta = with lib; {
    description = "Interface to Bitcoin transaction data structures";
    homepage = "https://github.com/Simplexum/python-bitcointx";
    maintainers = with maintainers; [ seberm nixbitcoin ];
    license = licenses.gpl3;
  };
}
