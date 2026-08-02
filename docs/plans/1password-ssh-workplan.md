# Workplan: SSH keys via 1Password

Status: **report / plan** (config assumptions updated; full cutover is phased)  
Author: grok · Date: 2026-08-01 · Branch: `feat/fleet-opencode-nix`

This note uses [Document Comments](https://community.obsidian.md/plugins/document-comments) for decisions.

---

## 1. Short answers

**Do you only store private keys?**  
You store **SSH key items** in 1Password (private key material lives in the vault). The **public** half is either:

- exported once into `authorized_keys` / GitHub / `~/.ssh/*.pub` files, or  
- viewed from the 1Password item when needed.

You do **not** need a private key file on disk for day-to-day SSH if the **1Password SSH agent** is enabled.

**Does 1Password have SSH options built in?**  
Yes. 1Password 8+ includes:

1. **SSH key item type** (generate or import ed25519/RSA).
2. **SSH agent** (`IdentityAgent` socket) that signs challenges after you approve (Touch ID / Windows Hello / master password).
3. Optional **Git commit signing** with SSH keys.
4. CLI: `op` can manage items; agent is desktop-app driven.

Docs: [1Password SSH agent](https://developer.1password.com/docs/ssh/).

---

## 2. How it works technically

```
ssh client
  → IdentityAgent ~/.1password/agent.sock  (or macOS app group path)
  → 1Password app unlock + item authorization
  → signature returned
  → server verifies against authorized_keys pubkey
```

No `ssh-add` of raw keys required. Agent config in `~/.ssh/config`:

```sshconfig
Host *
  IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
```

Linux typical:

```sshconfig
Host *
  IdentityAgent ~/.1password/agent.sock
```

NixOS/home-manager can set this via `programs.ssh.extraConfig` once the agent path is confirmed per OS.

**GitHub / Forge:** upload the **public** key from the 1Password item (or `ssh-add -L` when agent is up).

**Nix remote builders / root daemon:** this is the hard part. The Nix daemon runs as root and does **not** see your user GUI agent by default. Options:

| Approach                                                                        | Pros                               | Cons                                          |
| ------------------------------------------------------------------------------- | ---------------------------------- | --------------------------------------------- |
| **A. Dedicated builder key** still as file under `/etc/nix/` (or root-readable) | Works today for `mac-mini` builder | Not 1Password-backed                          |
| **<!--c:gf9fq-->B. User-level nix builds only** (`nix` as your user with agent)<!--/c:gf9fq-->               | Agent works                        | Daemon multi-user builds need extra setup     |
| **C. 1Password service account / CLI in headless**                              | Automatable                        | Different security model; careful with tokens |
| **D. Keep agent for interactive SSH; separate machine key for nix daemon**      | Pragmatic split                    | Two key classes                               |
<!--co:gf9fq by:Connor_Fuhr at:2026-08-02T07:39:38.312Z status:open quote:"B. User-level nix builds only** (`nix` as your user with agent)"
Connor Fuhr (2026-08-02T07:39:38.312Z): this is fine with me. I am the only user of my computers. \n\nwhen headless how can I log in?
-->

Recommendation: **D** — human SSH + git via 1Password agent; **nix-daemon builder auth** stays a small dedicated key (or Tailscale SSH) until a clean headless story exists.

---

## 3. Effect on this monorepo / your systems

Already true:

- 1Password CLI (+ GUI on darwin/desktop) via `*.onepassword` modules.
- Passwordless SSH assumed for `mac-mini` builder (`generic.mac-mini-builder`).

Planned changes (phased):

1. **home-manager `programs.ssh`** — IdentityAgent snippet per OS; `AddKeysToAgent` off; prefer agent identities.
2. **Document** that `initialPassword` on NixOS remains bootstrap only; day-2 is keys.
3. **Do not** commit private keys; public keys may live in host modules as `openssh.authorizedKeys.keys` **or** stay out-of-band.
4. **nono sandbox** — agent socket path may need a nono profile allow for SSH from sandboxed opencode (`~/.1password` or Group Containers). Expect a profile draft when interactive git/ssh from agents is required.
5. **hermes / servers** — continue pubkey `authorized_keys`; private keys never on guests.

---

## 4. Workplan phases

### Phase 0 — Inventory (you)

- [ ] List hosts that need interactive SSH (macbook, mini, nuc×2, mbp14).
- [ ] Decide one ed25519 key per machine vs one user key everywhere.
- [ ] Confirm 1Password SSH agent enabled in app settings on each Mac.

### Phase 1 — Interactive agent (low risk)

- [ ] HM module `homeManager.ssh-1password` with IdentityAgent paths.
- [ ] Import into `homeManager.standard`.
- [ ] Smoke: `ssh mac-mini` / `ssh nuc` with no disk keys loaded.

### Phase 2 — authorized_keys

- [ ] Export pubkeys to NixOS `users.users.connorfuhrman.openssh.authorizedKeys.keys` **or** keep in 1Password only and install once.
- [ ] Optionally disable password auth on servers after keys verified.

### Phase 3 — Nix builder path

- [ ] Keep dedicated builder key for root/daemon **or** switch clients to user-mode builders.
- [ ] Document which hosts use which path in AGENTS.md.

### Phase 4 — Agent + nono

- [ ] Profile allow for agent socket if sandboxed git push is required.
- [ ] Never inject private key PEM into the sandbox.

---

## 5. What we changed in-tree now

- Comments in `nixos.system` and `generic.mac-mini-builder` pointing here.
- No forced IdentityAgent yet (avoids breaking SSH before agent is enabled on every box).

---

## 6. Decisions

<!--c:a1p0-->Prefer split keys: 1Password agent for interactive SSH/git; dedicated file key for nix-daemon builders.<!--/c:a1p0-->
<!--co:a1p0 by:grok at:2026-08-01T00:00:00.000Z status:open quote:"Prefer split keys: 1Password agent for interactive SSH/git; dedicated file key for nix-daemon builders."
grok (2026-08-01T00:00:00.000Z): Approve split (recommended), agent-everywhere (harder), or hold.
-->

<!--c:a1p1-->Phase 1 IdentityAgent HM module: ship on next home-manager switch after you enable the agent in 1Password.app.<!--/c:a1p1-->
<!--co:a1p1 by:grok at:2026-08-01T00:00:00.000Z status:open quote:"Phase 1 IdentityAgent HM module: ship on next home-manager switch after you enable the agent in 1Password.app."
grok (2026-08-01T00:00:00.000Z): Reply ship-now / wait-until-agent-on / skip.
-->
