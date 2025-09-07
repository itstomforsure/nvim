local vim = vim
local settings = {
	background = "dark",
	encoding = "utf-8",
	termguicolors = true,
	shiftwidth = 4,
	tabstop = 4,
	number = true,
	relativenumber = true,
	smartindent = true,
	autoindent = true,
	smarttab = true,
	cursorline = true,
	textwidth = 80,
	colorcolumn = "80",
	wrap = true,
	scrolloff = 5,
	signcolumn = "yes",
	clipboard = "unnamedplus",
	mouse = "a",
	ignorecase = true,
	smartcase = true,
	hlsearch = true,
}

for key, value in pairs(settings) do
	vim.opt[key] = value
end

vim.g.mapleader = " "
vim.g.netrw_winsize = 25
vim.lsp.inlay_hint.enable()
vim.diagnostic.config({
	update_in_insert = true,
	virtual_text = true,
})
vim.cmd(":colorscheme vscode")
-- vim.cmd(":colorscheme jetbrains")
-- vim.cmd(":colorscheme habamax")

require("keybindings")
require("plugins")
require("lsp")

-- print("Print Neovim!", vim.log.levels.INFO)
-- vim.cmd("echo 'Echo Neovim!'")
-- vim.nvim_echo("Neovim Echo!", true, {})
-- vim.notify("Info!", 2)
-- vim.notify("Warning!", 3)
-- vim.notify("Error!", 4)
-- vim.notify("Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.", 2)
