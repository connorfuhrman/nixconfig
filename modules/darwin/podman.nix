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
      dockerGid = toString config.users.groups.docker.gid;
      # mac-mini is 16 GiB; linux-builder is already 8 GiB. Build 67's
      # nixos/nix:2.28.2 flake-check OOM-killed nix at ~7.4 GiB RSS (emacs
      # overlay unpack) inside an 8096 MiB machine — 4–6 GiB would still
      # SIGKILL 137. 10 GiB is the bump that can finish eval without adding
      # another full 8 GiB VM on a 16 GiB host (idle builder pages compress).
      desiredMemoryMiB = "10240";
      # Must match modules/darwin/buildkite.nix agentHome. applehv already
      # virtiofs-shares /private; Darwin /var is a symlink into that tree, so
      # the checkout is in the guest at /private/var/lib/buildkite-agent-macos.
      # docker-buildkite-plugin bind-mounts $PWD; the Linux engine statfs's
      # /var/lib/buildkite-agent-macos inside the VM — a guest symlink makes
      # that Darwin path real. Do not add a second virtiofs of this path:
      # it nests inside the /private share, CoreOS never mounts the extra tag,
      # and vfkit has been exiting seconds after start with that device.
      agentCheckoutRoot = "/var/lib/buildkite-agent-macos";
      # podman machine ssh exec's `ssh` from PATH. Launchd's default PATH is
      # only the nix bins below; without openssh the guest checkout symlink
      # exits 127 and KeepAlive crash-loops.
      scriptPath = lib.makeBinPath [
        podman
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.openssh
      ] + ":/usr/bin";

      # Drop nested virtiofs sources from applehv JSON (applied only while stopped).
      volumeEnsurePy = pkgs.writeText "podman-machine-ensure-volumes.py" ''
        import json
        import os
        import sys

        def load(path):
            with open(path, encoding="utf-8") as fh:
                return json.load(fh)

        def save(path, cfg):
            tmp = path + ".tmp"
            with open(tmp, "w", encoding="utf-8") as fh:
                json.dump(cfg, fh, separators=(",", ":"))
                fh.write("\n")
            os.replace(tmp, path)

        def extra_sources(cfg, sources):
            drop = set(sources)
            return [m.get("Source") for m in (cfg.get("Mounts") or []) if m.get("Source") in drop]

        def prune(path, sources):
            cfg = load(path)
            drop = set(sources)
            mounts = cfg.get("Mounts") or []
            kept = [m for m in mounts if m.get("Source") not in drop]
            if len(kept) == len(mounts):
                print("unchanged")
                return 0
            cfg["Mounts"] = kept
            save(path, cfg)
            print("changed")
            return 0

        def main(argv):
            if len(argv) < 4:
                print("usage: ensure-volumes.py --status|--prune JSON SOURCE...", file=sys.stderr)
                return 1
            mode, path = argv[1], argv[2]
            sources = argv[3:]
            if mode == "--status":
                extra = extra_sources(load(path), sources)
                print("needed" if extra else "unchanged")
                return 0
            if mode == "--prune":
                return prune(path, sources)
            print("unknown mode {}".format(mode), file=sys.stderr)
            return 1

        if __name__ == "__main__":
            sys.exit(main(sys.argv))
      '';

      dockerWrapper = pkgs.writeShellScript "docker-via-podman" ''
        export DOCKER_HOST="''${DOCKER_HOST:-unix:///var/run/docker.sock}"
        export CONTAINER_HOST="''${CONTAINER_HOST:-unix:///var/run/docker.sock}"
        exec ${podman}/bin/podman "$@"
      '';

      dockerCompat = pkgs.runCommand "${podman.pname}-docker-compat-${podman.version}"
        {
          nativeBuildInputs = [ pkgs.installShellFiles ];
          outputs = [ "out" "man" ];
          inherit (podman) meta;
          preferLocalBuild = true;
        }
        ''
          mkdir -p $out/bin
          ln -s ${dockerWrapper} $out/bin/docker

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
        getconf="/usr/bin/getconf"

        # sudo(8) drops the login-session TMPDIR; podman then reports
        # /tmp/podman/... while the real socket lives under /var/folders/.../T/.
        userTmpDir="$("$sudo" -u "$primaryUser" "$getconf" DARWIN_USER_TEMP_DIR)"

        as_user() {
          "$sudo" -u "$primaryUser" env HOME="$home" TMPDIR="$userTmpDir" PATH="${scriptPath}:$PATH" "$@"
        }

        podman_as_user() {
          as_user "$podman" "$@"
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

        desiredMemory="${desiredMemoryMiB}"
        currentMemory="$(podman_as_user machine inspect "$machine" --format '{{.Resources.Memory}}' 2>/dev/null || echo 0)"
        state="$(podman_as_user machine inspect "$machine" --format '{{.State}}' 2>/dev/null || echo stopped)"
        if [ "$currentMemory" != "$desiredMemory" ]; then
          echo "Podman machine memory $currentMemory MiB -> $desiredMemory MiB"
          # applehv applies --memory only when the VM is stopped.
          if [ "$state" = "running" ]; then
            podman_as_user machine stop "$machine"
            state=stopped
          fi
          podman_as_user machine set --memory "$desiredMemory" "$machine"
        fi

        # Same-path checkout: prune any nested virtiofs of $checkoutRoot, then
        # symlink it in the guest onto the existing /private share.
        checkoutRoot="${agentCheckoutRoot}"
        mkdir -p "$checkoutRoot"
        jsonPath="$(podman_as_user machine inspect "$machine" --format '{{.ConfigDir.Path}}')/$machine.json"
        volumePy="${volumeEnsurePy}"
        python="${pkgs.python3}/bin/python3"
        vol_status="$(as_user "$python" "$volumePy" --status "$jsonPath" "$checkoutRoot")"
        if [ "$vol_status" = "needed" ]; then
          echo "Podman machine virtiofs: dropping nested $checkoutRoot (covered by /private)"
          if [ "$state" = "running" ]; then
            podman_as_user machine stop "$machine"
            state=stopped
          fi
          as_user "$python" "$volumePy" --prune "$jsonPath" "$checkoutRoot"
        fi

        if [ "$state" = "starting" ]; then
          echo "Podman machine already starting; waiting"
        elif [ "$state" != "running" ]; then
          podman_as_user machine start "$machine" || true
        fi
        for _ in $(seq 1 60); do
          state="$(podman_as_user machine inspect "$machine" --format '{{.State}}' 2>/dev/null || echo stopped)"
          if [ "$state" = "running" ]; then
            break
          fi
          sleep 1
        done

        resolve_sock() {
          local candidate=""

          candidate="$(podman_as_user machine inspect "$machine" --format '{{.ConnectionInfo.PodmanSocket.Path}}' 2>/dev/null || true)"
          if [ -n "$candidate" ] && [ -S "$candidate" ]; then
            echo "$candidate"
            return 0
          fi

          candidate="$userTmpDir/podman/$machine-api.sock"
          if [ -S "$candidate" ]; then
            echo "$candidate"
            return 0
          fi

          candidate="$(find "$userTmpDir" /var/folders "$home/.local/share/containers/podman/machine" \
            -name "$machine-api.sock" -type s 2>/dev/null | head -n1 || true)"
          if [ -n "$candidate" ] && [ -S "$candidate" ]; then
            echo "$candidate"
            return 0
          fi

          return 1
        }

        sock=""
        for _ in $(seq 1 30); do
          sock="$(resolve_sock || true)"
          if [ -n "$sock" ]; then
            break
          fi
          sleep 1
        done

        if [ -z "$sock" ] || [ ! -S "$sock" ]; then
          echo "ERROR: Podman API socket not found (ConnectionInfo, TMPDIR, or find)" >&2
          exit 1
        fi

        mkdir -p /var/run
        target_file=/var/run/podman-api.target
        prev_file=/var/run/podman-api.target.prev
        listen=/var/run/docker.sock
        printf '%s\n' "$sock" > "$target_file"
        chgrp docker "$sock" 2>/dev/null || true
        chmod 660 "$sock" 2>/dev/null || true

        # Never leave a symlink into the 700 TMPDIR as the agent-visible path.
        # Root socat can open that sock; uid 536 cannot traverse the parents.
        need_proxy_restart=0
        if [ -L "$listen" ] || [ ! -S "$listen" ]; then
          need_proxy_restart=1
        fi
        prev=""
        if [ -f "$prev_file" ]; then
          prev="$(tr -d '\n' < "$prev_file")"
        fi
        if [ "$prev" != "$sock" ]; then
          need_proxy_restart=1
        fi

        if [ "$need_proxy_restart" = 1 ]; then
          if [ -L "$listen" ]; then
            rm -f "$listen"
          fi
          /bin/launchctl kickstart -k system/org.nixos.podman-docker-proxy 2>/dev/null || true
          printf '%s\n' "$sock" > "$prev_file"
        fi

        for _ in $(seq 1 10); do
          if [ -S "$listen" ] && [ ! -L "$listen" ]; then
            chgrp docker "$listen"
            chmod 660 "$listen"
            break
          fi
          sleep 1
        done

        # After the API is up, SSH works. Never fail the daemon here: missing
        # ssh on PATH used to exit 127, KeepAlive-restart, and race
        # `podman machine start` against a live VM. Guest symlink persists on
        # the FCOS /var disk; rmdir only an empty placeholder (never rm -rf).
        ssh_ready=0
        for _ in $(seq 1 30); do
          if podman_as_user machine ssh "$machine" -- true >/dev/null 2>&1; then
            ssh_ready=1
            break
          fi
          sleep 1
        done
        if [ "$ssh_ready" != 1 ]; then
          echo "WARNING: podman machine ssh not ready; guest checkout symlink skipped" >&2
        else
          echo "Guest: $checkoutRoot -> /private$checkoutRoot"
          guestParent="$(dirname "$checkoutRoot")"
          podman_as_user machine ssh "$machine" -- "sudo umount '$checkoutRoot' >/dev/null 2>&1 || true"
          podman_as_user machine ssh "$machine" -- "if [ -d '$checkoutRoot' ] && [ ! -L '$checkoutRoot' ]; then sudo rmdir '$checkoutRoot' || true; fi"
          podman_as_user machine ssh "$machine" -- "sudo mkdir -p '$guestParent' && sudo ln -sfn '/private$checkoutRoot' '$checkoutRoot'" || true
        fi

        echo "podman $machine running (rootful, ${desiredMemoryMiB} MiB, guest $checkoutRoot -> /private$checkoutRoot); proxy $listen -> $sock"
      '';

      podmanDockerProxy = pkgs.writeShellScript "podman-docker-proxy" ''
        set -euo pipefail
        target_file=/var/run/podman-api.target
        listen=/var/run/docker.sock
        target=""

        for _ in $(seq 1 60); do
          if [ -f "$target_file" ]; then
            target="$(tr -d '\n' < "$target_file")"
            if [ -n "$target" ] && [ -S "$target" ]; then
              break
            fi
          fi
          sleep 1
        done

        if [ -z "$target" ] || [ ! -S "$target" ]; then
          echo "ERROR: podman API target not ready ($target_file)" >&2
          exit 1
        fi

        # Drop Docker Desktop / stale symlink so we bind a real listen sock.
        rm -f "$listen"

        echo "proxy $listen -> $target"
        exec ${pkgs.socat}/bin/socat \
          UNIX-LISTEN:"$listen",fork,reuseaddr,unlink-early,mode=0660,user=root,group=${dockerGid} \
          UNIX-CONNECT:"$target"
      '';
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
        path = with pkgs; [ podman coreutils gnugrep openssh ];
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
