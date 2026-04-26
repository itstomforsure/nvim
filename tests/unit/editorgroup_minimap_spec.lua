local minimap = require("editorgroup.minimap")
local encode = minimap._internal.encode

describe("editorgroup.minimap._internal.encode", function()
	it("returns an empty list for an empty source", function()
		assert.same({}, encode({}, 4))
	end)

	it("emits one map row per 4 source lines (rounded up)", function()
		-- 1 source line → 1 row; 4 → 1 row; 5 → 2 rows; 8 → 2 rows; 9 → 3 rows.
		assert.equals(1, #encode({ "x" }, 4))
		assert.equals(1, #encode({ "x", "x", "x", "x" }, 4))
		assert.equals(2, #encode({ "x", "x", "x", "x", "x" }, 4))
		assert.equals(2, #encode({ "x", "x", "x", "x", "x", "x", "x", "x" }, 4))
		assert.equals(3, #encode({ "x", "x", "x", "x", "x", "x", "x", "x", "x" }, 4))
	end)

	it("each row has exactly map_width characters worth of braille codepoints", function()
		local rows = encode({ "abc", "def", "ghi", "jkl" }, 5)
		-- Lua-string length counts bytes; each braille codepoint is 3 bytes in UTF-8.
		assert.equals(5 * 3, #rows[1])
	end)

	it("empty lines (no non-whitespace) produce only blank braille (U+2800)", function()
		-- Single space line → 1 row of all-blank braille (codepoint 0x2800).
		local rows = encode({ "   " }, 2)
		assert.equals(1, #rows)
		-- 0x2800 in UTF-8 is E2 A0 80; per width 2, two codepoints = 6 bytes total.
		assert.equals(6, #rows[1])
		-- All 6 bytes are exactly the blank-braille pattern.
		assert.equals(string.rep("\xE2\xA0\x80", 2), rows[1])
	end)

	it("non-whitespace bytes produce non-blank braille codepoints", function()
		local rows = encode({ "x" }, 1)
		assert.equals(1, #rows)
		-- Single braille codepoint, 3 bytes, NOT the blank pattern (0x2800).
		assert.equals(3, #rows[1])
		assert.is_not.equals("\xE2\xA0\x80", rows[1])
	end)

	it("scales horizontally based on max line length and map_width", function()
		-- Long line forces scale > 1; encode shouldn't error and should still produce
		-- a single row (all 4 source lines fit in chunk 0).
		local long = string.rep("x", 100)
		local rows = encode({ long }, 4)
		assert.equals(1, #rows)
		assert.equals(4 * 3, #rows[1]) -- 4 braille codepoints * 3 bytes
	end)
end)
