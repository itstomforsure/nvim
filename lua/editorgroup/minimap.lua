-------------------------------------------------------------------------------
-- Editor Group Minimap
--
-- Per-editor-group minimap using braille encoding. Each editor window (or
-- group in multi-mode) gets its own persistent floating window that stays
-- visible regardless of focus, positioned flush at the right edge.
-------------------------------------------------------------------------------

local vim = vim
local M = {}

M.enabled = true
M.width = 10

-- target_id -> { map_win, map_buf, ns_id, last_source_buf, last_tick }
M._maps = {}

local VIEW_HL = "EgMinimapView"
local CURSOR_HL = "EgMinimapCursor"
local NORMAL_HL = "EgMinimapNormal"

-------------------------------------------------------------------------------
-- Braille encoding
--
-- Each braille character (U+2800..U+28FF) encodes a 4-row x 2-col dot grid.
-- We map source text: non-whitespace byte = dot on.
-------------------------------------------------------------------------------

local BRAILLE = 0x2800
local DOT = {
	[0] = { [0] = 0x01, [1] = 0x08 },
	[1] = { [0] = 0x02, [1] = 0x10 },
	[2] = { [0] = 0x04, [1] = 0x20 },
	[3] = { [0] = 0x40, [1] = 0x80 },
}

M._internal = {}

function M._internal.encode(lines, map_width)
	-- Find max line length for horizontal scaling
	local max_len = 0
	for _, l in ipairs(lines) do
		if #l > max_len then max_len = #l end
	end

	-- Each minimap dot-column covers `scale` source bytes
	local scale = math.max(1, math.ceil(max_len / (map_width * 2)))
	local total = #lines
	local out = {}

	for chunk = 0, math.ceil(total / 4) - 1 do
		local row_chars = {}
		for mc = 0, map_width - 1 do
			local cp = BRAILLE
			for dr = 0, 3 do
				local li = chunk * 4 + dr + 1
				local line = lines[li]
				if line then
					for dc = 0, 1 do
						local s = (mc * 2 + dc) * scale + 1
						local e = math.min(s + scale - 1, #line)
						for col = s, e do
							local b = line:byte(col)
							if b and b > 32 then
								cp = cp + DOT[dr][dc]
								break
							end
						end
					end
				end
			end
			table.insert(row_chars, vim.fn.nr2char(cp))
		end
		table.insert(out, table.concat(row_chars))
	end

	return out
end

local encode = M._internal.encode

-------------------------------------------------------------------------------
-- Floating window helpers
-------------------------------------------------------------------------------

local function create_buf()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].buflisted = false
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "editorgroup_minimap"
	return buf
end

local function create_win(buf, row, col, width, height)
	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		row = row,
		col = col,
		width = math.max(1, width),
		height = math.max(1, height),
		focusable = false,
		style = "minimal",
		zindex = 20,
	})
	vim.wo[win].winblend = 15
	vim.wo[win].winhighlight = "Normal:" .. NORMAL_HL .. ",NormalFloat:" .. NORMAL_HL
	return win
end

-------------------------------------------------------------------------------
-- Single-target update
-------------------------------------------------------------------------------

local function update_one(target)
	local id = target.id
	local src_win = target.win
	local src_buf = target.buf

	if not vim.api.nvim_win_is_valid(src_win) then return end
	if not vim.api.nvim_buf_is_valid(src_buf) then return end

	-- Source window geometry
	local pos = vim.api.nvim_win_get_position(src_win)
	local win_w = vim.api.nvim_win_get_width(src_win)
	local win_h = vim.api.nvim_win_get_height(src_win)

	if win_w < M.width * 3 then
		-- Editor too narrow
		if M._maps[id] then M.close_one(id) end
		return
	end

	local map_row = pos[1]
	local map_col = pos[2] + win_w - M.width
	local map_h = win_h

	-- Get or create floating window
	local data = M._maps[id]
	if not data or not vim.api.nvim_win_is_valid(data.map_win) then
		if data then M.close_one(id) end
		local mbuf = create_buf()
		local mwin = create_win(mbuf, map_row, map_col, M.width, map_h)
		data = {
			map_win = mwin,
			map_buf = mbuf,
			ns_id = vim.api.nvim_create_namespace("eg_mm_" .. id),
			last_source_buf = nil,
			last_tick = nil,
		}
		M._maps[id] = data
	end

	-- Reposition (always, in case window moved/resized)
	pcall(vim.api.nvim_win_set_config, data.map_win, {
		relative = "editor",
		row = map_row,
		col = map_col,
		width = M.width,
		height = math.max(1, map_h),
	})

	-- Re-encode content when source buffer changed or was edited
	local tick = vim.api.nvim_buf_get_changedtick(src_buf)
	if data.last_source_buf ~= src_buf or data.last_tick ~= tick then
		local lines = vim.api.nvim_buf_get_lines(src_buf, 0, -1, false)
		local encoded = encode(lines, M.width)
		vim.bo[data.map_buf].modifiable = true
		vim.api.nvim_buf_set_lines(data.map_buf, 0, -1, false, encoded)
		vim.bo[data.map_buf].modifiable = false
		data.last_source_buf = src_buf
		data.last_tick = tick
	end

	-- Scroll-view + cursor-line highlights
	local topline = vim.fn.line("w0", src_win)
	local botline = vim.fn.line("w$", src_win)
	local cursor_line = vim.api.nvim_win_get_cursor(src_win)[1]

	local mv_top = math.floor((topline - 1) / 4)
	local mv_bot = math.floor((botline - 1) / 4)
	local mv_cur = math.floor((cursor_line - 1) / 4)
	local line_count = vim.api.nvim_buf_line_count(data.map_buf)

	vim.api.nvim_buf_clear_namespace(data.map_buf, data.ns_id, 0, -1)
	for row = mv_top, math.min(mv_bot, line_count - 1) do
		pcall(vim.api.nvim_buf_add_highlight,
			data.map_buf, data.ns_id, VIEW_HL, row, 0, -1)
	end
	if mv_cur >= 0 and mv_cur < line_count then
		pcall(vim.api.nvim_buf_add_highlight,
			data.map_buf, data.ns_id, CURSOR_HL, mv_cur, 0, -1)
	end

	-- Scroll minimap so the visible range stays centred
	if line_count > map_h and map_h > 0 then
		local center = math.floor((mv_top + mv_bot) / 2)
		local scroll = math.max(0, center - math.floor(map_h / 2))
		scroll = math.min(scroll, line_count - map_h)
		pcall(vim.api.nvim_win_call, data.map_win, function()
			vim.fn.winrestview({ topline = scroll + 1 })
		end)
	end
end

-------------------------------------------------------------------------------
-- Target discovery
-------------------------------------------------------------------------------

local function is_mappable_buf(buf)
	if not vim.api.nvim_buf_is_valid(buf) then return false end
	if vim.bo[buf].buftype ~= "" then return false end
	local name = vim.api.nvim_buf_get_name(buf)
	return name ~= ""
end

function M.get_targets()
	local state = require("editorgroup.state")
	local targets = {}

	if state.multi_mode then
		for _, group in ipairs(state.groups) do
			local win = group.windows[1]
			if win and vim.api.nvim_win_is_valid(win)
				and group.active_buf and is_mappable_buf(group.active_buf) then
				table.insert(targets, {
					id = "g" .. group.id,
					win = win,
					buf = group.active_buf,
				})
			end
		end
	else
		local layout = require("layout")
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if vim.api.nvim_win_is_valid(win)
				and vim.api.nvim_win_get_config(win).relative == ""
				and layout.get_zone(win) == "editor" then
				local buf = vim.api.nvim_win_get_buf(win)
				if is_mappable_buf(buf) then
					table.insert(targets, {
						id = "w" .. win,
						win = win,
						buf = buf,
					})
				end
			end
		end
	end

	return targets
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function M.refresh()
	if not M.enabled then return end

	local targets = M.get_targets()
	local active = {}

	for _, t in ipairs(targets) do
		active[t.id] = true
		pcall(update_one, t)
	end

	-- Remove stale maps
	for id in pairs(M._maps) do
		if not active[id] then
			M.close_one(id)
		end
	end
end

function M.close_one(id)
	local data = M._maps[id]
	if not data then return end
	if data.map_win and vim.api.nvim_win_is_valid(data.map_win) then
		pcall(vim.api.nvim_win_close, data.map_win, true)
	end
	if data.map_buf and vim.api.nvim_buf_is_valid(data.map_buf) then
		pcall(vim.api.nvim_buf_delete, data.map_buf, { force = true })
	end
	M._maps[id] = nil
end

function M.close_all()
	for id in pairs(M._maps) do
		M.close_one(id)
	end
end

function M.toggle()
	M.enabled = not M.enabled
	if M.enabled then
		M.refresh()
		vim.notify("Minimap enabled", vim.log.levels.INFO)
	else
		M.close_all()
		vim.notify("Minimap disabled", vim.log.levels.INFO)
	end
end

-------------------------------------------------------------------------------
-- Setup (called from editorgroup.setup)
-------------------------------------------------------------------------------

local _refresh_timer = nil
local _content_timer = nil

local function schedule_refresh()
	if _refresh_timer then return end
	_refresh_timer = vim.defer_fn(function()
		_refresh_timer = nil
		M.refresh()
	end, 30)
end

local function schedule_content_refresh()
	if _content_timer then return end
	_content_timer = vim.defer_fn(function()
		_content_timer = nil
		-- Clear cached ticks to force re-encode
		for _, data in pairs(M._maps) do
			data.last_tick = nil
		end
		M.refresh()
	end, 150)
end

function M.setup()
	vim.api.nvim_set_hl(0, NORMAL_HL, { bg = "#1e1e2e", fg = "#585878" })
	vim.api.nvim_set_hl(0, VIEW_HL, { bg = "#2a2a4a" })
	vim.api.nvim_set_hl(0, CURSOR_HL, { bg = "#3a3a6a" })

	local grp = vim.api.nvim_create_augroup("EgMinimap", { clear = true })

	-- Position + scroll view updates (lightweight)
	vim.api.nvim_create_autocmd(
		{ "WinScrolled", "CursorMoved", "CursorMovedI" }, {
			group = grp,
			callback = schedule_refresh,
		})

	-- Content re-encode (heavier, debounced more)
	vim.api.nvim_create_autocmd(
		{ "TextChanged", "TextChangedI" }, {
			group = grp,
			callback = schedule_content_refresh,
		})

	-- Layout / focus changes
	vim.api.nvim_create_autocmd(
		{ "WinEnter", "BufEnter", "VimResized", "WinResized", "BufWinEnter" }, {
			group = grp,
			callback = schedule_refresh,
		})

	-- Close stale maps when windows close
	vim.api.nvim_create_autocmd("WinClosed", {
		group = grp,
		callback = function()
			vim.schedule(M.refresh)
		end,
	})

	-- Initial open (double-schedule to let layout settle after startup)
	vim.schedule(function()
		vim.schedule(M.refresh)
	end)
end

return M
