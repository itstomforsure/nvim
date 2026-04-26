local state = require("editorgroup.state")

describe("editorgroup.state", function()
	before_each(function() state.reset() end)

	describe("create_group", function()
		it("assigns sequential ids starting at 1", function()
			local a = state.create_group()
			local b = state.create_group()
			local c = state.create_group()
			assert.equals(1, a.id)
			assert.equals(2, b.id)
			assert.equals(3, c.id)
		end)

		it("appends to state.groups in creation order", function()
			state.create_group()
			state.create_group()
			assert.equals(2, #state.groups)
		end)

		it("accepts buffers, active_buf, and windows in opts", function()
			local g = state.create_group({
				buffers = { 10, 20 },
				active_buf = 10,
				windows = { 100 },
			})
			assert.same({ 10, 20 }, g.buffers)
			assert.equals(10, g.active_buf)
			assert.same({ 100 }, g.windows)
		end)
	end)

	describe("get_group / get_group_by_buf / get_group_by_win", function()
		it("get_group returns nil for an unknown id", function()
			state.create_group()
			assert.is_nil(state.get_group(99))
		end)

		it("get_group_by_buf finds the group containing a buffer", function()
			local a = state.create_group({ buffers = { 1, 2 } })
			local b = state.create_group({ buffers = { 3 } })
			assert.equals(a.id, state.get_group_by_buf(2).id)
			assert.equals(b.id, state.get_group_by_buf(3).id)
		end)

		it("get_group_by_win finds the group containing a window", function()
			local a = state.create_group({ windows = { 100, 101 } })
			state.create_group({ windows = { 200 } })
			assert.equals(a.id, state.get_group_by_win(101).id)
		end)
	end)

	describe("add_buffer / remove_buffer", function()
		it("add_buffer appends a buffer to the group", function()
			local g = state.create_group()
			state.add_buffer(g, 10)
			state.add_buffer(g, 20)
			assert.same({ 10, 20 }, g.buffers)
		end)

		it("add_buffer is idempotent (no duplicates)", function()
			local g = state.create_group()
			state.add_buffer(g, 10)
			state.add_buffer(g, 10)
			assert.same({ 10 }, g.buffers)
		end)

		it("remove_buffer removes the buffer and returns true", function()
			local g = state.create_group({ buffers = { 1, 2, 3 } })
			assert.is_true(state.remove_buffer(g, 2))
			assert.same({ 1, 3 }, g.buffers)
		end)

		it("remove_buffer returns false when buffer is not present", function()
			local g = state.create_group({ buffers = { 1 } })
			assert.is_false(state.remove_buffer(g, 99))
		end)

		it("remove_buffer reassigns active_buf when active was removed", function()
			local g = state.create_group({
				buffers = { 1, 2, 3 },
				active_buf = 2,
			})
			state.remove_buffer(g, 2)
			-- After removing index 2, group.active_buf becomes group.buffers[2] (= 3)
			assert.equals(3, g.active_buf)
		end)
	end)

	describe("add_window / remove_window", function()
		it("add_window appends; idempotent on duplicates", function()
			local g = state.create_group()
			state.add_window(g, 100)
			state.add_window(g, 100)
			state.add_window(g, 200)
			assert.same({ 100, 200 }, g.windows)
		end)

		it("remove_window removes and returns true; false when missing", function()
			local g = state.create_group({ windows = { 100, 200 } })
			assert.is_true(state.remove_window(g, 100))
			assert.same({ 200 }, g.windows)
			assert.is_false(state.remove_window(g, 999))
		end)
	end)

	describe("remove_group", function()
		it("removes by id and returns true", function()
			state.create_group()
			local b = state.create_group()
			state.create_group()
			assert.is_true(state.remove_group(b.id))
			assert.equals(2, #state.groups)
		end)

		it("returns false when id is unknown", function()
			assert.is_false(state.remove_group(999))
		end)
	end)

	describe("cleanup_windows / cleanup_buffers", function()
		it("cleanup_windows drops invalid window handles", function()
			local g = state.create_group({ windows = { 999998, 999999 } })
			state.cleanup_windows()
			assert.same({}, g.windows)
		end)

		it("cleanup_buffers drops invalid buffer handles and reassigns active", function()
			local g = state.create_group({
				buffers = { 999998, 999999 },
				active_buf = 999998,
			})
			state.cleanup_buffers()
			assert.same({}, g.buffers)
			assert.is_nil(g.active_buf)
		end)
	end)

	describe("reset", function()
		it("clears groups, resets next_id to 1, disables multi_mode", function()
			state.create_group()
			state.create_group()
			state.multi_mode = true
			state.reset()
			assert.same({}, state.groups)
			assert.equals(1, state.next_id)
			assert.is_false(state.multi_mode)
		end)
	end)

	describe("serialize", function()
		it("returns empty groups list when there are no buffers", function()
			state.create_group({ buffers = {} })
			local data = state.serialize()
			assert.same({}, data.groups)
			assert.is_false(data.multi_mode)
		end)

		it("serializes file paths via buffer names", function()
			local buf = vim.api.nvim_create_buf(true, false)
			local path = vim.fn.tempname() .. "_serialize.txt"
			vim.api.nvim_buf_set_name(buf, path)

			state.create_group({ buffers = { buf }, active_buf = buf })
			local data = state.serialize()
			assert.equals(1, #data.groups)
			assert.same({ path }, data.groups[1].buffers)
			assert.equals(path, data.groups[1].active_buf)

			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end)

		it("includes multi_mode flag", function()
			state.multi_mode = true
			local data = state.serialize()
			assert.is_true(data.multi_mode)
		end)
	end)
end)
