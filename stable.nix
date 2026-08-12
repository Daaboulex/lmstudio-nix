{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.21-2";
  hash = "sha256-EBQ3bYnWaMOBTNIOKxRqB2FGdg3tHvB7lo+2HFje01U=";
  inherit rocm6;
}
