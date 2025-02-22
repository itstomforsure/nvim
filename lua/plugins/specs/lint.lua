return {
  "mfussenegger/nvim-lint",
  config = function()
    require("lint").linters_by_ft = {
      typescript = { "eslint_d" },
      javascript = { "eslint_d" },
      -- go = { "golangcilint" },
      -- lua = { "luacheck" },
    }

    local lint_augroup = vim.api.nvim_create_augroup("Linting", { clear = true })

    local function safe_lint()
      local lint_ok, lint_err = pcall(function()
        require("lint").try_lint()
      end)

      if not lint_ok then
        vim.notify("Linting failed: " .. tostring(lint_err), vim.log.levels.WARN)
      end
    end

    vim.api.nvim_create_autocmd({
      "BufWritePost",
      "BufEnter",
      "InsertLeave",
      "TextChanged",
      "CursorHold",
    }, {
      group = lint_augroup,
      callback = function()
        if vim.bo.modifiable and vim.bo.buftype == "" then
          safe_lint()
        end
      end,
    })

    vim.opt.updatetime = 1000
  end,
}
