-------------------------------------------------------------------------------
-- Plugins
-------------------------------------------------------------------------------

local vim = vim
local M = {}

function M.init(keybinds, symbols)
	require("cmdline").setup(";")
	require("search").setup("/")
	require("sourcecontrol").setup()
	require("terminal").setup({
		keybind = "<leader>t",
		new_keybind = "<leader>T",
		prev_keybind = "[t",
		next_keybind = "]t"
	})
	-- require("error_window").setup("<leader>b")
	-- require("bufferline").setup()
	-- local llm_provider = vim.env.LLM_CHAT_PROVIDER or "ollama"
	-- require("llm_chat").setup({
	-- 	keybind = "<leader>g",
	-- 	new_keybind = "<leader>G",
	-- 	prev_keybind = "[g",
	-- 	next_keybind = "]g",
	-- 	add_buffer_keybind = "<leader>ga",
	-- 	add_buffers_keybind = "<leader>gA",
	-- 	add_nvim_tree_keybind = "<leader>gt",
	-- 	add_telescope_keybind = "<leader>gf",
	-- 	model_selector_keybind = "<leader>gb",
	-- 	provider = llm_provider,
	-- })
	-- require("llm_inline").setup({
	-- 	ollama_host = vim.env.OLLAMA_HOST,
	-- 	ollama_container = vim.env.OLLAMA_CONTAINER,
	-- 	accept_key = "<Tab>",
	-- })

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
		-- Snacks
		{
			"folke/snacks.nvim",
			priority = 1000,
			lazy = false,
			opts = {
				bigfile = { enabled = true },
				dashboard = { enabled = true },
				explorer = { enabled = true },
				indent = { enabled = true },
				input = { enabled = true },
				notifier = {
					enabled = true,
					timeout = 3000,
				},
				picker = {
					enabled = true,
					sources = {
						explorer = {
							hidden = true,
							ignored = true,
						},
					},
				},
				quickfile = { enabled = true },
				scope = { enabled = true },
				scroll = { enabled = true },
				statuscolumn = { enabled = true },
				words = { enabled = true },
				lazygit = { enabled = true },
			},
			keys = function()
				return keybinds.to_lazy_keys("snacks")
			end,
			init = function()
				vim.api.nvim_create_autocmd("User", {
					pattern = "VeryLazy",
					callback = function()
						_G.dd = function(...)
							Snacks.debug.inspect(...)
						end
						_G.bt = function()
							Snacks.debug.backtrace()
						end

						if vim.fn.has("nvim-0.11") == 1 then
							vim._print = function(_, ...)
								dd(...)
							end
						else
							vim.print = _G.dd
						end

						-- Toggle mappings driven by keybinds
						for _, toggle in ipairs(keybinds.snacks.toggles) do
							if toggle.option then
								Snacks.toggle.option(toggle.option,
									{ name = toggle.name }):map(toggle.key)
							elseif toggle.method then
								Snacks.toggle[toggle.method]():map(toggle.key)
							end
						end
					end,
				})
			end,
		},

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
						name_formatter = function(buf)
							local label = vim.b[buf.bufnr] and
								vim.b[buf.bufnr].sc_diff_label
							if label then return buf.name .. " " .. label end
							return buf.name
						end,
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
							{
								filetype = "sourcecontrol",
								text = "Source Control",
								highlight = "Directory",
								separator = true,
							},
							{
								filetype = "sourcecontrol_input",
								text = "Source Control",
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
			keys = keybinds.to_lazy_keys("bufferline"),
		},

		-- Minimap
		{
			"echasnovski/mini.map",
			version = "*",
			lazy = false,
			config = function()
				local map = require("mini.map")

				-- Custom integration: source control diff extmarks
				local sc_diff_integration = function()
					local ns_id = vim.api.nvim_create_namespace(
						"sourcecontrol_diff")
					local add_hl = "MiniMapSymbolDiffAdd"
					local del_hl = "MiniMapSymbolDiffDelete"

					vim.api.nvim_set_hl(0, add_hl, { fg = "#07ff00" })
					vim.api.nvim_set_hl(0, del_hl, { fg = "#ff0000" })

					return function()
						local buf = vim.api.nvim_get_current_buf()
						if not vim.b[buf].sc_diff_active then return {} end

						local marks = vim.api.nvim_buf_get_extmarks(
							buf, ns_id, 0, -1, { details = true })
						local out = {}
						for _, mark in ipairs(marks) do
							local line = mark[2] + 1
							local details = mark[4]
							if details.line_hl_group == "DiffAdd" then
								table.insert(out,
									{ line = line, hl_group = add_hl })
							elseif details.line_hl_group == "DiffDelete" then
								table.insert(out,
									{ line = line, hl_group = del_hl })
							end
							-- Virtual lines (deleted lines) - mark the anchor line
							if details.virt_lines then
								table.insert(out,
									{ line = line, hl_group = del_hl })
							end
						end
						return out
					end
				end

				map.setup({
					integrations = {
						map.gen_integration.builtin_search(),
						map.gen_integration.diagnostic({
							error = "DiagnosticFloatingError",
							warn = "DiagnosticFloatingWarn",
							info = "DiagnosticFloatingInfo",
							hint = "DiagnosticFloatingHint",
						}),
						map.gen_integration.diff(),
						sc_diff_integration(),
					},
					symbols = {
						encode = map.gen_encode_symbols.dot("4x2"),
						scroll_line = "▶",
						scroll_view = "┃",
					},
					window = {
						focusable = false,
						side = "right",
						width = 10,
						winblend = 10,
						show_integration_count = false,
					},
				})

				-- Auto behavior (reposition, open/close) is now handled by
				-- editorgroup/minimap.lua.  mini.map stays available for
				-- manual use via :lua MiniMap.open() if needed.
			end,
			keys = keybinds.to_lazy_keys("minimap"),
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
						extended_mode = true,
						max_file_lines = nil,
					},
				})
			end,
		},

		-- Comment
		{
			"numToStr/Comment.nvim",
			opts = {
				toggler = {
					line = keybinds.comment.binds.toggle.key,
				},
				opleader = {
					line = keybinds.comment.binds.toggle.key,
				},
			},
			keys = {
				{ keybinds.comment.binds.toggle.key, mode = keybinds.comment.binds.toggle.mode, desc = keybinds.comment.binds.toggle.desc },
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
					html = { "esling_d" }
				}

				vim.api.nvim_create_autocmd(
					{ "BufWritePost", "InsertLeave", "TextChanged",
						"TextChangedI" },
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
					timeout_ms = 1500,
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

									local linters = require("lint")
										.linters_by_ft
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

		-- Claude code
		{
			"coder/claudecode.nvim",
			dependencies = { "folke/snacks.nvim" },
			config = true,
			keys = keybinds.to_lazy_keys("claude"),
		},

		-- Copilot
		{
			"github/copilot.vim",
			event = "InsertEnter",
			init = function()
				vim.g.copilot_no_tab_map = true
			end,
			config = function()
				for _, bind in pairs(keybinds.copilot.binds) do
					vim.keymap.set(bind.mode or "n", bind.key, bind.cmd, {
						expr = bind.expr,
						replace_keycodes = bind.replace_keycodes,
						desc = bind.desc,
					})
				end
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
			keys = keybinds.to_lazy_keys("copilot_chat"),
		},
	})

	-- Editor groups (must run after lazy.setup so keybind overrides take effect)
	require("editorgroup").setup({
		vsplit_key = "<leader>\\",
		close_group_key = "<leader>Q",
	})
end

return M
