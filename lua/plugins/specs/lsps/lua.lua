local M = {}

function M.setup(lspconfig, capabilities, on_attach)
  lspconfig.lua_ls.setup({
    capabilities = capabilities,
    on_attach = on_attach,
    settings = {
      Lua = {
        completion = {
          callSnippet = "Replace",
          enable = true,
          keywordSnippet = "Replace",
          showWord = "Enable",
          workspaceWord = true,
        },
        diagnostics = {
          enable = true,
          globals = {
            "vim",
            "describe",
            "it",
            "before_each",
            "after_each",
          },
          disable = {
            "trailing-space",
          },
        },
        hover = {
          enable = true,
          viewNumber = true,
          viewString = true,
          viewStringMax = 1000,
        },
        workspace = {
          library = vim.api.nvim_get_runtime_file("", true),
          maxPreload = 2000,
          preloadFileSize = 50000,
          checkThirdParty = false,
        },
        runtime = {
          version = "LuaJIT",
          path = runtime_path,
          special = {
            include = "require",
          },
        },
        hint = {
          enable = true,
          arrayIndex = "Disable",
          setType = true,
          paramName = "All",
          paramType = true,
          semicolon = "SameLine",
        },
        telemetry = {
          enable = false,
        },
      },
    },
  })
end

return M
