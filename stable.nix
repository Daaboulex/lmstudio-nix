{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.19-2";
  hash = "sha256-kR84VRYbKOYi8Y494/KFrIwzbK6nwSiorIkaIJJDeHI=";
  inherit rocm6;
}
