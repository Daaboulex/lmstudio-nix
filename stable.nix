{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.18-1";
  hash = "sha256-KpznZu1tiXhtW9XDvbMCgH9xyGyaO37/F1sWqK1RCUk=";
  inherit rocm6;
}
