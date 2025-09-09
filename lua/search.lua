-- local vim = vim
-- local M = {}
-- local state = {
-- 	buf = nil,
-- 	win = nil,
-- 	list_buf = nil,
-- 	list_win = nil,
-- 	last_query = "",
-- 	matches = {},
-- }
--
-- local function create_search_buf()
-- 	if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
-- 		return state.buf
-- 	end
--
-- 	local buf = vim.api.nvim_create_buf(false, true)
-- 	vim.bo[buf].buftype = "nofile"
-- 	vim.bo[buf].bufhidden = "wipe"
--
-- 	return buf
-- end
--
-- local function create_search_win(buf)
-- 	if state.win and vim.api.nvim_win_is_valid(state.win) then
-- 		return
-- 	end
--
-- 	local width = math.min(80, vim.o.columns - 10)
-- 	local height = 1
-- 	local row = 45
-- 	local col = math.floor((vim.o.columns - width) / 2)
--
-- 	local opts = {
-- 		relative = "editor",
-- 		width = width,
-- 		height = height,
-- 		row = row,
-- 		col = col,
-- 		style = "minimal",
-- 		border = "rounded",
-- 	}
--
-- 	local win = vim.api.nvim_open_win(buf, true, opts)
-- 	vim.api.nvim_win_set_option(win, "winhl", "Normal:Normal,FloatBorder:DiagnosticInfo")
-- 	vim.api.nvim_win_set_option(win, "winblend", 10)
-- 	vim.api.nvim_win_set_option(win, "statuscolumn", " ⌕ ")
--
-- 	return win
-- end
--
-- -- local function create_list_buf(list)
-- -- 	if state.list_buf and vim.api.nvim_buf_is_valid(state.list_buf) then
-- -- 		return state.list_buf
-- -- 	end
-- --
-- -- 	local buf = vim.api.nvim_create_buf(false, true)
-- -- 	vim.bo[buf].buftype = "nofile"
-- -- 	vim.bo[buf].bufhidden = "wipe"
-- -- 	vim.bo[buf].modifiable = true
-- -- 	vim.api.nvim_buf_set_lines(buf, 0, -1, false, list)
-- -- 	vim.bo[buf].modifiable = false
-- --
-- -- 	return buf
-- -- end
--
-- -- local function create_list_win(buf)
-- -- 	if state.list_win and vim.api.nvim_win_is_valid(state.list_win) then
-- -- 		return
-- -- 	end
-- --
-- -- 	local config = vim.api.nvim_win_get_config(state.win)
-- -- 	if not config then
-- -- 		return
-- -- 	end
-- --
-- -- 	local opts = {
-- -- 		relative = "editor",
-- -- 		width = config.width,
-- -- 		height = #state.matches,
-- -- 		row = config.row - #state.matches - 1,
-- -- 		col = config.col,
-- -- 		style = "minimal",
-- -- 		border = "rounded",
-- -- 	}
-- --
-- -- 	local win = vim.api.nvim_open_win(buf, false, opts)
-- -- 	vim.api.nvim_win_set_option(win, "winhl", "Normal:Normal,FloatBorder:DiagnosticInfo")
-- -- 	vim.api.nvim_win_set_option(win, "winblend", 10)
-- --
-- -- 	return win
-- -- end
--
-- -- local function collect_matches(query)
-- -- 	state.matches = {}
-- --
-- -- 	if query == "" then
-- -- 		return
-- -- 	end
-- --
-- -- 	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
-- -- 	local results = {}
-- --
-- -- 	for lnum, line in ipairs(lines) do
-- -- 		local col = 1
-- -- 		while true do
-- -- 			local s, e = string.find(line, query, col)
-- -- 			if not s then
-- -- 				break
-- -- 			end
-- -- 			table.insert(results, {
-- -- 				lnum = lnum,
-- -- 				col = s,
-- -- 				text = line,
-- -- 			})
-- -- 			col = e + 1
-- -- 		end
-- -- 	end
-- --
-- -- 	return results
-- -- end
--
-- -- local function show_results_list(query)
-- -- 	if state.list_win and vim.api.nvim_win_is_valid(state.list_win) then
-- -- 		vim.api.nvim_win_close(state.list_win, true)
-- -- 	end
-- -- 	if state.list_buf and vim.api.nvim_buf_is_valid(state.list_buf) then
-- -- 		vim.api.nvim_buf_delete(state.list_buf, { force = true })
-- -- 	end
-- --
-- -- 	-- vim.notify("Search: " .. query, vim.log.levels.INFO)
-- --
-- -- 	-- state.matches = collect_matches(state.last_query)
-- -- 	-- if #state.matches == 0 then
-- -- 	-- 	return
-- -- 	-- end
-- --
-- -- 	-- vim.notify(string.format("Found %d matches", #state.matches), vim.log.levels.INFO)
-- --
-- -- 	-- state.list_buf = create_list_buf()
-- -- 	-- state.list_win = create_list_win(state.list_buf)
-- -- end
--
-- local function clear_hl()
-- 	vim.cmd("nohlsearch")
-- end
--
-- -- local function do_search(query)
-- -- 	if query == "" then
-- -- 		clear_hl()
-- -- 		return
-- -- 	end
-- -- 	state.last_query = query
-- -- 	vim.fn.setreg("/", query)
-- -- 	vim.opt.hlsearch = true
-- -- 	vim.cmd("silent! normal! n")
-- -- 	vim.notify("Searching for: " .. query, vim.log.levels.INFO)
-- --
-- -- 	-- collect_matches(query)
-- -- 	-- show_results_list(query)
-- -- end
--
-- local function close()
-- 	if state.win and vim.api.nvim_win_is_valid(state.win) then
-- 		vim.api.nvim_win_close(state.win, true)
-- 	end
-- 	if state.list_win and vim.api.nvim_win_is_valid(state.list_win) then
-- 		vim.api.nvim_win_close(state.list_win, true)
-- 	end
--
-- 	state.buf = nil
-- 	state.win = nil
-- 	state.list_buf = nil
-- 	state.list_win = nil
-- 	state.matches = {}
--
-- 	clear_hl()
-- 	vim.cmd("stopinsert")
-- end
--
-- local function open_search_win()
-- 	state.buf = create_search_buf()
-- 	state.win = create_search_win(state.buf)
--
-- 	vim.notify("Type your search query and press Enter to search. Press Esc to cancel.", vim.log.levels.INFO)
--
-- 	vim.api.nvim_buf_attach(state.buf, false, {
-- 		-- on_lines = function()
-- 		-- 	vim.notify("Updating search...", vim.log.levels.INFO)
-- 		-- end,
-- 		on_detach = function()
-- 			vim.notify("Search closed", vim.log.levels.INFO)
-- 			close()
-- 		end,
-- 	})
--
-- 	-- vim.bo[state.buf].modifiable = true
-- 	-- vim.api.nvim_buf_attach(state.buf, false, {
-- 	-- 	on_lines = function(_, _, _, _, _, _)
-- 	-- 		local input = vim.trim(vim.fn.getline(1):gsub("^Search:%s*", ""))
-- 	-- 		-- print(vim.inspect(input))
-- 	-- 		-- vim.notify("Searching for: " .. vim.fn.escape(input, "/\\"), vim.log.levels.INFO)
-- 	-- 		-- do_search(vim.fn.escape(input, "/\\"))
-- 	-- 	end,
-- 	-- })
--
-- 	local opts = { silent = true, buffer = state.buf }
--
-- 	vim.keymap.set("i", "<Esc>", function()
-- 		close()
-- 	end, opts)
--
-- 	vim.keymap.set("i", "<CR>", function()
-- 		close()
-- 	end, opts)
--
-- 	vim.cmd("startinsert")
-- end
--
-- function M.setup()
-- 	vim.keymap.set({ "n", "v" }, "/", function()
-- 		open_search_win()
-- 	end, { noremap = true, silent = true })
-- end
--
-- return M
local vim = vim
local M = {}
local state = {
	buf = nil,
	win = nil,
	list_buf = nil,
	list_win = nil,
	last_query = "",
	matches = {},
}

-- === Utility: clear highlights ===
local function clear_hl()
	vim.cmd("nohlsearch")
end

-- === Utility: collect all matches in buffer ===
local function collect_matches(query)
	state.matches = {}

	if query == "" then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local results = {}

	for lnum, line in ipairs(lines) do
		local col = 1
		while true do
			local s, e = string.find(line, query, col)
			if not s then
				break
			end
			table.insert(results, {
				lnum = lnum,
				col = s,
				text = line,
			})
			col = e + 1
		end
	end

	state.matches = results
end

-- === Create floating buffer for search ===
local function create_search_buf()
	if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
		return state.buf
	end
	return vim.api.nvim_create_buf(false, true)
end

-- === Create floating window for search ===
local function create_search_win()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		return
	end

	local width = math.min(80, vim.o.columns - 10)
	local height = 1
	local row = 45
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

	local win = vim.api.nvim_open_win(state.buf, true, opts)
	vim.api.nvim_win_set_option(win, "winhl", "Normal:Normal,FloatBorder:DiagnosticInfo")
	vim.api.nvim_win_set_option(win, "winblend", 10)

	return win
end

-- === Create floating window for match list ===
local function show_results_list()
	-- close old one
	if state.list_win and vim.api.nvim_win_is_valid(state.list_win) then
		vim.api.nvim_win_close(state.list_win, true)
	end
	if state.list_buf and vim.api.nvim_buf_is_valid(state.list_buf) then
		vim.api.nvim_buf_delete(state.list_buf, { force = true })
	end

	-- if no matches, don't show
	if #state.matches == 0 then
		return
	end

	local width = math.min(80, vim.o.columns - 10)
	local height = math.min(#state.matches, 10) -- show max 10 lines
	local row = 43 -- slightly above your search bar
	local col = math.floor((vim.o.columns - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)

	-- Fill buffer with match lines
	local display = {}
	for _, m in ipairs(state.matches) do
		table.insert(display, string.format("%4d:%-4d %s", m.lnum, m.col, m.text))
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, display)
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"

	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		width = width,
		height = height,
		row = row - height,
		col = col,
		style = "minimal",
		border = "rounded",
	})

	state.list_buf = buf
	state.list_win = win
end

-- === Perform search ===
local function do_search(query)
	if query == "" then
		clear_hl()
		return
	end
	state.last_query = query
	vim.fn.setreg("/", query)
	vim.opt.hlsearch = true
	vim.cmd("silent! normal! n")

	collect_matches(query)
	show_results_list()
end

-- === Close all windows ===
local function close()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, true)
	end
	if state.list_win and vim.api.nvim_win_is_valid(state.list_win) then
		vim.api.nvim_win_close(state.list_win, true)
	end
	state.buf = nil
	state.win = nil
	state.list_buf = nil
	state.list_win = nil
	state.matches = {}

	clear_hl()
	vim.cmd("stopinsert")
end

-- === Open search window ===
local function open_search_win()
	state.buf = create_search_buf()
	state.win = create_search_win()

	vim.api.nvim_buf_attach(state.buf, false, {
		on_lines = function(_, _, _, _, _, _)
			local input = vim.trim(vim.fn.getline(1))
			do_search(vim.fn.escape(input, "/\\"))
		end,
	})

	local opts = { silent = true, buffer = state.buf }
	vim.keymap.set("i", "<Esc>", function()
		close()
	end, opts)
	vim.keymap.set("i", "<CR>", function()
		close()
	end, opts)

	vim.cmd("startinsert")
end

function M.setup()
	vim.keymap.set({ "n", "v" }, "/", function()
		open_search_win()
	end, { noremap = true, silent = true })
end

return M
