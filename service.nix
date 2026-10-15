# lms server start with no daemon running wakes the install it last recorded, which can be the desktop app.
{
  lib,
  writeShellScript,
  package,
  port,
  bind ? null,
}:
let
  lms = "${package}/bin/lms";
  serverArgs = [
    "--port"
    (toString port)
  ]
  ++ lib.optionals (bind != null) [
    "--bind"
    bind
  ];
  serveWhenReady = writeShellScript "lmstudio-serve-when-ready" ''
    until status=$(${lms} daemon status --json) && [[ "$status" == *'"status":"running"'* ]]; do
      sleep 0.5
    done
    exec ${lms} server start ${lib.escapeShellArgs serverArgs}
  '';
in
{
  Type = "simple";
  ExecStart = "${package}/bin/llmster";
  ExecStartPost = "${serveWhenReady}";
  ExecStop = "${lms} daemon down";
  TimeoutStartSec = 120;
  Restart = "on-failure";
  RestartSec = 5;
}
