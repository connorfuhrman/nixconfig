---
name: document-comments
description: >
  Write or edit Markdown for Obsidian using the Document Comments plugin
  (kylemcd/obsidian-document-comments). Use when creating review plans, ADRs,
  design docs, or any .md where the agent needs human decisions, approvals,
  or input; when the user mentions Document Comments, margin comments,
  Obsidian review, or asks for commentable markdown. Agents MUST open
  comment threads on every blocking question and sign them with their short
  model name (e.g. grok, ling).
---

# Obsidian Document Comments

Format from [Document Comments](https://community.obsidian.md/plugins/document-comments)
(`kylemcd/obsidian-document-comments`). Comments are **HTML comments in the
file** — invisible in normal renderers, visible as margin cards in Obsidian,
readable by agents and `git diff`.

## When to use

- Plans, proposals, ADRs, threat models, checklists awaiting human review
- Any markdown where you need a **decision, approval, secret, or preference**
- User asks for Obsidian-friendly / commentable / Document Comments markdown

Do **not** spray comments on every paragraph. Only anchor text that needs a
human reply or is a named decision gate.

## Author identity (required)

Every thread you create must be signed with your **short model family name**,
lowercase, no provider prefix:

| Runtime model id (examples) | Author tag |
|---|---|
| `xai/grok-*`, `grok-*` | `grok` |
| `openrouter/inclusionai/ling-*`, `ling-*` | `ling` |
| `anthropic/claude-*` | `claude` |
| `openai/gpt-*`, `o1` / `o3` / `o4*` | `gpt` |
| unknown / other | first token of the model id before `/` or `-`, max 16 chars `[a-z0-9]` |

Use that same tag in:

1. `by:<author>` on the `<!--co:…-->` header
2. Each message line: `<author> (<ISO-8601>): …`

Never use `opencode`, `assistant`, or `ai` as the author.

## Storage format

Two pieces per comment, **same id**:

```markdown
Prose with <!--c:ID-->highlighted anchor text<!--/c:ID--> continues here.
<!--co:ID by:AUTHOR at:ISO8601 status:open quote:"highlighted anchor text"
AUTHOR (ISO8601): Question or statement for the human.
-->
```

### Rules

1. **ID** — short unique token per file: 4–8 lowercase hex chars (e.g. `a1b2c3`).
   No spaces. Generate fresh ids; never reuse within a file.
2. **Anchor** — `<!--c:ID-->…<!--/c:ID-->` wraps the exact span the card
   attaches to. Prefer a full decision sentence or option phrase (not a single
   vague word). Do not nest anchors. Avoid overlapping spans.
3. **Thread** — `<!--co:ID …-->` immediately after the paragraph (or on the
   next lines). Header fields:
   - `by:AUTHOR` — your short model name
   - `at:ISO8601` — UTC timestamp with milliseconds, e.g. `2026-07-30T12:00:00.000Z`
   - `status:open` | `status:resolved`
   - `quote:"…"` — copy of the anchor text (escape internal `"` as needed)
4. **Messages** — one per line inside the `co` block:
   `AUTHOR (ISO8601): markdown body…`
   Markdown in bodies is fine (`` `code` **, links).
5. **HTML comment safety** — never put `--` inside comment body text; rephrase.
6. **Blocking questions** — if you cannot proceed without input, create an
   `status:open` thread and **stop that path** until the human resolves it
   (or continue only non-blocked work). Say in chat that decisions are in the
   doc margin threads.
7. **Edits** — when replying in an existing thread, append a new message line;
   keep `status:open` until the human marks resolved (do not resolve your own
   decision threads unless the user told you the answer in chat).
8. **Chat vs file** — still summarize blockers in the user-visible reply; the
   file is the durable review surface.

## Minimal example

```markdown
## Deploy target

<!--c:9f3a-->Run Hermes only on mac-mini (not macbook).<!--/c:9f3a-->
<!--co:9f3a by:grok at:2026-07-30T15:01:00.000Z status:open quote:"Run Hermes only on mac-mini (not macbook)."
grok (2026-07-30T15:01:00.000Z): Confirm host scope for v1. Reply approve / also-macbook / other.
-->
```

## Multi-decision plan pattern

1. Write the full plan in normal markdown.
2. Wrap each **decision** or **phase gate** in `c:` / `co:` pairs.
3. End with a single status anchor:

```markdown
<!--c:e2e1-->Plan status: approved / approved-with-changes / rejected.<!--/c:e2e1-->
<!--co:e2e1 by:grok at:2026-07-30T15:02:00.000Z status:open quote:"Plan status: approved / approved-with-changes / rejected."
grok (2026-07-30T15:02:00.000Z): Resolve this thread when review is done. Implementation waits for approved*.
-->
```

## Acting on human instructions

When a Document Comment thread contains an instruction you are executing:

1. Perform the work.
2. Set `status:resolved` on the `<!--co:ID …-->` header (**never delete** the thread).
3. Append a signed message: `grok (ISO8601): …` describing what you did.

For **prose edits** the human will review in Obsidian, also follow skill
**document-review** (CriticMarkup / `cm` CLI, logical chunks).

## What not to do

- Do not invent a different comment syntax (no `> [!comment]`, no bare HTML).
- Do not sign threads as `opencode` or the full model path `xai/grok-4.5`.
- Do not resolve human decision threads yourself without an explicit answer
  (unless the thread was an instruction you fully completed).
- Do not put secrets in quote/anchor text; ask the human to place secrets out of band.
- Do not delete threads after resolving them.

## Plugin reference

- Community listing: https://community.obsidian.md/plugins/document-comments
- Upstream: https://github.com/kylemcd/obsidian-document-comments
