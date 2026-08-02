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
  preferredFreeOpenRouter = [
    "openrouter/deepseek/deepseek-r1"
    "openrouter/deepseek/deepseek-chat"
    "openrouter/nvidia/llama-3.3-nemotron-super-49b-v1"
  ];

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
    default_moe_test_model = defaultMoeTestModel;
  };

  # Helper for agent model fields (moe-advisor default).
  moeAdvisorModel = defaultMoeTestModel;
}
