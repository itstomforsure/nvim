local layout = require("layout")

local function fresh_buf(opts)
	opts = opts or {}
	local buf = vim.api.nvim_create_buf(opts.listed or false, opts.scratch ~= false)
	if opts.filetype then vim.bo[buf].filetype = opts.filetype end
	if opts.buftype then vim.bo[buf].buftype = opts.buftype end
	return buf
end

local function open_win(buf)
	-- Use a split so layout.classify_win sees it as a real window.
	vim.cmd("new")
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	return win
end

local function close_extras(keep)
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		if w ~= keep and vim.api.nvim_win_is_valid(w) then
			pcall(vim.api.nvim_win_close, w, true)
		end
	end
end

describe("layout.classify_win", function()
	local start_win

	before_each(function()
		start_win = vim.api.nvim_get_current_win()
	end)

	after_each(function()
		close_extras(start_win)
	end)

	it("returns 'editor' for regular file buffers (empty buftype)", function()
		local buf = fresh_buf({ buftype = "" })
		local win = open_win(buf)
		assert.equals("editor", layout.classify_win(win))
	end)

	it("returns 'explorer' for sourcecontrol filetype", function()
		local buf = fresh_buf({ filetype = "sourcecontrol" })
		local win = open_win(buf)
		assert.equals("explorer", layout.classify_win(win))
	end)

	it("returns 'explorer' for snacks_picker_list filetype", function()
		local buf = fresh_buf({ filetype = "snacks_picker_list" })
		local win = open_win(buf)
		assert.equals("explorer", layout.classify_win(win))
	end)

	it("returns 'sidebar' for copilot-chat filetype", function()
		local buf = fresh_buf({ filetype = "copilot-chat" })
		local win = open_win(buf)
		assert.equals("sidebar", layout.classify_win(win))
	end)

	it("returns 'terminal' for terminal buftype", function()
		-- buftype=terminal can't be set directly — it's only assigned by :terminal.
		-- Open a real terminal in a split, classify, then close.
		vim.cmd("split")
		vim.cmd("terminal true")
		local win = vim.api.nvim_get_current_win()
		assert.equals("terminal", layout.classify_win(win))
		vim.cmd("bdelete!")
	end)

	it("returns nil for unknown special buffers (non-empty buftype, no zone match)", function()
		local buf = fresh_buf({ buftype = "nofile" })
		local win = open_win(buf)
		assert.is_nil(layout.classify_win(win))
	end)

	it("returns nil for an invalid window handle", function()
		assert.is_nil(layout.classify_win(999999))
	end)
end)

describe("layout.tag_win + get_zone", function()
	local start_win

	before_each(function()
		start_win = vim.api.nvim_get_current_win()
	end)

	after_each(function()
		close_extras(start_win)
	end)

	it("get_zone reads back the explicit tag rather than re-classifying", function()
		local buf = fresh_buf({ buftype = "" })
		local win = open_win(buf)
		layout.tag_win(win, "sidebar")  -- intentionally inconsistent with classify
		assert.equals("sidebar", layout.get_zone(win))
	end)

	it("get_zone falls back to classify_win when no tag is present", function()
		local buf = fresh_buf({ filetype = "sourcecontrol" })
		local win = open_win(buf)
		-- No tag set; vim.w[win].zone is nil → falls back to classify
		assert.equals("explorer", layout.get_zone(win))
	end)

	it("get_zone returns nil for invalid windows", function()
		assert.is_nil(layout.get_zone(999999))
	end)
end)
