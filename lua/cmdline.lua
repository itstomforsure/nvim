local vim = vim
local M = {}
local state = {
	cmdline_buf = nil,
	cmdline_win = nil,
	history_buf = nil,
	history_win = nil,
	current_history_idx = 0,
	history_list = {},
}

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
	if state.cmdline_buf and vim.api.nvim_buf_is_valid(state.cmdline_buf) then
		return state.cmdline_buf
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"

	return buf
end

local function create_cmdline_win(buf)
	if state.cmdline_win and vim.api.nvim_win_is_valid(state.cmdline_win) then
		return
	end

	local width = math.min(80, vim.o.columns - 10)
	local height = 1
	local row = math.floor((vim.o.lines - height) * 0.8)
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
	vim.api.nvim_win_set_option(win, "winhl", "Normal:Normal,FloatBorder:DiagnosticInfo")
	vim.api.nvim_win_set_option(win, "winblend", 10)
	vim.api.nvim_win_set_option(win, "statuscolumn", " ꩜ : ") -- ꩜  → ☯ ᶠᶸᶜᵏᵧₒᵤ! ∞

	return win
end

local function create_history_buf(history)
	local display_lines = {}
	for i = #history, 1, -1 do
		table.insert(display_lines, history[i].display)
	end

	if state.history_buf and vim.api.nvim_buf_is_valid(state.history_buf) then
		vim.bo[state.history_buf].modifiable = true
		vim.api.nvim_buf_set_lines(state.history_buf, 0, -1, false, display_lines)
		vim.bo[state.history_buf].modifiable = false

		return state.history_buf
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)
	vim.bo[buf].modifiable = false

	return buf
end

local function update_history_highlight()
	if not state.history_buf or not vim.api.nvim_buf_is_valid(state.history_buf) then
		return
	end

	if not state.cmdline_win or not vim.api.nvim_win_is_valid(state.cmdline_win) then
		return
	end

	-- Clear existing highlights
	vim.api.nvim_buf_clear_namespace(state.history_buf, -1, 0, -1)

	-- Highlight current selection
	if state.current_history_idx == 0 then
		vim.api.nvim_win_set_option(state.cmdline_win, "statuscolumn", " ꩜ : ")
		return
	end
	if state.current_history_idx > 0 and state.current_history_idx <= #state.history_list then
		local line_idx = #state.history_list - state.current_history_idx
		vim.api.nvim_buf_add_highlight(state.history_buf, -1, "Visual", line_idx, 0, -1)

		if state.current_history_idx < 10 then
			vim.api.nvim_win_set_option(state.cmdline_win, "statuscolumn", "#" .. state.current_history_idx .. " : ")
		else
			vim.api.nvim_win_set_option(state.cmdline_win, "statuscolumn", "#" .. state.current_history_idx .. ": ")
		end

		-- Ensure the highlighted line is visible
		if state.history_win and vim.api.nvim_win_is_valid(state.history_win) then
			local win_height = vim.api.nvim_win_get_height(state.history_win)
			local line_to_show = line_idx

			-- Get current view
			local view = vim.api.nvim_win_call(state.history_win, function()
				return vim.fn.winsaveview()
			end)

			-- Scroll if necessary
			if line_to_show < view.topline or line_to_show >= view.topline + win_height then
				view.topline = math.max(0, line_to_show - math.floor(win_height / 2))
				vim.api.nvim_win_call(state.history_win, function()
					vim.fn.winrestview(view)
				end)
			end
		end
	end
end

local function update_cmdline_content()
	if not state.cmdline_buf or not vim.api.nvim_buf_is_valid(state.cmdline_buf) then
		return
	end

	local content = ""
	if state.current_history_idx > 0 and state.current_history_idx <= #state.history_list then
		content = state.history_list[state.current_history_idx].cmd
	end

	vim.bo[state.cmdline_buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.cmdline_buf, 0, -1, false, { content })
	vim.bo[state.cmdline_buf].modifiable = false

	-- Move cursor to end of line
	if state.cmdline_win and vim.api.nvim_win_is_valid(state.cmdline_win) then
		vim.api.nvim_win_set_cursor(state.cmdline_win, { 1, #content })
	end
end

local function create_history_win(history)
	if state.history_win and vim.api.nvim_win_is_valid(state.history_win) then
		update_history_highlight()
		return
	end

	if not state.history_buf or not vim.api.nvim_buf_is_valid(state.history_buf) then
		return
	end

	if not state.cmdline_win or not vim.api.nvim_win_is_valid(state.cmdline_win) then
		return
	end

	local config = vim.api.nvim_win_get_config(state.cmdline_win)
	if not config then
		return
	end
	local win = vim.api.nvim_open_win(state.history_buf, false, {
		relative = "editor",
		width = config.width,
		height = #history,
		row = config.row - #history - 1,
		col = config.col,
		style = "minimal",
		border = "rounded",
	})

	vim.api.nvim_win_set_option(win, "winhl", "Normal:Normal,FloatBorder:DiagnosticInfo")
	vim.api.nvim_win_set_option(win, "winblend", 10)

	-- Initialize selection to first item
	if #history > 0 and state.current_history_idx == 0 then
		update_cmdline_content()
	end

	update_history_highlight()

	return win
end

local function close()
	if state.cmdline_win and vim.api.nvim_win_is_valid(state.cmdline_win) then
		vim.api.nvim_win_close(state.cmdline_win, true)
		state.cmdline_buf = nil
		state.cmdline_win = nil
	end

	if state.history_win and vim.api.nvim_win_is_valid(state.history_win) then
		vim.api.nvim_win_close(state.history_win, true)
		state.history_buf = nil
		state.history_win = nil
		state.current_history_idx = 0
		state.history_list = {}
	end

	vim.cmd("stopinsert")
end

local function navigate_history(direction)
	if not state.cmdline_buf or not vim.api.nvim_buf_is_valid(state.cmdline_buf) then
		return
	end

	if #state.history_list == 0 then
		return
	end

	if direction == "up" and state.current_history_idx < #state.history_list then
		state.current_history_idx = state.current_history_idx + 1
	elseif direction == "down" and state.current_history_idx > 1 then
		state.current_history_idx = state.current_history_idx - 1
	elseif direction == "down" and state.current_history_idx == 1 then
		-- Go to empty command line
		state.current_history_idx = 0
		vim.bo[state.cmdline_buf].modifiable = true
		vim.api.nvim_buf_set_lines(state.cmdline_buf, 0, -1, false, { "" })
		if state.cmdline_win and vim.api.nvim_win_is_valid(state.cmdline_win) then
			vim.api.nvim_win_set_cursor(state.cmdline_win, { 1, 0 })
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
	if state.history_win and vim.api.nvim_win_is_valid(state.history_win) then
		return
	end

	state.history_list = get_all_history()

	if #state.history_list == 0 then
		return
	end

	state.history_buf = create_history_buf(state.history_list)
	state.history_win = create_history_win(state.history_list)
end

local function open_cmdline_win()
	state.cmdline_buf = create_cmdline_buf()
	state.cmdline_win = create_cmdline_win(state.cmdline_buf)

	local opts = { buffer = state.cmdline_buf, silent = true }
	vim.keymap.set("i", "<CR>", function()
		local line = vim.api.nvim_get_current_line()
		close()
		if line ~= "" then
			vim.cmd(line)
		end
	end, opts)

	vim.keymap.set("i", "<Esc>", function()
		close()
	end, opts)

	vim.keymap.set("i", "<Up>", function()
		if not state.history_win or not vim.api.nvim_win_is_valid(state.history_win) then
			open_history_win()
			vim.notify("Opened command history", vim.log.levels.INFO)
		end
		navigate_history("up")
	end, opts)

	vim.keymap.set("i", "<Down>", function()
		navigate_history("down")
	end, opts)

	vim.cmd("startinsert")
end

function M.setup(key)
	vim.keymap.set({ "n", "t" }, key, open_cmdline_win)
end

return M
