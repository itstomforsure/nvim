local vim = vim
local utils = require("utils")
local M = {}
local buf = nil
local win = nil
local terminals = {}
local current_index = nil
local last_win = nil
local last_buf = nil
local keybinds = {
	open = "<leader>t",
	new = "<leader>T",
	prev = nil,
	next = nil,
}

local close
local show_current
local terminal_tab_click
local terminal_tab_close

local function is_terminal_buf(target_buf)
	return utils.is_buf_valid(target_buf) and
		vim.bo[target_buf].buftype == "terminal"
end

local function remember_focus()
	local current_win = vim.api.nvim_get_current_win()
	if utils.is_win_valid(win) and current_win == win then
		return
	end

	if utils.is_win_valid(current_win) then
		last_win = current_win
		last_buf = vim.api.nvim_win_get_buf(current_win)
	end
end

local function focus_last_target()
	vim.api.nvim_feedkeys(
		vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true),
		"n",
		false
	)

	vim.schedule(function()
		if utils.is_win_valid(last_win) then
			vim.api.nvim_set_current_win(last_win)
			return
		end

		if utils.is_buf_valid(last_buf) then
			local wins = vim.fn.win_findbuf(last_buf)
			if #wins > 0 and utils.is_win_valid(wins[1]) then
				vim.api.nvim_set_current_win(wins[1])
				return
			end
		end

		close()
	end)
end

local function prune_terminals()
	local next_list = {}
	for _, term_buf in ipairs(terminals) do
		if is_terminal_buf(term_buf) then
			table.insert(next_list, term_buf)
		end
	end
	terminals = next_list

	current_index = nil
	if is_terminal_buf(buf) then
		for i, term_buf in ipairs(terminals) do
			if term_buf == buf then
				current_index = i
				break
			end
		end
	end

	if not current_index and #terminals > 0 then
		current_index = #terminals
		buf = terminals[current_index]
	elseif not current_index then
		buf = nil
	end
end

local function add_terminal(term_buf)
	for i, existing in ipairs(terminals) do
		if existing == term_buf then
			current_index = i
			buf = term_buf
			return
		end
	end

	table.insert(terminals, term_buf)
	current_index = #terminals
	buf = term_buf
end

local function remove_terminal(term_buf)
	local removed_index = nil
	for i, existing in ipairs(terminals) do
		if existing == term_buf then
			table.remove(terminals, i)
			removed_index = i
			break
		end
	end

	if not removed_index then
		return
	end

	if #terminals == 0 then
		current_index = nil
		buf = nil
		return
	end

	if current_index then
		if removed_index < current_index then
			current_index = current_index - 1
		elseif removed_index == current_index and current_index > #terminals then
			current_index = #terminals
		end
	end

	if current_index then
		buf = terminals[current_index]
	end
end

local function build_tabline()
	local total = #terminals
	if total <= 1 then
		return ""
	end

	local parts = {}
	for i = 1, total do
		local hl = (i == current_index) and "%#TabLineSel#" or "%#TabLine#"
		local click = string.format("%%%d@v:lua.TerminalTabClick@", i)
		local close_click = string.format("%%%d@v:lua.TerminalTabClose@", i)
		table.insert(parts, hl .. click .. " " .. i .. " " .. "%X")
		table.insert(parts, hl .. close_click .. " x " .. "%X")
	end
	table.insert(parts, "%#WinBar#")
	return table.concat(parts, "")
end

local function build_close_button(index)
	if not index then
		return ""
	end

	local hl = "%#TabLineSel#"
	local click = string.format("%%%d@v:lua.TerminalTabClose@", index)
	return hl .. click .. " x " .. "%X" .. "%#WinBar#"
end

local function build_hints()
	local parts = {
		"[Esc] back (t) / hide (n)",
		"[Ctrl-\\ Ctrl-n] normal",
		"[q] close",
	}

	if keybinds.new then
		table.insert(parts, "[" .. keybinds.new .. "] new")
	end
	if keybinds.prev then
		table.insert(parts, "[" .. keybinds.prev .. "] prev")
	end
	if keybinds.next then
		table.insert(parts, "[" .. keybinds.next .. "] next")
	end

	return table.concat(parts, "  ")
end

local function set_terminal_winbar()
	if not utils.is_win_valid(win) then
		return
	end

	prune_terminals()

	local label = " Terminal "
	local tabs = build_tabline()
	local close_button = ""
	if #terminals == 1 and current_index then
		close_button = " " .. build_close_button(current_index)
	end
	local winbar = label .. close_button .. tabs .. "%=" .. build_hints()
	vim.api.nvim_set_option_value("winbar", winbar, { win = win })
end

close = function()
	if utils.is_win_valid(win) then
		vim.api.nvim_win_close(win, true)
		win = nil
	end

	vim.cmd("stopinsert")
end

local function delete()
	local target_buf = buf
	prune_terminals()
	local keep_window = utils.is_win_valid(win) and #terminals > 1

	if not keep_window and utils.is_win_valid(win) then
		vim.api.nvim_win_close(win, true)
		win = nil
	end

	if utils.is_buf_valid(target_buf) then
		vim.api.nvim_buf_delete(target_buf, { force = true })
	end

	remove_terminal(target_buf)

	if keep_window and is_terminal_buf(buf) then
		show_current()
		return
	end

	vim.cmd("stopinsert")
end

local function buf_keybinds()
	local opts = { buffer = buf, silent = true }
	vim.keymap.set("t", "<Esc>", function()
		focus_last_target()
	end, opts)
	vim.keymap.set("n", "<Esc>", function()
		close()
	end, opts)
	vim.keymap.set("n", "q", function()
		delete()
	end, opts)
end

show_current = function()
	if not is_terminal_buf(buf) then
		return
	end

	win = utils.create_bottom_win(buf, win, { height = 15 })
	if utils.is_win_valid(win) then
		vim.api.nvim_set_current_win(win)
		vim.api.nvim_win_set_buf(win, buf)
	end

	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].buflisted = false
	set_terminal_winbar()
	vim.cmd("startinsert")
	buf_keybinds()
end

local function open_new()
	remember_focus()
	prune_terminals()

	local scratch_buf = nil
	if not utils.is_win_valid(win) then
		scratch_buf = utils.create_scratch_buf(nil)
	end

	if utils.is_win_valid(win) then
		vim.api.nvim_set_current_win(win)
	else
		win = utils.create_bottom_win(scratch_buf, win, { height = 15 })
		if utils.is_win_valid(win) then
			vim.api.nvim_set_current_win(win)
		end
	end

	vim.cmd("terminal")
	buf = vim.api.nvim_get_current_buf()
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].buflisted = false
	add_terminal(buf)
	set_terminal_winbar()

	if scratch_buf and utils.is_buf_valid(scratch_buf) and scratch_buf ~= buf then
		vim.api.nvim_buf_delete(scratch_buf, { force = true })
	end

	vim.cmd("startinsert")

	buf_keybinds()
end

local function open_win()
	remember_focus()
	prune_terminals()

	if not is_terminal_buf(buf) then
		if #terminals == 0 then
			open_new()
			return
		end
		current_index = #terminals
		buf = terminals[current_index]
	end

	show_current()
end

local function cycle_terminal(direction)
	remember_focus()
	prune_terminals()

	if #terminals == 0 then
		open_new()
		return
	end

	if not current_index then
		current_index = #terminals
	end

	local total = #terminals
	current_index = ((current_index - 1 + direction) % total) + 1
	buf = terminals[current_index]
	show_current()
end

local function next_terminal()
	cycle_terminal(1)
end

local function prev_terminal()
	cycle_terminal(-1)
end

terminal_tab_click = function(minwid, clicks, button, mods)
	if button ~= "l" then
		return
	end

	prune_terminals()
	local index = tonumber(minwid)
	if not index or index < 1 or index > #terminals then
		return
	end

	current_index = index
	buf = terminals[current_index]
	show_current()
end

terminal_tab_close = function(minwid, clicks, button, mods)
	if button ~= "l" then
		return
	end

	prune_terminals()
	local index = tonumber(minwid)
	if not index or index < 1 or index > #terminals then
		return
	end

	local target_buf = terminals[index]
	local target_is_current = target_buf == buf

	if utils.is_buf_valid(target_buf) then
		vim.api.nvim_buf_delete(target_buf, { force = true })
	end

	remove_terminal(target_buf)

	if #terminals == 0 then
		close()
		return
	end

	if target_is_current then
		show_current()
		return
	end

	if utils.is_win_valid(win) then
		set_terminal_winbar()
	end
end

function M.setup(config)
	if type(config) == "string" then
		config = { keybind = config }
	end
	config = config or {}

	_G.TerminalTabClick = terminal_tab_click
	_G.TerminalTabClose = terminal_tab_close

	if config.keybind ~= nil then
		keybinds.open = config.keybind
	end
	if config.new_keybind ~= nil then
		keybinds.new = config.new_keybind
	end
	if config.prev_keybind ~= nil then
		keybinds.prev = config.prev_keybind
	end
	if config.next_keybind ~= nil then
		keybinds.next = config.next_keybind
	end

	local opts = {
		noremap = true,
		silent = true,
		desc = "Open terminal window",
	}
	if keybinds.open then
		vim.keymap.set({ "n", "v" }, keybinds.open, open_win, opts)
	end

	if keybinds.new then
		local create_opts = {
			noremap = true,
			silent = true,
			desc = "Open new terminal window",
		}
		vim.keymap.set({ "n", "v" }, keybinds.new, open_new, create_opts)
	end

	if keybinds.prev then
		local prev_opts = {
			noremap = true,
			silent = true,
			desc = "Previous terminal",
		}
		vim.keymap.set({ "n", "v" }, keybinds.prev, prev_terminal, prev_opts)
	end

	if keybinds.next then
		local next_opts = {
			noremap = true,
			silent = true,
			desc = "Next terminal",
		}
		vim.keymap.set({ "n", "v" }, keybinds.next, next_terminal, next_opts)
	end
end

return M
