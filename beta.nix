# Beta channel — currently tracks the same version as stable.
# When LM Studio releases a beta, update this version + hash.
# Beta URL uses: https://lmstudio.ai/download/latest/linux/x64?channel=beta
{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.14-1";
  hash = "sha256-Lbq9BAvu2Q4WUlLji6hP01/74H+MCGBeGCV3zl0co4I=";
  inherit rocm6;
}
