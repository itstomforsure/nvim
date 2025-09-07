-- AI generated Neovim color scheme inspired by VSCode's Dark+ theme
local set = vim.api.nvim_set_hl

-- Palette (Dark+ defaults)
local colors = {
  bg         = "#1e1e1e",
  bg_light   = "#252526",
  bg_select  = "#264f78",
  fg         = "#d4d4d4",
  comment    = "#6a9955",
  string     = "#ce9178",
  keyword    = "#569cd6",
  func       = "#dcdcaa",
  ident      = "#9cdcfe",
  const      = "#b5cea8",
  type       = "#4ec9b0",
  num        = "#b5cea8",
  op         = "#d4d4d4",
  err        = "#f44747",
  warn       = "#ff8800",
  info       = "#4fc1ff",
  hint       = "#d7ba7d",
  cursorline = "#2a2a2a",
  line_nr    = "#858585",
  split      = "#444444",
  accent     = "#007acc",
}

-- Editor
set(0, "Normal",       { fg = colors.fg, bg = colors.bg })
set(0, "NormalFloat",  { fg = colors.fg, bg = colors.bg_light })
set(0, "CursorLine",   { bg = colors.cursorline })
set(0, "CursorColumn", { bg = colors.cursorline })
set(0, "Visual",       { bg = colors.bg_select })
set(0, "Search",       { fg = colors.bg, bg = colors.accent })
set(0, "IncSearch",    { fg = colors.bg, bg = colors.accent, bold = true })
set(0, "MatchParen",   { fg = colors.accent, bold = true })

-- UI
set(0, "LineNr",       { fg = colors.line_nr })
set(0, "CursorLineNr", { fg = colors.func, bold = true })
set(0, "VertSplit",    { fg = colors.split })
set(0, "StatusLine",   { fg = colors.fg, bg = colors.accent })
set(0, "Pmenu",        { fg = colors.fg, bg = colors.bg_light })
set(0, "PmenuSel",     { fg = colors.bg, bg = colors.accent })
set(0, "SignColumn",   { bg = colors.bg })
set(0, "ColorColumn",  { bg = colors.bg_light })

-- Syntax
set(0, "Comment",      { fg = colors.comment, italic = true })
set(0, "String",       { fg = colors.string })
set(0, "Keyword",      { fg = colors.keyword })
set(0, "Function",     { fg = colors.func })
set(0, "Identifier",   { fg = colors.ident })
set(0, "Constant",     { fg = colors.const })
set(0, "Number",       { fg = colors.num })
set(0, "Type",         { fg = colors.type })
set(0, "Operator",     { fg = colors.op })

-- Diagnostics (LSP)
set(0, "DiagnosticError", { fg = colors.err })
set(0, "DiagnosticWarn",  { fg = colors.warn })
set(0, "DiagnosticInfo",  { fg = colors.info })
set(0, "DiagnosticHint",  { fg = colors.hint })

-- Diagnostics underline
set(0, "DiagnosticUnderlineError", { undercurl = true, sp = colors.err })
set(0, "DiagnosticUnderlineWarn",  { undercurl = true, sp = colors.warn })
set(0, "DiagnosticUnderlineInfo",  { undercurl = true, sp = colors.info })
set(0, "DiagnosticUnderlineHint",  { undercurl = true, sp = colors.hint })

-- Treesitter (if installed)
set(0, "@comment",        { fg = colors.comment, italic = true })
set(0, "@string",         { fg = colors.string })
set(0, "@keyword",        { fg = colors.keyword })
set(0, "@function",       { fg = colors.func })
set(0, "@variable",       { fg = colors.ident })
set(0, "@constant",       { fg = colors.const })
set(0, "@number",         { fg = colors.num })
set(0, "@type",           { fg = colors.type })
set(0, "@operator",       { fg = colors.op })

-- Git signs (if using gitsigns or similar)
set(0, "GitSignsAdd",    { fg = "#587c0c" })
set(0, "GitSignsChange", { fg = "#0c7d9d" })
set(0, "GitSignsDelete", { fg = "#94151b" })
