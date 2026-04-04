local vim = vim

local lsp_utils = require("lsp.utils")

local fileTypes = { "go", "gomod", "gowork", "gotmpl" }

if not lsp_utils.lsp_exists("gopls") then
	print("gopls not found in PATH")
	return
end

local config = {
	name = "gopls",
	cmd = { "gopls" },
	filetypes = fileTypes,
	root_dir = lsp_utils.find_project_root,
	on_attach = function(client, bufnr)
		lsp_utils.on_attach(client, bufnr)

		local opts = { silent = true, buffer = bufnr }

		vim.keymap.set("n", "<leader>gi", function()
			vim.lsp.buf.code_action({
				context = { only = { "source.organizeImports" } },
				apply = true,
			})
		end, opts)

		vim.keymap.set("n", "<leader>gt", function()
			vim.cmd("!go test ./...")
		end, opts)

		vim.keymap.set("n", "<leader>gb", function()
			vim.cmd("!go build")
		end, opts)
	end,
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

-- Auto-format and organize imports on save for Go files
vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = "*.go",
	callback = function()
		local params = vim.lsp.util.make_range_params()
		params.context = { only = { "source.organizeImports" } }

		local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 1000)
		for cid, res in pairs(result or {}) do
			for _, r in pairs(res.result or {}) do
				if r.edit then
					local enc = (vim.lsp.get_client_by_id(cid) or {}).offset_encoding or "utf-16"
					vim.lsp.util.apply_workspace_edit(r.edit, enc)
				end
			end
		end

		vim.lsp.buf.format({ async = false })
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = fileTypes,
	callback = function()
		local root_dir = lsp_utils.find_project_root()

		-- Check if it's a Go project (has go.mod or .go files)
		if vim.fn.filereadable(root_dir .. "/go.mod") == 1 or vim.fn.glob(root_dir .. "/*.go") ~= "" then
			local existing_clients = vim.lsp.get_clients({
				bufnr = 0,
				name = "gopls",
			})
			if #existing_clients == 0 then
				vim.lsp.start(config)
			end
		end
	end,
})
