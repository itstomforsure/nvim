return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		local function line_info()
			local line = vim.fn.line(".")
			local col = vim.fn.col(".")
			local total_lines = vim.fn.line("$")
			return string.format("%d:%d / %d", line, col, total_lines)
		end
		require("lualine").setup({
			options = {
				theme = "auto",
				section_separators = { left = "", right = "" },
				component_separators = { left = "", right = "" },
				globalstatus = true,
			},
			sections = {
				lualine_b = { "branch" },
				lualine_c = { "filename" },
				lualine_x = {
					{
						"diagnostics",
						sources = { "nvim_diagnostic" },
						symbols = { error = " ", warn = " ", info = " ", hint = " " },
					},
					{
						function()
							local buf_clients = vim.lsp.get_active_clients({ bufnr = 0 })
							if #buf_clients == 0 then
								return "No LSP"
							end

							local client_names = {}
							for _, client in pairs(buf_clients) do
								table.insert(client_names, client.name)
							end
							return table.concat(client_names, ", ")
						end,
						icon = "",
					},
					"filetype",
				},
				lualine_y = { "filetype" },
				lualine_z = { line_info },
			},
			extensions = { "fugitive", "nvim-tree" },
		})
	end,
}
