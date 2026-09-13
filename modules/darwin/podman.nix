{ ... }: {
  # Podman on macOS for Linux containers (Buildkite docker plugin on mac-mini-macos).
  #
  # Rootless Podman is incompatible with the Buildkite agent: the API socket lives
  # under the primary user's /var/folders temp dir, which buildkite-agent-macos
  # cannot reach. Requires rootful mode plus a root launchd job that symlinks
  # /var/run/docker.sock for docker API compat.
  flake.modules.darwin.podman = { config, lib, pkgs, ... }:
    let
      primaryUser = config.system.primaryUser;
      agentUser = "buildkite-agent-macos";
      podman = pkgs.podman;
      scriptPath = lib.makeBinPath [
        podman
        pkgs.coreutils
        pkgs.gnugrep
      ];

      dockerCompat = pkgs.runCommand "${podman.pname}-docker-compat-${podman.version}"
        {
          nativeBuildInputs = [ pkgs.installShellFiles ];
          outputs = [ "out" "man" ];
          inherit (podman) meta;
          preferLocalBuild = true;
        }
        ''
          mkdir -p $out/bin
          ln -s ${podman}/bin/podman $out/bin/docker

          mkdir -p $man/share/man/man1
          for f in ${podman.man}/share/man/man1/*; do
            basename=$(basename "$f" | sed s/podman/docker/g)
            ln -s "$f" "$man/share/man/man1/$basename"
          done
        '';

      podmanMachineEnsure = pkgs.writeShellScript "podman-machine-ensure" ''
        set -euo pipefail
        export PATH="${scriptPath}:$PATH"

        primaryUser="${primaryUser}"
        home="/Users/${primaryUser}"
        machine=podman-machine-default
        podman="${podman}/bin/podman"
        sudo="/usr/bin/sudo"

        podman_as_user() {
          "$sudo" -u "$primaryUser" env HOME="$home" PATH="${scriptPath}:$PATH" "$podman" "$@"
        }

        if ! podman_as_user machine inspect "$machine" >/dev/null 2>&1; then
          echo "ERROR: podman machine '$machine' missing — run once as $primaryUser:" >&2
          echo "  podman machine init --rootful $machine" >&2
          exit 1
        fi

        rootful="$(podman_as_user machine inspect "$machine" --format '{{.Rootful}}' 2>/dev/null || echo false)"
        if [ "$rootful" != "true" ]; then
          state="$(podman_as_user machine inspect "$machine" --format '{{.State}}' 2>/dev/null || echo unknown)"
          if [ "$state" = "running" ]; then
            echo "ERROR: $machine is rootless (Rootful=false). Stop it, then run once as $primaryUser:" >&2
            echo "  podman machine stop $machine && podman machine set --rootful $machine" >&2
            exit 1
          fi
          echo "Converting $machine to rootful mode..."
          podman_as_user machine set --rootful "$machine"
        fi

        state="$(podman_as_user machine inspect "$machine" --format '{{.State}}' 2>/dev/null || echo stopped)"
        if [ "$state" != "running" ]; then
          podman_as_user machine start "$machine"
        fi

        sock=""
        for _ in $(seq 1 30); do
          sock="$(podman_as_user machine inspect "$machine" --format '{{.ConnectionInfo.PodmanSocket.Path}}' 2>/dev/null || true)"
          if [ -n "$sock" ] && [ -S "$sock" ]; then
            break
          fi
          sleep 1
        done

        if [ -z "$sock" ] || [ ! -S "$sock" ]; then
          echo "ERROR: Podman API socket not found (ConnectionInfo.PodmanSocket.Path)" >&2
          exit 1
        fi

        mkdir -p /var/run
        # Force-replace Docker Desktop (or stale) symlink every run.
        ln -sf "$sock" /var/run/docker.sock
        chgrp docker "$sock" /var/run/docker.sock
        chmod 660 "$sock"

        echo "podman $machine running (rootful); /var/run/docker.sock -> $sock"
      '';
    in
    {
      environment.systemPackages = [
        podman
        dockerCompat
      ];

      users.knownGroups = lib.mkAfter [ "docker" ];
      users.groups.docker = {
        gid = lib.mkDefault 537;
        members = [ primaryUser agentUser ];
      };

      # Root launchd: podman machine is owned by primaryUser, but /var/run/docker.sock
      # must be writable only by root. Runs at boot without a login session.
      launchd.daemons.podman-machine = {
        path = with pkgs; [ podman coreutils gnugrep ];
        script = "${podmanMachineEnsure}";
        serviceConfig = {
          RunAtLoad = true;
          StartInterval = 300;
          KeepAlive = {
            SuccessfulExit = false;
          };
          StandardOutPath = "/var/log/podman-machine.log";
          StandardErrorPath = "/var/log/podman-machine.log";
        };
      };

      system.activationScripts.postActivation.text = lib.mkAfter ''
        launchctl kickstart -k system/org.nixos.podman-machine 2>/dev/null || true
      '';
    };
}
