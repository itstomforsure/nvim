local sc = require("sourcecontrol")
local internal = sc._internal

describe("sourcecontrol._internal.parse_porcelain", function()
	it("returns empty buckets for nil or empty input", function()
		local r = internal.parse_porcelain(nil)
		assert.same({}, r.staged)
		assert.same({}, r.changes)
		assert.same({}, r.untracked)

		r = internal.parse_porcelain({})
		assert.same({}, r.staged)
		assert.same({}, r.changes)
		assert.same({}, r.untracked)
	end)

	it("buckets staged-only modify (X=M, Y=' ') as staged", function()
		local r = internal.parse_porcelain({ "M  README.md" })
		assert.equals(1, #r.staged)
		assert.equals("M", r.staged[1].status)
		assert.equals("README.md", r.staged[1].file)
		assert.equals(0, #r.changes)
	end)

	it("buckets unstaged-only modify (X=' ', Y=M) as changes", function()
		local r = internal.parse_porcelain({ " M plugins.lua" })
		assert.equals(0, #r.staged)
		assert.equals(1, #r.changes)
		assert.equals("plugins.lua", r.changes[1].file)
	end)

	it("buckets MM into both staged and changes", function()
		local r = internal.parse_porcelain({ "MM both.lua" })
		assert.equals(1, #r.staged)
		assert.equals(1, #r.changes)
	end)

	it("buckets ?? as untracked exclusively", function()
		local r = internal.parse_porcelain({ "?? new.txt" })
		assert.equals(1, #r.untracked)
		assert.equals(0, #r.staged)
		assert.equals(0, #r.changes)
	end)

	it("uses the rename target after '-> ' for renamed paths", function()
		local r = internal.parse_porcelain({ "R  old.lua -> new.lua" })
		assert.equals("new.lua", r.staged[1].file)
		assert.equals("R", r.staged[1].status)
	end)

	it("ignores lines shorter than 3 characters", function()
		local r = internal.parse_porcelain({ "", "M", "ab", "M  ok.lua" })
		assert.equals(1, #r.staged)
		assert.equals("ok.lua", r.staged[1].file)
	end)

	it("preserves input order within each bucket", function()
		local r = internal.parse_porcelain({
			"M  a.lua", "M  b.lua", "M  c.lua",
		})
		assert.equals("a.lua", r.staged[1].file)
		assert.equals("b.lua", r.staged[2].file)
		assert.equals("c.lua", r.staged[3].file)
	end)

	it("handles a realistic mixed status set", function()
		local r = internal.parse_porcelain({
			"M  staged_only.lua",
			" D unstaged_delete.lua",
			"AM staged_add_then_modified.lua",
			"?? brand_new.txt",
			"D  staged_delete.lua",
		})
		assert.equals(3, #r.staged)
		assert.equals(2, #r.changes)
		assert.equals(1, #r.untracked)
	end)
end)

describe("sourcecontrol._internal.get_section", function()
	it("returns the four canonical sections", function()
		assert.is_table(internal.get_section("commits"))
		assert.is_table(internal.get_section("staged"))
		assert.is_table(internal.get_section("changes"))
		assert.is_table(internal.get_section("untracked"))
	end)

	it("returns nil for an unknown key", function()
		assert.is_nil(internal.get_section("does_not_exist"))
	end)

	it("each section has key and label fields", function()
		local sec = internal.get_section("staged")
		assert.equals("staged", sec.key)
		assert.equals("Staged Changes", sec.label)
	end)
end)

describe("sourcecontrol._internal.lines_to_text", function()
	it("returns empty string for an empty list", function()
		assert.equals("", internal.lines_to_text({}))
	end)

	it("joins with newlines and adds a trailing newline", function()
		assert.equals("a\nb\nc\n", internal.lines_to_text({ "a", "b", "c" }))
	end)
end)

describe("sourcecontrol._internal.file_icon", function()
	it("returns sensible defaults when devicons is unavailable", function()
		local saved_loaded = package.loaded["nvim-web-devicons"]
		local saved_preload = package.preload["nvim-web-devicons"]
		package.loaded["nvim-web-devicons"] = nil
		package.preload["nvim-web-devicons"] = function() error("missing") end

		local icon, hl = internal.file_icon("README.md")
		assert.equals("", icon)
		assert.equals("Normal", hl)

		package.loaded["nvim-web-devicons"] = saved_loaded
		package.preload["nvim-web-devicons"] = saved_preload
	end)
end)
