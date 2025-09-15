local vim = vim
local M = {}

function M.is_buf_valid(buf)
	if buf and vim.api.nvim_buf_is_valid(buf) then
		return true
	else
		return false
	end
end

function M.is_win_valid(win)
	if win and vim.api.nvim_win_is_valid(win) then
		return true
	else
		return false
	end
end

function M.create_scratch_buf(buf)
	if M.is_buf_valid(buf) then
		return buf
	end

	return vim.api.nvim_create_buf(false, true)
end

function M.create_floating_win(buf, win, win_opts)
	if not M.is_buf_valid(buf) then
		return nil
	end

	if M.is_win_valid(win) then
		return win
	end

	win_opts = win_opts or {}
	local width = win_opts.width or math.min(80, vim.o.columns - 10)
	local height = win_opts.height or math.floor(vim.o.lines * 0.4)
	local row = win_opts.row or math.floor((vim.o.lines - height) / 2 - 1)
	local col = win_opts.col or math.floor((vim.o.columns - width) / 2)

	local config = {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = win_opts.border or "rounded",
	}

	local floating_win = vim.api.nvim_open_win(buf, true, config)
	local opts = { win = floating_win }
	vim.api.nvim_set_option_value("winhl", "Normal:Normal,StatusColumn:DiagnosticInfo", opts)
	vim.api.nvim_set_option_value("winblend", 10, opts)

	if win_opts.statuscolumn then
		vim.api.nvim_set_option_value("statuscolumn", win_opts.statuscolumn, opts)
	end

	return floating_win
end

return M
