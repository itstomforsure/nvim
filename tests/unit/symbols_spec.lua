local symbols = require("symbols")

describe("symbols", function()
	local categories = { "os", "vcs", "lang", "ui", "dev", "misc" }

	it("exposes every expected category as a non-empty table", function()
		for _, cat in ipairs(categories) do
			assert.is_table(symbols[cat], "missing category: " .. cat)
			assert.is_true(next(symbols[cat]) ~= nil, "empty category: " .. cat)
		end
	end)

	it("only contains string values", function()
		for _, cat in ipairs(categories) do
			for key, value in pairs(symbols[cat]) do
				assert.equals("string", type(value),
					string.format("symbols.%s.%s is not a string", cat, key))
			end
		end
	end)

	it("provides icons referenced by other modules (lsp.lua, sourcecontrol.lua)", function()
		-- Pin keys other modules look up by name. Renames here break callers silently.
		assert.is_string(symbols.ui.error)
		assert.is_string(symbols.ui.warn)
		assert.is_string(symbols.ui.info)
		assert.is_string(symbols.ui.hint)
		assert.is_string(symbols.ui.search)
		assert.is_string(symbols.vcs.git)
		assert.is_string(symbols.vcs.branch)
		assert.is_string(symbols.misc.folder)
		assert.is_string(symbols.dev.lsp)
		assert.is_string(symbols.dev.linter)
		assert.is_string(symbols.dev.formatter)
		assert.is_string(symbols.dev.command)
	end)
end)
