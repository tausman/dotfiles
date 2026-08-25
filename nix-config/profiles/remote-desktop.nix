{ ... }:
{
  # The Ubuntu VM with a remote desktop: everything `headless` has, plus a virtual X
  # server you reach over an SSH tunnel. Layered on ./headless.nix rather than replacing
  # it — a VM with no desktop is still a valid role, so `headless` stays importable on
  # its own and this only ever adds.
  imports = [ ./headless.nix ../modules/vnc.nix ];
}
