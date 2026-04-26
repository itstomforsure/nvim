-- Minimal init for headless test runs.
-- Puts the project root on rtp so `require("layout")` etc. resolve,
-- and loads plenary from tests/.deps (cloned by run.sh / CI).

local project_root = vim.fn.fnamemodify(
	vim.fn.resolve(debug.getinfo(1, "S").source:sub(2)), ":p:h:h")

vim.opt.rtp:prepend(project_root)
vim.opt.rtp:prepend(project_root .. "/tests/.deps/plenary.nvim")
vim.opt.swapfile = false

vim.cmd("runtime plugin/plenary.vim")
require("plenary.busted")
