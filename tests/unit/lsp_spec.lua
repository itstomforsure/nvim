local lsp = require("lsp")
local discover = lsp._internal.discover_servers

local function tmpdir()
	local d = vim.fn.tempname()
	vim.fn.mkdir(d, "p")
	return d
end

local function touch(path)
	local f = assert(io.open(path, "w"))
	f:close()
end

describe("lsp._internal.discover_servers", function()
	it("returns an empty list when the dir does not exist", function()
		assert.same({}, discover("/this/path/does/not/exist"))
	end)

	it("returns an empty list for an empty dir", function()
		assert.same({}, discover(tmpdir()))
	end)

	it("returns names (without .lua) for each .lua file", function()
		local d = tmpdir()
		touch(d .. "/lua_ls.lua")
		touch(d .. "/gopls.lua")
		touch(d .. "/ts_ls.lua")

		local names = discover(d)
		table.sort(names)
		assert.same({ "gopls", "lua_ls", "ts_ls" }, names)
	end)

	it("ignores non-.lua files and dot-files without .lua suffix", function()
		local d = tmpdir()
		touch(d .. "/lua_ls.lua")
		touch(d .. "/README.md")
		touch(d .. "/.hidden")
		touch(d .. "/notalua.txt")

		assert.same({ "lua_ls" }, discover(d))
	end)
end)
