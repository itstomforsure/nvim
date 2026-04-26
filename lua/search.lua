local vim = vim
local utils = require("utils")
local symbols = require("symbols")
local M = {}
local target_buf = nil
local target_win = nil
local search_bar = {
	buf = nil,
	win = nil,
	last_query = "",
}
local search_list = {
	buf = nil,
	win = nil,
	matches = {},
	selected_id = 0,
}

local function close()
	vim.schedule(function()
		if utils.is_win_valid(target_win) then
			vim.api.nvim_set_current_win(target_win)
		end

		target_win = nil
	end)

	if utils.is_win_valid(search_bar.win) then
		vim.api.nvim_win_close(search_bar.win, true)
		search_bar.win = nil
	end

	if utils.is_buf_valid(search_bar.buf) then
		vim.api.nvim_buf_delete(search_bar.buf, { force = true })
		search_bar.buf = nil
		search_bar.last_query = ""
	end

	if utils.is_win_valid(search_list.win) then
		vim.api.nvim_win_close(search_list.win, true)
		search_list.win = nil
	end

	if utils.is_buf_valid(search_list.buf) then
		vim.api.nvim_buf_clear_namespace(search_list.buf, -1, 0, -1)
		vim.api.nvim_buf_delete(search_list.buf, { force = true })
		search_list.buf = nil
		search_list.matches = {}
		search_list.selected_id = 0
	end

	vim.cmd("nohlsearch")
	vim.cmd("stopinsert")
end

local function get_matches(query)
	local matches = {}
	if query == "" then
		return matches
	end

	local buf = target_buf or vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local line_id = 1
	for lnum, line in ipairs(lines) do
		local col = 1
		while true do
			local s, e = string.find(line, query, col, true)
			if not s then
				break
			end
			table.insert(matches, {
				id = line_id,
				lnum = lnum,
				col = s,
				text = line:gsub("^%s*(.-)%s*$", "%1"),
			})
			line_id = line_id + 1
			col = e + 1
		end
	end

	return matches
end

M._internal = {
	get_matches = get_matches,
	set_target_buf = function(b) target_buf = b end,
}

local function update_search_list_highlight()
	local line_id = search_list.selected_id - 1
	vim.api.nvim_buf_add_highlight(search_list.buf, -1, "Search", line_id, 0, -1)
end

local function update_target_buf_highlight()
	local match = search_list.matches[search_list.selected_id]
	vim.api.nvim_win_set_cursor(vim.fn.win_getid(vim.fn.bufwinnr(target_buf)), { match.lnum, match.col - 1 })
end

local function update_search_info_on_search_bar()
	vim.api.nvim_buf_clear_namespace(search_bar.buf, -1, 0, -1)
	vim.api.nvim_buf_set_extmark(search_bar.buf, vim.api.nvim_create_namespace("searchinfo"), 0, 0, {
		virt_text = { { search_list.selected_id .. "/" .. #search_list.matches .. " " } },
		virt_text_pos = "right_align",
	})
end

local function scroll_to_view()
	local view = vim.api.nvim_win_call(search_list.win, function()
		return vim.fn.winsaveview()
	end)

	local line_id = search_list.selected_id - 4
	view.topline = line_id
	vim.api.nvim_win_call(search_list.win, function()
		vim.fn.winrestview(view)
	end)
end

local function update_highlights()
	if
		not utils.is_buf_valid(search_list.buf)
		or not utils.is_win_valid(search_list.win)
		or not utils.is_buf_valid(target_buf)
	then
		return
	end

	vim.api.nvim_buf_clear_namespace(search_list.buf, -1, 0, -1)

	if search_list.selected_id > 0 and search_list.selected_id <= #search_list.matches then
		update_search_list_highlight()
		update_target_buf_highlight()
		update_search_info_on_search_bar()
		scroll_to_view()
	end
end

local function update_search_list_content()
	if not utils.is_win_valid(search_bar.win) or not utils.is_buf_valid(search_list.buf) then
		return
	end

	local display_lines = {}
	for _, m in ipairs(search_list.matches) do
		table.insert(display_lines, string.format("%4d: %s", m.lnum, m.text))
	end

	vim.bo[search_list.buf].modifiable = true
	vim.api.nvim_buf_set_lines(search_list.buf, 0, -1, false, display_lines)
	vim.bo[search_list.buf].modifiable = false

	if utils.is_win_valid(search_bar.win) then
		vim.api.nvim_set_current_win(search_bar.win)
	end

	update_highlights()
end

local function navigate_list(direction)
	if not utils.is_win_valid(search_list.win) or not utils.is_buf_valid(search_bar.buf) then
		return
	end

	if #search_list.matches == 0 then
		return
	end

	if direction == -1 and search_list.selected_id > 1 then
		search_list.selected_id = search_list.selected_id + direction
	else
		if direction == 1 and search_list.selected_id <= #search_list.matches - 1 then
			search_list.selected_id = search_list.selected_id + direction
		end
	end

	update_highlights()
end

local function open_search_list_win()
	if not utils.is_buf_valid(search_bar.buf) or not utils.is_win_valid(search_bar.win) then
		return
	end

	local search_bar_win_config = vim.api.nvim_win_get_config(search_bar.win)
	if not search_bar_win_config then
		return
	end

	local height = math.min(10, #search_list.matches)
	local search_list_win_opts = {
		width = search_bar_win_config.width,
		height = height,
		row = search_bar_win_config.row + 2,
		col = search_bar_win_config.col,
	}

	search_list.buf = utils.create_scratch_buf(search_list.buf)
	search_list.win = utils.create_floating_win(search_list.buf, search_list.win, search_list_win_opts)
	vim.api.nvim_set_option_value("wrap", false, { win = search_list.win })
end

local function do_search(query)
	if query == "" then
		vim.cmd("nohlsearch")
		return
	end

	search_bar.last_query = query
	search_list.matches = get_matches(query)

	vim.fn.setreg("/", query)
	vim.opt.hlsearch = true
	vim.cmd("silent! normal! n")

	vim.schedule(function()
		if #search_list.matches > 0 and not utils.is_win_valid(search_list.win) then
			if search_list.selected_id == 0 then
				search_list.selected_id = 1
			end
			open_search_list_win()
		end

		update_search_list_content()
	end)
end

local function buf_keybinds(buf)
	local opts = { silent = true, buffer = buf }
	vim.keymap.set("i", "<Esc>", function()
		close()
	end, opts)

	vim.keymap.set("i", "<CR>", function()
		close()
	end, opts)

	vim.keymap.set("i", "<Down>", function()
		navigate_list(1)
	end, opts)

	vim.keymap.set("i", "<Up>", function()
		navigate_list(-1)
	end, opts)
end

local function open_search_bar_win()
	target_buf = vim.api.nvim_get_current_buf()
	target_win = vim.api.nvim_get_current_win()
	search_bar.buf = utils.create_scratch_buf(search_bar.buf)

	local width = math.min(50, vim.o.columns - 10)
	search_bar.win = utils.create_floating_win(search_bar.buf, search_bar.win, {
		width = width,
		height = 1,
		row = 0,
		col = vim.o.columns - width,
		statuscolumn = " " .. symbols.ui.search .. " ",
	})

	vim.cmd("startinsert")

	buf_keybinds(search_bar.buf)

	vim.api.nvim_buf_attach(search_bar.buf, false, {
		on_lines = function(_, _, _, _, _, _)
			local line = vim.fn.getline(1)
			local input = vim.trim(line:gsub("^Search:%s*", ""))
			local escaped_input = vim.fn.escape(input, "/\\")

			do_search(escaped_input)
		end,
	})
end

function M.setup(key)
	local opts = { noremap = true, silent = true, desc = "Open search bar" }
	vim.keymap.set({ "n", "v" }, key, open_search_bar_win, opts)
end

return M
