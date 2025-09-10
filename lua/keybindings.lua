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
vim.keymap.set("n", "<leader>q", ":bwipe<CR>:bprevious<CR>")

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

-- Lazygit
vim.keymap.set("n", "<leader>gg", ":LazyGit<CR>")

-- Copilot
vim.keymap.set("n", "<leader>c", function()
	if vim.g.copilot_enabled == true then
		vim.g.copilot_enabled = false
		vim.notify("Copilot Disabled", vim.log.levels.WARN)
	else
		vim.g.copilot_enabled = true
		vim.notify("Copilot Enabled", vim.log.levels.WARN)
	end
end)

-- Copilot chat
vim.keymap.set("n", "<leader>cc", ":CopilotChatToggle<CR>")
