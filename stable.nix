{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.9-1";
  hash = "sha256-+vn8gExfdfbYUBVzc59kCDlw7nEbFIyGR0fF9sFFodo=";
  inherit rocm6;
}
