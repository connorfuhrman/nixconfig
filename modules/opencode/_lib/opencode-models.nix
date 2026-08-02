{ lib, ... }:
# Paid OpenRouter models the orchestrator may use for MoE / hard decomposition.
# Free OpenRouter models are unrestricted. Grok on xAI is always available.
# Bump intentionally — this list is the security/cost boundary for paid OR calls.
rec {
  paidOpenRouterModels = [
    # Cheap MoE test defaults (Alibaba / Moonshot)
    "openrouter/qwen/qwen3-coder"
    "openrouter/qwen/qwen-2.5-72b-instruct"
    "openrouter/moonshotai/kimi-k2"
    "openrouter/moonshotai/kimi-k2-0905"
    # Frontier (optional MoE / hard review)
    "openrouter/anthropic/claude-sonnet-4"
    "openrouter/anthropic/claude-opus-4"
    "openrouter/openai/gpt-4.1"
    "openrouter/openai/o3"
    "openrouter/google/gemini-2.5-pro"
    "openrouter/google/gemini-2.5-flash"
  ];

  # Default worker / small tasks — free tier preference (not enforced as allowlist).
  # MUST carry the OpenRouter ":free" suffix — unsuffixed ids are paid.
  preferredFreeOpenRouter = [
    "openrouter/poolside/laguna-s-2.1:free"
    "openrouter/cohere/north-mini-code:free"
    "openrouter/nvidia/nemotron-3-super-120b-a12b:free"
    "openrouter/inclusionai/ling-3.0-flash:free"
    "openrouter/openai/gpt-oss-20b:free"
  ];

  # Pinned model for the worker-free agent. Without an explicit pin, subagents
  # inherit the orchestrator's session model (defeats cost + diversity goals).
  # Laguna S 2.1: coding-agent MoE (118B), free tier, vendor-diverse from the
  # orchestrator (Kimi) and ling-implementer (Ling 3.0 Flash).
  workerFreeModel = "openrouter/poolside/laguna-s-2.1:free";

  defaultMoeTestModel = "openrouter/moonshotai/kimi-k2";

  orchestrationModelsJson = builtins.toJSON {
    version = 1;
    policy = {
      xai_grok = "always_allowed";
      openrouter_free = "always_allowed";
      openrouter_paid = "allowlist_only";
    };
    paid_openrouter = paidOpenRouterModels;
    preferred_free_openrouter = preferredFreeOpenRouter;
    worker_free_model = workerFreeModel;
    default_moe_test_model = defaultMoeTestModel;
  };

  # Helper for agent model fields (moe-advisor default).
  moeAdvisorModel = defaultMoeTestModel;
}
