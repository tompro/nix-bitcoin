{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "lndinit";
  version = "0.1.36-beta";

  src = fetchFromGitHub {
    owner = "lightninglabs";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-2rFiDy1yVXqI0ag8fsifx9sCCu0BbwSj9U7bzU352dc=";
  };

  vendorHash = "sha256-vLatsVG4VUtSAJtOiZgy4zWdh9Qs4cwkz0CaUTRZ3oE=";

  subPackages = [ "." ];

  meta = with lib; {
    description = "Wallet initializer utility for lnd";
    homepage = "https://github.com/lightninglabs/lndinit";
    license = licenses.mit;
    maintainers = with maintainers; [ erikarvstedt ];
  };
}
