{ ... }: {
  flake.modules.darwin.buildkite = { config, lib, pkgs, ... }:
    let
      agentUser = "buildkite-agent-macos";
      agentHome = "/var/lib/${agentUser}";

      installBuildkiteClusterToken = pkgs.writeShellScript "install-buildkite-cluster-token" ''
        set -euo pipefail
        src="$1"
        mkdir -p /etc/buildkite-agent
        chmod 755 /etc/buildkite-agent
        install -m 640 -o root -g buildkite-agent-linux "$src" /etc/buildkite-agent/cluster.token
        rm -f "$src"
      '';

      # nix.linux-builder writes ssh_config.d/100-linux-builder.conf (Host
      # linux-builder, IdentityFile /etc/nix/builder_ed25519). Launchd runs
      # token-sync as root — use the system ssh_config explicitly.
      linuxBuilderSsh = pkgs.writeShellScript "linux-builder-ssh" ''
        exec ssh -F /etc/ssh/ssh_config \
          -o BatchMode=yes \
          -o ConnectTimeout=5 \
          -o IdentitiesOnly=yes \
          -i /etc/nix/builder_ed25519 \
          "$@"
      '';

      linuxBuilderScp = pkgs.writeShellScript "linux-builder-scp" ''
        exec scp -F /etc/ssh/ssh_config \
          -o BatchMode=yes \
          -o ConnectTimeout=5 \
          -o IdentitiesOnly=yes \
          -i /etc/nix/builder_ed25519 \
          "$@"
      '';
    in
    {
      # nix-darwin only creates users/groups listed in knownUsers/knownGroups.
      users.knownGroups = lib.mkAfter [ agentUser ];
      users.knownUsers = lib.mkAfter [ agentUser ];
      users.groups.buildkite-agent-macos.gid = lib.mkDefault 536;
      users.users.buildkite-agent-macos = {
        uid = lib.mkDefault 536;
        gid = lib.mkDefault config.users.groups.buildkite-agent-macos.gid;
        # createhomedir fails on /var/lib (errno 62); postActivation creates the workdir.
        createHome = lib.mkForce false;
      };

      programs.ssh.knownHosts.linux-builder = {
        hostNames = [ "linux-builder" ];
        extraHostNames = [ "localhost" "[localhost]:31022" ];
        publicKey =
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJBWcxb/Blaqt1auOtE+F8QUWrUotiC5qBJ+UuEWdVCb";
      };

      services.buildkite-agents.macos = {
        tokenPath = "/etc/buildkite-agent/cluster.token";
        extraConfig = "debug=true";
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
        agentUser
      ];

      launchd.daemons.buildkite-agent-macos.serviceConfig.ProcessType = lib.mkForce "Standard";

      # nix-darwin only runs hardcoded activation scripts (users, launchd,
      # postActivation, …). Custom script names are ignored; use postActivation
      # (after users) so buildkite-agent-macos exists before chgrp/chown.
      system.activationScripts.postActivation.text = lib.mkAfter ''
        agent_home=${agentHome}
        mkdir -p "$agent_home/builds"
        chown -R ${agentUser}:${agentUser} "$agent_home"
        chmod 755 "$agent_home"
        chmod 755 "$agent_home/builds"

        mkdir -p /etc/buildkite-agent
        chmod 755 /etc/buildkite-agent
        if [ -f /etc/buildkite-agent/cluster.token ]; then
          chown root:${agentUser} /etc/buildkite-agent/cluster.token
          chmod 640 /etc/buildkite-agent/cluster.token
        fi

        launchctl kickstart -k system/org.nixos.buildkite-agent-macos 2>/dev/null || true
        launchctl kickstart -k system/org.nixos.buildkite-token-sync 2>/dev/null || true
      '';

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
        environment = {
          HOME = "/var/root";
        };
        script = ''
          set -euo pipefail
          token=/etc/buildkite-agent/cluster.token
          if [ ! -f "$token" ]; then
            echo "buildkite cluster token missing at $token" >&2
            exit 1
          fi
          until ${linuxBuilderSsh} linux-builder true 2>/dev/null; do
            echo "waiting for linux-builder…" >&2
            sleep 5
          done
          tmp=$(mktemp /tmp/buildkite-cluster.token.XXXXXX)
          cp "$token" "$tmp"
          chmod 600 "$tmp"
          ${linuxBuilderScp} -q "$tmp" linux-builder:/tmp/buildkite-cluster.token
          rm -f "$tmp"
          if ! ${linuxBuilderSsh} linux-builder sudo ${toString installBuildkiteClusterToken} /tmp/buildkite-cluster.token; then
            echo "token install in linux-builder failed — run: sudo darwin-rebuild switch --flake .#mac-mini" >&2
            exit 1
          fi
          echo "token synced to linux-builder at $(date)"
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
