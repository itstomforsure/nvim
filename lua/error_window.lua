local vim = vim
local utils = require("utils")
local M = {}
local error = {
	buf = nil,
	win = nil,
}

local test_errors = {
	"asdfasdfasdfasdfasdfasdf",
	"asdfasdfasdfasdfasdfasdfasdfsadf",
	"wertqwertwerqwerqwerwqerwqerwer",
	"zxcvzxcvzxcvzxcvxzcvxzcvxzcvxzxcv",
}

local function get_errors()
	local messages = vim.cmd("messages")
	local lines = vim.split(messages, "\n", { trimempty = true })

	return lines
end

local function update_buf(buf, content)
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	if not content then
		vim.notify("No content!")
		return
	end

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
	vim.bo[buf].modifiable = false
end

local function close_win()
	if error.win and vim.api.nvim_win_is_valid(error.win) then
		vim.api.nvim_win_close(error.win, true)
		error.win = nil
	end
	if error.buf and vim.api.nvim_buf_is_valid(error.buf) then
		vim.api.nvim_buf_delete(error.buf, { force = true })
		error.buf = nil
	end
end

local function buf_keybinds()
	local opts = { buffer = error.buf, silent = true }
	vim.keymap.set({ "n", "t" }, "<Esc>", function()
		close_win()
	end, opts)
end

local function open_error_win()
	error.buf = utils.create_scratch_buf(error.buf)
	error.win = utils.create_floating_win(error.buf, error.win)

	local errors = get_errors()
	update_buf(error.buf, test_errors)

	buf_keybinds()
end

function M.setup(key)
	local opts = {
		noremap = true,
		silent = true,
		desc = "Open error window",
	}
	vim.keymap.set({ "n", "v" }, key, open_error_win, opts)
end

return M
