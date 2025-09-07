local vim = vim
local M = {}

vim.cmd("highlight NotifyBackground guibg=transparent guifg=#ffffff")

local notify_active = {}
local notify_heights = {}

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
	duration = 3000

	local icons = {
		[0] = "T",
		[1] = "D",
		[2] = " ",
		[3] = " ",
		[4] = " ",
	}

	local labels = {
		[0] = "Trace",
		[1] = "Debug",
		[2] = "Info",
		[3] = "Warning",
		[4] = "Error",
	}

	local hl = {
		[0] = "Normal",
		[1] = "Normal",
		[2] = "DiagnosticInfo",
		[3] = "DiagnosticWarn",
		[4] = "DiagnosticError",
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
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_add_highlight(buf, -1, hl[level], 0, 0, -1)

	local row = 1
	for _, height in ipairs(notify_heights) do
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
	vim.api.nvim_win_set_option(win, "winhl", "Normal:NotifyBackground,NormalFloat:NotifyBackground,FloatBorder:" .. hl[level])
	vim.api.nvim_win_set_option(win, "winblend", 10)

	table.insert(notify_active, win)
	table.insert(notify_heights, #lines)

	vim.defer_fn(function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
		for i, w in ipairs(notify_active) do
		  if w == win then
			table.remove(notify_active, i)
            table.remove(notify_heights, i)
			break
		  end
		end
	end, duration)
end

return M
