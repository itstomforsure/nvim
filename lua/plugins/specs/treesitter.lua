return {
	"nvim-treesitter/nvim-treesitter",
	run = ":TSUpdate",
	config = function()
		require("nvim-treesitter.configs").setup({
			highlight = { enable = true },
			indent = { enable = true },
			ensure_installed = {
				"vim",
				"vimdoc",
				"lua",
				"go",
				"typescript",
				"html",
				"css",
				"javascript",
				"angular",
			},
		})
	end,
}
