-------------------------------------------------------------------------------
-- Editor Group State
-------------------------------------------------------------------------------

local vim = vim
local M = {}

--- All editor groups, ordered left-to-right
M.groups = {}

--- Auto-incrementing group IDs
M.next_id = 1

--- Whether multi-group mode is active (2+ groups)
M.multi_mode = false

function M.create_group(opts)
	opts = opts or {}
	local group = {
		id = M.next_id,
		buffers = opts.buffers or {},
		active_buf = opts.active_buf or nil,
		windows = opts.windows or {},
	}
	M.next_id = M.next_id + 1
	table.insert(M.groups, group)
	return group
end

function M.get_group(id)
	for _, g in ipairs(M.groups) do
		if g.id == id then return g end
	end
	return nil
end

function M.get_group_by_win(win)
	for _, g in ipairs(M.groups) do
		for _, w in ipairs(g.windows) do
			if w == win then return g end
		end
	end
	return nil
end

function M.get_group_by_buf(buf)
	for _, g in ipairs(M.groups) do
		for _, b in ipairs(g.buffers) do
			if b == buf then return g end
		end
	end
	return nil
end

function M.get_active_group()
	local win = vim.api.nvim_get_current_win()
	return M.get_group_by_win(win)
end

function M.add_buffer(group, buf)
	for _, b in ipairs(group.buffers) do
		if b == buf then return end
	end
	table.insert(group.buffers, buf)
end

function M.remove_buffer(group, buf)
	for i, b in ipairs(group.buffers) do
		if b == buf then
			table.remove(group.buffers, i)
			if group.active_buf == buf then
				-- Pick adjacent: prefer next, then previous
				group.active_buf = group.buffers[i] or group.buffers[i - 1] or nil
			end
			return true
		end
	end
	return false
end

function M.add_window(group, win)
	for _, w in ipairs(group.windows) do
		if w == win then return end
	end
	table.insert(group.windows, win)
end

function M.remove_window(group, win)
	for i, w in ipairs(group.windows) do
		if w == win then
			table.remove(group.windows, i)
			return true
		end
	end
	return false
end

function M.remove_group(id)
	for i, g in ipairs(M.groups) do
		if g.id == id then
			table.remove(M.groups, i)
			return true
		end
	end
	return false
end

function M.cleanup_windows()
	for _, g in ipairs(M.groups) do
		local valid = {}
		for _, w in ipairs(g.windows) do
			if vim.api.nvim_win_is_valid(w) then
				table.insert(valid, w)
			end
		end
		g.windows = valid
	end
end

function M.cleanup_buffers()
	for _, g in ipairs(M.groups) do
		local valid = {}
		for _, b in ipairs(g.buffers) do
			if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted then
				table.insert(valid, b)
			end
		end
		g.buffers = valid
		if g.active_buf and (not vim.api.nvim_buf_is_valid(g.active_buf)
				or not vim.bo[g.active_buf].buflisted) then
			g.active_buf = g.buffers[1] or nil
		end
	end
end

function M.reset()
	M.groups = {}
	M.next_id = 1
	M.multi_mode = false
end

return M
