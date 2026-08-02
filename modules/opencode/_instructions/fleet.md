# Fleet opencode instructions (Nix-managed)

These rules are baked into the store-backed `opencode` install from nixconfig.
They apply to **every** agent and subagent on every host — not only when the
cwd is this monorepo. Project `AGENTS.md` (when present) adds repo-specific
rules on top.

## Long-form human output → Obsidian document, not chat

If the answer intended for the human is more than a short paragraph or a few
bullets — research, comparisons, runbooks, architecture notes, multi-section
explanations, surveys, workplans:

1. **Write a Markdown file** under the active project's documentation tree.
   In the nixconfig monorepo use:
   - `docs/plans/` — actionable workplans
   - `docs/rfcs/` — decisions / ADRs
   - `docs/research/` — surveys and deep-dives
   - `docs/` — other human-facing notes
2. **Reply in chat with only** the file path plus a **1–3 line summary**.
3. **Do not** paste the full document body into the chat.
4. When the human must **decide or approve**, use Obsidian Document Comments
   (skill `document-comments`) and sign threads with your short model name.
5. When editing collaborative prose the human reviews in Obsidian, use
   CriticMarkup via `cm` / skill `document-review`.

Short answers (a word, a command, a few bullets) stay in chat.

## Agent CLI tools

These tools are always on PATH inside opencode subshells:

- **rg** — recursive grep (fastest code search)
- **fd** — fast file finder (respects .gitignore)
- **jq** — JSON query/filter
- **sg** — structural code search (AST-aware pattern matching)
- **fzf** — fuzzy finder
- **tree** — directory tree visualization
- **delta** — syntax-highlighted git diff
- **bat** — cat clone with syntax highlighting
- **gh** — GitHub CLI (PRs, issues, repo queries)

Prefer these over generic `grep`/`find`/`sed` when doing code work.

## GitHub CLI (`gh`)

`gh` is on PATH for nondestructive GitHub work: creating PRs, reading issues
and PRs, posting review comments, checking status. GitHub credentials live in
**1Password** — never ask the human to paste a token. Get one at call time:

```sh
GH_TOKEN="$(op read 'op://Private/GitHub/token')" gh pr create …
# or wrap the whole command:
op run -- gh pr view 123
```

If `op` fails inside the sandbox, say so and name the exact denial (see skill
`nono-sandbox`) — do not work around it.

**Allowed without asking:** `gh pr create`, `gh pr status`, `gh pr view`,
`gh issue *` (read/comment), `gh repo view`, `gh api` GETs, `gh pr checks`.

**Ask the human first:** force-push, deleting branches/repos, closing or
merging PRs you didn't just create, editing branch protection, anything under
`gh repo delete` / `gh release delete`.

## Why

Chat is for control-plane messages. Long prose is reviewed in Obsidian (margin
comments, track changes) and versioned in git with the rest of the fleet.
