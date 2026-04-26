-------------------------------------------------------------------------------
-- LSP
-------------------------------------------------------------------------------
-- Per-server configurations live in <config>/lsp/<name>.lua and are
-- auto-discovered by Neovim 0.11+. Each file returns a config table with
-- `cmd`, `filetypes`, `root_markers`, `settings`, etc. Global concerns
-- (capabilities, on_attach, diagnostics, signs, completion-menu keymaps)
-- are set up here once and merged into every server.
-------------------------------------------------------------------------------

local vim = vim
local M = {}

local function setup_diagnostics(symbols)
	vim.diagnostic.config({
		virtual_text = {
			prefix = "●",
			spacing = 4,
		},
		signs = true,
		underline = true,
		update_in_insert = true,
		severity_sort = true,
		float = {
			focusable = true,
			style = "minimal",
			border = "rounded",
			source = "always",
			header = "",
			prefix = "",
		},
	})

	local signs = {
		DiagnosticSignError = symbols.ui.error,
		DiagnosticSignWarn  = symbols.ui.warn,
		DiagnosticSignHint  = symbols.ui.hint,
		DiagnosticSignInfo  = symbols.ui.info,
	}
	for name, text in pairs(signs) do
		vim.fn.sign_define(name, { texthl = name, text = text, numhl = "" })
	end
end

local function setup_completion_keymaps()
	vim.keymap.set("i", "<Tab>", function()
		if vim.fn.pumvisible() == 1 then return "<C-n>" end
		return "<Tab>"
	end, { expr = true })

	vim.keymap.set("i", "<S-Tab>", function()
		if vim.fn.pumvisible() == 1 then return "<C-p>" end
		return "<S-Tab>"
	end, { expr = true })

	vim.keymap.set("i", "<CR>", function()
		if vim.fn.pumvisible() == 1 then return "<C-y>" end
		return "<CR>"
	end, { expr = true })
end

local function setup_user_commands()
	vim.api.nvim_create_user_command("LspDebug", function()
		local clients = vim.lsp.get_clients()
		if #clients == 0 then
			vim.notify("No LSP clients are currently attached.")
			return
		end
		for _, client in pairs(clients) do
			vim.notify(string.format("LSP: %s (ID: %d)", client.name, client.id))
			vim.notify(" Supports definition: " ..
				tostring(client.server_capabilities.definitionProvider or false))
			vim.notify(" Supports declaration: " ..
				tostring(client.server_capabilities.declarationProvider or false))
			vim.notify(" Supports references: " ..
				tostring(client.server_capabilities.referencesProvider or false))
		end
	end, {})

	vim.api.nvim_create_user_command("EslintConfig", function()
		local file = vim.fn.expand("%:p")
		vim.cmd("!eslint_d --print-config " .. file .. " | less")
	end, {})

	vim.api.nvim_create_user_command("PrettierConfig", function()
		local file = vim.fn.expand("%:p")
		vim.cmd("!prettier --find-config-path " .. file)
	end, {})
end

local function setup_editorconfig()
	local root = vim.fs.root(0, { ".editorconfig" })
	if root and vim.fn.filereadable(root .. "/.editorconfig") == 1 then
		vim.cmd("silent! EditorConfigEnable")
		vim.notify("EditorConfig enabled from " .. root .. "/.editorconfig",
			vim.log.levels.INFO)
	end
end

local function setup_global_config()
	-- Merged into every server's config via vim.lsp.config('*', ...)
	vim.lsp.config("*", {
		capabilities = vim.tbl_deep_extend("force",
			vim.lsp.protocol.make_client_capabilities(),
			{
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
					definition = { linkSupport = true },
					declaration = { linkSupport = true },
					references = { context = { includeDeclaration = true } },
				},
			}),
	})
end

local function setup_attach_keymaps(keybinds)
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
		callback = function(ev)
			local bufnr = ev.buf
			local client = vim.lsp.get_client_by_id(ev.data.client_id)
			if not client then return end

			vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

			local opts = { silent = true, buffer = bufnr }
			for _, value in pairs(keybinds.lsp.binds) do
				vim.keymap.set(value.mode, value.key, value.cmd, opts)
			end

			if client.server_capabilities.inlayHintProvider then
				local b = keybinds.lsp.inlay_hint
				vim.keymap.set(b.mode, b.key, function()
					vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
					vim.notify(string.format("Inlay hints: %s",
						vim.lsp.inlay_hint.is_enabled() and "on" or "off"))
				end, opts)
			end
		end,
	})
end

local function discover_servers(lsp_dir)
	lsp_dir = lsp_dir or (vim.fn.stdpath("config") .. "/lsp")
	local names = {}
	if vim.fn.isdirectory(lsp_dir) == 0 then return names end

	for _, file in ipairs(vim.fn.readdir(lsp_dir)) do
		local name = file:match("^(.+)%.lua$")
		if name then table.insert(names, name) end
	end
	return names
end

M._internal = { discover_servers = discover_servers }

function M.init(keybinds, symbols)
	vim.lsp.inlay_hint.enable()

	setup_diagnostics(symbols)
	setup_completion_keymaps()
	setup_user_commands()
	setup_editorconfig()
	setup_global_config()
	setup_attach_keymaps(keybinds)

	local servers = discover_servers()
	if #servers > 0 then
		vim.lsp.enable(servers)
	end
end

return M
