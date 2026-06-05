{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.16-1";
  hash = "sha256-DLB1V7dSkHKlJz6CDaHgFkJxjptdGPL9e33w7ZXR3a8=";
  inherit rocm6;
}
