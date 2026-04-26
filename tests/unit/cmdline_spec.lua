local cmdline = require("cmdline")
local internal = cmdline._internal

local function clear_history()
	vim.fn.histdel(":")
end

describe("cmdline._internal.get_all_history", function()
	before_each(clear_history)
	after_each(clear_history)

	it("returns an empty list when no command history exists", function()
		assert.same({}, internal.get_all_history())
	end)

	it("returns commands newest-first with sequential display ids", function()
		vim.fn.histadd(":", "echo first")
		vim.fn.histadd(":", "echo second")
		vim.fn.histadd(":", "echo third")

		local result = internal.get_all_history()
		assert.equals(3, #result)
		assert.equals("echo third", result[1].cmd)
		assert.equals(1, result[1].id)
		assert.equals("echo first", result[3].cmd)
	end)

	it("formats display strings with right-aligned 3-char id", function()
		vim.fn.histadd(":", "echo hi")
		assert.equals("  1: echo hi", internal.get_all_history()[1].display)
	end)
end)

describe("cmdline._internal.navigate_command_history", function()
	local scratch

	before_each(function()
		scratch = vim.api.nvim_create_buf(false, true)
		internal.command_line.buf = scratch
		internal.command_line.win = nil
		internal.command_history.list = {
			{ id = 1, cmd = "first",  display = "  1: first" },
			{ id = 2, cmd = "second", display = "  2: second" },
			{ id = 3, cmd = "third",  display = "  3: third" },
		}
		internal.command_history.selected_id = 0
	end)

	after_each(function()
		if scratch and vim.api.nvim_buf_is_valid(scratch) then
			pcall(vim.api.nvim_buf_delete, scratch, { force = true })
		end
		internal.command_line.buf = nil
		internal.command_history.list = {}
		internal.command_history.selected_id = 0
	end)

	it("increments selected_id with direction +1", function()
		internal.navigate_command_history(1)
		assert.equals(1, internal.command_history.selected_id)
	end)

	it("clamps selected_id at #list", function()
		internal.command_history.selected_id = 3
		internal.navigate_command_history(1)
		assert.equals(3, internal.command_history.selected_id)
	end)

	it("clamps selected_id at 0 going down past the start", function()
		internal.navigate_command_history(-1)
		assert.equals(0, internal.command_history.selected_id)
	end)

	it("is a no-op when list is empty", function()
		internal.command_history.list = {}
		internal.navigate_command_history(1)
		assert.equals(0, internal.command_history.selected_id)
	end)
end)
