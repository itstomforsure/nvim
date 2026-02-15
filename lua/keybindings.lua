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

-- Close buffer
local function is_regular_buf(bufnr)
	return bufnr and bufnr > 0 and
		vim.api.nvim_buf_is_valid(bufnr) and
		vim.bo[bufnr].buftype == ""
end

local function pick_regular_replacement(current_win, current_buf)
	local ok, alternate = pcall(vim.api.nvim_win_call, current_win, function()
		return vim.fn.bufnr("#")
	end)
	if ok and type(alternate) == "number" and alternate > 0 and
		alternate ~= current_buf and is_regular_buf(alternate) then
		return alternate
	end

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if bufnr ~= current_buf and vim.bo[bufnr].buflisted and is_regular_buf(bufnr) then
			return bufnr
		end
	end

	return nil
end

vim.keymap.set("n", "<leader>q", function()
	local current_win = vim.api.nvim_get_current_win()
	local current_buf = vim.api.nvim_win_get_buf(current_win)

	if not vim.api.nvim_buf_is_valid(current_buf) then
		return
	end

	if vim.bo[current_buf].buftype == "terminal" then
		vim.notify("Use terminal keymaps to close terminal buffers", vim.log.levels.INFO)
		return
	end

	if vim.bo[current_buf].modified then
		vim.notify("No write since last change", vim.log.levels.WARN)
		return
	end

	local replacement = pick_regular_replacement(current_win, current_buf)
	if replacement then
		vim.api.nvim_win_set_buf(current_win, replacement)
	else
		vim.api.nvim_win_call(current_win, function()
			vim.cmd("enew")
		end)
	end

	if vim.api.nvim_buf_is_valid(current_buf) then
		local ok, err = pcall(vim.api.nvim_buf_delete, current_buf, { force = false })
		if not ok then
			vim.notify(tostring(err), vim.log.levels.ERROR)
		end
	end
end, { desc = "Close buffer and keep layout" })

-- Switch focus between explorer and editor
vim.keymap.set("n", "<leader>e", function()
	local explorer = require("nvim-tree.api")

	if vim.bo.filetype == "NvimTree" then
		vim.cmd(":wincmd p")
	else
		explorer.tree.open()
	end

	explorer.tree.focus()
end)

-- Toggle explorer
vim.keymap.set("n", "<leader>E", ":NvimTreeToggle<CR>")

-- Navigate between buffers
vim.keymap.set("n", "<Tab>", ":bnext<CR>")
vim.keymap.set("n", "<S-Tab>", ":bprevious<CR>")

-- Show diagnostics
vim.keymap.set("n", "T", vim.diagnostic.open_float)

-- Format with Conform
vim.keymap.set("n", "<leader>f", function()
	require("conform").format({ async = true, lsp_fallback = true })
	vim.notify("Formatted with Conform", vim.log.levels.INFO)
end)

-- The following keybinds are set in the plugins.lua file.

-- Lazygit
-- { "<leader>gg", ":LazyGit<CR>" }

-- Copilot
-- {
-- 	"<leader>c",
-- 	function()
-- 		if vim.g.copilot_enabled == true then
-- 			vim.g.copilot_enabled = false
-- 			vim.notify("Copilot Disabled")
-- 		else
-- 			vim.g.copilot_enabled = true
-- 			vim.notify("Copilot Enabled")
-- 		end
-- 	end,
-- }

-- Copilot chat
-- { "<leader>cp", ":CopilotChat<CR>" },
-- { "<leader>cpe", ":CopilotChatExplain<CR>" },
-- { "<leader>cpf", ":CopilotChatFix<CR>" },
-- { "<leader>cpo", ":CopilotChatOptimize<CR>" },
