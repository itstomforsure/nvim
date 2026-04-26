local search = require("search")
local internal = search._internal

local function buffer_with(lines)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	return buf
end

describe("search._internal.get_matches", function()
	before_each(function() internal.set_target_buf(nil) end)

	it("returns empty list for empty query", function()
		internal.set_target_buf(buffer_with({ "anything" }))
		assert.same({}, internal.get_matches(""))
	end)

	it("returns empty list when no occurrences", function()
		internal.set_target_buf(buffer_with({ "hello", "world" }))
		assert.same({}, internal.get_matches("xyz"))
	end)

	it("finds one match per occurrence with line and column info", function()
		internal.set_target_buf(buffer_with({ "hello world", "hello there" }))
		local m = internal.get_matches("hello")
		assert.equals(2, #m)
		assert.equals(1, m[1].lnum)
		assert.equals(1, m[1].col)
		assert.equals(2, m[2].lnum)
		assert.equals(1, m[2].col)
	end)

	it("finds multiple matches on the same line", function()
		internal.set_target_buf(buffer_with({ "ab ab ab" }))
		local m = internal.get_matches("ab")
		assert.equals(3, #m)
		assert.equals(1, m[1].col)
		assert.equals(4, m[2].col)
		assert.equals(7, m[3].col)
	end)

	it("trims surrounding whitespace from text", function()
		internal.set_target_buf(buffer_with({ "    hello   " }))
		assert.equals("hello", internal.get_matches("hello")[1].text)
	end)

	it("uses literal (non-pattern) matching", function()
		internal.set_target_buf(buffer_with({ "a.b axb" }))
		local m = internal.get_matches(".")
		assert.equals(1, #m)
		assert.equals(2, m[1].col)
	end)

	it("assigns sequential ids across all matches", function()
		internal.set_target_buf(buffer_with({ "a a", "a" }))
		local m = internal.get_matches("a")
		assert.equals(1, m[1].id)
		assert.equals(2, m[2].id)
		assert.equals(3, m[3].id)
	end)
end)
