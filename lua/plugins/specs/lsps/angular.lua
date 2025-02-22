local M = {}

function M.setup(lspconfig, capabilities, on_attach)
  print("Setting up Angular LSP", lspconfig, capabilities, on_attach)
  lspconfig.angularls.setup({
    capabilities = capabilities,
    on_attach = on_attach,
    root_dir = require("lspconfig").util.root_pattern("angular.json", "project.json"),
    on_new_config = function(new_config, new_root_dir)
      local global_ts = vim.fn.expand("~/.nvm/versions/node/v22.11.0/lib/node_modules/typescript")
      local global_ng = vim.fn.expand("~/.nvm/versions/node/v22.11.0/lib/node_modules/@angular/language-server")

      new_config.cmd = {
        "ngserver",
        "--stdio",
        "--tsProbeLocations",
        global_ts,
        "--ngProbeLocations",
        global_ng,
      }
    end,
  })
end

return M
