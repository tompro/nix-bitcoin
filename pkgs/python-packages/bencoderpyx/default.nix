{ lib, buildPythonPackage, fetchurl, cython, pytest, coverage }:

buildPythonPackage {
  pname = "bencoder.pyx";
  # Unstable snapshot of upstream master: the 3.0.1 release (and the commit
  # previously pinned here) fails to build with Cython 3 because `bencoder.pyx`
  # references the removed Python 2 `long` builtin.
  # Fixed upstream in https://github.com/whtsky/bencoder.pyx/commit/0a81b4e10cf297879148cf2b083a23eb006f6b5b
  version = "3.0.1-unstable-2025-11-17";
  format = "setuptools";

  src = fetchurl {
    url = "https://github.com/whtsky/bencoder.pyx/archive/0a81b4e10cf297879148cf2b083a23eb006f6b5b.tar.gz";
    sha256 = "1xm17ara2z4bm3hc6lh9hsc5mwma73xhckyv7b1p8ni89nnj692l";
  };

  nativeBuildInputs = [ cython ];

  checkInputs = [ pytest coverage ];

  meta = with lib; {
    description = "A fast bencode implementation in Cython";
    homepage = "https://github.com/whtsky/bencoder.pyx";
    maintainers = with maintainers; [ seberm nixbitcoin ];
    license = licenses.bsd3;
  };
}
