# Beta channel — currently tracks the same version as stable.
# When LM Studio releases a beta, update this version + hash.
# Beta URL uses: https://lmstudio.ai/download/latest/linux/x64?channel=beta
{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.15-1";
  hash = "sha256-9XQBFZpVz8/f2R4ElXfNh9vBuUG2eGAp41YCA834ZsM=";
  inherit rocm6;
}
