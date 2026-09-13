{ ... }: {
  flake.modules.darwin.buildkite = { config, lib, pkgs, ... }:
    let
      agentUser = "buildkite-agent-macos";
      agentHome = "/var/lib/${agentUser}";
      originSshKey = "${agentHome}/.ssh/origin_cursor";
      # Public only — private key is installed by
      # `nix run .#mac-mini-buildkite-install-origin-ssh`, never the Nix store.
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

      services.buildkite-agents.macos = {
        tokenPath = "/etc/buildkite-agent/cluster.token";
        # Unix sockets cannot ride virtiofs. docker-buildkite-plugin bind-mounts
        # BUILDKITE_AGENT_JOB_API_SOCKET when set; agent 3.129 overwrites an
        # empty step env. Disable Job API on this Darwin agent so every pipeline
        # can use docker# without a per-step hack.
        extraConfig = ''
          debug=true
          plugins-path="${agentHome}/plugins"
          job-api=false
        '';
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
          pkgs.podman
        ];
      };

      nix.settings.trusted-users = [
        "connorfuhrman"
        agentUser
      ];

      launchd.daemons.buildkite-agent-macos = {
        environment.DOCKER_HOST = "unix:///var/run/docker.sock";
        # Podman honors CONTAINER_HOST, not DOCKER_HOST.
        environment.CONTAINER_HOST = "unix:///var/run/docker.sock";
        # insteadOf HTTPS Origin clones → SSH. Store path is public (no secrets).
        environment.GIT_CONFIG_GLOBAL = "${originGitconfig}";
        environment.GIT_SSH_COMMAND = "ssh -i ${originSshKey} -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${originKnownHosts}";
        serviceConfig.ProcessType = lib.mkForce "Standard";
      };

      # nix-darwin only runs hardcoded activation scripts (users, launchd,
      # postActivation, …). Custom script names are ignored; use postActivation
      # (after users) so buildkite-agent-macos exists before chgrp/chown.
      system.activationScripts.postActivation.text = lib.mkAfter ''
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

        launchctl kickstart -k system/org.nixos.buildkite-agent-macos 2>/dev/null || true
      '';
    };
}
