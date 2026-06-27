# Beta channel — currently tracks the same version as stable.
# When LM Studio releases a beta, update this version + hash.
# Beta URL uses: https://lmstudio.ai/download/latest/linux/x64?channel=beta
{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.18-1";
  hash = "sha256-KpznZu1tiXhtW9XDvbMCgH9xyGyaO37/F1sWqK1RCUk=";
  inherit rocm6;
}
