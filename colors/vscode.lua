-- VSCode Dark+ inspired Neovim color scheme with TypeScript support
local set = vim.api.nvim_set_hl

-- Palette (matching VSCode Dark+ more closely)
local colors = {
	bg = "#1e1e1e",
	bg_light = "#252526",
	bg_select = "#264f78",
	fg = "#d4d4d4",
	comment = "#6a9955",
	string = "#ce9178",
	keyword = "#c586c0", -- Purple for keywords (import, export, return, etc.)
	keyword_blue = "#569cd6", -- Blue for const, let, var, this
	func = "#dcdcaa", -- Yellow for functions
	ident = "#9cdcfe", -- Light blue for variables
	ident_darker = "#4fc1ff", -- Slightly different blue
	const = "#4fc1ff", -- Constants
	type = "#4ec9b0", -- Teal for types
	num = "#b5cea8", -- Green for numbers
	op = "#d4d4d4", -- White for operators
	bracket_yellow = "#ffd700", -- Yellow for array brackets
	err = "#f44747",
	warn = "#ff8800",
	info = "#4fc1ff",
	hint = "#d7ba7d",
	cursorline = "#2a2a2a",
	line_nr = "#858585",
	split = "#444444",
	accent = "#007acc",
}

-- Editor
set(0, "Normal", { fg = colors.fg, bg = colors.bg })
set(0, "NormalFloat", { fg = colors.fg, bg = colors.bg_light })
set(0, "CursorLine", { bg = colors.cursorline })
set(0, "CursorColumn", { bg = colors.cursorline })
set(0, "Visual", { bg = colors.bg_select })
set(0, "Search", { fg = colors.bg, bg = colors.accent })
set(0, "IncSearch", { fg = colors.bg, bg = colors.accent, bold = true })
set(0, "MatchParen", { fg = colors.accent, bold = true })

-- UI
set(0, "LineNr", { fg = colors.line_nr })
set(0, "CursorLineNr", { fg = colors.func, bold = true })
set(0, "VertSplit", { fg = colors.split })
set(0, "WinSeparator", { fg = colors.split })
set(0, "StatusLine", { fg = colors.fg, bg = colors.accent })
set(0, "Pmenu", { fg = colors.fg, bg = colors.bg_light })
set(0, "PmenuSel", { fg = colors.bg, bg = colors.accent })
set(0, "SignColumn", { bg = colors.bg })
set(0, "ColorColumn", { bg = colors.bg_light })

-- Basic Syntax
set(0, "Comment", { fg = colors.comment, italic = true })
set(0, "String", { fg = colors.string })
set(0, "Character", { fg = colors.string })
set(0, "Keyword", { fg = colors.keyword })
set(0, "Conditional", { fg = colors.keyword })
set(0, "Repeat", { fg = colors.keyword })
set(0, "Function", { fg = colors.func })
set(0, "Identifier", { fg = colors.ident })
set(0, "Constant", { fg = colors.const })
set(0, "Number", { fg = colors.num })
set(0, "Float", { fg = colors.num })
set(0, "Boolean", { fg = colors.keyword_blue })
set(0, "Type", { fg = colors.type })
set(0, "StorageClass", { fg = colors.keyword_blue })
set(0, "Structure", { fg = colors.keyword_blue })
set(0, "Typedef", { fg = colors.keyword_blue })
set(0, "Operator", { fg = colors.op })
set(0, "Statement", { fg = colors.keyword })
set(0, "Include", { fg = colors.keyword })
set(0, "PreProc", { fg = colors.keyword })
set(0, "Exception", { fg = colors.keyword })
set(0, "Special", { fg = colors.func })
set(0, "SpecialChar", { fg = colors.string })
set(0, "Tag", { fg = colors.keyword })
set(0, "Delimiter", { fg = colors.fg })

-- Diagnostics (LSP)
set(0, "DiagnosticError", { fg = colors.err })
set(0, "DiagnosticWarn", { fg = colors.warn })
set(0, "DiagnosticInfo", { fg = colors.info })
set(0, "DiagnosticHint", { fg = colors.hint })
set(0, "DiagnosticUnderlineError", { undercurl = true, sp = colors.err })
set(0, "DiagnosticUnderlineWarn", { undercurl = true, sp = colors.warn })
set(0, "DiagnosticUnderlineInfo", { undercurl = true, sp = colors.info })
set(0, "DiagnosticUnderlineHint", { undercurl = true, sp = colors.hint })

-- Treesitter highlights for TypeScript/JavaScript
-- Comments
set(0, "@comment", { fg = colors.comment, italic = true })
set(0, "@comment.documentation", { fg = colors.comment, italic = true })

-- Literals
set(0, "@string", { fg = colors.string })
set(0, "@string.regex", { fg = colors.string })
set(0, "@string.escape", { fg = colors.func })
set(0, "@string.special", { fg = colors.func })
set(0, "@character", { fg = colors.string })
set(0, "@number", { fg = colors.num })
set(0, "@boolean", { fg = colors.keyword_blue })
set(0, "@float", { fg = colors.num })

-- Functions
set(0, "@function", { fg = colors.func })
set(0, "@function.builtin", { fg = colors.func })
set(0, "@function.call", { fg = colors.func })
set(0, "@function.macro", { fg = colors.func })
set(0, "@method", { fg = colors.func })
set(0, "@method.call", { fg = colors.func })
set(0, "@constructor", { fg = colors.type })
set(0, "@parameter", { fg = colors.ident })

-- Keywords
set(0, "@keyword", { fg = colors.keyword })
set(0, "@keyword.function", { fg = colors.keyword })
set(0, "@keyword.operator", { fg = colors.keyword })
set(0, "@keyword.return", { fg = colors.keyword })
set(0, "@keyword.import", { fg = colors.keyword })
set(0, "@keyword.export", { fg = colors.keyword })
set(0, "@conditional", { fg = colors.keyword })
set(0, "@repeat", { fg = colors.keyword })
set(0, "@label", { fg = colors.ident })
set(0, "@operator", { fg = colors.op })
set(0, "@exception", { fg = colors.keyword })
set(0, "@include", { fg = colors.keyword })

-- Punctuation
set(0, "@punctuation.delimiter", { fg = colors.fg })
set(0, "@punctuation.bracket", { fg = colors.func })
set(0, "@punctuation.special", { fg = colors.func })

-- Identifiers
set(0, "@variable", { fg = colors.ident })
set(0, "@variable.builtin", { fg = colors.keyword_blue })
set(0, "@variable.parameter", { fg = colors.ident })
set(0, "@variable.member", { fg = colors.ident })
set(0, "@constant", { fg = colors.const })
set(0, "@constant.builtin", { fg = colors.keyword_blue })
set(0, "@constant.macro", { fg = colors.const })
set(0, "@namespace", { fg = colors.ident })
set(0, "@symbol", { fg = colors.ident })

-- Types
set(0, "@type", { fg = colors.type })
set(0, "@type.builtin", { fg = colors.keyword_blue })
set(0, "@type.definition", { fg = colors.type })
set(0, "@type.qualifier", { fg = colors.keyword_blue })
set(0, "@storageclass", { fg = colors.keyword_blue })
set(0, "@attribute", { fg = colors.type })
set(0, "@field", { fg = colors.ident })
set(0, "@property", { fg = colors.ident })

-- TypeScript specific
set(0, "@keyword.import.typescript", { fg = colors.keyword })
set(0, "@keyword.export.typescript", { fg = colors.keyword })
set(0, "@keyword.return.typescript", { fg = colors.keyword })
set(0, "@keyword.operator.new.typescript", { fg = colors.keyword })
set(0, "@keyword.conditional.typescript", { fg = colors.keyword })
set(0, "@variable.builtin.typescript", { fg = colors.keyword_blue })
set(0, "@type.typescript", { fg = colors.type })
set(0, "@type.builtin.typescript", { fg = colors.keyword_blue })
set(0, "@constructor.typescript", { fg = colors.type })
set(0, "@namespace.typescript", { fg = colors.ident })
set(0, "@method.typescript", { fg = colors.func })
set(0, "@method.call.typescript", { fg = colors.func })
set(0, "@property.typescript", { fg = colors.ident })
set(0, "@variable.member.typescript", { fg = colors.ident })

-- Special handling for specific constructs
set(0, "@tag", { fg = colors.keyword })
set(0, "@tag.attribute", { fg = colors.ident })
set(0, "@tag.delimiter", { fg = colors.fg })

-- Text
set(0, "@text", { fg = colors.fg })
set(0, "@text.strong", { bold = true })
set(0, "@text.emphasis", { italic = true })
set(0, "@text.underline", { underline = true })
set(0, "@text.strike", { strikethrough = true })
set(0, "@text.title", { fg = colors.func, bold = true })
set(0, "@text.literal", { fg = colors.string })
set(0, "@text.uri", { fg = colors.string, underline = true })

-- LSP Semantic Tokens (if your LSP provides them)
set(0, "@lsp.type.class", { fg = colors.type })
set(0, "@lsp.type.decorator", { fg = colors.func })
set(0, "@lsp.type.enum", { fg = colors.type })
set(0, "@lsp.type.enumMember", { fg = colors.const })
set(0, "@lsp.type.function", { fg = colors.func })
set(0, "@lsp.type.interface", { fg = colors.type })
set(0, "@lsp.type.macro", { fg = colors.func })
set(0, "@lsp.type.method", { fg = colors.func })
set(0, "@lsp.type.namespace", { fg = colors.ident })
set(0, "@lsp.type.parameter", { fg = colors.ident })
set(0, "@lsp.type.property", { fg = colors.ident })
set(0, "@lsp.type.struct", { fg = colors.type })
set(0, "@lsp.type.type", { fg = colors.type })
set(0, "@lsp.type.typeParameter", { fg = colors.type })
set(0, "@lsp.type.variable", { fg = colors.ident })
set(0, "@lsp.typemod.variable.declaration", { fg = colors.ident })
set(0, "@lsp.typemod.variable.readonly", { fg = colors.const })
set(0, "@lsp.typemod.property.readonly", { fg = colors.const })
set(0, "@lsp.typemod.keyword", { fg = colors.keyword })
set(0, "@lsp.typemod.function.declaration", { fg = colors.func })

-- Git signs
set(0, "GitSignsAdd", { fg = "#587c0c" })
set(0, "GitSignsChange", { fg = "#0c7d9d" })
set(0, "GitSignsDelete", { fg = "#94151b" })

-- Additional TypeScript/JavaScript specific tweaks
-- These might need adjustment based on your treesitter queries
set(0, "@keyword.modifier.typescript", { fg = colors.keyword_blue }) -- for public, private, protected
set(0, "@keyword.modifier.javascript", { fg = colors.keyword_blue })
set(0, "@punctuation.bracket.typescript", { fg = colors.func }) -- for {} and ()
set(0, "@punctuation.bracket.javascript", { fg = colors.func })

-- Special: Override for array brackets to be yellow
-- Note: This might require custom treesitter queries to distinguish [] from other brackets
-- As a workaround, you might need to use a custom query or plugin
