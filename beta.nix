# Beta channel — currently tracks the same version as stable.
# When LM Studio releases a beta, update this version + hash.
# Beta URL uses: https://lmstudio.ai/download/latest/linux/x64?channel=beta
{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.16-2";
  hash = "sha256-faLtj/9M59KRdEMHHgTCPLG4Gl5C7hkdAgmaS/O5rOk=";
  inherit rocm6;
}
