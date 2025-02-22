return {
	"wfxr/minimap.vim",
	build = "cargo install --locked code-minimap",
	-- keys = {
	--   remap({ "n", "t" }, "<leader>mm", ":MinimapToggle<CR>", { desc = "Toggle minimap window" }),
	--   remap({ "n", "t" }, "<leader>mr", ":MinimapRefresh<CR>", { desc = "Force refresh minimap window" }),
	--   remap({ "n", "t" }, "<leader>mu", ":MinimapUpdateHighlight<CR>", { desc = "Force update minimap highlight" }),
	--   remap({ "n", "t" }, "<leader>me", ":MinimapRescan<CR>", { desc = "Force recalculation of minimap scaling ratio" }),
	-- },
	config = function()
		vim.g.minimap_width = 10
		vim.g.minimap_highlight_search = 1
		vim.g.minimap_git_colors = 1
		vim.g.minimap_range_color = "Search"
		-- :highlight minimapRange ctermbg=242 ctermfg=228 guibg=#004c68 guifg=#00d0ff
	end,
}
