-- AI generated JetBrains IDE Dark Theme for Neovim
local set = vim.api.nvim_set_hl

-- Palette (approx JetBrains IDE dark)
local colors = {
  bg         = "#2b2b2b",  -- editor background
  bg_light   = "#323232",  -- panels, menus
  bg_select  = "#214283",  -- selection
  fg         = "#a9b7c6",  -- default text
  comment    = "#808080",  -- comments
  string     = "#6a8759",  -- strings
  keyword    = "#cc7832",  -- keywords
  func       = "#ffc66d",  -- functions
  ident      = "#a9b7c6",  -- variables/identifiers
  const      = "#9876aa",  -- constants
  num        = "#6897bb",  -- numbers
  type       = "#a9b7c6",  -- types (JetBrains uses subdued type colors)
  op         = "#a9b7c6",  -- operators
  err        = "#ff6b68",
  warn       = "#f9c859",
  info       = "#62b5ff",
  hint       = "#b8c275",
  cursorline = "#323232",
  line_nr    = "#606366",
  split      = "#3c3f41",
  accent     = "#3c78d8",  -- JetBrains blue accents
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

set(0, "DiagnosticUnderlineError", { undercurl = true, sp = colors.err })
set(0, "DiagnosticUnderlineWarn",  { undercurl = true, sp = colors.warn })
set(0, "DiagnosticUnderlineInfo",  { undercurl = true, sp = colors.info })
set(0, "DiagnosticUnderlineHint",  { undercurl = true, sp = colors.hint })

-- Treesitter
set(0, "@comment",        { fg = colors.comment, italic = true })
set(0, "@string",         { fg = colors.string })
set(0, "@keyword",        { fg = colors.keyword })
set(0, "@function",       { fg = colors.func })
set(0, "@variable",       { fg = colors.ident })
set(0, "@constant",       { fg = colors.const })
set(0, "@number",         { fg = colors.num })
set(0, "@type",           { fg = colors.type })
set(0, "@operator",       { fg = colors.op })

-- Git signs
set(0, "GitSignsAdd",    { fg = "#629755" })
set(0, "GitSignsChange", { fg = "#6897bb" })
set(0, "GitSignsDelete", { fg = "#ff6b68" })
