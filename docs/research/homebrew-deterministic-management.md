# Deterministic Homebrew management (with nix-darwin)

Status: **research note**  
Author: grok · Date: 2026-08-01 · Branch: `feat/fleet-opencode-nix`  
Context: mac-mini / macbook fleet; current brew surface is mostly Roon cask.

This note uses [Document Comments](https://community.obsidian.md/plugins/document-comments) for optional decisions.

---

## 1. Reality check

Homebrew installs into **mutable** trees (`/opt/homebrew`, `/Applications`). You can get **declarative intent** (what should be installed) from Nix, not bit-identical rebuilds. Versions float with upstream bottles/casks unless you pin harder (locked taps, no auto-upgrade).

| Layer | What is pinned | Determinism |
|---|---|---|
| Full Nix package (flake / nixpkgs) | derivation hash | highest |
| nix-homebrew + flake-locked taps | brew binary + tap git SHAs | high for *tooling*, not formulae versions |
| nix-darwin `homebrew.*` + cleanup | package *names* in generated Brewfile | medium — set membership enforced |
| nix-darwin `homebrew.*`, cleanup none | install-only | low — drift accumulates |
| Imperative `brew install` | nothing | lowest |

---

## 2. Tooling map

### 2.1 nix-darwin `homebrew.*` (primary — already in this repo)

[nix-darwin homebrew module](https://github.com/nix-darwin/nix-darwin/blob/master/modules/homebrew.nix) generates a Brewfile and runs `brew bundle` during `darwin-rebuild switch`.

Important options:

| Option | Role |
|---|---|
| `homebrew.enable` | **Required** or taps/casks are inert |
| `casks` / `brews` / `taps` / `masApps` / `vscode` | Declared inventory |
| `onActivation.cleanup` | `"none"` \| `"uninstall"` \| `"zap"` — removes drift |
| `onActivation.upgrade` | Upgrade listed pkgs on activate |
| `onActivation.autoUpdate` | `brew update` before bundle (usually keep `false`) |
| `greedyCasks` | Force-upgrade self-updating / `:latest` casks |
| `taps = [{ name; trusted = true; }]` | Homebrew 6+ third-party tap trust |
| `config.homebrew.brewfile` | Read-only generated Brewfile (debug / diff) |

**This fleet today (mac-mini eval):**

- `onActivation.cleanup = "none"`
- `onActivation.upgrade = false`
- `onActivation.autoUpdate = false`
- Brewfile ≈ `cask "roon", trusted: true` only

So installs are declarative for Roon, but **nothing removes** leftover casks (e.g. old emacs-plus).

### 2.2 Homebrew Bundle (engine under the hood)

[`brew bundle`](https://docs.brew.sh/Manpage#bundle-subcommand): `install`, `check`, `cleanup`, `dump`, `list`.

Useful audit (declared vs actual):

```bash
brew bundle dump --file=/tmp/Brewfile.actual --force
nix eval --raw .#darwinConfigurations.mac-mini.config.homebrew.brewfile > /tmp/Brewfile.declared
diff -u /tmp/Brewfile.declared /tmp/Brewfile.actual
```

Do **not** maintain a hand-written Brewfile *and* nix-darwin lists — one source of truth.

### 2.3 <!--c:qmjcg-->nix-homebrew (pin Homebrew itself + taps)<!--/c:qmjcg-->
<!--co:qmjcg by:Connor_Fuhr at:2026-08-02T06:59:26.367Z status:open quote:"nix-homebrew (pin Homebrew itself + taps)"
Connor Fuhr (2026-08-02T06:59:26.367Z): grok - I want to implement this. I want to know the versions and exact packages that I am installing with homebrew and I do not want to be able to ephemerally alter the homebrew install via the `brew` command line tool.
Connor Fuhr (2026-08-02T07:02:34.890Z): my overall goal is to know exactly what is installed with homebrew. If I cannot guarentee a specific version then that is okay but I would prefer to. But my minimum requirement is that there is a set of packages installed with homebrew defined in Nix and no packages can be ephemercailly added or deleted
-->

[zhaofengli/nix-homebrew](https://github.com/zhaofengli/nix-homebrew):

- Manages the **Homebrew installation**, not formulae
- Works **with** nix-darwin `homebrew.*` for packages
- Optional flake inputs for `homebrew-core` / `homebrew-cask` / custom taps
- `mutableTaps = false` → no imperative `brew tap`
- `autoMigrate = true` for existing `/opt/homebrew`
- Declarative trust entries (Homebrew 6+)

Use when brew + tap SHAs should appear in `flake.lock`.

### 2.4 <!--c:h192l-->Prefer Nix packages when they exist<!--/c:h192l-->
<!--co:h192l by:Connor_Fuhr at:2026-08-02T07:01:11.220Z status:open quote:"Prefer Nix packages when they exist"
Connor Fuhr (2026-08-02T07:01:11.220Z): Grok - I do want to do this but I know that there are some apps that are only available for MacOS using Homebrew. \n\nYou should audit the existing install and replace anything that can be install using nix with nix but keep things with homebrew that either are not in nix or just provide a substantially better experience using homebrew
-->

| Source | Use for |
|---|---|
| nixpkgs / flakes + home-manager | CLI, many GUIs, emacs flake wrapper |
| nixpkgs darwin apps | Some `.app`s as store paths |
| brew cask via nix-darwin | Vendor Mac apps with no good Nix story (Roon) |
| Imperative brew | Avoid on managed hosts |

### 2.5 <!--c:j0cvx-->mac-app-util (Nix `.app`s in Spotlight)<!--/c:j0cvx-->
<!--co:j0cvx by:Connor_Fuhr at:2026-08-02T07:14:45.579Z status:open quote:"mac-app-util (Nix `.app`s in Spotlight)"
Connor Fuhr (2026-08-02T07:14:45.579Z): grok - I don't want this
-->

[hraban/mac-app-util](https://github.com/hraban/mac-app-util): trampolines so Nix-installed apps index in Spotlight/Launchpad and Dock pins survive store path changes. Orthogonal to brew; load darwin + HM modules.

### 2.6 What will not fully pin casks

- Most casks do not support stable version pins in Brewfile
- `mas` needs App Store sign-in; cleanup does not always uninstall MAS apps
- Self-updating casks need `greedy` / `greedyCasks`
- Brew is networked and upstream-moving by design

---

## 3. Recommended policy for this monorepo

1. **Single inventory:** nix-darwin `homebrew.*` only (dendritic feature modules append casks/brews).
2. **Central base module** (proposed): `darwin.homebrew-base` sets `enable`, shared `onActivation`, PATH; features only add packages.
3. **Cleanup:** move to `onActivation.cleanup = "uninstall"` after auditing `brew list --cask` on each Mac. <!--c:a1b2c3-->Use `"zap"` only if you accept aggressive cask file removal.<!--/c:a1b2c3-->
<!--co:a1b2c3 by:grok at:2026-08-01T00:00:00.000Z status:open quote:"Use zap only if you accept aggressive cask file removal."
grok (2026-08-01T00:00:00.000Z): Prefer uninstall or zap as the fleet default for onActivation.cleanup?
-->
4. **Upgrade policy:** keep `upgrade = false` and `autoUpdate = false` for pin-ish behavior; turn upgrade on only if you want “always current casks” on every rebuild.
5. **nix-homebrew:** optional phase-2 if locked brew/taps matter.
6. **Package placement:**
   - Real Nix packaging exists → Nix (not brew). Emacs is the cautionary tale: brew GUI + Nix config without packages = broken.
   - Proprietary / no Nix → brew cask under a feature module.
7. **mac-app-util:** add when Nix GUI apps should appear in Spotlight after HM/darwin switch.
8. **Hygiene:** never `brew install` on managed machines; if you do, either declare it in Nix or let cleanup remove it.

---

## 4. Suggested module shape (not implemented)

```nix
# modules/darwin/homebrew-base.nix
flake.modules.darwin.homebrew-base = { ... }: {
  homebrew.enable = true;
  homebrew.onActivation = {
    autoUpdate = false;
    upgrade = false;
    cleanup = "uninstall"; # after audit
  };
  environment.systemPath = [ "/opt/homebrew/bin" "/opt/homebrew/sbin" ];
};

# modules/darwin/roon-server.nix — append only
homebrew.casks = [ { name = "roon"; } ];
# imports homebrew-base (or host imports both)
```

Inspect after switch:

```bash
nix eval --raw .#darwinConfigurations.mac-mini.config.homebrew.brewfile
brew bundle check --file <(nix eval --raw .#darwinConfigurations.mac-mini.config.homebrew.brewfile)
```

---

## 5. Determinism ladder (summary)

```text
full Nix package             ████████████
nix-homebrew + locked taps   ████████░░░░
nix-darwin brew + cleanup    ██████░░░░░░
nix-darwin brew, no cleanup  ████░░░░░░░░
imperative brew              █░░░░░░░░░░░
```

---

## 6. References

- nix-darwin manual / `modules/homebrew.nix`
- [Homebrew Bundle](https://docs.brew.sh/Manpage#bundle-subcommand)
- [nix-homebrew](https://github.com/zhaofengli/nix-homebrew)
- [mac-app-util](https://github.com/hraban/mac-app-util)
- This repo: `modules/darwin/roon-server.nix`, `modules/darwin/system.nix` (PATH), `modules/darwin/emacs-plus.nix` (legacy, unused)
