-------------------------------------------------------------------------------
-- Layout
-------------------------------------------------------------------------------

-- Zones:
-- ┌─────────┬──────────────────────┬────────────┐
-- │         │  [bufferline tabs]   │            │
-- │         ├──────────────────────┤            │
-- │Explorer │   Editor Zone        │  Sidebar   │
-- │  Zone   │   (files/buffers)    │   Zone     │
-- │  (left) │                      │  (AI/etc)  │
-- │         ├──────────────────────┤            │
-- │         │   Terminal Zone      │            │
-- └─────────┴──────────────────────┴────────────┘
-- │         │   lualine statusbar  │            │

local vim = vim
local M = {}

-- Configuration
--- Zone definitions. Each zone declares the filetypes and/or buftypes that
--- identify windows belonging to it. The editor zone is the default - any
--- window that doesn't match another zone is considered an editor window.
---
--- You can override this by calling layout.setup({ zones = { ... } })
M.config = {
	zones = {
		explorer = {
			position = "left",
			filetypes = {
				"snacks_picker_list",
				"snacks_layout_box",
				"NvimTree",
				"neo-tree",
				"oil",
				"sourcecontrol",
				"sourcecontrol_input",
			},
		},
		sidebar = {
			position = "right",
			filetypes = {
				"copilot-chat",
				"snacks_terminal", -- ClaudeCode uses snacks terminal on the right
			},
		},
		terminal = {
			position = "bottom",
			buftypes = { "terminal" },
			-- Terminal zone only captures bottom-split terminals, not sidebar ones.
			-- We distinguish by checking window position (see classify_win).
		},
		editor = {
			-- Default zone: regular file buffers
		},
	},
	-- Special non-file buffers that should still be treated as editor content
	-- and kept out of explorer/sidebar/terminal windows.
	editor_buffers = {
		buftypes = { "help", "quickfix" },
		filetypes = { "help", "man", "checkhealth", "qf" },
	},
	-- Open docs/health buffers as centered floats to avoid disturbing layout
	-- splits. Set enabled=false to disable this behavior.
	floating_docs = {
		enabled = true,
		filetypes = { "help", "man", "checkhealth" },
		width = 0.78,
		height = 0.82,
		border = "rounded",
	},
}

local function is_floating_win(win)
	if not vim.api.nvim_win_is_valid(win) then
		return false
	end
	local cfg = vim.api.nvim_win_get_config(win)
	return cfg and cfg.relative and cfg.relative ~= ""
end

local function contains(list, value)
	for _, item in ipairs(list or {}) do
		if item == value then
			return true
		end
	end
	return false
end

-- Zone tracking
--- Determine which zone a window belongs to based on its buffer content.
--- Returns the zone name string.
function M.classify_win(win)
	if not vim.api.nvim_win_is_valid(win) then
		return nil
	end
	if is_floating_win(win) then
		return nil
	end

	local buf = vim.api.nvim_win_get_buf(win)
	local ft = vim.bo[buf].filetype
	local bt = vim.bo[buf].buftype

	-- Check each zone's patterns
	for zone_name, zone_cfg in pairs(M.config.zones) do
		if zone_name ~= "editor" then
			-- Check filetypes
			if zone_cfg.filetypes then
				for _, pattern in ipairs(zone_cfg.filetypes) do
					if ft == pattern then
						return zone_name
					end
				end
			end
			-- Check buftypes
			if zone_cfg.buftypes then
				for _, pattern in ipairs(zone_cfg.buftypes) do
					if bt == pattern then
						return zone_name
					end
				end
			end
		end
	end

	-- If it's a regular buffer, it's the editor zone
	if bt == "" then
		return "editor"
	end

	-- Unknown special buffer - don't classify
	return nil
end

--- Tag a window with its zone. Called automatically but can also be called
--- manually to force-tag a window.
function M.tag_win(win, zone)
	if vim.api.nvim_win_is_valid(win) then
		vim.w[win].zone = zone
	end
end

--- Get the zone of a window. First checks the tag, then classifies.
function M.get_zone(win)
	if not vim.api.nvim_win_is_valid(win) then
		return nil
	end
	return vim.w[win].zone or M.classify_win(win)
end

-- Editor zone window discovery
--- Find the best editor zone window to open files in.
--- Prefers: current window if editor > last accessed editor window > any editor window
function M.get_editor_win()
	local cur = vim.api.nvim_get_current_win()
	if not is_floating_win(cur) and M.get_zone(cur) == "editor" then
		return cur
	end

	-- Find all editor zone windows, prefer the most recently used one
	local best_win = nil
	local best_lastused = -1

	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win) and not is_floating_win(win) then
			local zone = M.get_zone(win)
			if zone == "editor" then
				local info = vim.fn.getwininfo(win)[1]
				local lastused = info and info.variables and
					info.variables.lastused or 0
				if lastused > best_lastused then
					best_lastused = lastused
					best_win = win
				end
			end
		end
	end

	return best_win
end

--- Open a buffer in the editor zone, regardless of which zone has focus.
--- This is the key function that solves the "file opens in terminal" problem.
function M.open_in_editor(buf_or_file)
	local editor_win = M.get_editor_win()

	if not editor_win then
		-- No editor window exists, create one in the center
		-- (This shouldn't normally happen, but handle it gracefully)
		vim.cmd("topleft new")
		editor_win = vim.api.nvim_get_current_win()
		M.tag_win(editor_win, "editor")
	end

	vim.api.nvim_set_current_win(editor_win)

	if type(buf_or_file) == "number" then
		vim.api.nvim_win_set_buf(editor_win, buf_or_file)
	elseif type(buf_or_file) == "string" then
		vim.cmd("edit " .. vim.fn.fnameescape(buf_or_file))
	end
end

-- Buffer routing (the core of the zone system)
--- Check if a buffer is a regular file that should live in the editor zone
local function is_file_buf(buf)
	if not vim.api.nvim_buf_is_valid(buf) then return false end
	local bt = vim.bo[buf].buftype
	local ft = vim.bo[buf].filetype
	-- Regular files have empty buftype and aren't special filetypes
	if bt ~= "" then return false end
	-- Skip unnamed empty buffers (scratch)
	if vim.api.nvim_buf_get_name(buf) == "" and not vim.bo[buf].modified then
		return false
	end
	-- Skip filetypes that belong to other zones
	for zone_name, zone_cfg in pairs(M.config.zones) do
		if zone_name ~= "editor" and zone_cfg.filetypes then
			for _, pattern in ipairs(zone_cfg.filetypes) do
				if ft == pattern then return false end
			end
		end
	end
	return true
end

local function is_editor_special_buf(buf)
	if not vim.api.nvim_buf_is_valid(buf) then return false end

	local cfg = M.config.editor_buffers or {}
	local ft = vim.bo[buf].filetype
	local bt = vim.bo[buf].buftype

	return contains(cfg.filetypes, ft) or contains(cfg.buftypes, bt)
end

--- The autocmd callback that redirects editor buffers away from non-editor zones.
local function route_buffer(ev)
	local buf = ev.buf
	local win = vim.api.nvim_get_current_win()
	if is_floating_win(win) then return end

	-- Only care about editor-content buffers landing in non-editor zones.
	if not is_file_buf(buf) and not is_editor_special_buf(buf) then return end

	local zone = M.get_zone(win)
	if not zone or zone == "editor" then
		-- Good - buffer is in the right place. Ensure it's tagged.
		M.tag_win(win, "editor")
		return
	end

	-- Buffer appeared in a non-editor zone - redirect it.
	local editor_win = M.get_editor_win()
	if not editor_win or editor_win == win then
		-- No separate editor window available; don't break anything
		return
	end

	vim.schedule(function()
		if not vim.api.nvim_win_is_valid(win) then return end
		if not vim.api.nvim_buf_is_valid(buf) then return end

		-- Restore the previous buffer in the non-editor window
		local alt = vim.fn.bufnr("#")
		if alt > 0 and alt ~= buf and vim.api.nvim_buf_is_valid(alt) then
			pcall(vim.api.nvim_win_set_buf, win, alt)
		else
			-- If no alt buffer, just create an empty one
			local empty = vim.api.nvim_create_buf(false, true)
			pcall(vim.api.nvim_win_set_buf, win, empty)
		end

		-- Open the file in the editor zone
		if vim.api.nvim_win_is_valid(editor_win) then
			vim.api.nvim_set_current_win(editor_win)
			vim.api.nvim_win_set_buf(editor_win, buf)
		end
	end)
end

local function should_float_doc(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return false
	end
	local cfg = M.config.floating_docs or {}
	if not cfg.enabled then
		return false
	end
	return contains(cfg.filetypes, vim.bo[buf].filetype)
end

local function open_doc_float(buf)
	local src_win = vim.fn.bufwinid(buf)
	if src_win == -1 or not vim.api.nvim_win_is_valid(src_win) then return end
	if is_floating_win(src_win) then return end

	local cfg = M.config.floating_docs or {}
	local width = math.floor(vim.o.columns * (cfg.width or 0.78))
	local height = math.floor((vim.o.lines - vim.o.cmdheight - 1) * (cfg.height or 0.82))
	width = math.max(60, math.min(width, vim.o.columns - 4))
	height = math.max(10, math.min(height, vim.o.lines - 4))

	local row = math.max(1, math.floor((vim.o.lines - height) / 2) - 1)
	local col = math.max(1, math.floor((vim.o.columns - width) / 2))

	local float = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		style = "minimal",
		border = cfg.border or "rounded",
		width = width,
		height = height,
		row = row,
		col = col,
	})

	vim.wo[float].number = false
	vim.wo[float].relativenumber = false
	vim.wo[float].linebreak = true
	vim.wo[float].wrap = true

	local other_layout_wins = 0
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if win ~= src_win and not is_floating_win(win) then
			other_layout_wins = other_layout_wins + 1
		end
	end

	if vim.api.nvim_win_is_valid(src_win) and src_win ~= float and other_layout_wins > 0 then
		pcall(vim.api.nvim_win_close, src_win, true)
	end
end

-- Auto-tagging
--- Scan all windows and tag them with their zones.
function M.tag_all_windows()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if not is_floating_win(win) then
			local zone = M.classify_win(win)
			if zone then
				M.tag_win(win, zone)
			end
		end
	end
end

-- Setup
function M.init(opts)
	if opts then
		M.config = vim.tbl_deep_extend("force", M.config, opts)
	end

	local group = vim.api.nvim_create_augroup("LayoutZones", { clear = true })

	-- Route file buffers away from non-editor zones
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = group,
		callback = route_buffer,
	})

	-- Float help/man/checkhealth in the center (after the window exists).
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		callback = function(ev)
			if not should_float_doc(ev.buf) then return end
			vim.schedule(function()
				open_doc_float(ev.buf)
			end)
		end,
	})

	-- Re-tag windows when buffers change (catches zone windows being created)
	vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "FileType" }, {
		group = group,
		callback = function()
			local win = vim.api.nvim_get_current_win()
			if is_floating_win(win) then return end
			local zone = M.classify_win(win)
			if zone then
				M.tag_win(win, zone)
			end
		end,
	})

	-- Tag the initial editor window
	vim.schedule(function()
		M.tag_all_windows()
	end)
end

return M
