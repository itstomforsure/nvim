local M = {}

function M.setup()
  print("Core init")
	local lazy_path = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
	if not vim.loop.fs_stat(lazy_path) then
		vim.fn.system({
			"git",
			"clone",
			"--filter=blob:none",
			"https://github.com/folke/lazy.nvim.git",
			"--branch=stable",
			lazy_path,
		})
	end
	vim.opt.rtp:prepend(lazy_path)

	local plugins = require("plugins")
	require("lazy").setup(plugins)
end

return M
