-------------------------------------------------------------------------------
-- Framework
-------------------------------------------------------------------------------

local vim = vim
vim.notify = require("notify").notify
local keybinds = require('keybindings')
local symbols = require("symbols")
require("layout").init()
require("plugins").init(keybinds, symbols)
require("lsp")
