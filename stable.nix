{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.17-4";
  hash = "sha256-4fJwkk1nmGu8k/bv3vtefRhNH3kq7/F18XJv8jnK0oQ=";
  inherit rocm6;
}
