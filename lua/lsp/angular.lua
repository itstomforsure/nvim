local lsp_utils = require("lsp/utils")

local fileTypes = { "html", "htmlangular" }

if not lsp_utils.lsp_exists("typescript-language-server") then
	vim.notify("typescript-language-server not found in PATH")
	return
end

if not lsp_utils.lsp_exists("ngserver") then
	vim.notify("ngserver not found in PATH")
	return
end

local nvm_dir = os.getenv("NVM_DIR")

if not nvm_dir or nvm_dir == "" then
	vim.notify("NVM_DIR environment variable is not set")
end

local node_version = vim.fn.system("node -v"):gsub("%s+$", "")

if not node_version or node_version == "" then
	vim.notify("No Node.js version is currently active in nvm")
end

local node_modules_path = vim.fn.expand(nvm_dir .. "/versions/node/" .. node_version .. "/lib/node_modules")
local ts_lib_path = node_modules_path .. "/typescript/lib"
local angular_language_server_path = node_modules_path .. "/@angular/language-server"

if vim.fn.isdirectory(ts_lib_path) == 0 then
	vim.notify("TypeScript lib path not found: " .. ts_lib_path)
	return
end

if vim.fn.isdirectory(angular_language_server_path) == 0 then
	vim.notify("Angular language server path not found: " .. angular_language_server_path)
	return
end

local config = {
	name = "angularls",
	cmd = { 
		"ngserver", 
		"--stdio", 
		"--tsProbeLocations", ts_lib_path,
		"--ngProbeLocations", angular_language_server_path 
	},
	filetypes = fileTypes,
	root_dir = lsp_utils.find_project_root,
	on_attach = lsp_utils.on_attach,
	settings = {
		angular = {
			enable = true,
			lint = true,
			suggest = {
				includeCompletionsWithInsertText = true,
				includeCompletionsForModuleExports = true
			}
		}
	},
	capabilities = vim.lsp.protocol.make_client_capabilities(),
}

vim.api.nvim_create_autocmd("FileType", {
	pattern = fileTypes,
	callback = function()
		local root_dir = lsp_utils.find_project_root()

		if vim.fn.filereadable(root_dir .. "/angular.json") == 1 or
			vim.fn.filereadable(root_dir .. "/project.json") == 1 then
			local existing_clients = vim.lsp.get_clients({ bufnr = 0, name = "angularls" })
			if #existing_clients == 0 then
				vim.lsp.start(config)
			end
		end
	end,
})
