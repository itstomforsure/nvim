-------------------------------------------------------------------------------
-- Editor Groups
--
-- VSCode-like editor group system for Neovim. Each group has its own
-- buffer list, winbar tabs, and minimap positioning.
--
-- Single group mode: bufferline.nvim handles everything (passive).
-- Multi group mode:  winbar shows per-group buffer tabs,
--                    tabline shows the group bar with close buttons.
-------------------------------------------------------------------------------

local vim = vim
local state = require("editorgroup.state")
local render = require("editorgroup.render")
local minimap = require("editorgroup.minimap")

local M = {}

-- Helpers

local function is_editor_buf(buf)
	if not vim.api.nvim_buf_is_valid(buf) then return false end
	local bt = vim.bo[buf].buftype
	local ft = vim.bo[buf].filetype
	return bt == ""
		and ft ~= "sourcecontrol"
		and ft ~= "sourcecontrol_input"
		and ft ~= "snacks_layout_box"
		and ft ~= "snacks_picker_list"
		and ft ~= "copilot-chat"
		and ft ~= "snacks_terminal"
		and ft ~= "minimap"
end

-------------------------------------------------------------------------------
-- Click handlers (global, referenced by %@v:lua._eg_*@ in winbar/tabline)
-------------------------------------------------------------------------------

function _G._eg_buf_click(bufnr, _, button, _)
	if button == "l" then
		local group = state.get_group_by_buf(bufnr)
		if group then
			group.active_buf = bufnr
			for _, win in ipairs(group.windows) do
				if vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_win_set_buf(win, bufnr)
					vim.api.nvim_set_current_win(win)
					break
				end
			end
			render.refresh()
		end
	elseif button == "m" then
		M.close_buffer(bufnr)
	end
end

function _G._eg_buf_close(bufnr, _, button, _)
	if button == "l" then
		M.close_buffer(bufnr)
	end
end

function _G._eg_group_click(group_id, _, button, _)
	if button == "l" then
		local group = state.get_group(group_id)
		if group then
			for _, win in ipairs(group.windows) do
				if vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_set_current_win(win)
					break
				end
			end
			render.refresh()
		end
	end
end

function _G._eg_group_close(group_id, _, button, _)
	if button == "l" then
		M.close_group(group_id)
	end
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function M.is_multi_mode()
	return state.multi_mode
end

--- Sync group state with actual Neovim windows/buffers.
--- Creates the default group on first call.
function M.sync_groups()
	state.cleanup_windows()
	state.cleanup_buffers()

	local layout = require("layout")

	if #state.groups == 0 then
		local group = state.create_group()
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if vim.api.nvim_win_is_valid(win)
				and vim.api.nvim_win_get_config(win).relative == ""
				and layout.get_zone(win) == "editor" then
				state.add_window(group, win)
			end
		end
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.bo[buf].buflisted and is_editor_buf(buf) then
				state.add_buffer(group, buf)
			end
		end
		local cur = vim.api.nvim_get_current_buf()
		group.active_buf = is_editor_buf(cur) and cur or group.buffers[1]
	else
		-- Ensure untracked editor windows/buffers go to the first group
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if vim.api.nvim_win_is_valid(win)
				and vim.api.nvim_win_get_config(win).relative == ""
				and layout.get_zone(win) == "editor"
				and not state.get_group_by_win(win) then
				state.add_window(state.groups[1], win)
			end
		end
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.bo[buf].buflisted and is_editor_buf(buf)
				and not state.get_group_by_buf(buf) then
				state.add_buffer(state.groups[1], buf)
			end
		end
	end
end

--- Split current buffer into a new editor group on the right.
--- If only one buffer exists, it appears in both groups (VSCode-like).
function M.vsplit()
	M.sync_groups()

	local cur_win = vim.api.nvim_get_current_win()
	local cur_buf = vim.api.nvim_get_current_buf()
	local cur_group = state.get_group_by_win(cur_win)

	if not cur_group then return end
	if not is_editor_buf(cur_buf) then
		vim.notify("Can only split editor buffers", vim.log.levels.WARN)
		return
	end

	local move_buf = #cur_group.buffers > 1

	-- Create the vsplit (splitright is set, so new window goes right)
	vim.cmd("vsplit")
	local new_win = vim.api.nvim_get_current_win()

	if move_buf then
		state.remove_buffer(cur_group, cur_buf)
		if cur_group.active_buf then
			for _, w in ipairs(cur_group.windows) do
				if vim.api.nvim_win_is_valid(w) then
					vim.api.nvim_win_set_buf(w, cur_group.active_buf)
				end
			end
		end
	end
	-- When only 1 buffer: it stays in both groups

	vim.api.nvim_win_set_buf(new_win, cur_buf)

	state.create_group({
		buffers = { cur_buf },
		active_buf = cur_buf,
		windows = { new_win },
	})

	if #state.groups >= 2 and not state.multi_mode then
		state.multi_mode = true
		render.enter_multi_mode()
	end

	render.refresh()
	minimap.refresh()
end

--- Close an editor group by ID.
function M.close_group(group_id)
	local group = state.get_group(group_id)
	if not group then return end

	if #state.groups <= 1 then
		vim.notify("Cannot close the last editor group", vim.log.levels.WARN)
		return
	end

	for _, win in ipairs(group.windows) do
		if vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, false)
		end
	end

	state.remove_group(group_id)

	if #state.groups <= 1 then
		state.multi_mode = false
		render.exit_multi_mode()

		-- Re-sync remaining group's windows
		if state.groups[1] then
			state.cleanup_windows()
			local layout = require("layout")
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_is_valid(win)
					and vim.api.nvim_win_get_config(win).relative == ""
					and layout.get_zone(win) == "editor"
					and not state.get_group_by_win(win) then
					state.add_window(state.groups[1], win)
				end
			end
		end
	end

	render.refresh()
	minimap.refresh()
end

--- Close a buffer within its group.
--- In multi-mode, scoped to the group that owns the current window.
function M.close_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then return end

	if vim.bo[bufnr].modified then
		vim.notify("No write since last change", vim.log.levels.WARN)
		return
	end

	-- Prefer the current window's group, fallback to buffer's group
	local win = vim.api.nvim_get_current_win()
	local group = state.get_group_by_win(win)
	if not group or not vim.tbl_contains(group.buffers, bufnr) then
		group = state.get_group_by_buf(bufnr)
	end

	if not group then
		_G.SmartCloseBuf(bufnr)
		return
	end

	state.remove_buffer(group, bufnr)

	if group.active_buf then
		for _, w in ipairs(group.windows) do
			if vim.api.nvim_win_is_valid(w) then
				vim.api.nvim_win_set_buf(w, group.active_buf)
			end
		end
	elseif #group.buffers == 0 then
		M.close_group(group.id)
	end

	-- Only delete buffer if no other group still has it
	local still_used = false
	for _, g in ipairs(state.groups) do
		if vim.tbl_contains(g.buffers, bufnr) then
			still_used = true
			break
		end
	end
	if not still_used then
		pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
	end

	render.refresh()
	minimap.refresh()
end

--- Next buffer in the current group
function M.next_buffer()
	local group = state.get_active_group()
	if not group or #group.buffers <= 1 then return end

	local idx = 1
	for i, b in ipairs(group.buffers) do
		if b == group.active_buf then idx = i; break end
	end
	idx = (idx % #group.buffers) + 1
	group.active_buf = group.buffers[idx]

	for _, win in ipairs(group.windows) do
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_set_buf(win, group.active_buf)
		end
	end
	render.refresh()
	minimap.refresh()
end

--- Previous buffer in the current group
function M.prev_buffer()
	local group = state.get_active_group()
	if not group or #group.buffers <= 1 then return end

	local idx = 1
	for i, b in ipairs(group.buffers) do
		if b == group.active_buf then idx = i; break end
	end
	idx = idx - 1
	if idx < 1 then idx = #group.buffers end
	group.active_buf = group.buffers[idx]

	for _, win in ipairs(group.windows) do
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_set_buf(win, group.active_buf)
		end
	end
	render.refresh()
	minimap.refresh()
end

--- Get the right edge column of a group's windows (for minimap positioning)
function M.get_group_right_edge(group)
	if not group then return 0 end
	local right = 0
	for _, win in ipairs(group.windows) do
		if vim.api.nvim_win_is_valid(win) then
			local pos = vim.api.nvim_win_get_position(win)
			local wr = pos[2] + vim.api.nvim_win_get_width(win)
			if wr > right then right = wr end
		end
	end
	return right
end

-------------------------------------------------------------------------------
-- Setup
-------------------------------------------------------------------------------

function M.setup(opts)
	opts = opts or {}

	-- Minimap system (replaces mini.map auto behavior)
	minimap.setup()

	-- User commands
	vim.api.nvim_create_user_command("EditorGroupVsplit", function()
		M.vsplit()
	end, { desc = "Split into new editor group" })

	vim.api.nvim_create_user_command("EditorGroupClose", function(args)
		local id = tonumber(args.args)
		if id then
			M.close_group(id)
		else
			local group = state.get_active_group()
			if group then M.close_group(group.id) end
		end
	end, { nargs = "?", desc = "Close editor group" })

	-- Keybinds
	local vsplit_key = opts.vsplit_key or "<leader>\\"
	local close_key = opts.close_group_key or "<leader>Q"

	vim.keymap.set("n", vsplit_key, function() M.vsplit() end,
		{ desc = "Split into new editor group" })

	vim.keymap.set("n", close_key, function()
		local group = state.get_active_group()
		if group then M.close_group(group.id) end
	end, { desc = "Close editor group" })

	-- Smart Tab/S-Tab: group-aware buffer cycling
	vim.keymap.set("n", "<Tab>", function()
		if state.multi_mode then
			M.next_buffer()
		else
			vim.cmd("BufferLineCycleNext")
		end
	end, { desc = "Next buffer" })

	vim.keymap.set("n", "<S-Tab>", function()
		if state.multi_mode then
			M.prev_buffer()
		else
			vim.cmd("BufferLineCyclePrev")
		end
	end, { desc = "Prev buffer" })

	-- Minimap toggle (overrides mini.map's <leader>m)
	vim.keymap.set("n", "<leader>m", function()
		minimap.toggle()
	end, { desc = "Toggle minimap" })

	-- Smart buffer close (group-aware)
	vim.keymap.set("n", "<leader>q", function()
		if state.multi_mode then
			M.close_buffer(vim.api.nvim_get_current_buf())
		else
			_G.SmartCloseBuf()
		end
	end, { desc = "Close buffer" })

	-- Autocmds
	local grp = vim.api.nvim_create_augroup("EditorGroup", { clear = true })

	-- Track new buffers opened in multi-mode
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = grp,
		callback = function(ev)
			if not state.multi_mode then return end
			local buf = ev.buf
			if not is_editor_buf(buf) then return end

			if not state.get_group_by_buf(buf) then
				local active = state.get_active_group()
				if active then
					state.add_buffer(active, buf)
					active.active_buf = buf
					render.refresh()
				end
			end
		end,
	})

	-- Track window closures
	vim.api.nvim_create_autocmd("WinClosed", {
		group = grp,
		callback = function()
			if not state.multi_mode then return end

			vim.schedule(function()
				state.cleanup_windows()

				local to_remove = {}
				for _, g in ipairs(state.groups) do
					if #g.windows == 0 then
						table.insert(to_remove, g.id)
					end
				end
				for _, id in ipairs(to_remove) do
					state.remove_group(id)
				end

				if #state.groups <= 1 and state.multi_mode then
					state.multi_mode = false
					render.exit_multi_mode()
				end

				render.refresh()
			end)
		end,
	})

	-- Track buffer deletions
	vim.api.nvim_create_autocmd("BufDelete", {
		group = grp,
		callback = function()
			if not state.multi_mode then return end
			vim.schedule(function()
				state.cleanup_buffers()
				render.refresh()
			end)
		end,
	})

	-- Update active buffer tracking on focus change
	vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
		group = grp,
		callback = function()
			if not state.multi_mode then return end

			local win = vim.api.nvim_get_current_win()
			local buf = vim.api.nvim_get_current_buf()
			local g = state.get_group_by_win(win)

			if g and is_editor_buf(buf) then
				if not vim.tbl_contains(g.buffers, buf) then
					state.add_buffer(g, buf)
				end
				g.active_buf = buf
				render.refresh()
			end
		end,
	})
end

return M
