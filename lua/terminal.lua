local vim = vim
local utils = require("utils")
local M = {}
local buf = nil
local win = nil
local terminals = {}
local current_index = nil
local last_win = nil
local last_buf = nil
local lifecycle_group = nil
local syncing_state = false
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

local function is_tracked_terminal(target_buf)
	for _, term_buf in ipairs(terminals) do
		if term_buf == target_buf then
			return true
		end
	end
	return false
end

local function set_terminal_buf_opts(target_buf)
	if not is_terminal_buf(target_buf) then
		return
	end

	vim.bo[target_buf].bufhidden = "hide"
	vim.bo[target_buf].buflisted = false
end

local function set_terminal_window_lock(target_win, locked)
	if not utils.is_win_valid(target_win) then
		return
	end

	local opts = { win = target_win }
	pcall(vim.api.nvim_set_option_value, "winfixbuf", locked, opts)
	pcall(vim.api.nvim_set_option_value, "winfixheight", locked, opts)
end

local function set_terminal_window_buf(target_win, target_buf)
	if not utils.is_win_valid(target_win) or not utils.is_buf_valid(target_buf) then
		return false
	end

	set_terminal_window_lock(target_win, false)
	local ok = pcall(vim.api.nvim_win_set_buf, target_win, target_buf)
	set_terminal_window_lock(target_win, true)
	return ok
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

local function is_regular_candidate(target_buf, blocked_buf)
	return utils.is_buf_valid(target_buf) and
		target_buf ~= blocked_buf and
		vim.bo[target_buf].buftype == ""
end

local function find_regular_replacement(target_win, blocked_buf)
	local ok, alternate = pcall(vim.api.nvim_win_call, target_win, function()
		return vim.fn.bufnr("#")
	end)

	if ok and type(alternate) == "number" and alternate > 0 and
		is_regular_candidate(alternate, blocked_buf) then
		return alternate
	end

	for _, candidate_win in ipairs(vim.api.nvim_list_wins()) do
		if utils.is_win_valid(candidate_win) and candidate_win ~= target_win and candidate_win ~= win then
			local candidate_buf = vim.api.nvim_win_get_buf(candidate_win)
			if is_regular_candidate(candidate_buf, blocked_buf) then
				return candidate_buf
			end
		end
	end

	for _, candidate_buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.bo[candidate_buf].buflisted and
			is_regular_candidate(candidate_buf, blocked_buf) then
			return candidate_buf
		end
	end

	return nil
end

local function replace_terminal_leak(target_win, leaked_buf)
	local replacement = find_regular_replacement(target_win, leaked_buf)
	if replacement then
		pcall(vim.api.nvim_win_set_buf, target_win, replacement)
		return
	end

	pcall(vim.api.nvim_win_call, target_win, function()
		vim.cmd("enew")
	end)
end

local function sync_terminal_state()
	if syncing_state then
		return
	end

	syncing_state = true

	pcall(function()
		prune_terminals()

		if utils.is_win_valid(win) then
			local win_buf = vim.api.nvim_win_get_buf(win)

			if is_terminal_buf(win_buf) then
				add_terminal(win_buf)
				buf = win_buf
				set_terminal_buf_opts(win_buf)
				set_terminal_window_lock(win, true)
				set_terminal_winbar()
			elseif is_terminal_buf(buf) then
				set_terminal_window_buf(win, buf)
				set_terminal_buf_opts(buf)
				set_terminal_winbar()
			elseif #terminals > 0 then
				if not current_index or current_index < 1 or current_index > #terminals then
					current_index = #terminals
				end
				buf = terminals[current_index]
				if is_terminal_buf(buf) then
					set_terminal_window_buf(win, buf)
					set_terminal_buf_opts(buf)
					set_terminal_winbar()
				end
			else
				set_terminal_window_lock(win, false)
				pcall(vim.api.nvim_win_close, win, true)
				win = nil
			end
		end

		for _, term_buf in ipairs(terminals) do
			if is_terminal_buf(term_buf) then
				set_terminal_buf_opts(term_buf)
				for _, term_win in ipairs(vim.fn.win_findbuf(term_buf)) do
					if utils.is_win_valid(term_win) and term_win ~= win then
						replace_terminal_leak(term_win, term_buf)
					end
				end
			end
		end
	end)

	syncing_state = false
end

close = function()
	if utils.is_win_valid(win) then
		set_terminal_window_lock(win, false)
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
	sync_terminal_state()
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
		set_terminal_window_buf(win, buf)
		vim.api.nvim_set_current_win(win)
	end

	set_terminal_buf_opts(buf)
	set_terminal_winbar()
	sync_terminal_state()
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
		set_terminal_window_lock(win, false)
	else
		win = utils.create_bottom_win(scratch_buf, win, { height = 15 })
		if utils.is_win_valid(win) then
			vim.api.nvim_set_current_win(win)
		end
	end

	local ok = pcall(vim.cmd, "terminal")
	if not ok then
		if utils.is_win_valid(win) then
			set_terminal_window_lock(win, true)
		end
		return
	end

	buf = vim.api.nvim_get_current_buf()
	set_terminal_buf_opts(buf)
	add_terminal(buf)
	set_terminal_window_lock(win, true)
	set_terminal_winbar()

	if scratch_buf and utils.is_buf_valid(scratch_buf) and scratch_buf ~= buf then
		vim.api.nvim_buf_delete(scratch_buf, { force = true })
	end

	sync_terminal_state()
	vim.cmd("startinsert")

	buf_keybinds()
end

function M.open_win()
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

-------------------------------------------------------------------------------
-- Session persistence API
-------------------------------------------------------------------------------

--- Create a terminal buffer in a specific working directory.
--- Used internally by M.restore() to recreate saved terminals.
local function create_terminal_at(cwd)
	if not utils.is_win_valid(win) then
		local scratch = utils.create_scratch_buf(nil)
		win = utils.create_bottom_win(scratch, win, { height = 15 })
		if not utils.is_win_valid(win) then return end
		vim.api.nvim_set_current_win(win)
		if scratch and utils.is_buf_valid(scratch) and scratch ~= vim.api.nvim_win_get_buf(win) then
			pcall(vim.api.nvim_buf_delete, scratch, { force = true })
		end
	else
		vim.api.nvim_set_current_win(win)
		set_terminal_window_lock(win, false)
	end

	-- Set window-local cwd so :terminal inherits it
	if cwd and vim.fn.isdirectory(cwd) == 1 then
		vim.cmd("lcd " .. vim.fn.fnameescape(cwd))
	end

	local ok = pcall(vim.cmd, "terminal")
	if not ok then
		set_terminal_window_lock(win, true)
		return
	end

	buf = vim.api.nvim_get_current_buf()
	set_terminal_buf_opts(buf)
	add_terminal(buf)
	set_terminal_window_lock(win, true)
	set_terminal_winbar()
	buf_keybinds()
end

--- Serialize terminal state for session persistence.
--- Returns a table with terminal cwds, visibility, and current index.
function M.serialize()
	prune_terminals()
	local data = {
		terminals = {},
		visible = utils.is_win_valid(win),
		current_index = current_index,
	}
	for _, term_buf in ipairs(terminals) do
		local cwd = nil
		if utils.is_buf_valid(term_buf) then
			local pid = vim.b[term_buf].terminal_job_pid
			if pid then
				local ok, resolved = pcall(vim.uv.fs_readlink, "/proc/" .. pid .. "/cwd")
				if ok and resolved then
					cwd = resolved
				end
			end
		end
		table.insert(data.terminals, { cwd = cwd })
	end
	return data
end

--- Close all terminals and their window. Used before session restore.
function M.close_all()
	if utils.is_win_valid(win) then
		set_terminal_window_lock(win, false)
		pcall(vim.api.nvim_win_close, win, true)
		win = nil
	end

	local to_delete = {}
	for _, term_buf in ipairs(terminals) do
		table.insert(to_delete, term_buf)
	end
	terminals = {}
	buf = nil
	current_index = nil

	for _, term_buf in ipairs(to_delete) do
		if utils.is_buf_valid(term_buf) then
			pcall(vim.api.nvim_buf_delete, term_buf, { force = true })
		end
	end
end

--- Restore terminals from serialized session data.
function M.restore(data)
	if not data or not data.terminals or #data.terminals == 0 then return end

	for _, term_data in ipairs(data.terminals) do
		create_terminal_at(term_data.cwd)
	end

	-- Set current index to saved position
	if data.current_index and data.current_index >= 1 and data.current_index <= #terminals then
		current_index = data.current_index
		buf = terminals[current_index]
		if utils.is_win_valid(win) then
			set_terminal_window_buf(win, buf)
			set_terminal_winbar()
		end
	end

	if not data.visible then
		close()
	else
		vim.cmd("stopinsert")
	end
end

function M.setup(config)
	if type(config) == "string" then
		config = { keybind = config }
	end
	config = config or {}

	if not lifecycle_group then
		lifecycle_group = vim.api.nvim_create_augroup("TerminalLifecycle",
			{ clear = true })

		vim.api.nvim_create_autocmd("WinClosed", {
			group = lifecycle_group,
			callback = function(args)
				local closed_win = tonumber(args.match)
				if closed_win and closed_win == win then
					win = nil
				end
				vim.schedule(sync_terminal_state)
			end,
		})

		vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
			group = lifecycle_group,
			callback = function(args)
				if is_tracked_terminal(args.buf) then
					remove_terminal(args.buf)
				end
				vim.schedule(sync_terminal_state)
			end,
		})

		vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
			group = lifecycle_group,
			callback = function()
				vim.schedule(sync_terminal_state)
			end,
		})
	end

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
		vim.keymap.set({ "n", "v" }, keybinds.open, M.open_win, opts)
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
