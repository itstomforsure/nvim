-------------------------------------------------------------------------------
-- Framework
-------------------------------------------------------------------------------

local vim = vim
local M = {}

function M.init()
	--- UI2 (experimental message + cmdline presentation layer; see :h ui2).
	--- Conservative: route everything through the cmdline as before, but use
	--- the new pipeline (better spill handling, g< recall, dialog prompts).
	pcall(function()
		require("vim._core.ui2").enable({
			enable = true,
			msg = { targets = "cmd" },
		})
	end)

	--- Updating the buffer when outside source edits it (e.g: GHC, ClaudeCode)
	vim.opt.autoread = true
	vim.api.nvim_create_autocmd(
		{ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
			command = "checktime",
		})

	--- Save toast (replaces the cmdline write feedback with a Snacks notification)
	vim.api.nvim_create_autocmd("BufWritePost", {
		callback = function(ev)
			local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(ev.buf),
				":t")
			if name == "" then return end
			local lines = vim.api.nvim_buf_line_count(ev.buf)
			vim.notify(string.format('"%s" %dL written', name, lines))
		end,
	})

	--- Mapleader
	vim.g.mapleader = " "

	--- Keybindings & symbols
	local keybinds = require('keybindings')
	local symbols = require("symbols")

	--- Native commenting (Neovim 0.10+ ships gcc / gc); re-bound to <leader>/.
	keybinds.apply("comment")

	--- Layout engine
	require("layout").init()

	--- Plugins
	require("plugins").init(keybinds, symbols)

	--- LSP
	require("lsp").init(keybinds, symbols)

	--- Branch-based sessions
	require("session").init()

	--- Colorscheme
	vim.cmd(":colorscheme vscode")
end

return M
