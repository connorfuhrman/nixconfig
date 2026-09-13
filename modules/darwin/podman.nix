{ ... }: {
  # Podman on macOS for Linux containers (Buildkite docker plugin on mac-mini-macos).
  #
  # The machine API socket lives under the primary user's 700 TMPDIR, which
  # buildkite-agent-macos cannot traverse. Rootful mode plus a root socat proxy
  # on /var/run/docker.sock (660, group docker) is the agent-visible path.
  flake.modules.darwin.podman = { config, lib, pkgs, ... }:
    let
      primaryUser = config.system.primaryUser;
      agentUser = "buildkite-agent-macos";
      podman = pkgs.podman;
      dockerCompat = pkgs.podman-docker-compat;
      dockerGid = toString config.users.groups.docker.gid;
      # 10 GiB: mac-mini is 16 GiB, linux-builder is already 8 GiB, and a full
      # `nix flake check` in a Linux VM needs ~8 GiB RSS (emacs overlay unpack).
      # Idle builder pages compress, so a second full 8 GiB VM is unnecessary.
      desiredMemoryMiB = "10240";
      # Must match modules/darwin/buildkite.nix agentCheckout / build-path.
      # Agent home stays /private/var/lib/buildkite-agent-macos (nix-darwin
      # will not move an existing user). applehv virtiofs-shares /Users by
      # default, so docker run -v $PWD works at this checkout with no guest
      # symlink. Do not add a nested virtiofs of /private/var or this path:
      # guest ls/umount of /private/var/lib hangs the share, and extra tags
      # are not mounted by the guest.
      agentCheckoutRoot = "/Users/Shared/buildkite-agent-macos";
      oldCheckoutRoot = "/var/lib/buildkite-agent-macos";
      agentHome = "/private/var/lib/buildkite-agent-macos";
      scriptPath = lib.makeBinPath [
        podman
        pkgs.coreutils
        pkgs.gnugrep
      ] + ":/usr/bin";

      volumeEnsurePy = pkgs.writeText "podman-machine-ensure-volumes.py" (
        builtins.readFile ./_podman/ensure-volumes.py
      );

      podmanMachineEnsure = pkgs.writeShellScript "podman-machine-ensure" (
        builtins.readFile (pkgs.replaceVars ./_podman/machine-ensure.sh {
          inherit
            scriptPath
            primaryUser
            desiredMemoryMiB
            agentCheckoutRoot
            oldCheckoutRoot
            agentHome
            ;
          podman = "${podman}/bin/podman";
          volumeEnsurePy = "${volumeEnsurePy}";
          python3 = "${pkgs.python3}/bin/python3";
        })
      );

      podmanDockerProxy = pkgs.writeShellScript "podman-docker-proxy" (
        builtins.readFile (pkgs.replaceVars ./_podman/docker-proxy.sh {
          inherit dockerGid;
          socat = "${pkgs.socat}/bin/socat";
        })
      );
    in
    {
      environment.systemPackages = [
        podman
        dockerCompat
      ];

      # nix-darwin's buildkite module sets launchd PATH from runtimePackages
      # only — not /run/current-system/sw/bin. The docker plugin execs `docker`.
      services.buildkite-agents.macos.runtimePackages = [ dockerCompat ];

      users.knownGroups = lib.mkAfter [ "docker" ];
      users.groups.docker = {
        gid = lib.mkDefault 537;
        members = [ primaryUser agentUser ];
      };

      # Root launchd: machine is owned by primaryUser; the proxy listen sock is
      # root:docker so the agent never opens the 700 TMPDIR path.
      launchd.daemons.podman-machine = {
        path = with pkgs; [ podman coreutils gnugrep ];
        script = "${podmanMachineEnsure}";
        serviceConfig = {
          RunAtLoad = true;
          StartInterval = 300;
          KeepAlive = {
            SuccessfulExit = false;
          };
          # `podman machine start` leaves vfkit+gvproxy in this job's process
          # group. Without AbandonProcessGroup, launchd SIGTERMs them when the
          # one-shot ensure exits 0.
          AbandonProcessGroup = true;
          StandardOutPath = "/var/log/podman-machine.log";
          StandardErrorPath = "/var/log/podman-machine.log";
        };
      };

      launchd.daemons.podman-docker-proxy = {
        path = with pkgs; [ coreutils socat ];
        script = "${podmanDockerProxy}";
        serviceConfig = {
          RunAtLoad = true;
          KeepAlive = {
            SuccessfulExit = false;
          };
          StandardOutPath = "/var/log/podman-docker-proxy.log";
          StandardErrorPath = "/var/log/podman-docker-proxy.log";
        };
      };

      system.activationScripts.postActivation.text = lib.mkAfter ''
        launchctl kickstart -k system/org.nixos.podman-machine 2>/dev/null || true
        launchctl kickstart -k system/org.nixos.podman-docker-proxy 2>/dev/null || true
      '';
    };
}
