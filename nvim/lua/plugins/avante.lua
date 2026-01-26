return {
  {
    "yetone/avante.nvim",
    opts = {
      provider = "openai",
      providers = {
        openai = {
          -- Keep model selection flexible; use :AvanteModels in-editor.
          -- model = "gpt-4.1",

          -- Pull key from 1Password CLI on-demand:
          -- IMPORTANT: use --no-newline so the key is clean.
          api_key_name = "cmd:op read op://Private/OpenAI\\ API\\ Key/password --no-newline",

          -- If you hit weird “parameter not supported” errors, keep the request body minimal.
          -- request_body = { temperature = 0.2 },
        },

        -- Claude
	claude = {
          auth_type = "max",
        },
      },
    },
  },
}

