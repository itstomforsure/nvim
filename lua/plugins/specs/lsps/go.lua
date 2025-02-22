local M = {}

function M.setup(lspconfig, capabilities, on_attach)
  lspconfig.gopls.setup({
    capabilities = capabilities,
    on_attach = on_attach,
    settings = {
      gopls = {
        hints = {
          assignVariableTypes = true,
          compositeLiteralFields = true,
          compositeLiteralTypes = true,
          constantValues = true,
          functionTypeParameters = true,
          parameterNames = true,
          rangeVariableTypes = true,
        },
        analyses = {
          unusedparams = true,
          shadow = true,
        },
        codelenses = {
          generate = true,
          gc_details = true,
          test = true,
          tidy = true,
        },
        usePlaceholders = true,
        completionDocumentation = true,
        importShortcut = "Definition",
        experimentalPostfixCompletions = true,
      },
    },
  })
end

return M
