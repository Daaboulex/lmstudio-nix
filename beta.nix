# Beta channel — currently tracks the same version as stable.
# When LM Studio releases a beta, update this version + hash.
# Beta URL uses: https://lmstudio.ai/download/latest/linux/x64?channel=beta
{ callPackage }:
callPackage ./desktop.nix {
  version = "0.4.7-4";
  hash = "sha256-2dSgBr2B+PIUi/YCBmXDWXQWEEId6Qymh1JQuAPG/xU=";
}
