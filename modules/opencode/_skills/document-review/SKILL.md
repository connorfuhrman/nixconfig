---
name: document-review
description: >
  Human↔agent review loop using Obsidian Document Comments plus CriticMarkup
  track-changes. Use when editing plans/ADRs/markdown the human reviews in
  Obsidian, when acting on Document Comments instructions, or when applying
  track-changes / CriticMarkup / cm CLI edits. Always use for collaborative
  markdown in this monorepo. Also applies whenever long-form human-facing
  output is written under docs/ (fleet rule: research and multi-section
  answers go to Obsidian files, not chat).
---

# Document review protocol

## Fleet rule (all agents)

Long-form answers for humans are **files under `docs/`**, not chat walls.
Chat reply = path + 1–3 line summary. Use Document Comments for decisions;
use CriticMarkup (`cm`) for prose edits the human reviews in Obsidian.

## Human → agent (Document Comments)

The human leaves instructions as [Document Comments](https://community.obsidian.md/plugins/document-comments)
HTML threads in markdown (`<!--c:ID-->…<!--/c:ID-->` + `<!--co:ID …-->`).

When you **act on** an instruction in a thread:

1. Do the work.
2. **Resolve** the thread: set `status:resolved` on the `<!--co:ID …-->` header.
3. Append a signed message line: `grok (ISO8601): …` describing what you did.
4. **Do not delete** the thread or anchor.

Load skill **document-comments** for exact syntax and author tags.

## Agent → human (CriticMarkup / Track Changes)

When you edit prose the human will review in Obsidian Track Changes
([philphilphil/obsidian-track-changes](https://github.com/philphilphil/obsidian-track-changes)):

Use **CriticMarkup** ([spec](https://github.com/CriticMarkup/CriticMarkup-toolkit#the-basic-syntax)):

| Intent | Syntax |
|---|---|
| Insertion | `{++ added text ++}` |
| Deletion | `{-- removed text --}` |
| Substitution | `{~~ old ~> new ~~}` |
| Comment / question | `{>> question for human <<}` (optionally on `{== highlight ==}`) |
| Highlight | `{== text ==}` |

### Logical chunks

Break edits into **reviewable hunks** (one paragraph, one list item, one decision
sentence). Do not wrap an entire file in a single `{++ ++}`.

### CLI (`cm`)

Store-packaged binary on PATH:

```bash
cm insert  --file PATH --at BYTE --text '…'
cm delete  --file PATH --start B --end B
cm sub     --file PATH --start B --end B --text 'new'
cm comment --file PATH --start B --end B --text 'question?'
cm highlight --file PATH --start B --end B [--text 'note']
cm list    --file PATH [--json]
cm accept  --file PATH --index N
cm reject  --file PATH --index N
cm validate --file PATH
```

Prefer `cm` over hand-typing delimiters when offsets are known. After edits,
`cm validate --file PATH`.

## Chat vs file

Still summarize blockers in chat. The markdown file is the durable review surface.

## What not to do

- Silent direct rewrites of review docs without CriticMarkup when the human
  expects track-changes
- Deleting Document Comment threads after handling them
- Resolving threads you did not complete
- Putting secrets in anchors or CriticMarkup comments
