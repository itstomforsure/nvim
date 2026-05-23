local vim = vim

local function disabled(reason)
	if reason then
		vim.schedule(function()
			vim.notify("angularls disabled: " .. reason, vim.log.levels.DEBUG)
		end)
	end
	return { filetypes = {} }
end

-- Locate the global node_modules directory in a way that works regardless of how
-- node was installed (Homebrew, nvm, fnm, volta, asdf, system). `npm root -g` is
-- the canonical, manager-agnostic answer, so we never have to hardcode a layout.
local function global_node_modules()
	if vim.fn.executable("npm") == 0 then
		return nil, "npm not found on PATH"
	end
	local out = vim.fn.system({ "npm", "root", "-g" })
	if vim.v.shell_error ~= 0 then
		return nil, "`npm root -g` failed"
	end
	local dir = vim.trim(out)
	if dir == "" or vim.fn.isdirectory(dir) == 0 then
		return nil, "global node_modules not found: " .. dir
	end
	return dir
end

local node_modules, err = global_node_modules()
if not node_modules then
	return disabled(err)
end

local ts_lib_path = node_modules .. "/typescript/lib"
local angular_ls_path = node_modules .. "/@angular/language-server"

if vim.fn.executable("ngserver") == 0 then
	return disabled("ngserver not on PATH — run: npm install -g @angular/language-server")
end

if vim.fn.isdirectory(ts_lib_path) == 0 then
	return disabled("typescript lib missing: " .. ts_lib_path .. " — run: npm install -g typescript")
end

if vim.fn.isdirectory(angular_ls_path) == 0 then
	return disabled("@angular/language-server missing — run: npm install -g @angular/language-server")
end

return {
	cmd = {
		"ngserver",
		"--stdio",
		"--tsProbeLocations",
		ts_lib_path,
		"--ngProbeLocations",
		angular_ls_path,
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
