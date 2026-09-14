# flake.lib is a shared helper bag (pkgsFor, installer ISO, …).
# Without this option, two modules assigning flake.lib cannot merge
# (flake-parts treats undeclared flake outputs as a single unique value).
{ lib, ... }: {
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
    description = "Repo-wide helpers closed over flake inputs.";
  };
}
