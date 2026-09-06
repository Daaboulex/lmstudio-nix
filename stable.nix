{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  channel = "stable";
  inherit rocm6;
}
