{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.11-1";
  hash = "sha256-l/WVuU+1muv2HOnOHy2h6/FXibiZpj3nMzGoLFTqZFc=";
  inherit rocm6;
}
