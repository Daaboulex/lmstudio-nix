{ callPackage, rocm6 }:
callPackage ./desktop.nix {
  version = "0.4.16-2";
  hash = "sha256-faLtj/9M59KRdEMHHgTCPLG4Gl5C7hkdAgmaS/O5rOk=";
  inherit rocm6;
}
