return {
	"hrsh7th/nvim-cmp",
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
		"hrsh7th/cmp-buffer",
		"hrsh7th/cmp-path",
		"hrsh7th/cmp-cmdline",
		"hrsh7th/cmp-nvim-lsp-signature-help",
		"hrsh7th/cmp-nvim-lsp-document-symbol",
	},
	config = function()
		local cmp = require("cmp")
		local window_config = {
			documentation = {
				max_height = 15,
				max_width = 40,
				border = "rounded",
				col_offset = 1,
				side_padding = 1,
				winhighlight = "Normal:Normal,FloatBorder:Normal",
				zindex = 1001,
			},
		}

		cmp.setup({
			window = window_config,
			completion = {
				completeopt = "menu,menuone,noinsert,noselect",
				keyword_length = 1,
			},
			mapping = cmp.mapping.preset.insert({
				["<C-b>"] = cmp.mapping.scroll_docs(-4),
				["<C-f>"] = cmp.mapping.scroll_docs(4),
				["<C-Space>"] = cmp.mapping.complete(),
				["<C-e>"] = cmp.mapping.abort(),
				["<CR>"] = cmp.mapping.confirm({ select = true }),
			}),
			sources = cmp.config.sources({
				{ name = "nvim_lsp" },
				{ name = "buffer" },
				{ name = "path" },
			}),
		})
	end,
}
