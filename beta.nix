# Beta channel — currently tracks the same version as stable.
# When LM Studio releases a beta, update this version + hash.
# Beta URL uses: https://lmstudio.ai/download/latest/linux/x64?channel=beta
{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.9-1";
  hash = "sha256-+vn8gExfdfbYUBVzc59kCDlw7nEbFIyGR0fF9sFFodo=";
  inherit rocm6;
}
