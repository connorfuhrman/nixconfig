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
      # to /private/var on Darwin — keep the /private path the live host has.
      agentHome = "/private/var/lib/${agentUser}";
      # Checkout on applehv /Users virtiofs so docker -v $PWD works. Do not
      # put checkout under /var/lib (/private/var on Darwin): guest ls/umount
      # of that path hangs the share, and nested virtiofs tags are unused.
      # Must match modules/darwin/podman.nix agentCheckoutRoot. ExtraConfig
      # build-path last-wins over nix-darwin's dataDir/builds.
      agentCheckout = "/Users/Shared/${agentUser}";
      originSshKey = "${agentHome}/.ssh/origin_cursor";
      sshConfigSource = ./buildkite/ssh_config;
      knownHostsSource = ./buildkite/known_hosts;
      postActivationBody = builtins.replaceStrings
        [
          "@agentHome@"
          "@agentCheckout@"
          "@agentUser@"
          "@sshConfigSource@"
          "@knownHostsSource@"
          "@originSshKey@"
        ]
        [
          agentHome
          agentCheckout
          agentUser
          "${sshConfigSource}"
          "${knownHostsSource}"
          originSshKey
        ]
        (builtins.readFile ./buildkite/post-activation.sh);
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
        # HOME so job bootstrap runs git/nix as the agent user. GitHub checkout
        # uses Buildkite's GitHub App credential helper (queue setting) — do not
        # set GIT_CONFIG_GLOBAL or GIT_SSH_COMMAND; do not manage ~/.gitconfig.
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
      # ~/.gitconfig: Buildkite's GitHub App helper writes it — create empty only
      # if missing (never install from the Nix store or set GIT_CONFIG_GLOBAL).
      # ~/.ssh: Origin-only config + pinned known_hosts; do not touch origin_cursor.
      system.activationScripts.postActivation.text = lib.mkAfter postActivationBody;
    };
}