{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.14-4";
  hash = "sha256-oDPL/m1Ghutxmi3iumsy2/Hs6Bp8UDWsJeup1Vlu/i8=";
  inherit rocm6;
}
