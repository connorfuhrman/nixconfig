{ ... }: {
  flake.modules.darwin.buildkite = { config, lib, pkgs, ... }:
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
      # Agent-global environment hook: runs before checkout (repo hooks are not).
      dockerEnvironmentHook = pkgs.writeShellScript "buildkite-docker-environment" (
        builtins.readFile ../../.buildkite/hooks/environment
      );
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
          hooks-path="${agentCheckout}/hooks"
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
          pkgs.podman-docker-compat
        ];
      };

      nix.settings.trusted-users = [
        "connorfuhrman"
        agentUser
      ];

      # build #129/#137: installer steps restart linux-builder after ENOSPC crashes.
      # nix-darwin exposes security.sudo.extraConfig (not NixOS extraRules).
      security.sudo.extraConfig = lib.mkAfter ''
        ${agentUser} ALL = (ALL) NOPASSWD: /bin/launchctl kickstart -k system/org.nixos.linux-builder
        ${agentUser} ALL = (ALL) NOPASSWD: /bin/launchctl kickstart system/org.nixos.linux-builder
        ${agentUser} ALL = (ALL) NOPASSWD: /usr/bin/launchctl kickstart -k system/org.nixos.linux-builder
        ${agentUser} ALL = (ALL) NOPASSWD: /usr/bin/launchctl kickstart system/org.nixos.linux-builder
      '';

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
        mkdir -p "$checkout/builds" "$checkout/plugins" "$checkout/hooks"
        install -m 755 ${dockerEnvironmentHook} "$checkout/hooks/environment"
        chown -R ${agentUser}:${agentUser} "$agent_home"
        chown -R ${agentUser}:docker "$checkout"
        chmod 755 "$agent_home"
        chmod 755 "$checkout"
        chmod 755 "$checkout/builds"
        chmod 755 "$checkout/plugins"
        chmod 755 "$checkout/hooks"
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

        # build #122: buildkite-agent-macos could not read /etc/nix/builder_ed25519
        # (platform mismatch for aarch64-linux installer builds via linux-builder).
        if [ -f /etc/nix/builder_ed25519 ]; then
          chown root:${agentUser} /etc/nix/builder_ed25519
          chmod 640 /etc/nix/builder_ed25519
        fi

        launchctl kickstart -k system/org.nixos.buildkite-agent-macos 2>/dev/null || true
      '';
    };
}
