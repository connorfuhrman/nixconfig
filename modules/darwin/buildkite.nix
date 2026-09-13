{ ... }: {
  flake.modules.darwin.buildkite = { config, lib, pkgs, ... }:
    let
      agentUser = "buildkite-agent-macos";
      # Existing dscl home. nix-darwin will not change it. /var is a symlink
      # to /private/var on Darwin — keep the /private path the live user has.
      agentHome = "/private/var/lib/${agentUser}";
      # Checkout on applehv /Users virtiofs so docker -v $PWD works. /private
      # virtiofs of the home wedges on guest ls/umount; nested virtiofs of
      # /var/lib/... kills vfkit. Must match modules/darwin/podman.nix
      # agentCheckoutRoot. ExtraConfig build-path last-wins over nix-darwin's
      # dataDir/builds.
      agentCheckout = "/Users/Shared/${agentUser}";
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
        home = agentHome;
        # createhomedir fails on /var/lib (errno 62); postActivation creates dirs.
        createHome = lib.mkForce false;
      };

      services.buildkite-agents.macos = {
        dataDir = agentHome;
        tokenPath = "/etc/buildkite-agent/cluster.token";
        # Buildkite requires %spawn in the name when spawn>1 shares build-path.
        # Default is "%hostname-macos-%n"; %n is not the spawn index.
        name = "%hostname-macos-%spawn";
        # Host is 16 GiB; linux-builder is ~8 GiB. spawn=2 is two concurrent
        # Darwin jobs; 4+ oversubscribes RAM if those jobs also use the builder
        # (or Podman Machine, once that lands).
        # Unix sockets cannot ride virtiofs. docker-buildkite-plugin v5.14.0
        # bind-mounts BUILDKITE_AGENT_JOB_API_SOCKET when set
        # (`[[ -n "${BUILDKITE_AGENT_JOB_API_SOCKET:-}" ]]`). Agent 3.129
        # overwrites an empty step env and always starts Job API unless
        # bootstrap gets --no-job-api. `job-api=false` is NOT an agent-start
        # key (live cfg had it; Job API still ran). nix-darwin has no
        # commandLine option — extraConfig bootstrap-script + launchd
        # BUILDKITE_AGENT_NO_JOB_API is the agent-level disable.
        extraConfig = ''
          debug=true
          plugins-path="${agentCheckout}/plugins"
          build-path="${agentCheckout}/builds"
          spawn=2
          bootstrap-script="${config.services.buildkite-agents.macos.package}/bin/buildkite-agent bootstrap --no-job-api"
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
        # insteadOf HTTPS Origin clones → SSH. Store path is public (no secrets).
        environment.GIT_CONFIG_GLOBAL = "${originGitconfig}";
        environment.GIT_SSH_COMMAND = "ssh -i ${originSshKey} -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${originKnownHosts}";
        environment.DOCKER_HOST = "unix:///var/run/docker.sock";
        # Podman honors CONTAINER_HOST, not DOCKER_HOST.
        environment.CONTAINER_HOST = "unix:///var/run/docker.sock";
        # Bootstrap EnvVar for --no-job-api (inherited via os.Environ()).
        environment.BUILDKITE_AGENT_NO_JOB_API = "true";
        serviceConfig.ProcessType = lib.mkForce "Standard";
      };

      # nix-darwin only runs hardcoded activation scripts (users, launchd,
      # postActivation, …). Custom script names are ignored; use postActivation
      # (after users) so buildkite-agent-macos exists before chgrp/chown.
      system.activationScripts.postActivation.text = lib.mkAfter ''
        agent_home=${agentHome}
        checkout=${agentCheckout}
        mkdir -p "$agent_home/.ssh"
        mkdir -p "$checkout/builds" "$checkout/plugins"
        chown -R ${agentUser}:${agentUser} "$agent_home"
        chown -R ${agentUser}:docker "$checkout"
        chmod 755 "$agent_home"
        chmod 755 "$checkout"
        chmod 755 "$checkout/builds"
        chmod 755 "$checkout/plugins"
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
