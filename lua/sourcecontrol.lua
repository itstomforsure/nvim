-------------------------------------------------------------------------------
-- Source Control
-------------------------------------------------------------------------------
-- VSCode-like source control panel for the explorer zone.
-- Shows staged changes, unstaged changes, and untracked files.
--
-- Layout:
--   ┌─────────────────────┐
--   │ commit message...   │  ← input_win (editable, 1 line)
--   ├─────────────────────┤
--   │  ✓ Commit           │  ← clickable button
--   │                     │
--   │  Staged Changes (2) │
--   │  ├── M  file.lua    │  ← main list_win
--   │  └── A  new.lua     │
--   │ ...                 │
--   └─────────────────────┘
--
-- Keymaps (list buffer):
--   <CR> / click  Open file diff / toggle section
--   s/-           Stage or unstage file under cursor
--   S             Stage all changes
--   U             Unstage all
--   r             Refresh
--   q             Close panel

local vim = vim
local M = {}

local NS = vim.api.nvim_create_namespace("sourcecontrol")
local DIFF_NS = vim.api.nvim_create_namespace("sourcecontrol_diff")
local INPUT_NS = vim.api.nvim_create_namespace("sourcecontrol_input")
local symbols = require("symbols")

vim.api.nvim_set_hl(0, "SCButton", { link = "PmenuSel" })
vim.api.nvim_set_hl(0, "SCPlaceholder", { link = "Comment" })
vim.api.nvim_set_hl(0, "SCSelectorActive", { link = "TabLineSel" })
vim.api.nvim_set_hl(0, "SCSelectorInactive", { link = "TabLine" })
vim.api.nvim_set_hl(0, "SCSelectorFill", { link = "TabLineFill" })

local state = {
	buf = nil,
	win = nil,
	input_buf = nil,
	input_win = nil,
	width = 40,
	line_map = {},
	branch = "",
	ahead_count = 0,
	commits = {},
	has_changes = false,
	sections = {
		{ key = "commits",   label = "Commits",        items = {}, collapsed = false },
		{ key = "staged",    label = "Staged Changes", items = {}, collapsed = false },
		{ key = "changes",   label = "Changes",        items = {}, collapsed = false },
		{ key = "untracked", label = "Untracked",      items = {}, collapsed = false },
	},
}

local STATUS_HL = {
	M = "WarningMsg",
	A = "String",
	D = "ErrorMsg",
	R = "Function",
	C = "String",
	["?"] = "Comment",
}

local function get_section(key)
	for _, s in ipairs(state.sections) do
		if s.key == key then return s end
	end
end

local function file_icon(filename)
	local ok, devicons = pcall(require, "nvim-web-devicons")
	if not ok then return "", "Normal" end
	local name = vim.fn.fnamemodify(filename, ":t")
	local ext = vim.fn.fnamemodify(filename, ":e")
	local icon, hl = devicons.get_icon(name, ext, { default = true })
	return icon or "", hl or "Normal"
end

local function git_root()
	local root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub(
		"\n", "")
	if vim.v.shell_error == 0 and root ~= "" then
		return root
	end
	return vim.fn.getcwd()
end

local function parse_status()
	for _, sec in ipairs(state.sections) do
		sec.items = {}
	end

	state.branch = vim.fn.system("git branch --show-current 2>/dev/null"):gsub("\n", "")
	if state.branch == "" then
		state.branch = "detached"
	end

	-- Ahead count (unpushed commits)
	local ahead_str = vim.fn.system(
		"git rev-list --count @{upstream}..HEAD 2>/dev/null"):gsub("\n", "")
	state.ahead_count = (vim.v.shell_error == 0) and tonumber(ahead_str) or 0

	-- Unpushed commit list
	state.commits = {}
	if state.ahead_count > 0 then
		local log = vim.fn.systemlist(
			{ "git", "log", "@{upstream}..HEAD", "--pretty=format:%h|%s" })
		if vim.v.shell_error == 0 then
			for _, entry in ipairs(log) do
				local hash, subject = entry:match("^(%S+)|(.*)$")
				if hash then
					table.insert(state.commits, { hash = hash, subject = subject })
				end
			end
		end
	end
	get_section("commits").items = state.commits

	-- File status
	local output = vim.fn.systemlist("git status --porcelain=v1 2>/dev/null")
	if vim.v.shell_error ~= 0 then return end

	for _, line in ipairs(output) do
		if #line >= 3 then
			local x = line:sub(1, 1)
			local y = line:sub(2, 2)
			local path = line:sub(4)
			local display = path:match("-> (.+)$") or path

			if x == "?" then
				table.insert(get_section("untracked").items, { status = "?", file = display })
			else
				if x ~= " " then
					table.insert(get_section("staged").items, { status = x, file = display })
				end
				if y ~= " " then
					table.insert(get_section("changes").items, { status = y, file = display })
				end
			end
		end
	end

	state.has_changes = #get_section("staged").items > 0
		or #get_section("changes").items > 0
		or #get_section("untracked").items > 0
end

-- Commit ---------------------------------------------------------------------

local function get_commit_msg()
	if not state.input_buf or not vim.api.nvim_buf_is_valid(state.input_buf) then
		return ""
	end
	local lines = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false)
	return vim.trim(table.concat(lines, "\n"))
end

local function do_commit()
	local msg = get_commit_msg()
	if msg == "" then
		vim.notify("Empty commit message", vim.log.levels.WARN)
		if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
			vim.api.nvim_set_current_win(state.input_win)
			vim.cmd("startinsert")
		end
		return
	end
	local output = vim.fn.system("git commit -m " .. vim.fn.shellescape(msg))
	if vim.v.shell_error ~= 0 then
		vim.notify("Commit failed: " .. vim.trim(output), vim.log.levels.ERROR)
	else
		vim.notify("Committed: " .. msg, vim.log.levels.INFO)
		if state.input_buf and vim.api.nvim_buf_is_valid(state.input_buf) then
			vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { "" })
		end
	end
	M.refresh()
end

local function do_push()
	if state.ahead_count == 0 then
		vim.notify("Nothing to push", vim.log.levels.INFO)
		return
	end
	vim.notify("Pushing to remote...", vim.log.levels.INFO)
	local output = vim.fn.system("git push 2>&1")
	if vim.v.shell_error ~= 0 then
		vim.notify("Push failed: " .. vim.trim(output), vim.log.levels.ERROR)
	else
		vim.notify("Pushed " .. state.ahead_count .. " commit(s)", vim.log.levels.INFO)
	end
	M.refresh()
end

local function do_pull()
	vim.notify("Pulling from remote...", vim.log.levels.INFO)
	local output = vim.fn.system("git pull 2>&1")
	if vim.v.shell_error ~= 0 then
		vim.notify("Pull failed: " .. vim.trim(output), vim.log.levels.ERROR)
	else
		vim.notify(vim.trim(output), vim.log.levels.INFO)
	end
	M.refresh()
end

-- Input placeholder ----------------------------------------------------------

local function update_placeholder()
	if not state.input_buf or not vim.api.nvim_buf_is_valid(state.input_buf) then return end
	vim.api.nvim_buf_clear_namespace(state.input_buf, INPUT_NS, 0, -1)
	local lines = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false)
	local empty = #lines == 0 or (#lines == 1 and lines[1] == "")
	if empty then
		vim.api.nvim_buf_set_extmark(state.input_buf, INPUT_NS, 0, 0, {
			virt_text = { { "Message (Enter to commit)", "SCPlaceholder" } },
			virt_text_pos = "overlay",
		})
	end
end

-- Render ---------------------------------------------------------------------

function M.render()
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end

	vim.bo[state.buf].modifiable = true

	local lines = {}
	local hls = {}
	local extmarks = {}
	state.line_map = {}

	local function add(text, data)
		lines[#lines + 1] = text
		if data then
			state.line_map[#lines] = data
		end
		return #lines - 1 -- 0-indexed for highlights
	end

	local function hl_line(lnum, group)
		hls[#hls + 1] = { lnum, 0, -1, group }
	end

	local function hl_range(lnum, col_start, col_end, group)
		hls[#hls + 1] = { lnum, col_start, col_end, group }
	end

	-- Branch header
	local branch_text = symbols.vcs.branch .. state.branch
	local lnum = add(branch_text)
	hl_line(lnum, "Title")

	-- Dynamic button: Sync or Commit
	local btn_text, btn_type
	if not state.has_changes and state.ahead_count > 0 then
		btn_text = string.format("  ↑ Sync %d", state.ahead_count)
		btn_type = "sync"
	else
		btn_text = "  ✓ Commit"
		btn_type = "commit"
	end
	lnum = add(btn_text, { type = "button", action = btn_type })
	table.insert(extmarks, { lnum, "SCButton" })

	add("")

	-- Sections
	for _, sec in ipairs(state.sections) do
		local chevron = sec.collapsed and " " or " "
		local header = string.format(" %s %s (%d)", chevron, sec.label, #sec.items)
		lnum = add(header, { type = "section", key = sec.key })
		hl_line(lnum, "Directory")

		if not sec.collapsed then
			if #sec.items == 0 then
				local empty_label = sec.key == "commits" and "No unpushed commits" or ("No " .. sec.label:lower())
				lnum = add("  └── " .. empty_label)
				hl_range(lnum, 0, #("  └── "), "NonText")
				hl_range(lnum, #("  └── "), -1, "Comment")
			elseif sec.key == "commits" then
				-- Render commit items
				for i, item in ipairs(sec.items) do
					local is_last = (i == #sec.items)
					local connector = is_last and "└── " or "├── "
					local prefix = "  " .. connector
					local text = prefix .. item.hash .. " " .. item.subject

					lnum = add(text, {
						type = "commit",
						hash = item.hash,
						subject = item.subject,
					})

					-- Tree guide
					hl_range(lnum, 0, #prefix, "NonText")
					-- Hash
					hl_range(lnum, #prefix, #prefix + #item.hash, "Function")
					-- Subject
					hl_range(lnum, #prefix + #item.hash + 1, -1, "Normal")
				end
			else
				-- Render file items
				for i, item in ipairs(sec.items) do
					local is_last = (i == #sec.items)
					local connector = is_last and "└── " or "├── "
					local icon, icon_hl = file_icon(item.file)
					local status_str = item.status
					local prefix = "  " .. connector
					local text = prefix .. status_str .. " " .. icon .. " " .. item.file

					lnum = add(text, {
						type = "file",
						section = sec.key,
						index = i,
						file = item.file,
						status = item.status,
					})

					-- Highlight tree guide
					hl_range(lnum, 0, #prefix, "NonText")

					-- Highlight status letter
					local s_start = #prefix
					local s_end = s_start + #status_str
					hl_range(lnum, s_start, s_end, STATUS_HL[item.status] or "Normal")

					-- Highlight file icon
					local i_start = s_end + 1
					local i_end = i_start + #icon
					hl_range(lnum, i_start, i_end, icon_hl)
				end
			end
		end

		add("")
	end

	-- Help
	lnum = add(" s:stage  S:all  p:pull  P:push  r:refresh  q:close")
	hl_line(lnum, "Comment")

	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)

	vim.api.nvim_buf_clear_namespace(state.buf, NS, 0, -1)
	for _, h in ipairs(hls) do
		vim.api.nvim_buf_add_highlight(state.buf, NS, h[4], h[1], h[2], h[3])
	end
	for _, em in ipairs(extmarks) do
		vim.api.nvim_buf_set_extmark(state.buf, NS, em[1], 0,
			{ line_hl_group = em[2] })
	end

	vim.bo[state.buf].modifiable = false
	update_placeholder()
end

-- Stage/unstage --------------------------------------------------------------

local function toggle_stage()
	local pos = vim.api.nvim_win_get_cursor(0)
	local d = state.line_map[pos[1]]
	if not d or d.type ~= "file" then return end

	local cmd
	if d.section == "staged" then
		cmd = "git reset HEAD -- " .. vim.fn.shellescape(d.file)
	else
		cmd = "git add -- " .. vim.fn.shellescape(d.file)
	end

	local output = vim.fn.system(cmd)
	if vim.v.shell_error ~= 0 then
		vim.notify("Git error: " .. vim.trim(output), vim.log.levels.ERROR)
		return
	end

	M.refresh()
	local max_line = vim.api.nvim_buf_line_count(state.buf)
	pcall(vim.api.nvim_win_set_cursor, 0, { math.min(pos[1], max_line), 0 })
end

-- Diff view ------------------------------------------------------------------

local DIFF_LABELS = {
	changes = "(Working Tree)",
	staged = "(Staged)",
	untracked = "(Untracked)",
}

local function lines_to_text(tbl)
	if #tbl == 0 then return "" end
	return table.concat(tbl, "\n") .. "\n"
end

function M.show_diff(file, section)
	local buf = vim.api.nvim_get_current_buf()

	vim.api.nvim_buf_clear_namespace(buf, DIFF_NS, 0, -1)

	local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	if section == "untracked" then
		for i = 0, #current_lines - 1 do
			vim.api.nvim_buf_set_extmark(buf, DIFF_NS, i, 0,
				{ line_hl_group = "DiffAdd" })
		end
		vim.b[buf].sc_diff_active = true
		vim.b[buf].sc_diff_label = DIFF_LABELS[section]
		M._setup_diff_autoclear(buf)
		return
	end

	local ref = section == "staged" and "HEAD" or ""
	local git_ref = (ref == "" and ":" or ref .. ":") .. file
	local base_lines = vim.fn.systemlist({ "git", "show", git_ref })
	if vim.v.shell_error ~= 0 then
		base_lines = {}
	end

	local base_text = lines_to_text(base_lines)
	local current_text = lines_to_text(current_lines)

	local ok, hunks = pcall(vim.diff, base_text, current_text,
		{ result_type = "indices" })
	if not ok or not hunks or #hunks == 0 then return end

	for _, hunk in ipairs(hunks) do
		local a_start, a_count, b_start, b_count = unpack(hunk)

		if b_count > 0 then
			for i = b_start, b_start + b_count - 1 do
				if i >= 1 and i <= #current_lines then
					vim.api.nvim_buf_set_extmark(buf, DIFF_NS, i - 1, 0, {
						line_hl_group = "DiffAdd",
					})
				end
			end
		end

		if a_count > 0 then
			local virt_lines = {}
			for i = a_start, a_start + a_count - 1 do
				local content = base_lines[i] or ""
				table.insert(virt_lines, {
					{ content .. string.rep(" ", 300), "DiffDelete" },
				})
			end

			if b_count > 0 then
				vim.api.nvim_buf_set_extmark(buf, DIFF_NS, b_start - 1, 0, {
					virt_lines = virt_lines,
					virt_lines_above = true,
				})
			elseif b_start >= #current_lines then
				vim.api.nvim_buf_set_extmark(buf, DIFF_NS,
					math.max(0, #current_lines - 1), 0, {
						virt_lines = virt_lines,
					})
			else
				vim.api.nvim_buf_set_extmark(buf, DIFF_NS, b_start, 0, {
					virt_lines = virt_lines,
					virt_lines_above = true,
				})
			end
		end
	end

	vim.b[buf].sc_diff_active = true
	vim.b[buf].sc_diff_label = DIFF_LABELS[section]
	M._setup_diff_autoclear(buf)
end

function M._setup_diff_autoclear(bufnr)
	local group = vim.api.nvim_create_augroup("SCDiff_" .. bufnr,
		{ clear = true })
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = group,
		buffer = bufnr,
		once = true,
		callback = function()
			vim.api.nvim_buf_clear_namespace(bufnr, DIFF_NS, 0, -1)
			vim.b[bufnr].sc_diff_active = nil
			vim.b[bufnr].sc_diff_label = nil
		end,
	})
end

-- Keymaps --------------------------------------------------------------------

local function activate_line()
	local d = state.line_map[vim.api.nvim_win_get_cursor(0)[1]]
	if not d then return end
	if d.type == "section" then
		get_section(d.key).collapsed = not get_section(d.key).collapsed
		M.render()
	elseif d.type == "file" then
		local path = git_root() .. "/" .. d.file
		local section = d.section
		require("layout").open_in_editor(path)
		vim.schedule(function()
			M.show_diff(d.file, section)
		end)
	elseif d.type == "commit" then
		vim.schedule(function()
			local layout = require("layout")
			local editor_win = layout.get_editor_win()
			if editor_win then
				vim.api.nvim_set_current_win(editor_win)
			end
			local diff = vim.fn.systemlist("git show --stat --patch " .. d.hash)
			local scratch = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_lines(scratch, 0, -1, false, diff)
			vim.bo[scratch].buftype = "nofile"
			vim.bo[scratch].filetype = "git"
			vim.bo[scratch].modifiable = false
			vim.api.nvim_buf_set_name(scratch, d.hash .. " " .. d.subject)
			vim.api.nvim_set_current_buf(scratch)
		end)
	elseif d.type == "button" then
		if d.action == "sync" then
			do_push()
		else
			do_commit()
		end
	end
end

local function setup_list_keymaps()
	local o = { buffer = state.buf, nowait = true, silent = true }

	vim.keymap.set("n", "<CR>", activate_line, o)
	vim.keymap.set("n", "<2-LeftMouse>", activate_line, o)
	vim.keymap.set("n", "<LeftRelease>", activate_line, o)

	vim.keymap.set("n", "s", toggle_stage, o)
	vim.keymap.set("n", "-", toggle_stage, o)

	vim.keymap.set("n", "S", function()
		vim.fn.system("git add -A")
		M.refresh()
	end, o)

	vim.keymap.set("n", "U", function()
		vim.fn.system("git reset HEAD")
		M.refresh()
	end, o)

	vim.keymap.set("n", "P", do_push, o)
	vim.keymap.set("n", "p", do_pull, o)

	vim.keymap.set("n", "r", function() M.refresh() end, o)
	vim.keymap.set("n", "q", function() M.close() end, o)
end

local function setup_input_keymaps()
	local o = { buffer = state.input_buf, nowait = true, silent = true }

	vim.keymap.set("i", "<CR>", function()
		vim.cmd("stopinsert")
		vim.schedule(do_commit)
	end, o)

	vim.keymap.set("n", "<CR>", do_commit, o)
	vim.keymap.set("n", "q", function() M.close() end, o)
end

-- Buffers & windows ----------------------------------------------------------

local function create_input_buf()
	state.input_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[state.input_buf].buftype = "nofile"
	vim.bo[state.input_buf].bufhidden = "hide"
	vim.bo[state.input_buf].swapfile = false
	vim.bo[state.input_buf].filetype = "sourcecontrol_input"

	setup_input_keymaps()

	local grp = vim.api.nvim_create_augroup("SCInput", { clear = true })
	vim.api.nvim_create_autocmd(
		{ "TextChanged", "TextChangedI", "InsertLeave", "BufEnter" }, {
			group = grp,
			buffer = state.input_buf,
			callback = update_placeholder,
		})

	update_placeholder()
end

local function create_list_buf()
	state.buf = vim.api.nvim_create_buf(false, true)
	vim.bo[state.buf].filetype = "sourcecontrol"
	vim.bo[state.buf].buftype = "nofile"
	vim.bo[state.buf].bufhidden = "hide"
	vim.bo[state.buf].swapfile = false
	vim.bo[state.buf].modifiable = false
	setup_list_keymaps()
end

local function set_win_opts(win)
	local wo = vim.wo[win]
	wo.number = false
	wo.relativenumber = false
	wo.signcolumn = "no"
	wo.winfixwidth = true
	wo.wrap = false
	wo.foldcolumn = "0"
	wo.spell = false
	wo.list = false
	wo.statuscolumn = ""
end

-- Sidebar selector -----------------------------------------------------------

local function is_explorer_open()
	local ok, pickers = pcall(function()
		return Snacks.picker.get({
			source =
			"explorer"
		})
	end)
	return ok and pickers and #pickers > 0
end

local function active_panel()
	if M.is_open() then return "sc" end
	if is_explorer_open() then return "explorer" end
	return nil
end

local function selector_statusline()
	local panel = active_panel()
	local explorer_hl = panel == "explorer" and "%#SCSelectorActive#" or
		"%#SCSelectorInactive#"
	local sc_hl = panel == "sc" and "%#SCSelectorActive#" or
		"%#SCSelectorInactive#"

	return table.concat({
		"%#SCSelectorFill#",
		explorer_hl,
		"%@v:lua.SCSelectExplorer@",
		" " .. symbols.misc.folder .. "Explorer ",
		"%X",
		sc_hl,
		"%@v:lua.SCSelectSourceControl@",
		" " .. symbols.vcs.git .. "Source Control ",
		"%X",
		"%#SCSelectorFill#%=",
	})
end

_G.SCSelectExplorer = function(_, _, btn)
	if btn ~= "l" then return end
	vim.schedule(function()
		local sc = require("sourcecontrol")
		if sc.is_open() then sc.close() end
		local exp = Snacks.picker.get({ source = "explorer" })[1]
		if exp then
			exp:focus()
		else
			Snacks.explorer.open()
		end
		sc.apply_selector()
	end)
end

_G.SCSelectSourceControl = function(_, _, btn)
	if btn ~= "l" then return end
	vim.schedule(function()
		local sc = require("sourcecontrol")
		if not sc.is_open() then
			sc.open()
		else
			sc.focus()
		end
	end)
end

function M.apply_selector()
	local stl = selector_statusline()

	-- Apply to SC windows
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.wo[state.win].statusline = stl
	end
	if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
		vim.wo[state.input_win].statusline = stl
	end

	-- Apply to explorer windows
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(w) then
			local ft = vim.bo[vim.api.nvim_win_get_buf(w)].filetype
			if ft == "snacks_layout_box" or ft == "snacks_picker_list" then
				vim.wo[w].statusline = stl
			end
		end
	end
end

local function get_explorer_width()
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(w) then
			local ft = vim.bo[vim.api.nvim_win_get_buf(w)].filetype
			if ft == "snacks_layout_box" or ft == "snacks_picker_list" then
				return vim.api.nvim_win_get_width(w)
			end
		end
	end
	return 40
end

function M.open()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_set_current_win(state.win)
		M.refresh()
		return
	end

	state.width = get_explorer_width()

	-- Close explorer if open
	pcall(function()
		local exp = Snacks.picker.get({ source = "explorer" })[1]
		if exp then exp:close() end
	end)

	-- Create buffers if needed
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		create_list_buf()
	end
	if not state.input_buf or not vim.api.nvim_buf_is_valid(state.input_buf) then
		create_input_buf()
	end

	-- Create main list window (left vsplit)
	vim.cmd("topleft vsplit")
	state.win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(state.win, state.buf)
	vim.api.nvim_win_set_width(state.win, state.width)
	set_win_opts(state.win)
	vim.wo[state.win].cursorline = true

	-- Create input window above the list (split within the SC column)
	vim.cmd("aboveleft split")
	state.input_win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(state.input_win, state.input_buf)
	vim.api.nvim_win_set_height(state.input_win, 1)
	set_win_opts(state.input_win)
	vim.wo[state.input_win].winfixheight = true
	vim.wo[state.input_win].cursorline = false
	vim.wo[state.input_win].winhighlight = "Normal:NormalFloat"

	-- Tag both windows as explorer zone
	local layout = require("layout")
	layout.tag_win(state.win, "explorer")
	layout.tag_win(state.input_win, "explorer")

	-- Focus list window
	vim.api.nvim_set_current_win(state.win)
	M.refresh()
	M.apply_selector()
end

function M.focus()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_set_current_win(state.win)
	end
end

function M.close()
	if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
		vim.api.nvim_win_close(state.input_win, true)
	end
	state.input_win = nil

	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, true)
	end
	state.win = nil

	vim.schedule(function() M.apply_selector() end)
end

function M.toggle()
	if M.is_open() then
		M.close()
	else
		M.open()
	end
end

function M.is_open()
	return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

function M.refresh()
	parse_status()
	M.render()
end

function M.setup()
	local grp = vim.api.nvim_create_augroup("SourceControl", { clear = true })

	vim.api.nvim_create_autocmd("BufWritePost", {
		group = grp,
		callback = function()
			if M.is_open() then
				vim.schedule(function() M.refresh() end)
			end
		end,
	})

	vim.api.nvim_create_autocmd("FocusGained", {
		group = grp,
		callback = function()
			if M.is_open() then
				vim.schedule(function() M.refresh() end)
			end
		end,
	})

	vim.api.nvim_create_autocmd("WinClosed", {
		group = grp,
		callback = function(ev)
			local closed = tonumber(ev.match)
			if state.win and closed == state.win then
				state.win = nil
			end
			if state.input_win and closed == state.input_win then
				state.input_win = nil
			end
		end,
	})

	-- Apply selector to explorer windows when they appear
	vim.api.nvim_create_autocmd("FileType", {
		group = grp,
		pattern = { "snacks_layout_box", "snacks_picker_list" },
		callback = function()
			vim.schedule(function() M.apply_selector() end)
		end,
	})
end

return M
