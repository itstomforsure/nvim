-------------------------------------------------------------------------------
-- Editor Group Renderer (swappable adapter)
--
-- This module handles all visual rendering for editor groups:
--   - Winbar: per-group buffer tabs (replaces bufferline.nvim in multi mode)
--   - Tabline: group bar showing all groups with close buttons
--
-- To swap to a custom bufferbar, replace the render_winbar/render_groupbar
-- functions with your own implementation.
-------------------------------------------------------------------------------

local vim = vim
local M = {}

-- Saved tabline state for restoring bufferline.nvim
M._saved_tabline = nil
M._saved_showtabline = nil

local has_devicons, devicons = pcall(require, "nvim-web-devicons")

local function get_icon(buf)
	if not has_devicons then return nil, nil end
	local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
	local ext = vim.fn.fnamemodify(name, ":e")
	return devicons.get_icon(name, ext, { default = true })
end

local function buf_label(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	if name == "" then return "[No Name]" end
	return vim.fn.fnamemodify(name, ":t")
end

--- Render winbar string for a group (buffer tabs).
--- Each tab is clickable (left click = switch, middle click = close).
--- Each tab has a close button icon.
---@param group table  The group object from state
---@return string      The winbar format string
function M.render_winbar(group)
	if not group then return "" end

	local parts = {}
	for _, buf in ipairs(group.buffers) do
		if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
			local is_active = (buf == group.active_buf)
			local hl = is_active and "%#TabLineSel#" or "%#TabLine#"
			local icon = get_icon(buf)
			local name = buf_label(buf)
			local modified = vim.bo[buf].modified and " +" or ""

			-- %N@v:lua.FuncName@ ... %X  = clickable region, N passed to func
			local tab = string.format(
				"%s%%%d@v:lua._eg_buf_click@ %s%s%s %%X%%%d@v:lua._eg_buf_close@ %s %%X",
				hl,
				buf,
				icon and (icon .. " ") or "",
				name,
				modified,
				buf,
				is_active and "~" or "x"
			)
			table.insert(parts, tab)
		end
	end

	if #parts == 0 then return "" end
	return table.concat(parts, "%#TabLineFill# ") .. "%#TabLineFill#%="
end

--- Calculate left-side offset for explorer/sourcecontrol zone windows.
--- Replicates bufferline.nvim's offsets behavior so the group bar
--- doesn't overlap the explorer.
local function get_left_offset()
	local layout = require("layout")
	local label_map = {
		snacks_layout_box = "Explorer",
		snacks_picker_list = "Explorer",
		NvimTree = "Explorer",
		["neo-tree"] = "Explorer",
		oil = "Explorer",
		sourcecontrol = "Source Control",
		sourcecontrol_input = "Source Control",
	}

	local max_right = 0
	local label = nil

	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win)
			and vim.api.nvim_win_get_config(win).relative == "" then
			local zone = layout.get_zone(win)
			if zone == "explorer" then
				local pos = vim.api.nvim_win_get_position(win)
				local right = pos[2] + vim.api.nvim_win_get_width(win)
				if right > max_right then
					max_right = right
					local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
					label = label_map[ft] or "Explorer"
				end
			end
		end
	end

	return max_right, label
end

--- Render tabline string for the group bar.
--- Shows one entry per editor group with the active buffer name and a close button.
--- Respects explorer zone offset on the left.
---@return string  The tabline format string
function M.render_groupbar()
	local state = require("editorgroup.state")
	if #state.groups <= 1 then return "" end

	-- Left offset for explorer zone (like bufferline's offsets)
	local offset_width, offset_label = get_left_offset()
	local prefix = ""
	if offset_width > 0 then
		local text = " " .. (offset_label or "")
		-- +1 for the vertical split separator column
		local total = offset_width + 1
		local pad = total - vim.fn.strwidth(text)
		if pad > 0 then text = text .. string.rep(" ", pad) end
		prefix = "%#Directory#" .. text .. "%#TabLineFill#"
	end

	local active_group = state.get_active_group()
	local active_id = active_group and active_group.id or -1

	local parts = {}
	for _, group in ipairs(state.groups) do
		local is_active = (group.id == active_id)
		local hl = is_active and "%#TabLineSel#" or "%#TabLine#"

		local label = "Empty"
		if group.active_buf and vim.api.nvim_buf_is_valid(group.active_buf) then
			local icon = get_icon(group.active_buf)
			label = (icon and (icon .. " ") or "") .. buf_label(group.active_buf)
		end

		local entry = string.format(
			"%s%%%d@v:lua._eg_group_click@  %s  %%X%%%d@v:lua._eg_group_close@ x %%X",
			hl,
			group.id,
			label,
			group.id
		)
		table.insert(parts, entry)
	end

	return prefix .. table.concat(parts, "%#TabLineFill#  ") .. "%#TabLineFill#%="
end

--- Enter multi-group mode: take over tabline from bufferline.nvim, enable winbars
function M.enter_multi_mode()
	M._saved_tabline = vim.o.tabline
	M._saved_showtabline = vim.o.showtabline

	_G._eg_tabline = function()
		return M.render_groupbar()
	end

	vim.o.showtabline = 2
	vim.o.tabline = "%!v:lua._eg_tabline()"
end

--- Exit multi-group mode: restore bufferline.nvim, clear winbars
function M.exit_multi_mode()
	if M._saved_tabline ~= nil then
		vim.o.tabline = M._saved_tabline
		M._saved_tabline = nil
	end
	if M._saved_showtabline ~= nil then
		vim.o.showtabline = M._saved_showtabline
		M._saved_showtabline = nil
	end

	_G._eg_tabline = nil

	-- Clear winbars from editor windows
	local layout = require("layout")
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win) and layout.get_zone(win) == "editor" then
			vim.wo[win].winbar = ""
		end
	end
end

--- Update winbars for all editor group windows
function M.update_winbars()
	local state = require("editorgroup.state")
	if not state.multi_mode then return end

	for _, group in ipairs(state.groups) do
		local winbar_str = M.render_winbar(group)
		for _, win in ipairs(group.windows) do
			if vim.api.nvim_win_is_valid(win) then
				vim.wo[win].winbar = winbar_str
			end
		end
	end
end

--- Refresh all rendering (call after any state change)
function M.refresh()
	local state = require("editorgroup.state")
	if state.multi_mode then
		M.update_winbars()
		vim.cmd("redrawtabline")
	end
end

return M
