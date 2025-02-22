local M = {}

local function remap(mode, input, result, opts)
	vim.keymap.set(mode, input, result, opts or {})
end

function M.setup()
	-- Tabs
	remap("n", "<Tab>", ":bnext<CR>", { desc = "Next buffer" })
	remap("n", "<S-Tab>", ":bprevious<CR>", { desc = "Previous buffer" })

	-- Visual mode indentation
	remap("v", "<Tab>", ">gv", { desc = "Indent selected lines right" })
	remap("v", "<S-Tab>", "<gv", { desc = "Indent selected lines right" })

	-- Splits
	remap({ "n", "t" }, "<leader>s", ":new<CR>")
	remap({ "n", "t" }, "<leader>v", ":vnew<CR>")

	-- Split navigation
	remap({ "n", "t" }, "<leader>h", "<C-w>h")
	remap({ "n", "t" }, "<leader>j", "<C-w>j")
	remap({ "n", "t" }, "<leader>k", "<C-w>k")
	remap({ "n", "t" }, "<leader>l", "<C-w>l")

	-- Navigation
	remap({ "n", "t" }, "<leader>e", function()
		local api = require("nvim-tree.api")
		if api.tree.is_visible() then
			api.tree.focus()
		else
			api.tree.open()
			api.tree.focus()
		end
	end, { desc = "Focus nvim-tree" })

	-- Additional Mappings
	remap({ "n", "t" }, ";", ":", { desc = "Enter command mode" })
	remap("n", "<C-s>", ":wa<CR>", { desc = "Save all buffers in normal mode" })
	remap("i", "<C-s>", "<Esc>:wa<CR>i", { desc = "Save all buffers in insert mode" })
	remap("v", "<C-s>", "<Esc>:wa<CR>v", { desc = "Save all buffers in visual mode" })
	remap("v", "<C-c>", '"+y', { desc = "Copy selection to system clipboard" })
	remap("n", "<C-a>", "ggVG", { desc = "Select all" })
	remap("n", "<C-d>", "yyp", { desc = "Duplicate line" })
	remap("v", "<C-d>", "y'>p", { desc = "Duplicate selected lines" })
	remap({ "n", "t", "v" }, "<C-v>", '"+p', { desc = "Paste from system clipboard" })

	-- Minimap
	remap({ "n", "t" }, "<leader>mm", ":MinimapToggle<CR>", { desc = "Toggle minimap window" })
	remap({ "n", "t" }, "<leader>mr", ":MinimapRefresh<CR>", { desc = "Force refresh minimap window" })
	remap({ "n", "t" }, "<leader>mu", ":MinimapUpdateHighlight<CR>", { desc = "Force update minimap highlight" })
	remap({ "n", "t" }, "<leader>me", ":MinimapRescan<CR>", { desc = "Force recalculation of minimap scaling ratio" })

	-- Keymap for Telescope fuzzy finders
	local remap = vim.api.nvim_set_keymap

	remap("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { noremap = true, silent = true, desc = "Find files" })
	remap(
		"n",
		"<leader>fg",
		"<cmd>Telescope live_grep<cr>",
		{ noremap = true, silent = true, desc = "Live grep (search in files)" }
	)
	remap("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { noremap = true, silent = true, desc = "Switch buffers" })
	remap("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { noremap = true, silent = true, desc = "Find help tags" })
	remap(
		"n",
		"<leader>fl",
		"<cmd>Telescope lsp_references<cr>",
		{ noremap = true, silent = true, desc = "Find lsp references" }
	)
	remap(
		"n",
		"<leader>fk",
		"<cmd>Telescope git_branches<cr>",
		{ noremap = true, silent = true, desc = "Find git branches" }
	)
end

return M
