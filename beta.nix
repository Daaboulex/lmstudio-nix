# Beta channel — currently tracks the same version as stable.
# When LM Studio releases a beta, update this version + hash.
# Beta URL uses: https://lmstudio.ai/download/latest/linux/x64?channel=beta
{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.8-1";
  hash = "sha256-gbLq6nY3Jdo2nZYWbh0XEVojrqkO5noZLV/lw4TaEs8=";
  inherit rocm6;
}
