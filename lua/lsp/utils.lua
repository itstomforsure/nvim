local vim = vim

local M = {}

function M.init(keybinds)
	M.keybinds = keybinds
	vim.diagnostic.config({
		update_in_insert = true,
		virtual_text = true,
	})
end

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
	local root_markers = { "angular.json", "package.json", "project.json", ".git",
		".editorconfig", "lazy-lock.json", "README.md" }

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
		eslint = vim.fn.filereadable(root_dir .. "/.eslintrc.json") == 1 or
			vim.fn.filereadable(
				root_dir .. "/.eslintrc.js"
			) == 1 or vim.fn.filereadable(root_dir .. "/.eslintrc.yaml") == 1 or
			vim.fn.filereadable(
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

	for _, value in pairs(M.keybinds.lsp.binds) do
		vim.keymap.set(value.mode, value.key, value.cmd, opts)
	end

	if client.server_capabilities.inlayHintProvider then
		local inlay_hint_bind = M.keybinds.lsp.inlay_hint
		vim.keymap.set(inlay_hint_bind.mode, inlay_hint_bind.key, function()
			vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
			vim.notify(string.format("Inlay hints: %s",
				vim.lsp.inlay_hint.is_enabled() and "on" or "off"))
		end, opts)
	end
end

return M
