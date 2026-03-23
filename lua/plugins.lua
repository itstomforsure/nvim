local vim = vim

vim.notify = require("notify").notify
require("search").setup("\\")

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
	-- Bufferline
	{
		"akinsho/bufferline.nvim",
		version = "*",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		lazy = false,
		config = function()
			local bufferline = require("bufferline")
			bufferline.setup({
				options = {
					mode = "buffers",
					style_preset = bufferline.style_preset.default,
					themable = true,
					numbers = "ordinal",
					close_command = function(bufnr) _G.SmartCloseBuf(bufnr) end,
					left_mouse_command = function(bufnr)
						vim.api
							.nvim_set_current_buf(bufnr)
					end,
					right_mouse_command = nil,
					middle_mouse_command = function(bufnr)
						_G.SmartCloseBuf(
							bufnr)
					end,
					indicator = {
						style = 'icon'
					},
					buffer_close_icon = '󰅖',
					modified_icon = '● ',
					close_icon = ' ',
					left_trunc_marker = ' ',
					right_trunc_marker = ' ',
					max_name_length = 18,
					max_prefix_length = 15,
					truncate_names = true,
					tab_size = 18,
					diagnostics = "nvim_lsp",
					diagnostics_update_on_event = true,
					diagnostics_indicator = function(count, level)
						local icon = level:match("error") and " " or " "
						return " " .. icon .. count
					end,
					offsets = {
						{
							filetype = "snacks_layout_box",
							text = "Explorer",
							highlight = "Directory",
							separator = true,
						},
					},
					color_icons = true,
					show_buffer_icons = true,
					show_buffer_close_icons = true,
					show_close_icon = true,
					show_tab_indicators = true,
					separator_style = "slant",
				},
			})
		end,
		keys = {
			{ "<Tab>",   "<cmd>BufferLineCycleNext<cr>", desc = "Next buffer" },
			{ "<S-Tab>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev buffer" },
		},
	},

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
			{ "<leader>fr", "<cmd>Telescope lsp_references<cr>" },
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

	-- Snacks
	{
		"folke/snacks.nvim",
		priority = 1000,
		lazy = false,
		---@type snacks.Config
		opts = {
			animate = {
				duration = 10, -- ms per step
				easing = "linear",
				fps = 120,
			},
			bigfile = { enabled = true },
			dashboard = { enabled = true },
			explorer = { enabled = true },
			indent = { enabled = true },
			input = { enabled = true },
			notifier = {
				enabled = true,
				timeout = 3000,
			},
			picker = { enabled = true },
			quickfile = { enabled = true },
			scope = { enabled = true },
			scroll = { enabled = true },
			statuscolumn = { enabled = true },
			words = { enabled = true },
			terminal = {
				win = {
					height = 0.3
				}
			},
			lazygit = {
				win = {
					height = 0.9
				}
			},
			styles = {
				notification = {
					wo = { wrap = true } -- Wrap notifications
				}
			},
		},
		keys = {
			-- Top Pickers & Explorer
			{ "<leader><space>", function() Snacks.picker.grep() end,            desc = "Grep" },
			{ "<leader>;",       function() Snacks.picker.command_history() end, desc = "Command History" },
			{ "<leader>n",       function() Snacks.picker.notifications() end,   desc = "Notification History" },
			{
				"<leader>e",
				function()
					local explorer = Snacks.picker.get({ source = "explorer" })
						[1]
					if explorer then
						explorer:focus()
					else
						Snacks.explorer.open()
					end
				end,
				desc = "Focus/Open File Explorer"
			},
			{
				"<leader>E",
				function() Snacks.explorer() end,
				desc = "Toggle File Explorer"
			},
			{ "<leader>ff", function() Snacks.picker.files() end,                 desc = "Find Files" },
			{ "<leader>fg", function() Snacks.picker.git_files() end,             desc = "Find Git Files" },
			{ "<leader>fb", function() Snacks.picker.buffers() end,               desc = "Buffers" },
			{ "<leader>gb", function() Snacks.picker.git_branches() end,          desc = "Git Branches" },
			{ "<leader>gl", function() Snacks.picker.git_log() end,               desc = "Git Log" },
			{ "<leader>gL", function() Snacks.picker.git_log_line() end,          desc = "Git Log Line" },
			{ "<leader>gs", function() Snacks.picker.git_status() end,            desc = "Git Status" },
			{ "<leader>gS", function() Snacks.picker.git_stash() end,             desc = "Git Stash" },
			{ "<leader>gd", function() Snacks.picker.git_diff() end,              desc = "Git Diff (Hunks)" },
			{ "<leader>gf", function() Snacks.picker.git_log_file() end,          desc = "Git Log File" },
			{ "<leader>gw", function() Snacks.picker.grep_word() end,             desc = "Visual selection or word", mode = { "n", "x" } },
			{ "<leader>uc", function() Snacks.picker.colorschemes() end,          desc = "Colorschemes" },
			-- search
			{ '<leader>hr', function() Snacks.picker.registers() end,             desc = "Registers" },
			{ '<leader>hs', function() Snacks.picker.search_history() end,        desc = "Search History" },
			{ "<leader>hu", function() Snacks.picker.undo() end,                  desc = "Undo History" },
			{ "<leader>sa", function() Snacks.picker.autocmds() end,              desc = "Autocmds" },
			{ "<leader>sC", function() Snacks.picker.commands() end,              desc = "Commands" },
			{ "<leader>sd", function() Snacks.picker.diagnostics() end,           desc = "Diagnostics" },
			{ "<leader>sD", function() Snacks.picker.diagnostics_buffer() end,    desc = "Buffer Diagnostics" },
			{ "<leader>sh", function() Snacks.picker.highlights() end,            desc = "Highlights" },
			{ "<leader>si", function() Snacks.picker.icons() end,                 desc = "Icons" },
			{ "<leader>sj", function() Snacks.picker.jumps() end,                 desc = "Jumps" },
			{ "<leader>sk", function() Snacks.picker.keymaps() end,               desc = "Keymaps" },
			{ "gi",         function() Snacks.picker.lsp_implementations() end,   desc = "Goto Implementation" },
			{ "gy",         function() Snacks.picker.lsp_type_definitions() end,  desc = "Goto T[y]pe Definition" },
			{ "<leader>ss", function() Snacks.picker.lsp_symbols() end,           desc = "LSP Symbols" },
			{ "<leader>sS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "LSP Workspace Symbols" },
			-- Other
			{ "<leader>gB", function() Snacks.gitbrowse() end,                    desc = "Git Browse",               mode = { "n", "v" } },
			{ "<leader>gg", function() Snacks.lazygit() end,                      desc = "Lazygit" },
			{ "<leader>t",  function() Snacks.terminal() end,                     desc = "Toggle Terminal" },
			{ "]]",         function() Snacks.words.jump(vim.v.count1) end,       desc = "Next Reference",           mode = { "n", "t" } },
			{ "[[",         function() Snacks.words.jump(-vim.v.count1) end,      desc = "Prev Reference",           mode = { "n", "t" } },
		},
		init = function()
			vim.api.nvim_create_autocmd("User", {
				pattern = "VeryLazy",
				callback = function()
					-- Setup some globals for debugging (lazy-loaded)
					_G.dd = function(...)
						Snacks.debug.inspect(...)
					end
					_G.bt = function()
						Snacks.debug.backtrace()
					end

					-- Override print to use snacks for `:=` command
					if vim.fn.has("nvim-0.11") == 1 then
						vim._print = function(_, ...)
							dd(...)
						end
					else
						vim.print = _G.dd
					end

					-- Create some toggle mappings
					Snacks.toggle.option("spell", { name = "Spelling" }):map(
						"<leader>us")
					Snacks.toggle.option("wrap", { name = "Wrap" }):map(
						"<leader>uw")
					Snacks.toggle.option("relativenumber",
						{ name = "Relative Number" }):map("<leader>uL")
					Snacks.toggle.diagnostics():map("<leader>ud")
					Snacks.toggle.line_number():map("<leader>ul")
					Snacks.toggle.inlay_hints():map("<leader>uh")
					Snacks.toggle.indent():map("<leader>ug")
					Snacks.toggle.dim():map("<leader>uD")
					Snacks.toggle.treesitter():map("<leader>uT")
				end,
			})
		end,
	},

	-- Claude code
	{
		"coder/claudecode.nvim",
		dependencies = { "folke/snacks.nvim" },
		config = true,
		keys = {
			{ "<leader>v",  "<cmd>ClaudeCode<cr>",            desc = "Toggle Claude" },
			{ "<leader>vf", "<cmd>ClaudeCodeFocus<cr>",       desc = "Focus Claude" },
			{ "<leader>vr", "<cmd>ClaudeCode --resume<cr>",   desc = "Resume Claude" },
			{ "<leader>vc", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
			{ "<leader>vm", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
			{ "<leader>vb", "<cmd>ClaudeCodeAdd %<cr>",       desc = "Add current buffer" },
			{ "<leader>vs", "<cmd>ClaudeCodeSend<cr>",        mode = "v",                  desc = "Send to Claude" },
			{
				"<leader>vB",
				"<cmd>ClaudeCodeTreeAdd<cr>",
				desc = "Add file",
				ft = { "NvimTree", "neo-tree", "oil", "minifiles", "netrw" },
			},
			-- Diff management
			{ "<leader>vv", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
			{ "<leader>vd", "<cmd>ClaudeCodeDiffDeny<cr>",   desc = "Deny diff" },
		},
	},

	-- Copilot
	{
		"github/copilot.vim",
		event = "InsertEnter",
		init = function()
			vim.g.copilot_no_tab_map = true
		end,
		config = function()
			-- Accept full suggestion
			vim.keymap.set("i", "<C-l>", 'copilot#Accept("\\<CR>")', {
				expr = true,
				replace_keycodes = false,
				desc = "Accept Copilot suggestion",
			})
			-- Accept next word only
			vim.keymap.set("i", "<M-l>", "<Plug>(copilot-accept-word)",
				{ desc = "Accept Copilot word" })
			-- Dismiss suggestion
			vim.keymap.set("i", "<C-]>", "<Plug>(copilot-dismiss)",
				{ desc = "Dismiss Copilot suggestion" })
			-- Cycle suggestions
			vim.keymap.set("i", "<M-n>", "<Plug>(copilot-next)",
				{ desc = "Next Copilot suggestion" })
			vim.keymap.set("i", "<M-p>", "<Plug>(copilot-prev)",
				{ desc = "Prev Copilot suggestion" })
		end,
	},

	-- Copilot Chat
	{
		"CopilotC-Nvim/CopilotChat.nvim",
		dependencies = {
			{ "github/copilot.vim" },
			{ "nvim-lua/plenary.nvim" },
		},
		event = "VeryLazy",
		config = function()
			require("CopilotChat").setup({
				model = "gpt-4o",
				window = {
					layout = "vertical",
					width = 0.4,
				},
			})
		end,
		keys = {
			{ "<leader>cc", "<cmd>CopilotChatToggle<cr>",   desc = "Toggle Copilot Chat" },
			{ "<leader>cm", "<cmd>CopilotChatModels<cr>",   desc = "Select Copilot Model" },
			{ "<leader>ce", "<cmd>CopilotChatExplain<cr>",  mode = { "n", "v" },          desc = "Copilot Explain" },
			{ "<leader>cf", "<cmd>CopilotChatFix<cr>",      mode = { "n", "v" },          desc = "Copilot Fix" },
			{ "<leader>co", "<cmd>CopilotChatOptimize<cr>", mode = { "n", "v" },          desc = "Copilot Optimize" },
			{ "<leader>cr", "<cmd>CopilotChatReview<cr>",   mode = { "n", "v" },          desc = "Copilot Review" },
			{ "<leader>ct", "<cmd>CopilotChatTests<cr>",    mode = { "n", "v" },          desc = "Copilot Tests" },
			{
				"<leader>cq",
				function()
					local input = vim.fn.input("Quick Chat: ")
					if input ~= "" then
						require("CopilotChat").ask(input,
							{ selection = require("CopilotChat.select").buffer })
					end
				end,
				desc = "Copilot Quick Chat",
			},
		},
	},
})
