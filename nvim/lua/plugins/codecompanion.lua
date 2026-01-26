return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      -- optional but helpful while setting up
      opts = { log_level = "INFO" },

      adapters = {
        http = {
          openai = function()
            return require("codecompanion.adapters").extend("openai_responses", {
              env = {
                api_key = "cmd:op read op://Private/OpenAI\\ API\\ Key/password --no-newline",
              },
            })
          end,
          anthropic = function()
            return require("codecompanion.adapters").extend("anthropic", {
              env = {
                api_key = "cmd:op read op://Private/Anthropic\\ API\\ Key/password --no-newline",
              },
            })
          end,
        },
      },

      interactions = {
        -- Big “reasoning + design + refactor” chat
        chat = {
          adapter = { name = "openai", model = "gpt-4.1" },
        },

        -- Fast inline edits in your current buffer
        inline = {
          adapter = { name = "openai", model = "gpt-4.1-mini" },
        },

        -- Quick command-line helpers (small/cheap is fine)
        cmd = {
          adapter = { name = "openai", model = "gpt-4.1-mini" },
        },
      },
    },
  },
}

