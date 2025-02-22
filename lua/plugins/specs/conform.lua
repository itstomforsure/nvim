return {
  "stevearc/conform.nvim",
  config = function()
    require("conform").setup({
      formatters_by_ft = {
        typescript = { "eslint_d", "prettier" },
        javascript = { "eslint_d", "prettier" },
        htmlangular = { "prettier" },
        html = { "prettier" },
        css = { "prettier" },
        scss = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        go = { "gofumpt", "goimports" },
        lua = { "stylua" },
      },
      format_on_save = {
        timeout_ms = 1000,
        lsp_fallback = true,
      },
    })
  end,
}
