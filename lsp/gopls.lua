local vim = vim

vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = "*.go",
	callback = function()
		local params = vim.lsp.util.make_range_params()
		params.context = { only = { "source.organizeImports" } }

		local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction",
			params, 1000)
		for cid, res in pairs(result or {}) do
			for _, r in pairs(res.result or {}) do
				if r.edit then
					local enc = (vim.lsp.get_client_by_id(cid) or {}).offset_encoding or
						"utf-16"
					vim.lsp.util.apply_workspace_edit(r.edit, enc)
				end
			end
		end

		vim.lsp.buf.format({ async = false })
	end,
})

return {
	cmd = { "gopls" },
	filetypes = { "go", "gomod", "gowork", "gotmpl" },
	root_markers = { "go.mod", "go.work", ".git" },
	settings = {
		gopls = {
			experimentalPostfixCompletions = true,

			analyses = {
				unusedparams = true,
				unreachable = true,
				fillstruct = true,
				nonewvars = true,
				shadow = true,
			},

			staticcheck = true,

			hints = {
				assignVariableTypes = true,
				compositeLiteralFields = true,
				compositeLiteralTypes = true,
				constantValues = true,
				functionTypeParameters = true,
				parameterNames = true,
				rangeVariableTypes = true,
			},

			usePlaceholders = true,
			completeUnimported = true,
			deepCompletion = true,

			gofumpt = true,
			codelenses = {
				gc_details = false,
				generate = true,
				regenerate_cgo = true,
				test = true,
				tidy = true,
				upgrade_dependency = true,
				vendor = true,
			},

			semanticTokens = true,

			hoverKind = "FullDocumentation",
			linkTarget = "pkg.go.dev",
			linksInHover = true,

			buildFlags = { "-tags", "integration" },
			env = {
				GOFLAGS = "-tags=integration",
			},

			formatting = {
				gofumpt = true,
			},
		},
	},
	init_options = {
		usePlaceholders = true,
	},
}
