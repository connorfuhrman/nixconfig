{ ... }: {
  flake.modules.darwin.buildkite =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      agentUser = "buildkite-agent-macos";
      # Existing dscl home. nix-darwin will not change it. /var is a symlink
      # to /private/var on Darwin — keep the /private path the live user has.
      agentHome = "/private/var/lib/${agentUser}";
      # Checkout on applehv /Users virtiofs so docker -v $PWD works. Do not
      # put checkout under /var/lib (/private/var on Darwin): guest ls/umount
      # of that path hangs the share, and nested virtiofs tags are unused.
      # Must match modules/darwin/podman.nix agentCheckoutRoot. ExtraConfig
      # build-path last-wins over nix-darwin's dataDir/builds.
      agentCheckout = "/Users/Shared/${agentUser}";
      githubSshKey = "${agentHome}/.ssh/github_buildkite";
      originSshKey = "${agentHome}/.ssh/origin_cursor";
      agentKnownHostsPath = "${agentHome}/.ssh/known_hosts";
      # Public only — private keys at githubSshKey / originSshKey are runtime
      # files installed by `nix run .#mac-mini-buildkite-install-ssh`.
      originGitconfig = pkgs.writeText "buildkite-agent-gitconfig" ''
        [url "git@origin.cursor.com:"]
        	insteadOf = https://origin.cursor.com/git/
      '';
      # GitHub host keys: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
      agentKnownHosts = pkgs.writeText "buildkite-agent-ssh-known-hosts" ''
        github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
        github.com ecdsa-sha2-nistp256 AAAAE2VjZHZhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87vR0dfdUVN7TZrl7U43MNB3eRlG66F7tYB3dFhdpmxv5c=
        github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7bn1qTs9+Yc092s3G58IO6T9goTXyB3wEEA1t8QPLp0LVYNh3krxNLYlEo2bni0ejDvB2aDjK/GxQWo0cXAVrQMCNvxfx4v1C4FrRsuB9m7pKncM58MZt4J549yghChIKyCVMPfLYPdJRslqavTqupSZdxNnC7Y82oPbvl3r6Tpgsqu7JgEFg+grdbjjT0ROAJ6VAO7S8lKQ9WJN0x4x/Gb6IVh2jf+4+0H1giatIu8ZKUfQttXrT9WgYWw==
        origin.cursor.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFaMKo6HCtmngBwlSH2ATs8+A6eTr+cCON5RKZX/3/MO
      '';
      agentSshConfig = pkgs.writeText "buildkite-agent-ssh-config" ''
        # Managed by nix-darwin (modules/darwin/buildkite.nix). Identity files
        # are runtime secrets — install with mac-mini-buildkite-install-ssh.
        Host github.com
          User git
          IdentityFile ${githubSshKey}
          IdentitiesOnly yes
          StrictHostKeyChecking yes
          UserKnownHostsFile ${agentKnownHostsPath}

        Host origin.cursor.com
          User git
          IdentityFile ${originSshKey}
          IdentitiesOnly yes
          StrictHostKeyChecking yes
          UserKnownHostsFile ${agentKnownHostsPath}
      '';
      installRuntimeSshKeyPerms = keyPath: ''
        if [ -f ${keyPath} ]; then
          chown ${agentUser}:${agentUser} ${keyPath}
          chmod 600 ${keyPath}
        fi
        if [ -f ${keyPath}.pub ]; then
          chown ${agentUser}:${agentUser} ${keyPath}.pub
          chmod 644 ${keyPath}.pub
        fi
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
        # Darwin jobs; higher spawn oversubscribes RAM when jobs also use the
        # builder or Podman Machine (~10 GiB).
        # Unix sockets cannot ride virtiofs. docker-buildkite-plugin bind-mounts
        # BUILDKITE_AGENT_JOB_API_SOCKET when that env is set, so Job API is
        # disabled agent-wide: bootstrap --no-job-api plus launchd
        # BUILDKITE_AGENT_NO_JOB_API. `job-api=false` is not an agent-start
        # key. nix-darwin has no commandLine option, so extraConfig
        # bootstrap-script is the switch. Do not rely on step env (agent
        # overwrites an empty BUILDKITE_AGENT_JOB_API_SOCKET).
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
        # No GIT_SSH_COMMAND: HOME points at the agent home so git/OpenSSH read
        # ~/.ssh/config and per-host IdentityFile entries (GitHub + Origin).
        environment.HOME = agentHome;
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
        install -m 644 -o ${agentUser} -g ${agentUser} ${agentSshConfig} "$agent_home/.ssh/config"
        install -m 644 -o ${agentUser} -g ${agentUser} ${agentKnownHosts} "$agent_home/.ssh/known_hosts"
        ${installRuntimeSshKeyPerms githubSshKey}
        ${installRuntimeSshKeyPerms originSshKey}

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