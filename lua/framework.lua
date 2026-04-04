-------------------------------------------------------------------------------
-- Framework
-------------------------------------------------------------------------------

local vim = vim
local M = {}

function M.init()
	--- Notify
	--- using it with Snacks.notifier is redundant, although still feels like this catches more things.
	--- TODO: Either combine them or set up notifier and use that for everything if possible.
	vim.notify = require("notify").notify

	--- Updating the buffer when outside source edits it (e.g: GHC, ClaudeCode)
	vim.opt.autoread = true
	vim.api.nvim_create_autocmd(
		{ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
			command = "checktime",
		})

	--- Mapleader
	vim.g.mapleader = " "

	--- Keybindings & symbols
	local keybinds = require('keybindings')
	local symbols = require("symbols")

	--- Layout engine
	require("layout").init()

	--- Plugins
	require("plugins").init(keybinds, symbols)

	--- LSP
	require("lsp.init").init(keybinds, symbols)

	--- Colorscheme
	vim.cmd(":colorscheme vscode")
end

return M
