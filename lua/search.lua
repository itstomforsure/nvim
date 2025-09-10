local vim = vim
local M = {}
local search_bar = {
	buf = nil,
	win = nil,
	last_query = "",
}
local search_list = {
	buf = nil,
	win = nil,
	matches = {},
}

local function create_search_bar_buf()
	if search_bar.buf and vim.api.nvim_buf_is_valid(search_bar.buf) then
		return search_bar.buf
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile" -- nofile, prompt
	vim.bo[buf].bufhidden = "wipe"

	return buf
end

local function create_search_bar_win(buf)
	if search_bar.win and vim.api.nvim_win_is_valid(search_bar.win) then
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
	vim.api.nvim_win_set_option(win, "statuscolumn", " / ") -- ⌕

	return win
end

local function create_search_list_buf()
	local display_lines = {}
	for i = #search_list.matches, 1, -1 do
		table.insert(display_lines, search_list.matches[i].text)
	end

	if search_list.buf and vim.api.nvim_buf_is_valid(search_list.buf) then
		vim.bo[search_list.buf].modifiable = true
		vim.api.nvim_buf_set_lines(search_list.buf, 0, -1, false, display_lines)
		vim.bo[search_list.buf].modifiable = false

		return search_list.buf
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)
	vim.bo[buf].modifiable = false

	return buf
end

local function create_search_list_win(buf)
	if search_list.win and vim.api.nvim_win_is_valid(search_list.win) then
		return
	end

	local config = vim.api.nvim_win_get_config(search_bar.win)
	if not config then
		return
	end

	local width = math.min(80, vim.o.columns - 10)
	-- local height = math.min(20, math.floor(vim.o.lines * 0.5))
	local row = config.row - #search_list.matches - 1
	local col = math.floor((vim.o.columns - width) / 2)

	local opts = {
		relative = "editor",
		width = width,
		height = #search_list.matches,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	}

	local win = vim.api.nvim_open_win(buf, false, opts)
	vim.api.nvim_win_set_option(win, "winhl", "Normal:Normal,FloatBorder:DiagnosticInfo")
	vim.api.nvim_win_set_option(win, "winblend", 10)
	-- vim.api.nvim_win_set_option(win, "statuscolumn", " / ") -- ⌕

	return win
end

local function close()
	if search_bar.buf and vim.api.nvim_buf_is_valid(search_bar.buf) then
		vim.api.nvim_buf_delete(search_bar.buf, { force = true })
		search_bar.buf = nil
		search_bar.last_query = ""
	end
	if search_bar.win and vim.api.nvim_win_is_valid(search_bar.win) then
		vim.api.nvim_win_close(search_bar.win, true)
		search_bar.win = nil
	end

	if search_list.buf and vim.api.nvim_buf_is_valid(search_list.buf) then
		vim.api.nvim_buf_delete(search_list.buf, { force = true })
		search_list.buf = nil
		search_list.matches = {}
	end
	if search_list.win and vim.api.nvim_win_is_valid(search_list.win) then
		vim.api.nvim_win_close(search_list.win, true)
		search_list.win = nil
	end

	vim.cmd("nohlsearch")
	vim.cmd("stopinsert")
end

local function get_matches(query)
	local matches = {}
	if query == "" then
		return matches
	end

	local lines = vim.api.nvim_buf_get_lines(search_bar.buf, 0, -1, false)
	for lnum, line in ipairs(lines) do
		local col = 1
		while true do
			local s, e = string.find(line, query, col)
			if not s then
				break
			end
			table.insert(matches, {
				lnum = lnum,
				col = s,
				text = line,
			})
			col = e + 1
		end
	end

	return matches
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

	-- local display_lines = {}
	-- for i = #search_list.matches, 1, -1 do
	-- 	table.insert(display_lines, search_list.matches[i].text)
	-- end
	-- vim.bo[search_list.buf].modifiable = true
	-- vim.api.nvim_buf_set_lines(search_list.buf, 0, -1, false, { display_lines })
	-- vim.bo[search_list.buf].modifiable = false

	vim.cmd("silent! normal! n")
end

local function open_search_bar_win()
	search_bar.buf = create_search_bar_buf()
	search_bar.win = create_search_bar_win(search_bar.buf)

	-- if search_bar.last_query ~= "" then
	-- 	vim.notify("Last query: " .. search_bar.last_query, vim.log.levels.INFO)
	-- 	-- vim.api.nvim_buf_set_lines(search_bar.buf, 0, -1, false, { "Search: " .. search_bar.last_query })
	-- 	-- vim.api.nvim_win_set_cursor(search_bar.win, { 1, #("Search: " .. search_bar.last_query) })
	-- else
	-- 	vim.notify("No previous query.", vim.log.levels.INFO)
	-- 	-- vim.api.nvim_buf_set_lines(search_bar.buf, 0, -1, false, { "Search: " })
	-- 	-- vim.api.nvim_win_set_cursor(search_bar.win, { 1, #("Search: ") })
	-- end
	-- vim.notify("Type to search. Press <Esc> or <CR> to close.", vim.log.levels.INFO)

	-- search_list.buf = create_search_list_buf()
	-- search_list.win = create_search_list_win(search_list.buf)

	vim.api.nvim_buf_attach(search_bar.buf, false, {
		on_lines = function(_, _, _, _, _, _)
			local input = vim.trim(vim.fn.getline(1):gsub("^Search:%s*", ""))
			do_search(vim.fn.escape(input, "/\\"))
		end,
	})

	local opts = { silent = true, buffer = search_bar.buf }
	vim.keymap.set("i", "<Esc>", function()
		close()
	end, opts)

	vim.keymap.set("i", "<CR>", function()
		close()
	end, opts)

	vim.cmd("startinsert")
end

function M.setup(key)
	vim.keymap.set({ "n", "v" }, key, open_search_bar_win, { noremap = true, silent = true })
end

return M
