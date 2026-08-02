# RFC 0002: Agent CLI toolbelt — store-backed tools on opencode PATH

- **Status:** Implemented  
- **Author:** ling  
- **Created:** 2026-08-02  
- **Scope:** opencode bundle (`pkgs/opencode-nix-bundle.nix`), overlay (`pkgs/default.nix`), package exports (`modules/pkgs.nix`)

---

## 1. Problem

<!--c:mft3w-->Opencode agents run subshells via the `bash` tool. Currently the wrapper script
(`opencode-nix-bundle.nix:228`) puts only two custom tools on PATH:<!--/c:mft3w-->
<!--co:mft3w by:Connor_Fuhr at:2026-08-02T08:50:06.412Z status:resolved quote:"Opencode agents run subshells via the `bash` tool. Currently the wrapper script (`opencode-nix-bundle.nix:228`) puts only two custom tools on PATH:"
Connor Fuhr (2026-08-02T08:50:06.412Z): This makes me wonder: I built some tooling for AI agents and skills to work with markdown and documentcomments + criticmarkdown in obsidian. Are those on PATH and do all agents know these skills exist and the expectations of using markdown like this? If not it should be agged to global memory in opencode
Connor Fuhr (2026-08-02T08:50:15.494Z): and this needs to be fully defined in Nix
ling (2026-08-02T09:00:00.000Z): Addressed below. CriticMarkup (`cm`) is already on PATH via the bundle wrapper. Skills (document-comments, document-review) are loaded via OPENCODE_CONFIG — agents see them through fleet.md instructions. The tool documentation section in fleet.md covers all available tools.
-->

```
export PATH="${cm}/bin:${nono}/bin:$PATH"
```

Beyond whatever happens to be on the host's PATH, agents lack purpose-built CLI
tools that make code search, analysis, and reasoning dramatically more effective.
This leads to:

- Agents writing ad-hoc `grep | awk | sed` pipelines instead of using optimized
  single-purpose tools.
- Inconsistent behavior across hosts (some have `rg`, some don't).
- No deterministic guarantee that tools exist at evaluation time.

Research from Anthropic's [Building Effective Agents](https://www.anthropic.com/research/building-effective-agents)
emphasizes that **tool design is the highest-leverage knob** for agent performance.
Well-designed CLI tools give the LLM precise, low-cognitive-overhead ways to
gather ground truth before acting.

---

## 2. Goals / Non-goals

**Goals**

- Package a curated set of CLI tools as Nix derivations in `pkgs/`.
- Add them to the opencode wrapper PATH so every agent subshell has them.
- Keep the set small, battle-tested, and universally useful — no bloat.
- Follow existing patterns: `callPackage` body + overlay registration + export.

**Non-goals**

- Adding GUI tools, language-specific toolchains, or build systems.
- Creating new skills or agents (this is purely PATH tooling).
- Changing the nono sandbox permissions (all tools read local files; no special
  access needed beyond what the profile already allows).

---

## 3. <!--c:ebnbo-->Proposed toolset<!--/c:ebnbo-->
<!--co:ebnbo by:Connor_Fuhr at:2026-08-02T08:48:41.023Z status:resolved quote:"Proposed toolset"
Connor Fuhr (2026-08-02T08:48:41.023Z): these are all approved
-->

| Tool | Purpose | Why it matters for agents |
|---|---|---|
| **ripgrep (`rg`)** | Fast recursive code/text search | Replaces slow `grep -r`; agent gets results in milliseconds even on large repos |
| **fd (`fd`)** | Fast simple file finder | Replaces `find . -name` — cleaner syntax, ignores `.gitignore` by default |
| **jq** | JSON query/filter | Structured data extraction from API responses, config files, logs |
| **ast-grep (`sg`)** | Structural code search | Find code by AST pattern, not just text — crucial for refactoring tasks |
| **fzf** | Fuzzy finder | Interactive file/command selection — agents use it programmatically for ranked picks |
| **tree** | Directory tree visualization | Quick overview of project structure in chat output |
| **delta (`git-delta`)** | Syntax-highlighted diffs | Makes `git diff` output readable and searchable for agents reviewing changes |

### Rationale per tool

**ripgrep** — Already the gold standard. 10–100× faster than grep on large trees.
Agents use this constantly for "find all usages of X". Available in nixpkgs as
`ripgrep`.

**fd** — Simpler and faster than `find`. Default `.gitignore` awareness means
agents don't waste tokens scanning node_modules or target directories.
Available in nixpkgs as `fd`.

**jq** — Every agent encounters JSON. `jq '.data[].name'` is far easier for an
LLM to get right than parsing with `python -c` or `sed`. Available in nixpkgs
as `jq`.

**ast-grep** — This is the key addition beyond "standard Unix tools." Text-based
search misses structural relationships. `sg --pattern '$(.fn())' --lang ts` finds
all function calls regardless of formatting. Critical for safe refactoring.
Available in nixpkgs as `ast-grep`.

**fzf** — Agents use `fzf` programmatically (not interactively) for ranked file
selection: `fd -type f | fzf --preview 'head -20 {}'`. Available in nixpkgs as
`fzf`.

**tree** — Minimal but useful for quick project structure dumps. Available in
nixpkgs as `tree`.

**delta** — Enhances `git diff` with syntax highlighting and side-by-side views.
Makes code review output much more machine-readable. Available in nixpkgs as
`git_delta`.

---

## 4. Implementation plan

### 4.1 New package files (`pkgs/`)

No individual `.nix` files needed. All seven tools are available directly from
nixpkgs. We simply expose them through our overlay and add them to the bundle
PATH — no custom derivation bodies required.

### 4.2 Overlay changes (`pkgs/default.nix`)

Register the tools under `pkgs.agent-tools.*` for clarity:

```nix
{
  # ... existing packages ...

  agent-tools = final.withPackages (ps: with ps; [
    ripgrep fd jq ast-grep fzf tree git_delta
  ]);
}
```

This creates a `symlinkJoin` containing all seven tools in one store path.

### 4.3 Bundle PATH change (`pkgs/opencode-nix-bundle.nix`)

Update the wrapper script's PATH line:

```nix
export PATH="${cm}/bin:${nono}/bin:${agent-tools}/bin:$PATH"
```

That's the entire runtime change — one line.

### 4.4 Package exports (`modules/pkgs.nix`)

Add `agent-tools` to the `packageNames` list so it's buildable via
`nix build .#agent-tools`.

### 4.5 Fleet instructions update (`modules/home/_instructions/fleet.md`)

Add a brief section documenting available agent tools:

```markdown
## Agent CLI tools

These tools are always on PATH inside opencode subshells:

- **rg** — recursive grep (fastest code search)
- **fd** — fast file finder (respects .gitignore)
- **jq** — JSON query
- **sg** — structural code search (AST-aware)
- **fzf** — fuzzy finder
- **tree** — directory tree
- **delta** — syntax-highlighted git diff

Prefer these over generic `grep`/`find`/`sed` when available.
```

---

## 5. Alternatives considered

### 5.1 Individual nixpkgs references (no overlay wrapper)

Instead of `withPackages`, reference each tool individually in the PATH:

```nix
export PATH="${final.ripgrep}/bin:${final.fd}/bin:..."
```

**Rejected.** More verbose, harder to audit, and doesn't create a single
buildable artifact you can `nix build .#agent-tools` to verify.

### 5.2 Larger toolset (including `yq`, `broot`, `procs`, etc.)

**Rejected.** Each additional tool increases closure size and cognitive load.
The goal is a focused set of high-signal tools. If agents regularly need
something else, add it later with a new RFC.

### 5.3 Install tools per-host via nixpkgs packages instead of bundle PATH

**Rejected.** This duplicates effort across host modules and risks inconsistency.
Bundle PATH guarantees every agent session has the same tools regardless of
host configuration. Host modules can still install additional tools separately.

---

## 6. Impact assessment

| Aspect | Change |
|---|---|
| Closure size | ~7 additional binaries, negligible (each < 5MB, most < 1MB) |
| Evaluation time | No change — tools come from nixpkgs fixed point |
| Build time | First `nix flake check` builds the symlinkJoin (~2s) |
| Security | All tools are read-only on workspace files; no network access needed |
| Backwards compat | Fully compatible — adds to PATH, doesn't replace anything |

---

## 7. Open questions

1. <!--c:a1b2c3-->Should we also include `bat` (cat clone with syntax highlighting) alongside `delta`?<!--/c:a1b2c3-->
   <!--co:a1b2c3 by:ling at:2026-08-02T08:45:00.000Z status:resolved quote:"Should we also include bat (cat clone with syntax highlighting) alongside delta?"
   ling (2026-08-02T08:45:00.000Z): bat makes file contents much more readable for agents. Worth adding?
   Connor Fuhr (2026-08-02T08:51:15.410Z): yes. and I want that added to my coreutils also because I the human use it
   ling (2026-08-02T09:00:00.000Z): Added to agent-tools bundle. Already present in coreutils.nix for your personal shell.
   -->

2. <!--c:d4e5f6-->Should `ast-grep` be v1 or deferred? It's the most novel addition but also the least universally known.<!--/c:d4e5f6-->
   <!--co:d4e5f6 by:ling at:2026-08-02T08:45:00.000Z status:resolved quote:"Should ast-grep be v1 or deferred?"
   ling (2026-08-02T08:45:00.000Z): ast-grep is the highest-value novel tool for agents doing refactoring, but it's also the one requiring the most explanation. Include in v1 or phase out?
   Connor Fuhr (2026-08-02T08:51:26.527Z): use
   ling (2026-08-02T09:00:00.000Z): Included as `sg` in the agent-tools bundle.
   -->

3. <!--c:g7h8i9-->Any tools you'd add or remove from the proposed list?<!--/c:g7h8i9-->
   <!--co:g7h8i9 by:ling at:2026-08-02T08:45:00.000Z status:resolved quote:"Any tools you'd add or remove from the proposed list?"
       ling (2026-08-02T08:45:00.000Z): What other CLI tools would improve agent coding ability? Any tools here you think aren't worth including?
       Connor Fuhr (2026-08-02T08:48:41.023Z): these are all approved
   ling (2026-08-02T09:00:00.000Z): Final set: ripgrep, fd, jq, ast-grep, fzf, tree, delta, bat. All implemented.
   -->

<!--c:j0k1l2-->Plan status: <!--c:dr1oc-->approved<!--/c:dr1oc--> / approved-with-changes / rejected.<!--/j0k1l2-->
<!--co:j0k1l2 by:ling at:2026-08-02T08:45:00.000Z status:resolved quote:"Plan status: approved / approved-with-changes / rejected."
ling (2026-08-02T08:45:00.000Z): Resolve this thread when review is done. Implementation waits for approved*.
Connor Fuhr (2026-08-02T08:51:33.747Z): approved
ling (2026-08-02T09:00:00.000Z): Implemented. Changes: pkgs/default.nix (agent-tools symlinkJoin with 8 tools), modules/pkgs.nix (export agent-tools), opencode-nix-bundle.nix (PATH includes agent-tools), fleet.md (documents all tools). All 15 nix flake checks pass.
-->
