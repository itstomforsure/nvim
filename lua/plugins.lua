local vim = vim

vim.notify = require("notify").notify
require("error_window").setup("<leader>b")
require("cmdline").setup(";")
require("search").setup("/")
require("terminal").setup({ keybind = "<leader>t", new_keybind = "<leader>T", prev_keybind = "[t", next_keybind = "]t" })
-- require("llm").setup({ debounce_ms = 250, debug = true })
require("llm_chat").setup({ keybind = "<leader>g", position = "rightbelow" })
-- require("comment").setup("<leader>/")

local symbols = require("symbols")

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

require("lazy").setup({
	-- Treesitter
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "master",
		lazy = false,
		build = ":TSUpdate",
		config = function()
			require("nvim-treesitter.configs").setup({
				ensure_installed = {
					"lua",
					"typescript",
					"javascript",
					"html",
					"css",
					"go",
					"gomod",
					"gosum",
					"gowork",
					"json",
					"bash",
					"vim",
					"markdown",
					"markdown_inline",
					"regex",
					"yaml",
					"toml",
					"query",
					"gitignore",
				},
				auto_install = true,
				highlight = {
					enable = true,
					additional_vim_regex_highlighting = false,
				},
				indent = { enable = true },
				incremental_selection = {
					enable = true,
					keymaps = {
						init_selection = "gnn", -- start selection
						node_incremental = "grn", -- expand
						scope_incremental = "grc", -- expand scope
						node_decremental = "grm", -- shrink
					},
				},
				rainbow = {
					enable = true,
					extended_mode = true, -- also highlight non-bracket delimiters like <>
					max_file_lines = nil,
				},
			})
		end,
	},

	-- Telescope
	{
		"nvim-telescope/telescope.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			{
				"nvim-telescope/telescope-fzf-native.nvim",
				build = "make",
			},
		},
		keys = {
			{ "<leader>ff", "<cmd>Telescope find_files<cr>" },
			{ "<leader>fg", "<cmd>Telescope live_grep<cr>" },
			{ "<leader>fr", "<cmd>Telescope lsp_references<cr>" },
			{ "<leader>fb", "<cmd>Telescope buffers<cr>" },
			{ "<leader>fh", "<cmd>Telescope help_tags<cr>" },
		},
		config = function()
			local telescope = require("telescope")
			pcall(telescope.load_extension, "fzf")
		end,
	},

	-- Comment
	{
		"numToStr/Comment.nvim",
		opts = {
			toggler = {
				line = "<leader>/",
			},
			opleader = {
				line = "<leader>/",
			},
		},
		keys = {
			{ "<leader>/", mode = { "n", "v" } },
		},
	},

	-- Explorer
	{
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
				width = 55,
				side = "left",
				adaptive_size = false,
				number = false,
			},
		},
	},

	-- Linting
	{
		"mfussenegger/nvim-lint",
		config = function()
			local lint = require("lint")
			lint.linters_by_ft = {
				lua = { "luacheck" },
				go = { "golangci-lint" },
				javascript = { "eslint_d" },
				javascriptreact = { "eslint_d" },
				typescript = { "eslint_d" },
				typescriptreact = { "eslint_d" },
			}

			vim.api.nvim_create_autocmd(
				{ "BufWritePost", "InsertLeave", "TextChanged", "TextChangedI" },
				{
					callback = function()
						require("lint").try_lint()
					end,
				})
		end,
	},

	-- Formatting
	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				lua = { "stylua" },
				go = { "gofumpt", "goimports" },
				javascript = { "prettierd", "prettier" },
				javascriptreact = { "prettierd", "prettier" },
				typescript = { "prettierd", "prettier" },
				typescriptreact = { "prettierd", "prettier" },
				html = { "prettierd", "prettier" },
				css = { "prettierd", "prettier" },
				scss = { "prettierd", "prettier" },
				json = { "prettierd", "prettier" },
				yaml = { "prettierd", "prettier" },
				markdown = { "prettierd", "prettier" },
			},
			format_on_save = {
				lsp_fallback = true,
				timeout_ms = 500,
			},
		},
	},

	-- Buffer configuration
	{
		"akinsho/bufferline.nvim",
		dependencies = "nvim-tree/nvim-web-devicons",
		config = function()
			require("bufferline").setup({
				options = {
					offsets = {
						{
							filetype = "NvimTree",
							text = "File Explorer",
							highlight = "Directory",
							separator = true,
						},
					},
					show_buffer_icons = true,
					show_buffer_close_icons = true,
					show_close_icon = true,
					show_tab_indicators = true,
					diagnostics = "nvim_lsp",
					diagnostics_indicator = function(count, level)
						local icon = level:match("error") and " " or " "
						return " " .. icon .. count
					end,
					separator_style = "slant",
					modified_icon = "●",
					enforce_regular_tabs = false,
					always_show_bufferline = true,
					tab_size = 32,
					max_name_length = 25,
				},
			})
		end,
	},

	-- Bottom status bar
	{
		"nvim-lualine/lualine.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			local function line_info()
				local line = vim.fn.line(".")
				local col = vim.fn.col(".")
				local total_lines = vim.fn.line("$")
				return string.format("%d:%d / %d", line, col, total_lines)
			end
			require("lualine").setup({
				options = {
					theme = "nord",
					section_separators = { left = "", right = "" },
					component_separators = { left = "", right = "" },
					globalstatus = true,
				},
				sections = {
					lualine_b = { "branch" },
					lualine_c = { "filename" },
					lualine_x = {
						{
							"diagnostics",
							sources = { "nvim_diagnostic" },
							symbols = {
								error = symbols.ui.error,
								warn = symbols.ui.warn,
								info = symbols.ui.info,
								hint = symbols.ui.hint,
							},
						},
						{
							function()
								local buf_clients = vim.lsp.get_clients({ bufnr = 0 })
								local parts = {}

								if #buf_clients > 0 then
									local lsps = {}
									for _, client in pairs(buf_clients) do
										table.insert(lsps, client.name)
									end
									table.insert(parts,
										symbols.dev.lsp ..
										" " .. table.concat(lsps, ", "))
								end

								local linters = require("lint").linters_by_ft
									[vim.bo.filetype] or {}
								if #linters > 0 then
									table.insert(parts,
										symbols.dev.linter ..
										" " .. table.concat(linters, ", "))
								end

								local formatters = require("conform")
									.list_formatters(0)
								if #formatters > 0 then
									local names = {}
									for _, f in ipairs(formatters) do
										table.insert(names, f.name)
									end
									table.insert(parts,
										symbols.dev.formatter ..
										" " .. table.concat(names, ", "))
								end

								if #parts == 0 then
									return "No LSP"
								end

								return table.concat(parts, " | ")
							end,
							icon = "",
						},
					},
					lualine_y = { "filetype" },
					lualine_z = { line_info },
				},
				extensions = { "fugitive", "nvim-tree" },
			})
		end,
	},

	-- Lazygit
	{
		"kdheepak/lazygit.nvim",
		lazy = false,
		cmd = {
			"LazyGit",
			"LazyGitConfig",
			"LazyGitCurrentFile",
			"LazyGitFilter",
			"LazyGitFilterCurrentFile",
		},
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
		keys = {
			{ "<leader>gg", ":LazyGit<cr>" },
		},
	},

	-- Copilot
	{
		"github/copilot.vim",
		lazy = true,
		cmd = "Copilot",
		init = function()
			vim.g.copilot_enabled = true
			vim.notify("Copilot enabled: " .. vim.g.copilot_enabled)
		end,
		keys = {
			{
				"<leader>c",
				function()
					if vim.g.copilot_enabled == true then
						vim.g.copilot_enabled = false
						vim.notify("Copilot Disabled")
					else
						vim.g.copilot_enabled = true
						vim.notify("Copilot Enabled")
					end
				end,
			},
		},
	},

	-- Copilot Chat
	{
		"CopilotC-Nvim/CopilotChat.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"github/copilot.vim",
		},
		build = "make tiktoken",
		lazy = true,
		keys = {
			{ "<leader>cp",  ":CopilotChat<CR>" },
			{ "<leader>cpe", ":CopilotChatExplain<CR>" },
			{ "<leader>cpf", ":CopilotChatFix<CR>" },
			{ "<leader>cpo", ":CopilotChatOptimize<CR>" },
		},
		config = function()
			require("CopilotChat").setup({
				auto_insert_mode = true,
				window = {
					layout = "vertical",
					border = "simple",
					width = 0.25,
				},
				headers = {
					user = "👤 Copilot Chat ",
				},
			})
		end,
	},
})
