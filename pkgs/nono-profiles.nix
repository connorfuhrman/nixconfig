# Shared nono profile building blocks for AI coding agents.
#
# Conventions learned the hard way (see WORK_JOURNAL in repo history and
# docs/plans/nimbus-sandbox-godot-plan.md):
#   - Profiles are ALWAYS consumed from the nix store (nono-wrap embeds the
#     store path) — never let nono rewrite a named home profile; it
#     auto-adds read:["~/"], which breaks sandbox init.
#   - NEVER grant "~/" or "~/.local/state/nono" (protected path; sandbox
#     init refuses overlapping grants).
#   - The deny_* groups are marked `required` upstream: they are always
#     active. Extends "default" so future required groups stay on.
{
  lib,
}: let
  # Baseline policy for an AI coding agent: runtimes it shells out to,
  # caches, nix store, git config. Tool-specific state (e.g. "$HOME/.pi")
  # is added by the caller via extendProfile.
  agentBase = {
    extends = [ "default" ];
    meta = {
      name = "agent-base";
      description = "Shared baseline nono policy for AI coding agents";
    };
    interactive = false;
    security = {
      signal_mode = "isolated";
      capability_elevation = false;
    };
    groups = {
      include = [
        "node_runtime"
        "rust_runtime"
        "python_runtime"
        {
          name = "user_caches_macos";
          when = "macos";
        }
        {
          name = "user_caches_linux";
          when = "linux";
        }
        {
          name = "linux_sysfs_read";
          when = "linux";
        }
        "nix_runtime"
        "git_config"
        "unlink_protection"
      ];
    };
    workdir = {
      access = "readwrite";
    };
    filesystem = {
      # Ephemeral runtime state only under XDG — never configuration.
      allow = [
        "$TMPDIR"
        "$NONO_CONFIG/profile-drafts"
        "$HOME/.local/share/nix"
      ];
      read = [
        "/nix/store"
        # Agent Skills standard discovery dir (skills read-only).
        "$HOME/.agents"
      ];
      suppress_save_prompt = [
        "~/"
        "$HOME"
      ];
    };
    network = {
      block = false;
      allow_domain = [ ];
      credentials = [ ];
    };
    allow_launch_services = true;
  };

  # filesystem.* keys that are lists and merge by concatenation; everything
  # else merges via recursiveUpdate (later value wins).
  listKeys = [
    "allow"
    "read"
    "write"
    "read_file"
    "allow_file"
    "write_file"
    "bypass_protection"
    "suppress_save_prompt"
  ];

  # extendProfile base ext — merge a tool-specific profile onto a baseline.
  # Lists under filesystem.* concatenate (dedup); other attrs overlay.
  extendProfile = base: ext:
    lib.recursiveUpdate base (ext
      // lib.optionalAttrs (ext.filesystem or null != null) {
        filesystem =
          base.filesystem or {}
          // (builtins.removeAttrs ext.filesystem listKeys)
          // (builtins.listToAttrs (map (k:
              lib.nameValuePair k
              (lib.unique ((base.filesystem.${k} or []) ++ (ext.filesystem.${k} or []))))
            (builtins.filter (k: ext.filesystem ? ${k} || base.filesystem ? ${k}) listKeys)));
      });
in {
  inherit agentBase extendProfile;
}
