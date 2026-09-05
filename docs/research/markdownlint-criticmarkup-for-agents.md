---
title: "markdownlint + CriticMarkup for agent-authored Markdown"
author: grok
date: 2026-08-02
status: research
---

# markdownlint + CriticMarkup for agent-authored Markdown

> Question from human: how effective is `DavidAnson/markdownlint` for helping AI
> agents write good Markdown, and how can it be combined with the fleet's
> existing Obsidian `cm` (CriticMarkup) tooling so agents generate Markdown that
> renders well in Obsidian?

## 1. What markdownlint actually is

`DavidAnson/markdownlint` is a Node.js **static analyzer** for
Markdown/CommonMark/GFM. It is *not* a renderer and *not* a formatter — it
reports rule violations and, for rules that carry `fixInfo`, can apply
mechanical fixes (`applyFixes`).

- 60 built-in rules (MD001–MD060) covering heading hierarchy, list style,
  blank lines around blocks, code-fence language, link validity, table shape,
  trailing whitespace, etc. See the rule index in the README.
- Configurable per-file via `.markdownlint.json(c|yaml)` or inline
  `<!-- markdownlint-disable MD013 -->` HTML comments.
- CLI surface: `markdownlint-cli` (simple) and `markdownlint-cli2`
  (config-file discovery, globs, extends). The author maintains `cli2`.
- Parser is `micromark` (CommonMark) + GFM extensions + footnotes + math +
  directives. This matters: it understands the *same* GFM dialect Obsidian's
  base renderer targets, so its verdicts line up with what Obsidian will
  actually do.

Two things it deliberately is **not**:

1. A **formatter** in the Prettier sense. It has auto-fix for whitespace /
   spacing / list-marker rules, but it will not reflow long lines, reformat
   tables, or normalize prose. `--fix` is conservative.
2. A **prose linter**. It checks structure, not content. It will not catch
   bad writing, hallucinated claims, or inconsistent terminology (the
   `MD044 proper-names` rule除外 — that one only enforces exact casing of a
   fixed allowlist).

## 2. Effectiveness for AI-agent-authored Markdown

Honest assessment: **highly effective for the structural problems LLMs
actually make, useless for the semantic ones.** Mapping the common LLM
Markdown failure modes onto markdownlint rules:

| LLM failure mode | Caught by | How well |
|---|---|---|
| Missing blank line around headings/code-fences/lists | MD022 / MD031 / MD032 | Fully auto-fixable. LLMs violate this constantly. |
| Skipping heading levels (`#` → `###`) | MD001 | Fully caught. |
| Duplicate or empty link text / bare URLs | MD034, MD042, MD059 | Caught. |
| Code fence without language | MD040 | Caught; LLMs do this often. |
| Inconsistent list markers (`-`, `*`, `+` mixed) | MD004 | Caught, auto-fixable. |
| Trailing whitespace / hard tabs | MD009 / MD010 | Caught, auto-fixable. |
| No trailing newline | MD047 | Caught, auto-fixable. |
| Multiple H1 / first line not H1 | MD025 / MD041 | Caught (tune to taste; `docs/plans` may legitimately start with `##`). |
| Long-line prose (LLMs love 1-line-per-sentence) | MD013 | Caught but **disable by default** — Obsidian is line-break agnostic and forcing wrap fights GFM soft-breaks. |
| Tables with ragged columns | MD056 / MD055 / MD058 | Caught, partially fixable. |
| Hallucinated link fragments | MD051 | Caught — this is genuinely valuable, LLMs invent anchors. |
| Wrong heading style (Setext vs ATX) | MD003 | Caught, auto-fixable. |
| **Bad prose, wrong claims, made-up citations** | — | **Not caught.** Out of scope. |

Net: enabling the **default** rule set catches ~80% of the structural
mistakes an agent makes, and `--fix` cleans up the trivial ones. The
remaining 20% (line-length, MD041 first-line-h1 on `docs/plans/*`,
MD024 sibling-duplicate headings in RFCs) needs a small per-section
config.

### Where it falls short for agents specifically

- **No awareness of CriticMarkup.** `{++ … ++}`, `{-- … --}`, `{~~ ~> ~~}`
  etc. are not real Markdown; markdownlint sees them as inline text. Most
  rules still work (the marks are inside spans), but a few interact badly:
  - `MD022 blanks-around-headings` can fire if an insertion mark sits
    against a heading line.
  - `MD038 no-space-in-code` and `MD037 no-space-in-emphasis` occasionally
    false-positive on `{++ ++}` adjacent to code/emphasis.
  - `MD009 no-trailing-spaces` is fine; the marks themselves contain no
    trailing spaces.
  - The bigger problem is `--fix`: applying fixes to a document with
    unresolved CriticMarkup marks will shift byte offsets, invalidating
    the `--start/--end` indices `cm list` reports. **Never run
    markdownlint `--fix` on a doc with open CriticMarkup marks.**
- **No awareness of Obsidian extensions.** Wiki-links `[[foo]]`, callouts
  `> [!note]`, Dataview blocks, frontmatter `prope​rties:` syntax are all
  outside CommonMark/GFM. markdownlint will mostly ignore them (they parse
  as text), but `MD040 fenced-code-language` and a few others can misfire
  on indented Dataview/` ``` ` blocks.
- **No semantic consistency** (terminology, "is this claim supported by the
  cited doc"). markdownlint is structural only; pair it with a prose/citation
  reviewer (the `moe-advisor` / `document-review` skill loop) for that.

## 3. Combining with the fleet `cm` tooling

The goal: agent emits Markdown → human reviews in Obsidian Track Changes →
the doc that lands in Obsidian is both **structurally clean** (renders
without quirks) **and reviewable** (CriticMarkup marks survive). The two
tools operate at different layers and compose cleanly if you sequence
them.

### Layering

```
agent draft  ──► markdownlint (structure gate) ──► cm edits (review marks) ──► Obsidian
                     ↑ mechanical, before marks       ↑ semantic, after lint
```

**Rule: lint before you mark.** Run markdownlint (and any auto-fix) on the
plain draft *first*, then apply `cm insert/sub/delete` to the cleaned
text. Reversed order breaks byte offsets and risks `--fix` corrupting
marks.

### Recommended workflow (concrete)

1. **Agent writes draft** to `docs/<area>/<file>.md` (no CriticMarkup yet).
2. **Agent runs lint** with the repo config:
   `markdownlint-cli2 'docs/<area>/<file>.md' --fix`.
   This silently fixes whitespace, list-marker, blank-line, and
   trailing-newline violations. Anything it can't fix is reported.
3. **Agent addresses remaining diagnostics** (heading hierarchy, missing
   code-fence language, broken link fragments) by hand edits — these are
   real content issues, not formatting.
4. **Agent opens Document Comment threads** (skill `document-comments`)
   on any decision the human must approve.
5. **Agent applies CriticMarkup** via `cm` for prose edits the human
   should see as track-changes. `cm validate` after.
6. **Human reviews in Obsidian**: Track Changes for CriticMarkup,
   Document Comments for decisions. Accepts/rejects via the
   `obsidian-track-changes` plugin or `cm accept/reject` from a shell.
7. **After all marks resolved** (`cm strip` or accept-all), the agent
   re-runs `markdownlint-cli2` (no `--fix`) as a final gate before commit.

This keeps the two tools in their lanes: markdownlint = "did the agent
produce structurally valid Markdown," `cm` = "what did the agent change
and why, for human review."

### Sequencing gotchas (real, with the current `cm`)

`cm` uses **byte offsets** into the UTF-8 file (`--start/--end`,
`cm list` `Start`/`End` fields are byte indices). markdownlint `--fix`
mutates the file. So:

- **Never interleave** `markdownlint --fix` and `cm` calls on the same
  file in the same pass. Lint to a clean baseline, *then* mark.
- After `cm accept/reject`, offsets of *later* marks shift. `cm list`
  re-numbers indices on every call, so always re-list before the next
  accept/reject. (The current implementation already does this —
  `cmdAcceptReject` re-runs `findMarks` on the current bytes — but the
  `--index` you pass must come from a fresh `cm list`.)
- `cm validate` only checks token balance, not structural Markdown
  validity. A doc can `cm validate` true and still render badly in
  Obsidian. That's exactly the gap markdownlint fills.

### Configuring markdownlint for this repo

A small `.markdownlint.jsonc` at repo root keeps the rules aligned with
Obsidian + the fleet's conventions. Suggested starting config:

```jsonc
{
  "default": true,
  // Obsidian is line-break agnostic; long prose is fine.
  "MD013": false,
  // docs/plans/* and RFCs often start with frontmatter or a `##` decision;
  // require H1 only where it matters (README, top-level docs).
  "MD041": false,
  // Sibling headings ("Decision" appears in many RFCs) are intentional.
  "MD024": { "siblings_only": true },
  // Allow inline HTML — Obsidian comment anchors and CriticMarkup are not
  // HTML anyway, but Document Comments use <!--c:ID--> HTML comments.
  "MD033": false,
  // CriticMarkup and Obsidian callouts legitimately sit close to headings;
  // keep the blank-line rule but relax for callouts is not possible, so
  // leave on and let agents fix.
  "MD022": true,
  // Obsidian wiki-links and embeds are not bare URLs.
  "MD034": false
}
```

Rationale per line: MD013 off matches Obsidian's renderer; MD041 off
matches the fleet's `docs/plans/*` and RFC style; MD024 siblings-only
allows repeated section names across an RFC; MD033 off is required for
the `<!--c:…-->` Document Comment syntax (HTML comments); MD034 off
because `[[wiki links]]` and `![[embeds]]` are not bare URLs.

### Packaging it nix-side (optional, low-effort)

The fleet already pins small tools (nono, opencode, cm) via
`flake.overlays.default`. markdownlint is a Node package — two options:

1. **`nodePackages.markdownlint-cli2`** is already in nixpkgs. Add it to
   `home.packages` in `modules/home/standard.nix` (or a new
   `homeManager.markdown-lint` module registered next to
   `criticmarkup.nix`). Zero new derivation to maintain.
2. If you want it on the **opencode bundle PATH** (so subagents inside
   nono can call it), add a small `pkgs/markdownlint.nix` wrapper that
   pulls `nodePackages.markdownlint-cli2` and a `bin/markdownlint`
   symlink, then include it in `pkgs/opencode-nix-bundle.nix`'s `PATH`
   line next to `${cm}/bin`. ~15 lines.

Option 1 is enough for now; the agent can shell out to
`markdownlint-cli2` from the dev machine the same way it shells out to
`cm`.

### Skill / instruction update

To make this actually part of the agent loop, two small edits:

1. In `modules/opencode/_skills/document-review/SKILL.md`, add a
   "Pre-edit lint" step before the CriticMarkup section: "Run
   `markdownlint-cli2 --fix` on the draft *before* applying any `cm`
   marks; never run `--fix` on a doc with open CriticMarkup."
2. In `modules/opencode/_instructions/fleet.md` (or a new
   `modules/opencode/_instructions/markdown-quality.md`), state the
   contract: "Long-form `docs/*.md` output must pass `markdownlint-cli2`
   with the repo config before commit. CriticMarkup marks are applied
   *after* linting."

No new skill is needed; this is a workflow rule, not a capability.

## 4. Cost / benefit verdict

| Dimension | Verdict |
|---|---|
| Catches the structural mistakes LLMs actually make | Yes — default rules cover ~80%. |
| Auto-fixes the trivial ones | Yes — `--fix` for whitespace/list/blank-line/newline. |
| Catches semantic / prose problems | No — out of scope; pair with `moe-advisor` / review loop. |
| Composes with `cm` | Yes, if lint runs **before** marks. Byte-offset contract is the only sharp edge. |
| Obsidian-extension aware | Partial — GFM only; wiki-links/callouts need config exemptions. |
| Maintenance cost in this repo | Low — one `.markdownlint.jsonc`, one `home.packages` line, two doc edits. |

**Recommendation:** adopt it. Enable the default rules with the small
exemptions above, gate `docs/*.md` through `markdownlint-cli2 --fix`
before CriticMarkup, and document the sequencing rule in the
document-review skill. The combination gives you "structurally valid
Markdown that renders cleanly in Obsidian" (markdownlint) *and*
"human-reviewable changes" (CriticMarkup) — the two concerns the fleet
currently conflates under `cm` alone.

## 5. Open questions for the human

- {>> Should `markdownlint-cli2 --fix` be a hard pre-commit gate for
  `docs/*.md`, or advisory? A hard gate means agents must run it before
  `git add`; advisory means it's a hint. <<}
- {>> Do you want markdownlint on the opencode bundle PATH (so nono-sandboxed
  subagents can call it), or only on the dev shell PATH via
  `home.packages`? <<}
- {>> Keep MD041 (first-line-h1) off globally, or scope it on for README /
  top-level docs via a per-directory `.markdownlint.jsonc`? <<}
