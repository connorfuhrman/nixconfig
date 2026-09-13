{ ... }: {
  flake.modules.darwin.buildkite = { config, lib, pkgs, ... }:
    let
      installBuildkiteClusterToken = pkgs.writeShellScript "install-buildkite-cluster-token" ''
        set -euo pipefail
        src="$1"
        mkdir -p /etc/buildkite-agent
        chmod 755 /etc/buildkite-agent
        install -m 640 -o root -g buildkite-agent-linux "$src" /etc/buildkite-agent/cluster.token
        rm -f "$src"
      '';
    in
    {
      # nix-darwin only creates users/groups listed in knownUsers/knownGroups.
      users.knownGroups = lib.mkAfter [ "buildkite-agent-macos" ];
      users.knownUsers = lib.mkAfter [ "buildkite-agent-macos" ];
      users.groups.buildkite-agent-macos.gid = lib.mkDefault 536;
      users.users.buildkite-agent-macos = {
        uid = lib.mkDefault 536;
        gid = lib.mkDefault config.users.groups.buildkite-agent-macos.gid;
      };

      services.buildkite-agents.macos = {
        tokenPath = "/etc/buildkite-agent/cluster.token";
        tags = {
          queue = "mac-mini-macos";
          os = "macos";
          arch = "aarch64";
        };
        runtimePackages = [
          pkgs.nix
          pkgs.git
          pkgs.bash
          pkgs.coreutils
          pkgs.gnutar
          pkgs.gzip
        ];
      };

      nix.settings.trusted-users = [
        "connorfuhrman"
        "buildkite-agent-macos"
      ];

      system.activationScripts.buildkiteTokenDir.text = ''
        mkdir -p /etc/buildkite-agent
        chmod 755 /etc/buildkite-agent
      '';

      # Token is read at agent start by buildkite-agent-macos (not root). Install
      # scripts may run before the user exists; activation fixes group/mode.
      system.activationScripts.buildkiteTokenPermissions = {
        deps = [ "users" ];
        text = ''
          if [ -f /etc/buildkite-agent/cluster.token ]; then
            chown root:buildkite-agent-macos /etc/buildkite-agent/cluster.token
            chmod 640 /etc/buildkite-agent/cluster.token
          fi
        '';
      };

      nix.linux-builder.config = { ... }: {
        services.buildkite-agents.linux = {
          tokenPath = "/etc/buildkite-agent/cluster.token";
          tags = {
            queue = "mac-mini-aarch64-linux";
            os = "linux";
            arch = "aarch64";
          };
          runtimePackages = [
            pkgs.nix
            pkgs.git
            pkgs.bash
            pkgs.coreutils
            pkgs.gnutar
            pkgs.gzip
          ];
        };

        nix.settings.trusted-users = [
          "root"
          "builder"
          "buildkite-agent-linux"
        ];

        system.activationScripts.buildkiteTokenDir.text = ''
          mkdir -p /etc/buildkite-agent
          chmod 755 /etc/buildkite-agent
        '';

        system.activationScripts.buildkiteTokenPermissions = {
          deps = [ "users" ];
          text = ''
            if [ -f /etc/buildkite-agent/cluster.token ]; then
              chown root:buildkite-agent-linux /etc/buildkite-agent/cluster.token
              chmod 640 /etc/buildkite-agent/cluster.token
            fi
          '';
        };

        security.sudo.extraRules = [
          {
            users = [ "builder" ];
            commands = [
              {
                command = toString installBuildkiteClusterToken;
                options = [ "NOPASSWD" ];
              }
            ];
          }
        ];
      };

      launchd.daemons.buildkite-token-sync = {
        script = ''
          set -euo pipefail
          token=/etc/buildkite-agent/cluster.token
          if [ ! -f "$token" ]; then
            echo "buildkite cluster token missing at $token" >&2
            exit 1
          fi
          until ssh -o BatchMode=yes -o ConnectTimeout=5 linux-builder true 2>/dev/null; do
            sleep 5
          done
          tmp=$(mktemp /tmp/buildkite-cluster.token.XXXXXX)
          cp "$token" "$tmp"
          chmod 600 "$tmp"
          scp -q "$tmp" linux-builder:/tmp/buildkite-cluster.token
          rm -f "$tmp"
          ssh linux-builder sudo ${toString installBuildkiteClusterToken} /tmp/buildkite-cluster.token
        '';
        serviceConfig = {
          RunAtLoad = true;
          StartInterval = 300;
          WatchPaths = [ "/etc/buildkite-agent/cluster.token" ];
          StandardOutPath = "/var/log/buildkite-token-sync.log";
          StandardErrorPath = "/var/log/buildkite-token-sync.log";
        };
      };
    };
}
