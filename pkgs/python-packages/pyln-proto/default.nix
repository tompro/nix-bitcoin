{ buildPythonPackage
, clightning
, hatchling
, pytestCheckHook
, bitstring
, cryptography
, coincurve
, base58
, pysocks
}:

buildPythonPackage rec {
  pname = "pyln-proto";
  version = clightning.version;
  format = "pyproject";

  inherit (clightning) src;

  # clightning >= 26.06 depends on `coincurve-cp314-fix` (a coincurve fork
  # published for cp314 wheels) which is not packaged in nixpkgs. Depend on
  # nixpkgs' coincurve instead; both provide the `coincurve` python module.
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'coincurve-cp314-fix>=22.0.1' 'coincurve==21.0.0'
  '';

  nativeBuildInputs = [ hatchling ];

  propagatedBuildInputs = [
    bitstring
    cryptography
    coincurve
    base58
    pysocks
  ];

  checkInputs = [ pytestCheckHook ];

  pythonNamespaces = [ "pyln" ];

  postUnpack = "sourceRoot=$sourceRoot/contrib/pyln-proto";
}
