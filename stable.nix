{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.20-1";
  hash = "sha256-bhyeeXOuiS7vk01wZhLJIMBLJBZYYRCNWIMliAHGSu0=";
  inherit rocm6;
}
