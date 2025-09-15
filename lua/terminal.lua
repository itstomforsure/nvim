local vim = vim
local utils = require("utils")
local M = {}
local terminal_buf = nil
local terminal_win = nil

local function close()
	if utils.is_win_valid(terminal_win) then
		vim.api.nvim_win_close(terminal_win, true)
		terminal_win = nil
	end

	if utils.is_buf_valid(terminal_buf) then
		vim.api.nvim_buf_delete(terminal_buf, { force = true })
		terminal_buf = nil
	end

	vim.cmd("stopinsert")
end

local function buf_keybinds()
	local opts = { buffer = terminal_buf, silent = true }
	vim.keymap.set({ "n", "t" }, "<Esc>", function()
		close()
	end, opts)
end

local function open_terminal_win()
	terminal_buf = utils.create_scratch_buf(terminal_buf)
	terminal_win = utils.create_floating_win(terminal_buf, terminal_win)

	vim.cmd("terminal")
	vim.cmd("startinsert")

	buf_keybinds()
end

function M.setup(key)
	local opts = {
		noremap = true,
		silent = true,
		desc = "Open terminal window",
	}
	vim.keymap.set({ "n", "v" }, key, open_terminal_win, opts)
end

return M
