# Beta channel — currently tracks the same version as stable.
# When LM Studio releases a beta, update this version + hash.
# Beta URL uses: https://lmstudio.ai/download/latest/linux/x64?channel=beta
{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.17-4";
  hash = "sha256-4fJwkk1nmGu8k/bv3vtefRhNH3kq7/F18XJv8jnK0oQ=";
  inherit rocm6;
}
