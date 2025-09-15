-- I have issues getting the selected lines in visual mode, until I figure that
-- out, I will use the comment.nvim plugin

local vim = vim
local M = {}

local comment_templates = {
	lua = "-- %s",
	vim = '"%s',
	sh = "# %s",
	python = "# %s",
	javascript = "// %s",
	typescript = "// %s",
	go = "// %s",
	c = "// %s",
	cpp = "// %s",
	rust = "// %s",
	html = "<!-- %s -->",
	css = "/* %s */",
}

local function escape_lua_pattern(s)
	return s:gsub("([^%w])", "%%%1")
end

local function get_comment_template()
	local ft = vim.bo.filetype
	local tpl = comment_templates[ft]
	if tpl then
		return tpl
	end

	local cb = vim.bo.commentstring
	if cb and cb:find("%%s") then
		return cb
	end

	return "# %s"
end

local function get_tokens_from_template()
	local tpl = get_comment_template()
	local left, right = tpl:match("^(.-)%%s(.-)$")
	left = left or ""
	right = right or ""

	return left, right
end

local function detect_commented(content, left, right)
	if right ~= "" then
		local pat = "^" .. escape_lua_pattern(left) .. "(.-)" .. escape_lua_pattern(right) .. "%s*$"
		local inner = content:match(pat)
		if inner then
			return true, inner
		end
		return false, nil
	else
		local pat = "^" .. escape_lua_pattern(left) .. "%s?(.*)"
		local inner = content:match(pat)
		if inner then
			return true, inner
		end
		return false, nil
	end
end

local function comment_single_line(line, left, right)
	local indent = line:match("^(%s*)") or ""
	local content = line:sub(#indent + 1)
	if content == "" then
		if right ~= "" then
			return indent .. left .. right
		else
			return indent .. left
		end
	end

	if right ~= "" then
		return indent .. left .. content .. right
	else
		return indent .. left .. content
	end
end

local function uncomment_single_line(line, left, right)
	local indent = line:match("^(%s*)") or ""
	local content = line:sub(#indent + 1)
	local ok, inner = detect_commented(content, left, right)
	if ok then
		return indent .. (inner or "")
	end
	return nil
end

local function toggle_range(start_row, end_row)
	if not start_row or not end_row then
		return
	end
	if start_row > end_row then
		start_row, end_row = end_row, start_row
	end

	local left, right = get_tokens_from_template()
	local bufnr = 0
	local lines = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, end_row, false)

	local all_commented = true
	for _, line in ipairs(lines) do
		local indent = line:match("^(%s*)") or ""
		local content = line:sub(#indent + 1)
		local ok = false
		if right ~= "" then
			local pat = "^" .. escape_lua_pattern(left)
			local pat_right = escape_lua_pattern(right) .. "%s*$"
			if content:match(pat) and content:match(pat_right) then
				ok = true
			end
		else
			local pat = "^" .. escape_lua_pattern(left)
			if content:match(pat) then
				ok = true
			end
		end
		if not ok then
			all_commented = false
			break
		end
	end

	local out = {}
	for _, line in ipairs(lines) do
		if all_commented then
			local new = uncomment_single_line(line, left, right) or line
			table.insert(out, new)
		else
			local new = comment_single_line(line, left, right)
			table.insert(out, new)
		end
	end

	vim.api.nvim_buf_set_lines(bufnr, start_row - 1, end_row, false, out)
end

local function toggle_comment_line()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	toggle_range(row, row)
end

-- local function get_visual_selection()
-- 	local esc = vim.api.nvim_replace_termcodes("<esc>", true, false, true)
-- 	vim.api.nvim_feedkeys(esc, "x", false)
-- 	local vstart = vim.fn.getpos("'<")
-- 	local vend = vim.fn.getpos("'>")
-- 	return table.concat(vim.fn.getregion(vstart, vend), "\n")
-- end
--
-- local function get_selected_text()
-- 	local mode = vim.api.nvim_get_mode().mode
-- 	local opts = {}
-- 	-- \22 is an escaped version of <c-v>
-- 	if mode == "v" or mode == "V" or mode == "\22" then
-- 		opts.type = mode
-- 	end
-- 	return vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), opts)
-- end

local function toggle_comment_block()
	local start_row = vim.fn.line("'<")
	local end_row = vim.fn.line("'>")
	toggle_range(start_row, end_row)
end

function M.setup(key)
	vim.keymap.set("n", key, toggle_comment_line, { noremap = true, silent = true })
	vim.keymap.set({ "v", "x" }, key, toggle_comment_block, { noremap = true, silent = true })
end

return M
