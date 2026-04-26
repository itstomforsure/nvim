local vim = vim
local settings = {
	background = "dark",
	encoding = "utf-8",
	termguicolors = true,
	shiftwidth = 4,
	tabstop = 4,
	number = true,
	relativenumber = false,
	smartindent = true,
	autoindent = true,
	smarttab = true,
	cursorline = true,
	textwidth = 120,
	colorcolumn = "120",
	wrap = true,
	scrolloff = 5,
	signcolumn = "yes",
	clipboard = "unnamedplus",
	mouse = "a",
	ignorecase = true,
	smartcase = true,
	hlsearch = true,
	splitright = true,
}

for key, value in pairs(settings) do
	vim.opt[key] = value
end

-- Disable language providers we don't use; silences :checkhealth warnings.
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

require("framework").init()
