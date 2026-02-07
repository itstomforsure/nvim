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
	vim.api.nvim_set_option_value("winhl",
		"Normal:Normal,StatusColumn:DiagnosticInfo", opts)
	vim.api.nvim_set_option_value("winblend", 10, opts)

	if win_opts.statuscolumn then
		vim.api.nvim_set_option_value("statuscolumn", win_opts.statuscolumn, opts)
	end

	return floating_win
end

function M.create_right_win(buf, win, win_opts)
	if not M.is_buf_valid(buf) then
		return nil
	end

	if M.is_win_valid(win) then
		return win
	end

	win_opts = win_opts or {}

	vim.cmd("rightbelow vsplit")

	local new_win = vim.api.nvim_get_current_win()

	if win_opts.width then vim.api.nvim_win_set_width(new_win, win_opts.width) end

	vim.api.nvim_win_set_buf(new_win, buf)

	local opts = { win = new_win }

	vim.api.nvim_set_option_value("winhl",
		"Normal:Normal,StatusColumn:DiagnosticInfo", opts)

	vim.api.nvim_set_option_value("winblend", 0, opts)

	if win_opts.statuscolumn then
		vim.api.nvim_set_option_value("statuscolumn", win_opts.statuscolumn,
			opts)
	end

	if not win_opts.focus then vim.api.nvim_set_current_win(win) end

	return new_win
end

function M.create_bottom_win(buf, win, win_opts)
	if not M.is_buf_valid(buf) then
		return nil
	end

	if M.is_win_valid(win) then
		return win
	end

	win_opts = win_opts or {}

	vim.cmd("rightbelow split")
	local new_win = vim.api.nvim_get_current_win()
	if win_opts.height then vim.api.nvim_win_set_height(new_win, win_opts.height) end
	vim.api.nvim_win_set_buf(new_win, buf)
	local opts = { win = new_win }
	vim.api.nvim_set_option_value("winhl",
		"Normal:Normal,StatusColumn:DiagnosticInfo", opts)
	vim.api.nvim_set_option_value("winblend", 0, opts)
	if win_opts.statuscolumn then
		vim.api.nvim_set_option_value("statuscolumn", win_opts.statuscolumn,
			opts)
	end
	return new_win
end

-- function M.create_win(buf, win, win_opts, position)
-- 	if not M.is_buf_valid(buf) then
-- 		return nil
-- 	end

-- 	if M.is_win_valid(win) then
-- 		return win
-- 	end

-- 	win_opts = win_opts or {}
-- 	position = position or win_opts.position or "right"
-- 	local width = win_opts.width or math.min(80, math.floor(vim.o.columns * 0.3))
-- 	local height = win_opts.height or math.floor(vim.o.lines * 0.4)

-- 	local cur_win = vim.api.nvim_get_current_win()
-- 	if position == "right" then
-- 		vim.cmd("rightbelow vsplit")
-- 		local new_win = vim.api.nvim_get_current_win()
-- 		if width then vim.api.nvim_win_set_width(new_win, width) end
-- 		vim.api.nvim_win_set_buf(new_win, buf)
-- 		local opts = { win = new_win }
-- 		vim.api.nvim_set_option_value("winhl",
-- 			"Normal:Normal,StatusColumn:DiagnosticInfo", opts)
-- 		vim.api.nvim_set_option_value("winblend", 0, opts)
-- 		if win_opts.statuscolumn then
-- 			vim.api.nvim_set_option_value("statuscolumn", win_opts.statuscolumn,
-- 				opts)
-- 		end
-- 		if not win_opts.focus then vim.api.nvim_set_current_win(cur_win) end
-- 		return new_win
-- 	elseif position == "left" then
-- 		vim.cmd("leftabove vsplit")
-- 		local new_win = vim.api.nvim_get_current_win()
-- 		if width then vim.api.nvim_win_set_width(new_win, width) end
-- 		vim.api.nvim_win_set_buf(new_win, buf)
-- 		local opts = { win = new_win }
-- 		vim.api.nvim_set_option_value("winhl",
-- 			"Normal:Normal,StatusColumn:DiagnosticInfo", opts)
-- 		vim.api.nvim_set_option_value("winblend", 0, opts)
-- 		if win_opts.statuscolumn then
-- 			vim.api.nvim_set_option_value("statuscolumn", win_opts.statuscolumn,
-- 				opts)
-- 		end
-- 		if not win_opts.focus then vim.api.nvim_set_current_win(cur_win) end
-- 		return new_win
-- 	elseif position == "top" then
-- 		vim.cmd("leftabove split")
-- 		local new_win = vim.api.nvim_get_current_win()
-- 		if height then vim.api.nvim_win_set_height(new_win, height) end
-- 		vim.api.nvim_win_set_buf(new_win, buf)
-- 		local opts = { win = new_win }
-- 		vim.api.nvim_set_option_value("winhl",
-- 			"Normal:Normal,StatusColumn:DiagnosticInfo", opts)
-- 		vim.api.nvim_set_option_value("winblend", 0, opts)
-- 		if win_opts.statuscolumn then
-- 			vim.api.nvim_set_option_value("statuscolumn", win_opts.statuscolumn,
-- 				opts)
-- 		end
-- 		if not win_opts.focus then vim.api.nvim_set_current_win(cur_win) end
-- 		return new_win
-- 	elseif position == "bottom" then
-- 		vim.cmd("rightbelow split")
-- 		local new_win = vim.api.nvim_get_current_win()
-- 		if height then vim.api.nvim_win_set_height(new_win, height) end
-- 		vim.api.nvim_win_set_buf(new_win, buf)
-- 		local opts = { win = new_win }
-- 		vim.api.nvim_set_option_value("winhl",
-- 			"Normal:Normal,StatusColumn:DiagnosticInfo", opts)
-- 		vim.api.nvim_set_option_value("winblend", 0, opts)
-- 		if win_opts.statuscolumn then
-- 			vim.api.nvim_set_option_value("statuscolumn", win_opts.statuscolumn,
-- 				opts)
-- 		end
-- 		if not win_opts.focus then vim.api.nvim_set_current_win(cur_win) end
-- 		return new_win
-- 	else
-- 		vim.cmd("rightbelow vsplit")
-- 		local new_win = vim.api.nvim_get_current_win()
-- 		if width then vim.api.nvim_win_set_width(new_win, width) end
-- 		vim.api.nvim_win_set_buf(new_win, buf)
-- 		local opts = { win = new_win }
-- 		vim.api.nvim_set_option_value("winhl",
-- 			"Normal:Normal,StatusColumn:DiagnosticInfo", opts)
-- 		vim.api.nvim_set_option_value("winblend", 0, opts)
-- 		if win_opts.statuscolumn then
-- 			vim.api.nvim_set_option_value("statuscolumn", win_opts.statuscolumn,
-- 				opts)
-- 		end
-- 		if not win_opts.focus then vim.api.nvim_set_current_win(cur_win) end
-- 		return new_win
-- 	end
-- end

return M
