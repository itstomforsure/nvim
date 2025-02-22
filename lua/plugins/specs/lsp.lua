return {
	{
		"williamboman/mason.nvim",
		config = function()
			require("mason").setup()
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = {
					"ts_ls",
					"angularls",
					"cssls",
					"html",
					"gopls",
					"lua_ls",
				},
			})
		end,
	},
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
		},
		config = function()
			local lspconfig = require("lspconfig")
			local capabilities = require("cmp_nvim_lsp").default_capabilities()
			local function on_attach(client, bufnr)
				local function buf_set_keymap(mode, lhs, rhs, desc)
					vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
				end

				buf_set_keymap("n", "gd", vim.lsp.buf.definition, "Go to definition")
				buf_set_keymap("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
				buf_set_keymap("n", "gr", vim.lsp.buf.references, "Go to references")
				buf_set_keymap("n", "K", vim.lsp.buf.hover, "Show hover documentation")
				buf_set_keymap("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
				buf_set_keymap("n", "<leader>ca", vim.lsp.buf.code_action, "Code actions")

				vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

				-- Debug
				-- print(string.format("LSP %s initialized for buffer %s", client.name, bufnr))
			end

			-- for _, _lsp in ipairs(vim.fn.glob("~/.config/nvim_lazy/lua/plugins/specs/lsps/*.lua", false, true)) do
			--   local name = vim.fn.fnamemodify(_lsp, ":t:r")
			--   local lsp = require("plugins.specs.lsps." .. name)
			--
			--   lsp.setup({
			--     lspconfig = lspconfig,
			--     capabilities = capabilities,
			--     on_attach = on_attach,
			--   })
			-- end

			-- TypeScript configuration
			lspconfig.ts_ls.setup({
				capabilities = capabilities,
				on_attach = on_attach,
				settings = {
					typescript = {
						inlayHints = {
							includeInlayParameterNameHints = "all",
							includeInlayParameterNameHintsWhenArgumentMatchesName = false,
							includeInlayFunctionParameterTypeHints = true,
							includeInlayVariableTypeHints = true,
							includeInlayPropertyDeclarationTypeHints = true,
							includeInlayFunctionLikeReturnTypeHints = true,
							includeInlayEnumMemberValueHints = true,
						},
						updateImportsOnFileMove = {
							enabled = "always",
						},
					},
					javascript = {
						inlayHints = {
							includeInlayParameterNameHints = "all",
							includeInlayParameterNameHintsWhenArgumentMatchesName = false,
							includeInlayFunctionParameterTypeHints = true,
							includeInlayVariableTypeHints = true,
							includeInlayPropertyDeclarationTypeHints = true,
							includeInlayFunctionLikeReturnTypeHints = true,
							includeInlayEnumMemberValueHints = true,
						},
					},
				},
			})

			-- Angular configuration
			lspconfig.angularls.setup({
				capabilities = capabilities,
				on_attach = on_attach,
				root_dir = require("lspconfig").util.root_pattern("angular.json", "project.json"),
				on_new_config = function(new_config, new_root_dir)
					local global_ts = vim.fn.expand("~/.nvm/versions/node/v22.11.0/lib/node_modules/typescript")
					local global_ng =
						vim.fn.expand("~/.nvm/versions/node/v22.11.0/lib/node_modules/@angular/language-server")

					new_config.cmd = {
						"ngserver",
						"--stdio",
						"--tsProbeLocations",
						global_ts,
						"--ngProbeLocations",
						global_ng,
					}
				end,
			})

			-- Go configuration
			lspconfig.gopls.setup({
				capabilities = capabilities,
				on_attach = on_attach,
				settings = {
					gopls = {
						hints = {
							assignVariableTypes = true,
							compositeLiteralFields = true,
							compositeLiteralTypes = true,
							constantValues = true,
							functionTypeParameters = true,
							parameterNames = true,
							rangeVariableTypes = true,
						},
						analyses = {
							unusedparams = true,
							shadow = true,
						},
						codelenses = {
							generate = true,
							gc_details = true,
							test = true,
							tidy = true,
						},
						usePlaceholders = true,
						completionDocumentation = true,
						importShortcut = "Definition",
						experimentalPostfixCompletions = true,
					},
				},
			})

			-- Lua configuration
			lspconfig.lua_ls.setup({
				capabilities = capabilities,
				settings = {
					Lua = {
						completion = {
							callSnippet = "Replace",
							enable = true,
							keywordSnippet = "Replace",
							showWord = "Enable",
							workspaceWord = true,
						},
						diagnostics = {
							enable = true,
							globals = {
								"vim",
								"describe",
								"it",
								"before_each",
								"after_each",
							},
							disable = {
								"trailing-space",
							},
						},
						hover = {
							enable = true,
							viewNumber = true,
							viewString = true,
							viewStringMax = 1000,
						},
						workspace = {
							library = vim.api.nvim_get_runtime_file("", true),
							maxPreload = 2000,
							preloadFileSize = 50000,
							checkThirdParty = false,
						},
						runtime = {
							version = "LuaJIT",
							path = runtime_path,
							special = {
								include = "require",
							},
						},
						hint = {
							enable = true,
							arrayIndex = "Disable",
							setType = true,
							paramName = "All",
							paramType = true,
							semicolon = "SameLine",
						},
						telemetry = {
							enable = false,
						},
					},
				},
			})
		end,
	},
}
