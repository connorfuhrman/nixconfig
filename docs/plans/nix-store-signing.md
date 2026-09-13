# Nix store-path signing (mac-mini)

Locally-built nix-darwin paths on `mac-mini` (darwin-system, `etc-machines`,
activation fragments, linux-builder artifacts) are unsigned by default.
`nix copy --from ssh-ng://mac-mini <path>` on other machines fails with:

```text
error: cannot add path '/nix/store/…'
because it lacks a signature by a trusted key
```

The fix: **mac-mini signs paths**; every machine that imports Mini-built
closures **trusts Mini's public key**. We do not disable `require-sigs` globally
or set `trusted-users = "*"`.

Modules:

| Module | Hosts | Role |
|---|---|---|
| `generic.nix-store-trust` | mac-mini, macbook, mbp14, nuc, cluster roles | Trust `mac-mini-1` public key; set `trusted-users` |
| `darwin.nix-store-sign` | mac-mini only | `nix.settings.secret-key-files` |

## One-time key generation (mac-mini only)

Run on **mac-mini** as a user who can write the secret path and rebuild:

```sh
sudo mkdir -p /etc/nix/keys
sudo chown root:wheel /etc/nix/keys
sudo chmod 755 /etc/nix/keys

nix key generate-secret --key-name mac-mini-1 \
  | sudo tee /etc/nix/keys/mac-mini-1.secret
sudo chmod 600 /etc/nix/keys/mac-mini-1.secret
sudo chown root:wheel /etc/nix/keys/mac-mini-1.secret
```

Alternative layout (`/var/lib/nix/…`) is fine if you update
`darwin.nix-store-sign` to match — keep the secret **outside** the git repo.

Extract the **public** key (safe to paste into git):

```sh
nix key convert-secret-to-public < /etc/nix/keys/mac-mini-1.secret
```

Replace the placeholder in `modules/generic/keys/mac-mini.public` with that
single line (no comments in the file), commit, and rebuild mac-mini.

**Never** commit `/etc/nix/keys/mac-mini-1.secret` or copy it off the machine.

## Rebuild mac-mini (signer)

After the public key is in the flake and the secret is on disk:

```sh
# on mac-mini — human runs darwin-rebuild; agents only eval.
sudo darwin-rebuild switch --flake .#mac-mini
```

New builds from mac-mini are signed automatically. **Existing** unsigned paths
still need a one-time recursive sign (on mac-mini):

```sh
sudo nix store sign --recursive \
  --key-file /etc/nix/keys/mac-mini-1.secret \
  /run/current-system
```

Repeat after major switches if you copy old closures, or sign specific paths:

```sh
sudo nix store sign --recursive \
  --key-file /etc/nix/keys/mac-mini-1.secret \
  /nix/store/<hash>-darwin-system-<version>
```

Agents cannot run `nix store sign` from Nix eval — this is a manual/ops step.

## Rebuild clients (trust)

Rebuild every host that imports `generic.nix-store-trust`:

- `macbook` (nix-darwin)
- `mbp14`, `nuc`, `nuc-cluster-head`, `nuc-cluster-worker`, `rpi-cluster-head` (NixOS)

```sh
# examples — human runs rebuild on each machine
sudo darwin-rebuild switch --flake .#macbook
sudo nixos-rebuild switch --flake .#mbp14
```

## Verify copy without --no-check-sigs

On **macbook** (or any trusting client), after both sides are rebuilt and
current-system on mini is signed:

```sh
nix copy --from ssh-ng://mac-mini "$(ssh mac-mini nix build .#darwinConfigurations.mac-mini.config.system.build.toplevel --no-link --print-out-paths)"
```

Should succeed **without** `--no-check-sigs`.

## Remote builder / ssh-ng notes

- `generic.mac-mini-builder` uses `protocol = "ssh-ng"`. Query params like
  `?trusted=true` do **not** skip destination signature checks on
  `nix copy --from` — signing + trusted public keys is the real fix.
- Linux builds offloaded to mac-mini's `nix.linux-builder` VM produce paths on
  the mini; clients that pull those closures need the same trust key (already
  wired on mac-mini-builder consumers).

## Security

- **`trusted-users`** (`root`, `@admin` on Darwin, `connorfuhrman`) can use
  `nix store` operations that bypass signature checks via CLI flags. Treat this
  like root access to the Nix store.
- The **secret key** must stay mode `600` and readable by the Nix daemon
  (root). Rotating keys: generate a new `--key-name`, update the public key
  file, redeploy trust on all clients, re-sign closures.

## Validation (eval-only, dev machine)

```sh
git add modules/generic/nix-store-trust.nix modules/generic/keys/mac-mini.public \
  modules/darwin/nix-store-sign.nix docs/plans/nix-store-signing.md
nix flake check .
nix eval .#darwinConfigurations.mac-mini.config.nix.settings.secret-key-files
nix eval .#darwinConfigurations.macbook.config.nix.settings.extra-trusted-public-keys --apply 'keys: builtins.elem "mac-mini-1:PLACEHOLDER_REPLACE_WITH_nix_key_convert-secret-to-public_OUTPUT" keys'
nix eval .#nixosConfigurations.mbp14.config.nix.settings.trusted-users
```
