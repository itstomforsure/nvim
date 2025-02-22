return {
	"nvim-tree/nvim-tree.lua",
	opts = {
		sync_root_with_cwd = true,
		respect_buf_cwd = true,
		update_focused_file = {
			enable = true,
			update_root = true,
			ignore_list = {},
		},
		view = {
			width = 35,
			side = "left",
			adaptive_size = false,
			number = false,
		},
	},
}
