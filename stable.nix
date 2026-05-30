{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.15-2";
  hash = "sha256-M7doFWVEyzcDJF4M+h4WKR+Q45yn3FZc2vZbzjYWBPE=";
  inherit rocm6;
}
