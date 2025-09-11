local vim = vim
local symbols = require("symbols")
local M = {}
local state = {
	notify_active = {},
	notify_heights = {},
}

vim.cmd("highlight NotifyBackground guibg=transparent guifg=#ffffff")

local function wrap_text(text, max_width)
	local lines = {}
	for line in text:gmatch("[^\n]+") do
		while #line > max_width do
			table.insert(lines, line:sub(1, max_width))
			line = line:sub(max_width + 1)
		end
		table.insert(lines, line)
	end
	return lines
end

function M.notify(msg, level)
	level = level or 2
	local duration = 3000

	local icons = {
		[0] = "T",
		[1] = "D",
		[2] = symbols.ui.info,
		[3] = symbols.ui.warn,
		[4] = symbols.ui.error,
		[5] = "P",
		[6] = "E",
	}

	local labels = {
		[0] = "Trace",
		[1] = "Debug",
		[2] = "Info",
		[3] = "Warning",
		[4] = "Error",
		[5] = "Print",
		[6] = "Echo",
	}

	local hl = {
		[0] = "Normal",
		[1] = "Normal",
		[2] = "DiagnosticInfo",
		[3] = "DiagnosticWarn",
		[4] = "DiagnosticError",
		[5] = "DiagnosticInfo",
		[6] = "DiagnosticInfo",
	}

	local time = os.date("%H:%M:%S")
	local max_width = 60
	local wrapped_msg = wrap_text(msg, max_width - 4)
	for i, l in ipairs(wrapped_msg) do
		wrapped_msg[i] = " " .. l .. " "
	end

	local label_part = string.format(" %s %s", icons[level], labels[level])
	local time_part = string.format("⏱︎ %s", time)
	local padding = math.max(1, max_width - #label_part - #time_part + 4)
	local header = label_part .. string.rep(" ", padding) .. time_part

	local lines = { header }
	vim.list_extend(lines, wrapped_msg)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_add_highlight(buf, -1, hl[level], 0, 0, -1)
	vim.bo[buf].modifiable = false

	local row = 1
	for _, height in ipairs(state.notify_heights) do
		row = row + height + 2
	end

	local opts = {
		relative = "editor",
		width = max_width,
		height = #lines,
		row = row,
		col = vim.o.columns,
		style = "minimal",
		border = "rounded",
	}

	local win = vim.api.nvim_open_win(buf, false, opts)
	vim.api.nvim_win_set_option(
		win,
		"winhl",
		"Normal:NotifyBackground,NormalFloat:NotifyBackground,FloatBorder:" .. hl[level]
	)
	vim.api.nvim_win_set_option(win, "winblend", 10)

	table.insert(state.notify_active, win)
	table.insert(state.notify_heights, #lines)

	vim.defer_fn(function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
		for i, w in ipairs(state.notify_active) do
			if w == win then
				table.remove(state.notify_active, i)
				table.remove(state.notify_heights, i)
				break
			end
		end
	end, duration)
end

-- Override print function
-- local original_print = print
_G.print = function(...)
	local args = { ... }
	local msg = ""
	for i, v in ipairs(args) do
		if i > 1 then
			msg = msg .. "\t"
		end
		msg = msg .. tostring(v)
	end

	if msg and msg ~= "" then
		M.notify(msg, 5)
	end

	-- original_print(...) -- Call original print if needed
end

-- Override vim.api.nvim_echo to capture echo commands
-- local original_echo = vim.api.nvim_echo
vim.api.nvim_echo = function(chunks, _, _)
	local msg = ""
	for _, chunk in ipairs(chunks) do
		if type(chunk) == "table" then
			msg = msg .. chunk[1]
		else
			msg = msg .. tostring(chunk)
		end
	end

	if msg and msg ~= "" and not msg:match("^%s*$") then
		M.notify(msg, 6)
	end

	-- original_echo(chunks, history, opts) -- Call original echo if needed
end

-- Capture file write messages
vim.api.nvim_create_autocmd("BufWritePost", {
	callback = function()
		local filename = vim.fn.expand("%:t")
		local lines = vim.api.nvim_buf_line_count(0)
		local size = vim.fn.getfsize(vim.fn.expand("%:p"))

		M.notify(string.format('"%s" %dL, %dB written', filename, lines, size), vim.log.levels.INFO)
	end,
})

-- Capture LSP messages
vim.lsp.handlers["window/showMessage"] = function(_, result, _)
	local level_map = {
		[1] = vim.log.levels.ERROR,
		[2] = vim.log.levels.WARN,
		[3] = vim.log.levels.INFO,
		[4] = vim.log.levels.INFO,
	}

	M.notify(result.message, level_map[result.type] or vim.log.levels.INFO)
end

return M
