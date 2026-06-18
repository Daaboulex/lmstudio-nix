# Beta channel — currently tracks the same version as stable.
# When LM Studio releases a beta, update this version + hash.
# Beta URL uses: https://lmstudio.ai/download/latest/linux/x64?channel=beta
{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.17-3";
  hash = "sha256-wA2t/TSB4VO3FZS3TmqVEfeg93Hk5GZxU5Au+idguzQ=";
  inherit rocm6;
}
