local vim = vim

local lsp_utils = require("lsp.utils")

local fileTypes = { "lua" }

if not lsp_utils.lsp_exists("lua-language-server") then
	print("lua-language-server not found in PATH")
	return
end

local config = {
	name = "lua_ls",
	cmd = { "lua-language-server" },
	filetypes = fileTypes,
	root_dir = lsp_utils.find_project_root,
	on_attach = lsp_utils.on_attach,
	capabilities = {
		textDocument = {
			completion = {
				completionItem = {
					snippetSupport = true,
					resolveSupport = {
						properties = {
							"documentation",
							"detail",
							"additionalTextEdits",
						},
					},
				},
			},
			hover = {
				contentFormat = { "markdown", "plaintext" },
			},
		},
	},
	settings = {
		Lua = {
			runtime = {
				version = "LuaJIT",
			},
			diagnostics = {
				globals = { "vim" },
				disable = { "missing-fields", "incomplete-signature-doc" },
			},
			workspace = {
				library = vim.api.nvim_get_runtime_file("", true),
				checkThirdParty = false,
			},
			telemetry = {
				enable = false,
			},
			completion = {
				callSnippet = "Replace",
				keywordSnippet = "Replace",
				displayContext = 3,
			},
			hint = {
				enable = true,
				paramName = "All",
				paramType = true,
				arrayIndex = "Enable",
				setType = true,
			},
			format = {
				enable = true,
				defaultConfig = {
					indent_style = "space",
					indent_size = "4",
					continuation_indent = "4",
					max_line_length = "120",
				},
			},
			misc = {
				parameters = {
					"--log-level=warn",
				},
			},
		},
	},
}

vim.api.nvim_create_autocmd("FileType", {
	pattern = fileTypes,
	callback = function()
		local existing_clients = vim.lsp.get_clients({
			bufnr = 0,
			name = "lua_ls",
		})
		if #existing_clients == 0 then
			vim.lsp.start(config)
		end
	end,
})
