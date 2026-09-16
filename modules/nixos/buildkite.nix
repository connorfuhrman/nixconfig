{ ... }: {
  flake.modules.nixos.buildkite = { pkgs, ... }:
    let
      agentUser = "buildkite-agent-linux";
      agentHome = "/var/lib/${agentUser}";
      originSshKey = "${agentHome}/.ssh/origin_cursor";
      # Public only — private key is installed by
      # `nix run .#nuc-buildkite-install-origin-ssh`, never the Nix store.
      originGitconfig = pkgs.writeText "buildkite-agent-gitconfig" ''
        [url "git@origin.cursor.com:"]
        	insteadOf = https://origin.cursor.com/git/
      '';
      originSshConfig = pkgs.writeText "buildkite-agent-ssh-config" ''
        Host origin.cursor.com
          User git
          IdentityFile ${originSshKey}
          IdentitiesOnly yes
          StrictHostKeyChecking yes
          UserKnownHostsFile ${agentHome}/.ssh/known_hosts
      '';
      originKnownHosts = pkgs.writeText "buildkite-agent-ssh-known-hosts" ''
        origin.cursor.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFaMKo6HCtmngBwlSH2ATs8+A6eTr+cCON5RKZX/3/MO
      '';
    in
    {
      services.buildkite-agents.linux = {
        enable = true;
        tokenPath = "/etc/buildkite-agent/cluster.token";
        # Buildkite requires %spawn in the name when spawn>1 shares build-path.
        # Default is "%hostname-linux-%n"; %n is not the spawn index.
        name = "%hostname-linux-%spawn";
        # No linux-builder VM on this host, so RAM is all for jobs. spawn=2
        # matches mac-mini until hardware RAM is confirmed; raise later.
        extraConfig = ''
          debug=true
          plugins-path="${agentHome}/plugins"
          spawn=2
        '';
        tags = {
          queue = "nuc-linux";
          os = "linux";
          arch = "x86_64";
          nixos = "true";
        };
        runtimePackages = [
          pkgs.nix
          pkgs.git
          pkgs.bash
          pkgs.coreutils
          pkgs.gnutar
          pkgs.gzip
          pkgs.openssh
        ];
      };

      nix.settings.trusted-users = [
        "connorfuhrman"
        agentUser
      ];

      systemd.services.buildkite-agent-linux.environment = {
        GIT_CONFIG_GLOBAL = "${originGitconfig}";
        GIT_SSH_COMMAND = "ssh -i ${originSshKey} -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${originKnownHosts}";
      };

      # After users exist: agent workdir, Origin git/ssh files, token mode.
      system.activationScripts.buildkite-agent-linux = {
        deps = [ "users" "groups" ];
        text = ''
          agent_home=${agentHome}
          mkdir -p "$agent_home/builds" "$agent_home/plugins" "$agent_home/.ssh"
          chown -R ${agentUser}:${agentUser} "$agent_home"
          chmod 755 "$agent_home"
          chmod 755 "$agent_home/builds"
          chmod 755 "$agent_home/plugins"
          chmod 700 "$agent_home/.ssh"
          install -m 644 -o ${agentUser} -g ${agentUser} ${originGitconfig} "$agent_home/.gitconfig"
          install -m 644 -o ${agentUser} -g ${agentUser} ${originSshConfig} "$agent_home/.ssh/config"
          install -m 644 -o ${agentUser} -g ${agentUser} ${originKnownHosts} "$agent_home/.ssh/known_hosts"
          if [ -f ${originSshKey} ]; then
            chown ${agentUser}:${agentUser} ${originSshKey}
            chmod 600 ${originSshKey}
          fi
          if [ -f ${originSshKey}.pub ]; then
            chown ${agentUser}:${agentUser} ${originSshKey}.pub
            chmod 644 ${originSshKey}.pub
          fi

          mkdir -p /etc/buildkite-agent
          chmod 755 /etc/buildkite-agent
          if [ -f /etc/buildkite-agent/cluster.token ]; then
            chown root:${agentUser} /etc/buildkite-agent/cluster.token
            chmod 640 /etc/buildkite-agent/cluster.token
          fi
        '';
      };
    };
}
