local vim = vim
local symbols = require("symbols")
local utils = require("utils")
local M = {}
local command_line = {
	buf = nil,
	win = nil,
}
local command_history = {
	buf = nil,
	win = nil,
	list = {},
	selected_id = 0,
}

local function close()
	if utils.is_win_valid(command_line.win) then
		vim.api.nvim_win_close(command_line.win, true)
		command_line.win = nil
	end

	if utils.is_buf_valid(command_line.buf) then
		vim.api.nvim_buf_delete(command_line.buf, { force = true })
		command_line.buf = nil
	end

	if utils.is_win_valid(command_history.win) then
		vim.api.nvim_win_close(command_history.win, true)
		command_history.win = nil
	end

	if utils.is_buf_valid(command_history.buf) then
		vim.api.nvim_buf_delete(command_history.buf, { force = true })
		command_history.buf = nil
		command_history.selected_id = 0
		command_history.list = {}
	end

	vim.cmd("stopinsert")
end

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

local function update_command_line_content()
	if not utils.is_buf_valid(command_line.buf) or not utils.is_win_valid(command_line.win) then
		return
	end

	local content = ""
	if command_history.selected_id > 0 and command_history.selected_id <= #command_history.list then
		content = command_history.list[command_history.selected_id].cmd
	end

	vim.bo[command_line.buf].modifiable = true
	vim.api.nvim_buf_set_lines(command_line.buf, 0, -1, false, { content })
	vim.api.nvim_buf_clear_namespace(command_line.buf, -1, 0, -1)
	vim.api.nvim_buf_set_extmark(command_line.buf, vim.api.nvim_create_namespace("searchinfo"), 0, 0, {
		virt_text = { { command_history.selected_id .. "/" .. #command_history.list .. " " } },
		virt_text_pos = "right_align",
	})
	vim.bo[command_line.buf].modifiable = false

	vim.api.nvim_win_set_cursor(command_line.win, { 1, #content })
end

local function update_command_history_highlight()
	if not utils.is_win_valid(command_line.win) or not utils.is_buf_valid(command_history.buf) then
		return
	end

	vim.api.nvim_buf_clear_namespace(command_history.buf, -1, 0, -1)

	if command_history.selected_id > 0 and command_history.selected_id <= #command_history.list then
		local line_id = #command_history.list - command_history.selected_id
		vim.api.nvim_buf_add_highlight(command_history.buf, -1, "Visual", line_id, 0, -1)

		if command_history.win and vim.api.nvim_win_is_valid(command_history.win) then
			local win_height = vim.api.nvim_win_get_height(command_history.win)
			local line_to_show = line_id
			local view = vim.api.nvim_win_call(command_history.win, function()
				return vim.fn.winsaveview()
			end)

			if line_to_show < view.topline or line_to_show >= view.topline + win_height then
				view.topline = math.max(0, line_to_show - math.floor(win_height) + 2)
				vim.api.nvim_win_call(command_history.win, function()
					vim.fn.winrestview(view)
				end)
			end
		end
	end
end

local function navigate_command_history(direction)
	if not utils.is_buf_valid(command_line.buf) then
		return
	end

	if #command_history.list == 0 then
		return
	end

	command_history.selected_id = command_history.selected_id + direction

	if command_history.selected_id < 0 then
		command_history.selected_id = 0
	elseif command_history.selected_id > #command_history.list then
		command_history.selected_id = #command_history.list
	end

	if command_history.selected_id == 0 then
		vim.bo[command_line.buf].modifiable = true
		vim.api.nvim_buf_set_lines(command_line.buf, 0, -1, false, { "" })
		vim.api.nvim_buf_clear_namespace(command_line.buf, -1, 0, -1)

		if utils.is_win_valid(command_line.win) then
			vim.api.nvim_win_set_cursor(command_line.win, { 1, 0 })
		end

		update_command_history_highlight()
		return
	end

	update_command_line_content()
	update_command_history_highlight()
end

local function open_command_history_win()
	if utils.is_win_valid(command_history.win) then
		update_command_history_highlight()
		return
	end

	local command_line_win_config = vim.api.nvim_win_get_config(command_line.win)
	if not command_line_win_config then
		return
	end

	command_history.list = get_all_history()
	if not #command_history.list then
		return
	end

	local display_lines = {}
	for i = #command_history.list, 1, -1 do
		table.insert(display_lines, command_history.list[i].display)
	end

	command_history.buf = utils.create_scratch_buf(command_history.buf)
	vim.bo[command_history.buf].modifiable = true
	vim.api.nvim_buf_set_lines(command_history.buf, 0, -1, false, display_lines)
	vim.bo[command_history.buf].modifiable = false

	local current_win = vim.api.nvim_get_current_win()
	command_history.win = utils.create_floating_win(command_history.buf, command_history.win, {
		height = math.min(40, #command_history.list),
		width = command_line_win_config.width,
		row = command_line_win_config.row - math.min(40, #command_history.list) - 1,
		col = command_line_win_config.col,
	})

	if utils.is_win_valid(current_win) then
		vim.api.nvim_set_current_win(current_win)
	end

	if #command_history.list > 0 and command_history.selected_id == 0 then
		update_command_line_content()
	end

	update_command_history_highlight()
end

local function buf_keybinds(buf, win)
	local opts = { buffer = buf, silent = true }

	vim.keymap.set("i", "<CR>", function()
		local line = vim.api.nvim_get_current_line()
		close()
		if line ~= "" then
			vim.cmd(line)
		end
	end, opts)

	vim.keymap.set({ "i", "n" }, "<Esc>", function()
		close()
	end, opts)

	vim.keymap.set("i", "<Up>", function()
		if not utils.is_win_valid(win) then
			open_command_history_win()
		end
		navigate_command_history(1)
	end, opts)

	vim.keymap.set("i", "<Down>", function()
		navigate_command_history(-1)
	end, opts)
end

local function open_command_line_win()
	command_line.buf = utils.create_scratch_buf(command_line.buf)
	command_line.win = utils.create_floating_win(command_line.buf, command_line.win, {
		width = math.min(80, vim.o.columns - 10),
		height = 1,
		row = math.floor((vim.o.lines - 1) * 0.8),
		col = math.floor((vim.o.columns - math.min(80, vim.o.columns - 10)) / 2),
		statuscolumn = " " .. symbols.dev.command .. " ",
	})

	vim.cmd("startinsert")

	buf_keybinds(command_line.buf, command_history.win)
end

function M.setup(key)
	local opts = {
		noremap = true,
		silent = true,
		desc = "Open command line",
	}
	vim.keymap.set({ "n", "v" }, key, open_command_line_win, opts)
end

return M
