# Beta channel — currently tracks the same version as stable.
# When LM Studio releases a beta, update this version + hash.
# Beta URL uses: https://lmstudio.ai/download/latest/linux/x64?channel=beta
{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.19-1";
  hash = "sha256-KQAtobEdEW8+0swT70TYEaf7zd/TDyT+z0dwsI57kr8=";
  inherit rocm6;
}
