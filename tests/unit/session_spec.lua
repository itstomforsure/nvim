local session = require("session")
local internal = session._internal

describe("session._internal.repo_id_from_root", function()
	it("returns nil for a nil root", function()
		assert.is_nil(internal.repo_id_from_root(nil))
	end)

	it("strips the leading slash and replaces / with __", function()
		assert.equals("home__tom__projects__nvim",
			internal.repo_id_from_root("/home/tom/projects/nvim"))
	end)

	it("handles a top-level path", function()
		assert.equals("a", internal.repo_id_from_root("/a"))
	end)
end)

describe("session._internal.session_path_for", function()
	it("returns nil when root is nil", function()
		assert.is_nil(internal.session_path_for("/state", nil, "main"))
	end)

	it("returns nil when branch is nil", function()
		assert.is_nil(internal.session_path_for("/state", "/repo", nil))
	end)

	it("composes <base>/<repo_id>/<safe_branch>.json", function()
		local got = internal.session_path_for(
			"/state", "/home/tom/repo", "main")
		assert.equals("/state/home__tom__repo/main.json", got)
	end)

	it("escapes / in branch names to __", function()
		local got = internal.session_path_for(
			"/state", "/home/tom/repo", "feature/foo")
		assert.equals("/state/home__tom__repo/feature__foo.json", got)
	end)
end)
