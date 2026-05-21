# Beta channel — currently tracks the same version as stable.
# When LM Studio releases a beta, update this version + hash.
# Beta URL uses: https://lmstudio.ai/download/latest/linux/x64?channel=beta
{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.14-3";
  hash = "sha256-ST3/qP6qWpnWUtqSZJdhbyUIzQoUWp15EKr2WrpWcec=";
  inherit rocm6;
}
