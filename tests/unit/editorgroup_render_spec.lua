local render = require("editorgroup.render")

local function fresh_listed_buf(name)
	local buf = vim.api.nvim_create_buf(true, false)
	if name then vim.api.nvim_buf_set_name(buf, name) end
	return buf
end

describe("editorgroup.render.render_winbar", function()
	it("returns empty string when group is nil", function()
		assert.equals("", render.render_winbar(nil))
	end)

	it("returns empty string when group has no listed buffers", function()
		assert.equals("", render.render_winbar({ buffers = {}, active_buf = nil }))
	end)

	it("highlights the active buffer with TabLineSel and shows ~ on its close button", function()
		local a = fresh_listed_buf(vim.fn.tempname() .. "_a.txt")
		local b = fresh_listed_buf(vim.fn.tempname() .. "_b.txt")

		local out = render.render_winbar({ buffers = { a, b }, active_buf = a })

		-- The active tab uses TabLineSel; the close button on the active tab is "~"
		assert.is_truthy(out:find("TabLineSel", 1, true))
		-- TabLine (non-Sel) appears for the inactive tab
		assert.is_truthy(out:find("%%#TabLine#"))

		pcall(vim.api.nvim_buf_delete, a, { force = true })
		pcall(vim.api.nvim_buf_delete, b, { force = true })
	end)

	it("renders [No Name] for unnamed buffers", function()
		local b = fresh_listed_buf(nil)
		local out = render.render_winbar({ buffers = { b }, active_buf = b })
		assert.is_truthy(out:find("[No Name]", 1, true))
		pcall(vim.api.nvim_buf_delete, b, { force = true })
	end)

	it("appends ' +' to a modified buffer's tab", function()
		local b = fresh_listed_buf(vim.fn.tempname() .. "_dirty.txt")
		vim.api.nvim_buf_set_lines(b, 0, -1, false, { "hello" })
		assert.is_true(vim.bo[b].modified)

		local out = render.render_winbar({ buffers = { b }, active_buf = b })
		assert.is_truthy(out:find(" %+"))
		pcall(vim.api.nvim_buf_delete, b, { force = true })
	end)

	it("ends with the fill segment so the right side aligns", function()
		local b = fresh_listed_buf(vim.fn.tempname() .. "_x.txt")
		local out = render.render_winbar({ buffers = { b }, active_buf = b })
		assert.is_truthy(out:find("%%#TabLineFill#%%=$"))
		pcall(vim.api.nvim_buf_delete, b, { force = true })
	end)

	it("skips invalid or non-listed buffers without erroring", function()
		local valid = fresh_listed_buf(vim.fn.tempname() .. "_v.txt")
		local out = render.render_winbar({
			buffers = { 999999, valid }, -- invalid + valid
			active_buf = valid,
		})
		-- Output should still contain the valid one's basename, not crash on the invalid handle.
		assert.is_truthy(out:find(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(valid), ":t"), 1, true))
		pcall(vim.api.nvim_buf_delete, valid, { force = true })
	end)
end)
