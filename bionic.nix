{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  channel = "bionic";
  inherit rocm6;
}
