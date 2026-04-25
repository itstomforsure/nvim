local vim = vim

local function disabled(reason)
	if reason then
		vim.schedule(function()
			vim.notify("angularls disabled: " .. reason, vim.log.levels.DEBUG)
		end)
	end
	return { filetypes = {} }
end

local nvm_dir = os.getenv("NVM_DIR")
if not nvm_dir or nvm_dir == "" then
	return disabled("NVM_DIR not set")
end

local node_version = vim.fn.system("node -v"):gsub("%s+$", "")
if not node_version or node_version == "" then
	return disabled("no active node version")
end

local node_modules_path = vim.fn.expand(
	nvm_dir .. "/versions/node/" .. node_version .. "/lib/node_modules")
local ts_lib_path = node_modules_path .. "/typescript/lib"
local angular_language_server_path = node_modules_path .. "/@angular/language-server"

if vim.fn.isdirectory(ts_lib_path) == 0 then
	return disabled("typescript lib path missing: " .. ts_lib_path)
end

if vim.fn.isdirectory(angular_language_server_path) == 0 then
	return disabled("@angular/language-server missing: " ..
		angular_language_server_path)
end

return {
	cmd = {
		"ngserver",
		"--stdio",
		"--tsProbeLocations",
		ts_lib_path,
		"--ngProbeLocations",
		angular_language_server_path,
	},
	filetypes = { "html", "htmlangular" },
	root_markers = { "angular.json", "project.json" },
	settings = {
		angular = {
			enable = true,
			lint = true,
			suggest = {
				includeCompletionsWithInsertText = true,
				includeCompletionsForModuleExports = true,
			},
		},
	},
}
