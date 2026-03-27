{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.8-1";
  hash = "sha256-gbLq6nY3Jdo2nZYWbh0XEVojrqkO5noZLV/lw4TaEs8=";
  inherit rocm6;
}
