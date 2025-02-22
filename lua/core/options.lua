local M = {}

function M.setup()
	local settings = {
		background = "dark",
		encoding = "utf-8",
		termguicolors = true,
		hlsearch = false,
		wrap = true,
		linebreak = true,
		breakindent = true,
		showbreak = "↪ ",
		incsearch = true,
		inccommand = "split",
		smartcase = true,
		expandtab = true,
		smartindent = true,
		scrolloff = 5,
		shiftwidth = 2,
		tabstop = 2,
		number = true,
		ruler = true,
		cursorline = true,
		relativenumber = false,
		mouse = "a",
		splitbelow = true,
		splitright = true,
	}

	for key, value in pairs(settings) do
		vim.opt[key] = value
	end

	vim.g.mapleader = " "
	vim.g.netrw_banner = 0
	vim.g.netrw_winsize = 25
	vim.g.netrw_liststyle = 3
	vim.lsp.inlay_hint.enable()
	vim.diagnostic.config({
		update_in_insert = true,
		virtual_text = true,
	})

	vim.o.signcolumn = "yes"
	vim.cmd("set nocompatible")
end

return M
