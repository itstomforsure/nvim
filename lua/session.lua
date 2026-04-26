-------------------------------------------------------------------------------
-- Session
-------------------------------------------------------------------------------
-- Branch-based session save/restore. Saves the entire workspace state
-- (open buffers, editor groups, terminals with cwds, cursor positions)
-- per git branch. When switching branches, the previous branch's state
-- is saved and the new branch's state is restored automatically.
--
-- Sessions are stored as JSON in:
--   ~/.local/state/nvim/branch_sessions/<repo_id>/<branch>.json

local vim = vim
local M = {}

local current_branch = nil
local state_base = nil
local timer = nil

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local function git_root()
	local root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
	if vim.v.shell_error ~= 0 or root == "" then return nil end
	return root
end

local function get_branch()
	local branch = vim.fn.system("git branch --show-current 2>/dev/null"):gsub("\n", "")
	if vim.v.shell_error ~= 0 or branch == "" then return nil end
	return branch
end

local function repo_id_from_root(root)
	if not root then return nil end
	return root:gsub("^/", ""):gsub("/", "__")
end

local function repo_id()
	return repo_id_from_root(git_root())
end

local function session_path_for(base, root, branch)
	local id = repo_id_from_root(root)
	if not id or not branch then return nil end
	local safe_branch = branch:gsub("/", "__")
	return base .. "/" .. id .. "/" .. safe_branch .. ".json"
end

local function session_path(branch)
	return session_path_for(state_base, git_root(), branch)
end

M._internal = {
	repo_id_from_root = repo_id_from_root,
	session_path_for = session_path_for,
}

-------------------------------------------------------------------------------
-- JSON persistence
-------------------------------------------------------------------------------

local function save_json(path, data)
	local dir = vim.fn.fnamemodify(path, ":h")
	vim.fn.mkdir(dir, "p")
	local json = vim.json.encode(data)
	vim.fn.writefile({ json }, path)
end

local function load_json(path)
	if vim.fn.filereadable(path) ~= 1 then return nil end
	local lines = vim.fn.readfile(path)
	if #lines == 0 then return nil end
	local ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
	if ok then return data end
	return nil
end

-------------------------------------------------------------------------------
-- Collect state
-------------------------------------------------------------------------------

local function collect_views()
	local views = {}

	-- Visible buffers: cursor + scroll position from their windows
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win) then
			local buf = vim.api.nvim_win_get_buf(win)
			if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
				local name = vim.api.nvim_buf_get_name(buf)
				if name ~= "" and not views[name] then
					local cursor = vim.api.nvim_win_get_cursor(win)
					local info = vim.fn.getwininfo(win)[1]
					views[name] = {
						cursor = { cursor[1], cursor[2] },
						topline = info and info.topline or 1,
					}
				end
			end
		end
	end

	-- Non-visible listed buffers: last cursor position from marks
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted
			and vim.bo[buf].buftype == "" then
			local name = vim.api.nvim_buf_get_name(buf)
			if name ~= "" and not views[name] then
				local mark = vim.api.nvim_buf_get_mark(buf, '"')
				if mark[1] > 0 then
					views[name] = {
						cursor = { mark[1], mark[2] },
						topline = 1,
					}
				end
			end
		end
	end

	return views
end

local function collect_state()
	local eg_state = require("editorgroup.state")
	local eg = require("editorgroup")
	local terminal = require("terminal")

	-- Ensure groups are synced so single-group mode is captured
	eg.sync_groups()

	return {
		editor_groups = eg_state.serialize(),
		terminals = terminal.serialize(),
		views = collect_views(),
	}
end

-------------------------------------------------------------------------------
-- Save
-------------------------------------------------------------------------------

function M.save(branch)
	branch = branch or current_branch
	if not branch then return end

	local path = session_path(branch)
	if not path then return end

	local ok, data = pcall(collect_state)
	if not ok or not data then return end

	pcall(save_json, path, data)
end

-------------------------------------------------------------------------------
-- Wipe workspace
-------------------------------------------------------------------------------

local function wipe_workspace()
	local terminal = require("terminal")
	local eg_state = require("editorgroup.state")
	local render = require("editorgroup.render")
	local layout = require("layout")

	-- Close terminals
	terminal.close_all()

	-- Exit multi-mode
	if eg_state.multi_mode then
		eg_state.multi_mode = false
		render.exit_multi_mode()
	end

	-- Close all editor windows except one
	local editor_wins = {}
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win)
			and vim.api.nvim_win_get_config(win).relative == ""
			and layout.get_zone(win) == "editor" then
			table.insert(editor_wins, win)
		end
	end
	for i = 2, #editor_wins do
		pcall(vim.api.nvim_win_close, editor_wins[i], true)
	end

	-- Reset editorgroup state
	eg_state.reset()

	-- Delete all listed file buffers
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted
			and vim.bo[buf].buftype == "" then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
	end

	-- Ensure we have a clean buffer in an editor window
	local cur = vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(cur) or vim.bo[cur].buftype ~= "" then
		vim.cmd("enew")
	end
end

-------------------------------------------------------------------------------
-- Restore workspace
-------------------------------------------------------------------------------

local function restore_workspace(data)
	if not data then return end

	local eg_state = require("editorgroup.state")
	local render = require("editorgroup.render")
	local minimap = require("editorgroup.minimap")
	local terminal = require("terminal")
	local layout = require("layout")

	local groups_data = data.editor_groups and data.editor_groups.groups
	if not groups_data or #groups_data == 0 then return end

	-- 1. Load all file buffers silently
	local path_to_buf = {}
	for _, gd in ipairs(groups_data) do
		for _, file in ipairs(gd.buffers) do
			if not path_to_buf[file] and vim.fn.filereadable(file) == 1 then
				local b = vim.fn.bufadd(file)
				vim.fn.bufload(b)
				vim.bo[b].buflisted = true
				path_to_buf[file] = b
			end
		end
	end

	-- 2. Set up window layout (create splits for each group)
	local editor_win = layout.get_editor_win()
	if not editor_win then
		vim.cmd("enew")
		editor_win = vim.api.nvim_get_current_win()
		layout.tag_win(editor_win, "editor")
	end

	local win_list = { editor_win }
	for i = 2, #groups_data do
		vim.api.nvim_set_current_win(win_list[#win_list])
		vim.cmd("vsplit")
		local new_win = vim.api.nvim_get_current_win()
		layout.tag_win(new_win, "editor")
		table.insert(win_list, new_win)
	end

	-- 3. Create editor groups and assign buffers
	eg_state.reset()

	for i, gd in ipairs(groups_data) do
		local bufs = {}
		local active = nil
		for _, file in ipairs(gd.buffers) do
			if path_to_buf[file] then
				table.insert(bufs, path_to_buf[file])
				if file == gd.active_buf then
					active = path_to_buf[file]
				end
			end
		end
		active = active or bufs[1]

		eg_state.create_group({
			buffers = bufs,
			active_buf = active,
			windows = { win_list[i] },
		})

		if active and vim.api.nvim_win_is_valid(win_list[i]) then
			vim.api.nvim_win_set_buf(win_list[i], active)
		end
	end

	-- Set widths after all groups exist (avoids resize conflicts)
	for i, gd in ipairs(groups_data) do
		if gd.width and vim.api.nvim_win_is_valid(win_list[i]) then
			pcall(vim.api.nvim_win_set_width, win_list[i], gd.width)
		end
	end

	-- Enter multi-mode if needed
	if #eg_state.groups >= 2 then
		eg_state.multi_mode = true
		render.enter_multi_mode()
	end

	render.refresh()
	minimap.refresh()

	-- 4. Restore cursor positions and scroll
	if data.views then
		for file, view in pairs(data.views) do
			local b = path_to_buf[file]
			if b and vim.api.nvim_buf_is_valid(b) and view.cursor then
				local line_count = vim.api.nvim_buf_line_count(b)
				local line = math.min(view.cursor[1], line_count)
				local col = view.cursor[2]
				local wins = vim.fn.win_findbuf(b)
				for _, w in ipairs(wins) do
					if vim.api.nvim_win_is_valid(w) then
						pcall(vim.api.nvim_win_set_cursor, w, { line, col })
						if view.topline then
							pcall(vim.api.nvim_win_call, w, function()
								vim.fn.winrestview({ topline = view.topline })
							end)
						end
						break
					end
				end
			end
		end
	end

	-- 5. Restore terminals (with their cwds)
	if data.terminals then
		terminal.restore(data.terminals)
	end

	-- Focus the first editor window
	if vim.api.nvim_win_is_valid(editor_win) then
		vim.api.nvim_set_current_win(editor_win)
	end
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function M.restore(branch)
	branch = branch or current_branch or get_branch()
	if not branch then return end

	local path = session_path(branch)
	if not path then return end

	local data = load_json(path)
	if not data then return end

	restore_workspace(data)
end

-------------------------------------------------------------------------------
-- Branch change detection
-------------------------------------------------------------------------------

local function on_branch_change(old_branch, new_branch)
	-- Save old branch state
	if old_branch then
		M.save(old_branch)
	end

	-- Wipe current workspace and restore new branch
	wipe_workspace()
	M.restore(new_branch)

	vim.notify("Branch: " .. new_branch, vim.log.levels.INFO)
end

local function check_branch()
	local branch = get_branch()
	if not branch then return end
	if branch == current_branch then return end

	local old = current_branch
	current_branch = branch
	on_branch_change(old, branch)
end

-------------------------------------------------------------------------------
-- Init
-------------------------------------------------------------------------------

function M.init()
	local root = git_root()
	if not root then return end

	state_base = vim.fn.stdpath("state") .. "/branch_sessions"
	current_branch = get_branch()

	local group = vim.api.nvim_create_augroup("BranchSession", { clear = true })

	-- Detect branch changes when Neovim regains focus
	vim.api.nvim_create_autocmd("FocusGained", {
		group = group,
		callback = function()
			vim.schedule(check_branch)
		end,
	})

	-- Save session on exit
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			if timer then
				timer:stop()
				timer:close()
				timer = nil
			end
			M.save()
		end,
	})

	-- Restore session on startup (only when opened without file arguments)
	vim.api.nvim_create_autocmd("VimEnter", {
		group = group,
		once = true,
		callback = function()
			if vim.fn.argc() > 0 then return end
			vim.schedule(function()
				M.restore()
			end)
		end,
	})

	-- Poll for branch changes every 2 seconds
	timer = vim.uv.new_timer()
	timer:start(2000, 2000, vim.schedule_wrap(check_branch))
end

return M
