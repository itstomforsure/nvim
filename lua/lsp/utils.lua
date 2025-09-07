local vim = vim

local M = {}

function M.lsp_exists(server)
	local handle = io.popen("which " .. server .. " 2>/dev/null")
	if handle then
		local result = handle:read("*a")
		handle:close()
		return result and result ~= ""
	end
	return false
end

function M.find_project_root()
	local current_dir = vim.fn.expand("%:p:h")
	local root_markers = { "angular.json", "package.json", "project.json", ".git", ".editorconfig" }

	local function find_root(path)
		for _, marker in ipairs(root_markers) do
			if vim.fn.filereadable(vim.fn.join({ path, marker }, "/")) == 1 then
				return path
			end
		end

		local parent = vim.fn.fnamemodify(path, ":h")
		if parent == path then
			return nil
		end
		return find_root(parent)
	end

	return find_root(current_dir) or vim.fn.getcwd()
end

function M.detect_project_configs(root_dir)
	local configs = {
		editorconfig = vim.fn.filereadable(root_dir .. "/.editorconfig") == 1,
		eslint = vim.fn.filereadable(root_dir .. "/.eslintrc.json") == 1 or vim.fn.filereadable(
			root_dir .. "/.eslintrc.js"
		) == 1 or vim.fn.filereadable(root_dir .. "/.eslintrc.yaml") == 1 or vim.fn.filereadable(
			root_dir .. "/.eslintrc.yml"
		) == 1 or vim.fn.filereadable(root_dir .. "/eslint.config.js") == 1,
		prettier = vim.fn.filereadable(root_dir .. "/.prettierrc") == 1
			or vim.fn.filereadable(root_dir .. "/.prettierrc.json") == 1
			or vim.fn.filereadable(root_dir .. "/.prettierrc.js") == 1
			or vim.fn.filereadable(root_dir .. "/.prettierrc.yaml") == 1
			or vim.fn.filereadable(root_dir .. "/.prettierrc.yml") == 1
			or vim.fn.filereadable(root_dir .. "/prettier.config.js") == 1,
	}

	return configs
end

-- Common LSP on_attach function
function M.on_attach(client, bufnr)
	vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

	local opts = { silent = true, buffer = bufnr }

	vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
	vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
	vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
	vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
	vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
	vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)

	vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
	vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)

	vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
	vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
	vim.keymap.set("n", "<leader>r", vim.diagnostic.open_float, opts)
	vim.keymap.set("n", "<leader>R", vim.diagnostic.setloclist, opts)

	if client.server_capabilities.inlayHintProvider then
		vim.keymap.set("n", "<leader>ih", function()
			vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
			vim.notify(string.format("Inlay hints: %s", vim.lsp.inlay_hint.is_enabled() and "on" or "off"))
		end, opts)
	end
end

return M
