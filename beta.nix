# Beta channel — currently tracks the same version as stable.
# When LM Studio releases a beta, update this version + hash.
# Beta URL uses: https://lmstudio.ai/download/latest/linux/x64?channel=beta
{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.12-1";
  hash = "sha256-U7TJkMUqmL4Wk77zcIN2/4IFz7artvVg0saREjoGy8I=";
  inherit rocm6;
}
