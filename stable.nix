{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.10-1";
  hash = "sha256-FC7rPA1CxTaYakpSSpjxYiPETW8+N5QmsmUib3RHD0o=";
  inherit rocm6;
}
