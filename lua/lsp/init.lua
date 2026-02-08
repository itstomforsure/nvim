local vim = vim

-- Main setup function
local root_dir = require("lsp/utils").find_project_root()

-- Enable EditorConfig if .editorconfig file exists
local editorconfig_file = root_dir .. "/.editorconfig"
if vim.fn.filereadable(editorconfig_file) == 1 then
	vim.cmd("silent! EditorConfigEnable")
	vim.notify("EditorConfig enabled from " .. editorconfig_file, vim.log.levels.INFO)
end

-- Setup LSP handlers and diagnostics
vim.lsp.handlers["textDocument/hover"] =
	vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded", max_width = 80, max_height = 20 })
vim.lsp.handlers["textDocument/signatureHelp"] =
	vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded", max_width = 80, max_height = 20 })

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
	{ name = "DiagnosticSignError", text = "x" },
	{ name = "DiagnosticSignWarn", text = "!" },
	{ name = "DiagnosticSignHint", text = "?" },
	{ name = "DiagnosticSignInfo", text = "i" },
}

for _, sign in pairs(signs) do
	vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = "" })
end

-- Setup completion
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspConfig", {}),
	callback = function(ev)
		vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"
	end,
})

do
	local ok, inline = pcall(require, "llm_inline")
	local accept_key = ok and type(inline.get_accept_key) == "function" and inline.get_accept_key() or nil

	if accept_key ~= "<Tab>" then
		vim.keymap.set("i", "<Tab>", function()
			if vim.fn.pumvisible() == 1 then
				return "<C-n>"
			end
			return "<Tab>"
		end, { expr = true })
	end
end

vim.keymap.set("i", "<S-Tab>", function()
	if vim.fn.pumvisible() == 1 then
		return "<C-p>"
	else
		return "<S-Tab>"
	end
end, { expr = true })

vim.keymap.set("i", "<CR>", function()
	if vim.fn.pumvisible() == 1 then
		return "<C-y>"
	else
		return "<CR>"
	end
end, { expr = true })

-- Setup user commands
vim.api.nvim_create_user_command("LspDebug", function()
	local clients = vim.lsp.get_clients()
	if #clients == 0 then
		vim.notify("No LSP clients are currently attached.")
		return
	end

	for _, client in pairs(clients) do
		vim.notify(string.format("LSP: %s (ID: %d)", client.name, client.id))
		vim.notify(" Supports definition: ", client.server_capabilities.definitionProvider or false)
		vim.notify(" Supports declaration: ", client.server_capabilities.declarationProvider or false)
		vim.notify(" Supports references: ", client.server_capabilities.referencesProvider or false)
		-- vim.notify(string.format("LSP: %s (ID: %d)", client.name, client.id), vim.inspect(client)))
	end
end, {})

vim.api.nvim_create_user_command("EslintConfig", function()
	local file = vim.fn.expand("%:p")
	vim.cmd("!" .. "eslint_d --print-config " .. file .. " | less")
end, {})

vim.api.nvim_create_user_command("PrettierConfig", function()
	local file = vim.fn.expand("%:p")
	vim.cmd("!" .. "prettier --find-config-path " .. file)
end, {})

-- Load LSP configurations
local config_path = vim.fn.stdpath("config") .. "/lua/lsp/"

for _, module in ipairs(vim.fn.readdir(config_path)) do
	local name = module:match("^(.*)%.lua$")
	if name and name ~= "init" and name ~= "utils" then
		local ok = pcall(require, "lsp." .. name)
		if not ok then
			vim.notify("Failed to load LSP module: " .. name, vim.log.levels.WARN)
		end
	end
end
