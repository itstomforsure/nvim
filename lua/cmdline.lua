local vim = vim
local M = {}

local cmdline_buf = nil
local cmdline_win = nil

local history_buf = nil
local history_win = nil

local current_history_idx = 0
local history_list = {}

local function get_all_history()
	local history = {}
	local count = vim.fn.histnr(":")
	for i = count, 1, -1 do
		local cmd = vim.fn.histget(":", i)
		if cmd and cmd ~= "" then
			local display_id = count - i + 1
			local display_text = string.format("%3d: %s", display_id, cmd)
			table.insert(history, {
				id = display_id,
				cmd = cmd,
				display = display_text,
			})
		end
	end

	return history
end

local function create_cmdline_buf()
	if cmdline_buf and vim.api.nvim_buf_is_valid(cmdline_buf) then
		return cmdline_buf
	end
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

	return buf
end

local function create_cmdline_win()
	if cmdline_win and vim.api.nvim_win_is_valid(cmdline_win) then
		return
	end

	local width = math.min(80, vim.o.columns - 10)
	local height = 1
	local row = 45
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

	local win = vim.api.nvim_open_win(cmdline_buf, true, opts)
	vim.api.nvim_win_set_option(win, "winhl", "Normal:Normal,FloatBorder:DiagnosticInfo")
	vim.api.nvim_win_set_option(win, "winblend", 10)
	vim.api.nvim_win_set_option(win, "statuscolumn", "#" .. current_history_idx .. " : ") -- 🖥️

	return win
end

local function create_history_buf(history)
	local display_lines = {}
	for i = #history, 1, -1 do
		table.insert(display_lines, history[i].display)
	end

	if history_buf and vim.api.nvim_buf_is_valid(history_buf) then
		vim.api.nvim_buf_set_option(history_buf, "modifiable", true)
		vim.api.nvim_buf_set_lines(history_buf, 0, -1, false, display_lines)
		vim.api.nvim_buf_set_option(history_buf, "modifiable", false)
		return history_buf
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)

	return buf
end

local function update_history_highlight()
	if not history_buf or not vim.api.nvim_buf_is_valid(history_buf) then
		return
	end

	-- Clear existing highlights
	vim.api.nvim_buf_clear_namespace(history_buf, -1, 0, -1)

	-- Highlight current selection
	if current_history_idx > 0 and current_history_idx <= #history_list then
		local line_idx = #history_list - current_history_idx
		vim.api.nvim_buf_add_highlight(history_buf, -1, "Visual", line_idx, 0, -1)
		vim.api.nvim_win_set_option(cmdline_win, "statuscolumn", "#" .. current_history_idx .. " : ")

		-- Ensure the highlighted line is visible
		if history_win and vim.api.nvim_win_is_valid(history_win) then
			local win_height = vim.api.nvim_win_get_height(history_win)
			local line_to_show = line_idx

			-- Get current view
			local view = vim.api.nvim_win_call(history_win, function()
				return vim.fn.winsaveview()
			end)

			-- Scroll if necessary
			if line_to_show < view.topline or line_to_show >= view.topline + win_height then
				view.topline = math.max(0, line_to_show - math.floor(win_height / 2))
				vim.api.nvim_win_call(history_win, function()
					vim.fn.winrestview(view)
				end)
			end
		end
	end
end

local function update_cmdline_content()
	if not cmdline_buf or not vim.api.nvim_buf_is_valid(cmdline_buf) then
		return
	end

	local content = ""
	if current_history_idx > 0 and current_history_idx <= #history_list then
		content = history_list[current_history_idx].cmd
	end

	vim.api.nvim_buf_set_option(cmdline_buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(cmdline_buf, 0, -1, false, { content })
	vim.api.nvim_buf_set_option(cmdline_buf, "modifiable", true)

	-- Move cursor to end of line
	if cmdline_win and vim.api.nvim_win_is_valid(cmdline_win) then
		vim.api.nvim_win_set_cursor(cmdline_win, { 1, #content })
	end
end

local function create_history_win(history)
	if history_win and vim.api.nvim_win_is_valid(history_win) then
		update_history_highlight()
		return
	end

	local cmdline_config = vim.api.nvim_win_get_config(cmdline_win)
	local width = cmdline_config.width
	local height = math.max(1, #history)
	local row = cmdline_config.row - height - 1 -- above cmdline; cmdline_config.row + 2 -- below cmdline

	local win = vim.api.nvim_open_win(history_buf, false, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = cmdline_config.col,
		style = "minimal",
		border = "rounded",
	})

	vim.api.nvim_win_set_option(win, "winhl", "Normal:Normal,FloatBorder:DiagnosticInfo")
	vim.api.nvim_win_set_option(win, "winblend", 10)

	-- Initialize selection to first item
	if #history > 0 and current_history_idx == 0 then
		update_cmdline_content()
	end

	update_history_highlight()

	return win
end

local function close()
	if cmdline_win and vim.api.nvim_win_is_valid(cmdline_win) then
		vim.api.nvim_win_close(cmdline_win, true)
		cmdline_buf = nil
		cmdline_win = nil
	end

	if history_win and vim.api.nvim_win_is_valid(history_win) then
		vim.api.nvim_win_close(history_win, true)
		history_buf = nil
		history_win = nil
	end

	current_history_idx = 0
	history_list = {}

	vim.cmd("stopinsert")
end

local function navigate_history(direction)
	if #history_list == 0 then
		return
	end

	if direction == "up" and current_history_idx < #history_list then
		current_history_idx = current_history_idx + 1
	elseif direction == "down" and current_history_idx > 1 then
		current_history_idx = current_history_idx - 1
	elseif direction == "down" and current_history_idx == 1 then
		-- Go to empty command line
		current_history_idx = 0
		vim.api.nvim_buf_set_option(cmdline_buf, "modifiable", true)
		vim.api.nvim_buf_set_lines(cmdline_buf, 0, -1, false, { "" })
		if cmdline_win and vim.api.nvim_win_is_valid(cmdline_win) then
			vim.api.nvim_win_set_cursor(cmdline_win, { 1, 0 })
		end
		update_history_highlight()
		return
	else
		return
	end

	update_cmdline_content()
	update_history_highlight()
end

local function open_history_win()
	if history_win and vim.api.nvim_win_is_valid(history_win) then
		return
	end

	history_list = get_all_history()

	if #history_list == 0 then
		return
	end

	history_buf = create_history_buf(history_list)
	history_win = create_history_win(history_list)
end

local function setup_cmdline_keymaps()
	local opts_keymap = { buffer = cmdline_buf, silent = true }

	-- Enter to execute command
	vim.keymap.set("i", "<CR>", function()
		local line = vim.api.nvim_get_current_line()
		close()
		if line ~= "" then
			vim.cmd(line)
		end
	end, opts_keymap)

	-- Escape to close
	vim.keymap.set("i", "<Esc>", function()
		close()
	end, opts_keymap)

	-- Up/Down to navigate history - ONLY when cmdline window is focused
	vim.keymap.set("i", "<Up>", function()
		if not history_win or not vim.api.nvim_win_is_valid(history_win) then
			open_history_win()
		end
		navigate_history("up")
	end, opts_keymap)

	vim.keymap.set("i", "<Down>", function()
		navigate_history("down")
	end, opts_keymap)
end

local function open_cmdline_win()
	cmdline_buf = create_cmdline_buf()
	cmdline_win = create_cmdline_win()

	vim.cmd("startinsert")
	setup_cmdline_keymaps()
end

function M.setup()
	vim.keymap.set({ "n", "t" }, ":", open_cmdline_win)
	vim.keymap.set({ "n", "t" }, ";", open_cmdline_win)
end

return M
