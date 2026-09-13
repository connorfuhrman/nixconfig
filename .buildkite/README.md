# Buildkite — nixconfig

Pipeline: [connor-m-fuhrman/nixconfig](https://buildkite.com/connor-m-fuhrman/nixconfig)

## One-time setup

### Cursor API token (cluster secret)

The `cursor-env-build` step authenticates to the Cloud Agents API with
**`CURSOR_AUTOMATION_WEBHOOK_TOKEN`** (same secret used by the t-hex pipeline).
**`CURSOR_API_KEY`** is accepted as a fallback.

1. Reuse the existing Buildkite cluster secret `CURSOR_AUTOMATION_WEBHOOK_TOKEN`
   (Cursor automation “Generate auth header” value, `crsr_…` without `Bearer`).
2. Or add **`CURSOR_API_KEY`** from Cursor Dashboard → API Keys.
3. Confirm **Cursor Cloud MCP** is enabled for the team (Agents → MCP settings).

Never commit tokens. The step fails immediately when neither secret is set.

### GitHub branch protection (after first green run)

On `develop` and `main`, require status check **`buildkite/nixconfig`**
(Settings → Branches → branch protection rules).

## Cursor environment Build CI

See `.cursor/AGENTS.md` for what each step validates and
`.buildkite/prompts/cursor-env-build.md` for the locked-down agent prompt.
