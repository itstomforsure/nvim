local M = {}

function M.load()
	local plugin_specs = {}

	for _, plugin in ipairs(vim.fn.glob("~/.config/nvim/lua/plugins/specs/*.lua", false, true)) do
		local name = vim.fn.fnamemodify(plugin, ":t:r")
		local spec = require("plugins.specs." .. name)
		if type(spec) == "table" then
			table.insert(plugin_specs, spec)
		end
	end

	return plugin_specs
end

return M.load()
