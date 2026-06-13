# Beta channel — currently tracks the same version as stable.
# When LM Studio releases a beta, update this version + hash.
# Beta URL uses: https://lmstudio.ai/download/latest/linux/x64?channel=beta
{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.17-2";
  hash = "sha256-4Jj3/ABMnq1a8j6nScRnIrS5HSA2L4Muyl63thCK9OU=";
  inherit rocm6;
}
