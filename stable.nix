{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.13-1";
  hash = "sha256-IHhqAsYVi1XCaryxrEyhakDyye2vehbsJ77eF68KaIg=";
  inherit rocm6;
}
