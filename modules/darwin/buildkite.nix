{ ... }: {
  flake.modules.darwin.buildkite = { config, lib, pkgs, ... }:
    let
      agentUser = "buildkite-agent-macos";
      agentHome = "/var/lib/${agentUser}";
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
        extraConfig = ''
          debug=true
          plugins-path="${agentHome}/plugins"
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
        serviceConfig.ProcessType = lib.mkForce "Standard";
      };

      # nix-darwin only runs hardcoded activation scripts (users, launchd,
      # postActivation, …). Custom script names are ignored; use postActivation
      # (after users) so buildkite-agent-macos exists before chgrp/chown.
      system.activationScripts.postActivation.text = lib.mkAfter ''
        agent_home=${agentHome}
        mkdir -p "$agent_home/builds" "$agent_home/plugins"
        chown -R ${agentUser}:${agentUser} "$agent_home"
        chmod 755 "$agent_home"
        chmod 755 "$agent_home/builds"
        chmod 755 "$agent_home/plugins"

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
