/**
 * Smoke test against the official @opencode-ai/sdk package (vendored tarball)
 * plus orchestration allowlist + agent wiring. No live provider calls.
 *
 * Full runtime import of sdk/dist/server.js needs npm deps (cross-spawn, …);
 * this test validates package identity/exports from package.json and that our
 * Nix allowlist/agents are coherent — the contract agents rely on.
 */
import { readFileSync, existsSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);

function must(cond, msg) {
  if (!cond) {
    console.error("FAIL:", msg);
    process.exit(1);
  }
  console.log("ok:", msg);
}

// Vendored SDK lives on NODE_PATH (exports map blocks require.resolve of package.json)
const nodePath = (process.env.NODE_PATH || "").split(":").filter(Boolean);
const sdkRoots = [
  ...nodePath.map((p) => join(p, "@opencode-ai/sdk")),
  join(dirname(fileURLToPath(import.meta.url)), "node_modules/@opencode-ai/sdk"),
];
let sdkPkgPath = sdkRoots.map((r) => join(r, "package.json")).find((p) => existsSync(p));
must(!!sdkPkgPath, `found @opencode-ai/sdk package.json in NODE_PATH (${nodePath.join(",")})`);

const sdkPkg = JSON.parse(readFileSync(sdkPkgPath, "utf8"));
must(sdkPkg.name === "@opencode-ai/sdk", `sdk name=${sdkPkg.name}`);
must(typeof sdkPkg.version === "string" && sdkPkg.version.length > 0, `sdk version=${sdkPkg.version}`);
must(sdkPkg.version.startsWith("1."), `sdk major 1.x (got ${sdkPkg.version})`);

// package exports map — official surface
const exportsField = sdkPkg.exports || sdkPkg.main || sdkPkg.module;
must(!!exportsField, "sdk declares exports/main");

// Allowlist JSON
const modelsPath = process.env.OPENCODE_ORCHESTRATION_MODELS || process.argv[2];
must(modelsPath && existsSync(modelsPath), `models file exists: ${modelsPath}`);
const models = JSON.parse(readFileSync(modelsPath, "utf8"));
must(models.policy?.openrouter_paid === "allowlist_only", "paid policy");
must(models.policy?.xai_grok === "always_allowed", "xai always");
must(models.policy?.openrouter_free === "always_allowed", "free always");
must(Array.isArray(models.paid_openrouter) && models.paid_openrouter.length > 0, "paid list");
must(
  models.paid_openrouter.every((m) => typeof m === "string" && m.startsWith("openrouter/")),
  "paid ids openrouter/*",
);
must(
  models.paid_openrouter.some((m) => m.includes("moonshot") || m.includes("qwen")),
  "includes moonshot or qwen MoE test model",
);
must(typeof models.default_moe_test_model === "string", "default moe test model");
must(
  models.paid_openrouter.includes(models.default_moe_test_model),
  "default moe is on allowlist",
);

// Agents
const agentDir = process.env.OPENCODE_AGENTS_DIR || process.argv[3];
if (agentDir) {
  for (const name of ["orchestrator.md", "worker-free.md", "moe-advisor.md"]) {
    const p = join(agentDir, name);
    must(existsSync(p), `agent ${name}`);
    const body = readFileSync(p, "utf8");
    must(body.startsWith("---"), `${name} has frontmatter`);
    must(/mode:\s*(primary|subagent)/.test(body), `${name} has mode`);
  }
  const orch = readFileSync(join(agentDir, "orchestrator.md"), "utf8");
  must(/orchestration/i.test(orch), "orchestrator mentions orchestration");

  // Regression guard: worker-free MUST pin an explicit free model, otherwise
  // subagents silently inherit the orchestrator's (paid) session model.
  const worker = readFileSync(join(agentDir, "worker-free.md"), "utf8");
  const workerModel = worker.match(/^model:\s*(\S+)\s*$/m)?.[1];
  must(!!workerModel, "worker-free pins an explicit model");
  must(workerModel.endsWith(":free"), `worker-free model is free tier (${workerModel})`);
  must(workerModel.startsWith("openrouter/"), `worker-free model is on openrouter (${workerModel})`);
}

// Free preference list must contain real free-tier ids (":free" suffix —
// unsuffixed ids are PAID on OpenRouter).
must(
  Array.isArray(models.preferred_free_openrouter) &&
    models.preferred_free_openrouter.length > 0,
  "preferred free list non-empty",
);
must(
  models.preferred_free_openrouter.every((m) => m.endsWith(":free")),
  "preferred free ids all carry :free suffix",
);
must(
  models.preferred_free_openrouter.includes(models.worker_free_model),
  "worker_free_model is on the preferred free list",
);

console.log("PASS orchestration sdk package + allowlist + agents smoke test");
console.log(`sdk@${sdkPkg.version} paid_models=${models.paid_openrouter.length}`);
