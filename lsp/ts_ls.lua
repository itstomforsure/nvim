local inlay_hints = {
	includeInlayParameterNameHints = "all",
	includeInlayParameterNameHintsWhenArgumentMatchesName = false,
	includeInlayFunctionParameterTypeHints = true,
	includeInlayVariableTypeHints = true,
	includeInlayPropertyDeclarationTypeHints = true,
	includeInlayFunctionLikeReturnTypeHints = true,
	includeInlayEnumMemberValueHints = true,
}

return {
	cmd = { "typescript-language-server", "--stdio" },
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
	root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
	settings = {
		typescript = {
			inlayHints = inlay_hints,
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
			inlayHints = inlay_hints,
		},
	},
	init_options = {
		preferences = {
			disableSuggestions = false,
		},
	},
}
