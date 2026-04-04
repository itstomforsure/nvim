local vim = vim

local lsp_utils = require("lsp.utils")

local fileTypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" }

if not lsp_utils.lsp_exists("typescript-language-server") then
	vim.notify("typescript-language-server not found in PATH")
	return
end

local config = {
	name = "ts_ls",
	cmd = { "typescript-language-server", "--stdio" },
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
			definition = {
				linkSupport = true,
			},
			declaration = {
				linkSupport = true,
			},
			references = {
				context = { includeDeclaration = true },
			},
			hover = {
				contentFormat = { "markdown", "plaintext" },
			},
		},
	},
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
			updateImportsOnFileMove = { enabled = "always" },
			suggest = {
				completionsForModuleExports = true,
				autoImports = true,
			},
			preferences = {
				importModuleSpecifier = "relative",
				includePackageJsonAutoImports = "auto",
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
	init_options = {
		preferences = {
			disableSuggestions = false,
		},
	},
}

-- Dynamically configure settings based on project configs
vim.api.nvim_create_autocmd("FileType", {
	pattern = fileTypes,
	callback = function()
		local root_dir = lsp_utils.find_project_root()
		local project_configs = lsp_utils.detect_project_configs(root_dir)

		-- Update TypeScript settings based on project configuration
		if project_configs.prettier then
			config.settings.typescript.preferences.insertSpaceAfterCommaDelimiter = false
			config.settings.typescript.preferences.insertSpaceAfterSemicolonInForStatements = false
			config.settings.typescript.preferences.insertSpaceBeforeAndAfterBinaryOperators = false
			config.settings.typescript.preferences.insertSpaceAfterKeywordsInControlFlowStatements = false
			config.settings.typescript.preferences.insertSpaceAfterFunctionKeywordForAnonymousFunctions = false
		else
			config.settings.typescript.preferences.insertSpaceAfterCommaDelimiter = true
			config.settings.typescript.preferences.insertSpaceAfterSemicolonInForStatements = true
			config.settings.typescript.preferences.insertSpaceBeforeAndAfterBinaryOperators = true
			config.settings.typescript.preferences.insertSpaceAfterKeywordsInControlFlowStatements = true
			config.settings.typescript.preferences.insertSpaceAfterFunctionKeywordForAnonymousFunctions = true
		end

		config.settings.typescript.preferences.insertSpaceAfterOpeningAndBeforeClosingNonemptyParenthesis = false
		config.settings.typescript.preferences.insertSpaceAfterOpeningAndBeforeClosingNonemptyBrackets = false

		-- ESLint configuration
		config.settings.typescript.validate = { enable = project_configs.eslint }
		config.settings.javascript.validate = { enable = project_configs.eslint }

		if project_configs.eslint then
			config.settings.eslint = {
				enable = true,
				autoFixOnSave = true,
				codeActionsOnSave = {
					mode = "all",
					rules = { "!debugger", "!no-only-tests/*" },
				},
				workingDirectory = { mode = "auto" },
			}
		end

		local existing_clients = vim.lsp.get_clients({ bufnr = 0, name = "typescript-language-server" })
		if #existing_clients == 0 then
			vim.lsp.start(config)
		end
	end,
})
