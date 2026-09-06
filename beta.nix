{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  channel = "beta";
  inherit rocm6;
}
