# Cursor IDE — Nix installation plan

Plan to add [Cursor](https://cursor.com) to this flake across hosts, replacing
the removed opencode stack as the primary AI-assisted editor.

## Goals

- Install Cursor declaratively on **macbook** and **mac-mini** (daily-use Darwin hosts).
- Optionally install on **mbp14** (Asahi desktop) once that host is validated.
- Skip headless Linux servers (`nuc`, cluster roles, `rpi-cluster-head`) unless
  you later want a GUI session there.
- Install the **Cursor app only** — settings, keybindings, extensions, and AI
  config stay in Cursor's own UI / `~/.cursor/` (not VS Code, not
  `programs.vscode`).
- Keep unfree licensing scoped (like 1Password / Obsidian) so `nix flake check`
  stays pure.

## Packaging landscape

| Approach | Pros | Cons |
|---|---|---|
| **`pkgs.code-cursor` (nixpkgs)** | Upstream-maintained; puts `cursor` on PATH + `.app` on Darwin; no VS Code involved | **Unfree**; version lags Cursor releases; Darwin bundle is code-signed — nixpkgs leaves the `.app` untouched (wrapper only) |
| **Homebrew cask `cursor`** | Easy on Darwin; always current via `brew upgrade` | Not declarative enough for this repo's goals; duplicates nixpkgs GUI apps pattern you already avoid for 1Password |
| **Custom `pkgs/cursor.nix` overlay** | Pin exact version + hash | Maintenance burden; duplicates nixpkgs |

**Recommendation:** use **`pkgs.code-cursor` from nixpkgs** via home-manager, not
Homebrew. This matches how Obsidian and 1Password are handled on Darwin.

## Proposed module structure (dendritic)

```
modules/home/cursor.nix          # flake.modules.homeManager.cursor
```

Register once; import from `homeManager.standard` on GUI hosts only (not on
headless NUC/RPi closures — or gate behind a small `homeManager.cursor-gui`
wrapper used only by macbook, mac-mini, mbp14).

### Phase 1 — Darwin (macbook + mac-mini)

1. **Extend unfree predicate** in `modules/darwin/onepassword.nix` (or extract a
   shared `modules/darwin/unfree.nix` if the list grows):

   ```nix
   nixpkgs.config.allowUnfreePredicate = pkg:
     builtins.elem (lib.getName pkg) [
       "1password" "1password-cli" "1password-gui"
       "_1password" "_1password-cli"
       "obsidian"
       "cursor"   # pkgs.code-cursor; lib.getName → "cursor"
     ];
   ```

2. **Add `modules/home/cursor.nix`:**

   ```nix
   { ... }: {
     flake.modules.homeManager.cursor = { pkgs, ... }: {
       home.packages = [ pkgs.code-cursor ];
     };
   }
   ```

   That is the whole module for phase 1. **Do not use `programs.vscode`** —
   that home-manager option is named for Microsoft's editor but is really a
   generic “VS Code–compatible fork” integration (settings JSON, extension
   symlinks). Since you use Emacs + Cursor and do not run VS Code, skip it;
   let Cursor manage its own config under `~/.cursor/` and
   `~/Library/Application Support/Cursor`.

   **Optional later:** if you ever want Nix-pinned extensions, home-manager's
   `programs.vscode` with `package = pkgs.code-cursor` is the supported hook —
   still no VS Code binary installed. Not recommended unless you explicitly
   want declarative extensions.

3. **Wire into host home configs** — add to `standard` *or* import
   `homeManager.cursor` only on:

   - `connorfuhrman@macbook`
   - `connorfuhrman@mac-mini`

   Prefer **per-host import** over putting Cursor in `standard`, so headless
   Linux HM configs stay lean.

4. **Validate:**

   ```sh
   nix flake check .
   nix eval .#homeConfigurations.connorfuhrman@macbook.config.home.packages \
     --apply 'ps: map (p: p.name) ps' | rg cursor
   ```

5. **Human test on macbook:** `home-manager switch --flake .#connorfuhrman@macbook`,
   launch Cursor from `/Applications` or `cursor` on PATH, sign in, confirm
   extensions sync.

### Phase 2 — Asahi desktop (mbp14)

After `mbp14` is validated on hardware:

1. **Extend** `modules/nixos/onepassword.nix` unfree list with `"code-cursor"`.
2. **Import** `homeManager.cursor` in `connorfuhrman@mbp14` (or a
   `homeManager.standard-gui` variant shared with Darwin).
3. **Optional:** add `pkgs.code-cursor-fhs` if Electron sandbox / GPU issues
   appear on Asahi (nixpkgs ships an FHS variant for Linux).
4. **Desktop integration:** ensure Plasma sees Cursor — may need a
   `.desktop` entry (code-cursor on Linux installs `cursor` binary; HM may
   already link it).

### Phase 3 — Cursor config (optional polish)

| Item | Approach |
|---|---|
| User settings / keybindings | Cursor UI, or manual files under `~/.cursor/` |
| Extensions | Cursor marketplace / UI (not Nix-managed unless you opt into `programs.vscode`) |
| Project rules | Repo `.cursor/rules/` (project-level, version-controlled) |
| MCP servers | Cursor UI or project `.cursor/mcp.json` — keep secrets in 1Password, not Nix |

## Host rollout matrix

| Host | Install Cursor? | Rationale |
|---|---|---|
| `macbook` | **Yes — phase 1** | Primary dev machine |
| `mac-mini` | **Yes — phase 1** | Always-on; useful for remote edits |
| `mbp14` | **Phase 2** | GUI desktop once Asahi validated |
| `nuc` / cluster / `rpi` | **No** | Headless servers |
| HM on cluster roles | **No** | Same headless rationale |

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| `code-cursor` version stale vs upstream | Periodic `nix flake update nixpkgs`; or overlay bump |
| Unfree eval breaks `flake check` | Extend existing `allowUnfreePredicate` — never `--impure` |
| HM overwrites existing Cursor config | First switch on a machine with manual Cursor: back up `~/.cursor` and `~/Library/Application Support/Cursor` |
| Cursor auto-update fights Nix | Disable in-app auto-update when managed by Nix (`"update.mode": "none"`) |
| Large closure / first build time | Acceptable on Darwin; Linux build pulls AppImage extract |

## Acceptance criteria

- [ ] `nix flake check` passes with Cursor module
- [ ] `cursor` launches on macbook after HM switch
- [ ] Cursor settings/extensions unchanged from pre-Nix workflow (UI-managed)
- [ ] No duplicate Cursor from Homebrew cask
- [ ] AGENTS.md documents the module and unfree entry

## Suggested PR sequence

1. **PR 1:** `modules/home/cursor.nix` + unfree + macbook/mac-mini only
2. **PR 2:** mbp14 after hardware validation
3. **PR 3:** settings/extensions polish + `.cursor/rules` for repo conventions

## Out of scope (for now)

- Cursor CLI agent / headless `cursor-agent` in Nix (evaluate separately if needed)
- Replacing Emacs workflow
- Installing on Linux servers without a desktop session
