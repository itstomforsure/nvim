local vim = vim

-- General keybindings
vim.keymap.set("n", "<C-q>", ":qa!<CR>")

-- Save on Ctrl+s in normal and insert and visual modes
vim.keymap.set("n", "<C-s>", ":wa<CR>")
vim.keymap.set("i", "<C-s>", "<Esc>:wa<CR>a")
vim.keymap.set("v", "<C-s>", "<Esc>:wa<CR>v")

-- Copy and paste to system clipboard
vim.keymap.set("v", "<C-c>", '"+y')
vim.keymap.set({ "n", "t", "v" }, "<C-v>", '"+p')

-- Smart buffer close: navigate away cleanly, fall back to dashboard
local function is_regular_buf(bufnr)
	return bufnr and bufnr > 0
		and vim.api.nvim_buf_is_valid(bufnr)
		and vim.bo[bufnr].buftype == ""
end

local function pick_replacement(exclude_buf)
	local bufs = {}
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if b ~= exclude_buf and vim.bo[b].buflisted and is_regular_buf(b) then
			table.insert(bufs, b)
		end
	end
	if #bufs == 0 then return nil end
	table.sort(bufs)

	-- Prefer the nearest buffer to the left (lower ID), else go right
	local prev = nil
	for _, b in ipairs(bufs) do
		if b < exclude_buf then prev = b end
	end
	return prev or bufs[1]
end

local function smart_close_buf(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then return end

	if vim.bo[bufnr].buftype == "terminal" then
		vim.notify("Use terminal keymaps to close terminal buffers", vim.log.levels.INFO)
		return
	end

	if vim.bo[bufnr].modified then
		vim.notify("No write since last change", vim.log.levels.WARN)
		return
	end

	local replacement = pick_replacement(bufnr)
	for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
		if vim.api.nvim_win_is_valid(win) then
			if replacement then
				vim.api.nvim_win_set_buf(win, replacement)
			else
				vim.api.nvim_win_call(win, function() vim.cmd("enew") end)
			end
		end
	end

	pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
end

-- Expose for bufferline's close_command
_G.SmartCloseBuf = smart_close_buf

vim.keymap.set("n", "<leader>q", function()
	smart_close_buf()
end, { desc = "Close buffer and keep layout" })

-- Switch focus between explorer and editor
-- vim.keymap.set("n", "<leader>e", function()
-- 	local explorer = require("nvim-tree.api")
--
-- 	if vim.bo.filetype == "NvimTree" then
-- 		vim.cmd(":wincmd p")
-- 	else
-- 		explorer.tree.open()
-- 	end
--
-- 	explorer.tree.focus()
-- end)

-- Toggle explorer
-- vim.keymap.set("n", "<leader>E", ":NvimTreeToggle<CR>")

-- Show diagnostics
vim.keymap.set("n", "T", vim.diagnostic.open_float)
vim.keymap.set("n", "<leader>ua", function()
	if vim.g.snacks_animate == false then
		vim.g.snacks_animate = true
		vim.notify("Animation turned on")
	else
		vim.g.snacks_aniamte = false
		vim.notify("Animation turned off")
	end
end
)

-- Format with Conform
-- vim.keymap.set("n", "<leader>f", function()
-- 	require("conform").format({ async = true, lsp_fallback = true })
-- 	vim.notify("Formatted with Conform", vim.log.levels.INFO)
-- end)
