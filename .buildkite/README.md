# Buildkite — nixconfig

Pipeline: [connor-m-fuhrman/nixconfig](https://buildkite.com/connor-m-fuhrman/nixconfig)

## One-time setup

### `CURSOR_API_KEY` cluster secret

The `cursor-env-build` step needs a Cursor Cloud Agents API key:

1. Cursor Dashboard → **API Keys** → create a user or service-account key.
2. Buildkite → **Clusters** → **Default** → **Secrets** → add `CURSOR_API_KEY`.
3. Confirm **Cursor Cloud MCP** is enabled for the team (Agents → MCP settings).

Never commit the key. The step fails immediately when the secret is missing.

### GitHub branch protection (after first green run)

On `develop` and `main`, require status check **`buildkite/nixconfig`**
(Settings → Branches → branch protection rules).

## Cursor environment Build CI

See `.cursor/AGENTS.md` for what each step validates and
`.buildkite/prompts/cursor-env-build.md` for the locked-down agent prompt.
