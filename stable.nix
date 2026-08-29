{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.23-1";
  hash = "sha256-wb3xlSgeJdySGvXJHrJQIDUkDc4SFxQMQwNtbPMDj9g=";
  inherit rocm6;
}
