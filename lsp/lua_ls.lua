local vim = vim

return {
	cmd = { "lua-language-server" },
	filetypes = { "lua" },
	root_markers = { ".luarc.json", ".luarc.jsonc", "stylua.toml", ".git" },
	settings = {
		Lua = {
			runtime = { version = "LuaJIT" },
			diagnostics = {
				globals = { "vim" },
				disable = { "missing-fields", "incomplete-signature-doc" },
			},
			workspace = {
				library = vim.api.nvim_get_runtime_file("", true),
				checkThirdParty = false,
			},
			telemetry = { enable = false },
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
				parameters = { "--log-level=warn" },
			},
		},
	},
}
