local vim = vim
local M = {}
local terminal_buf = nil
local terminal_win = nil

local function create_terminal_buf()
	if terminal_buf and vim.api.nvim_buf_is_valid(terminal_buf) then
		return terminal_buf
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"

	return buf
end

local function create_terminal_win(buf)
	if terminal_win and vim.api.nvim_win_is_valid(terminal_win) then
		return terminal_win
	end

	local width = math.min(80, vim.o.columns - 10)
	local height = math.floor(vim.o.lines * 0.4)
	local row = math.floor((vim.o.lines - height) / 2 - 1)
	local col = math.floor((vim.o.columns - width) / 2)

	local opts = {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	}

	local win = vim.api.nvim_open_win(buf, true, opts)
	vim.api.nvim_win_set_option(win, "winblend", 10)

	return win
end

-- local function close_terminal()
-- 	if terminal_win and vim.api.nvim_win_is_valid(terminal_win) then
-- 		vim.api.nvim_win_close(terminal_win, true)
-- 		terminal_win = nil
-- 	end
-- 	if terminal_buf and vim.api.nvim_buf_is_valid(terminal_buf) then
-- 		vim.api.nvim_buf_delete(terminal_buf, { force = true })
-- 		terminal_buf = nil
-- 	end
-- 	vim.api.nvim_command("stopinsert")
-- end

local function open_terminal_win()
	if terminal_win and vim.api.nvim_win_is_valid(terminal_win) then
		vim.api.nvim_set_current_win(terminal_win)
	else
		terminal_buf = create_terminal_buf()
		terminal_win = create_terminal_win(terminal_buf)

		-- local opts = { buffer = terminal_buf, silent = true }
		-- vim.keymap.set({ "n", "i", "v", "t" }, "<Esc>", function()
		-- 	vim.notify("Closing terminal...", vim.log.levels.INFO)
		-- 	close_terminal()
		-- end, opts)

		vim.api.nvim_command("terminal")
		vim.api.nvim_command("startinsert")
	end
end

function M.setup(key)
	vim.keymap.set({ "n", "v" }, key, open_terminal_win, { noremap = true, silent = true })
end

return M
