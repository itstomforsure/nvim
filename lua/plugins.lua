-------------------------------------------------------------------------------
-- Plugins
-------------------------------------------------------------------------------
-- Uses Neovim 0.12's built-in vim.pack as the package manager.
-- Specs are listed once in a flat table; each spec carries its own config()
-- callback that runs after vim.pack has put the plugin on the runtimepath.
-- Plugin keymaps are owned by lua/keybindings.lua and applied via
-- keybinds.apply(<plugin_name>) inside each config().
-------------------------------------------------------------------------------

local vim = vim
local M = {}

local function pack(plugins)
	local specs = {}
	for _, p in ipairs(plugins) do
		table.insert(specs, { src = p.src, version = p.version, name = p.name })
	end
	vim.pack.add(specs)

	for _, p in ipairs(plugins) do
		if p.config then
			local ok, err = pcall(p.config)
			if not ok then
				vim.notify(("plugin '%s' config failed: %s"):format(p.src, err),
					vim.log.levels.ERROR)
			end
		end
	end
end

-- When vim.pack installs or updates nvim-treesitter, run :TSUpdate so parsers
-- stay in sync with the new runtime.
vim.api.nvim_create_autocmd("PackChanged", {
	callback = function(ev)
		local data = ev.data or {}
		local spec = data.spec or {}
		if spec.name ~= "nvim-treesitter" then return end
		if data.kind ~= "install" and data.kind ~= "update" then return end
		vim.schedule(function() pcall(vim.cmd, "TSUpdate") end)
	end,
})

function M.init(keybinds, symbols)
	-- Internal modules that have always been treated as first-class plugins.
	require("cmdline").setup(";")
	require("search").setup("/")
	require("sourcecontrol").setup()
	require("terminal").setup({
		keybind = "<leader>t",
		new_keybind = "<leader>T",
		prev_keybind = "[t",
		next_keybind = "]t"
	})

	pack({
		--------------------------------------------------------------------
		-- Snacks (priority everything: notifier, picker, explorer, etc.)
		--------------------------------------------------------------------
		{
			src = "https://github.com/folke/snacks.nvim",
			config = function()
				require("snacks").setup({
					bigfile = { enabled = true },
					dashboard = {
						enabled = true,
						-- Default `startup` section requires lazy.stats; omitted
						-- since we use vim.pack.
						sections = {
							{ section = "header" },
							{ section = "keys", gap = 1, padding = 1 },
							{ pane = 2, icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
							{ pane = 2, icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
						},
					},
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
				})

				_G.dd = function(...) Snacks.debug.inspect(...) end
				_G.bt = function() Snacks.debug.backtrace() end
				vim._print = function(_, ...) _G.dd(...) end

				keybinds.apply("snacks")

				for _, toggle in ipairs(keybinds.snacks.toggles) do
					if toggle.option then
						Snacks.toggle.option(toggle.option,
							{ name = toggle.name }):map(toggle.key)
					elseif toggle.method then
						Snacks.toggle[toggle.method]():map(toggle.key)
					end
				end
			end,
		},

		--------------------------------------------------------------------
		-- Web devicons (dependency for bufferline / lualine)
		--------------------------------------------------------------------
		{
			src = "https://github.com/nvim-tree/nvim-web-devicons",
		},

		--------------------------------------------------------------------
		-- Bufferline
		--------------------------------------------------------------------
		{
			src = "https://github.com/akinsho/bufferline.nvim",
			version = vim.version.range("*"),
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
							vim.api.nvim_set_current_buf(bufnr)
						end,
						right_mouse_command = nil,
						middle_mouse_command = function(bufnr)
							_G.SmartCloseBuf(bufnr)
						end,
						indicator = { style = "icon" },
						buffer_close_icon = "󰅖",
						modified_icon = "● ",
						close_icon = " ",
						left_trunc_marker = " ",
						right_trunc_marker = " ",
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
				keybinds.apply("bufferline")
			end,
		},

		--------------------------------------------------------------------
		-- Mini.map
		--------------------------------------------------------------------
		{
			src = "https://github.com/echasnovski/mini.map",
			version = vim.version.range("*"),
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

				keybinds.apply("minimap")
			end,
		},

		--------------------------------------------------------------------
		-- Treesitter
		--------------------------------------------------------------------
		{
			src = "https://github.com/nvim-treesitter/nvim-treesitter",
			version = "main",
			config = function()
				local ts_install = require("nvim-treesitter.install")

				ts_install.ensure_installed({
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
				})

				-- v1.0 has no setup({highlight=..., indent=...}). Start
				-- treesitter per buffer on FileType; pcall guards filetypes
				-- without an installed parser.
				vim.api.nvim_create_autocmd("FileType", {
					group = vim.api.nvim_create_augroup(
						"UserTreesitter", { clear = true }),
					callback = function(ev)
						if pcall(vim.treesitter.start, ev.buf) then
							vim.bo[ev.buf].indentexpr = "nvim_treesitter#indent()"
						end
					end,
				})

				-- Incremental selection (legacy gnn / grn / grc / grm).
				-- v1.0 dropped the built-in module; this re-implements it
				-- on top of vim.treesitter.get_node + the < / > marks.
				local sel_stack = {}

				local function set_selection(node)
					local srow, scol, erow, ecol = node:range()
					vim.api.nvim_buf_set_mark(0, "<", srow + 1, scol, {})
					vim.api.nvim_buf_set_mark(0, ">",
						erow + 1, math.max(0, ecol - 1), {})
					vim.cmd("normal! gv")
				end

				vim.keymap.set("n", "gnn", function()
					local node = vim.treesitter.get_node()
					if not node then return end
					sel_stack = { node }
					set_selection(node)
				end, { desc = "TS: init selection" })

				vim.keymap.set({ "x", "v" }, "grn", function()
					local top = sel_stack[#sel_stack]
					if not top then return end
					local parent = top:parent()
					if not parent then return end
					table.insert(sel_stack, parent)
					set_selection(parent)
				end, { desc = "TS: expand to parent node" })

				vim.keymap.set({ "x", "v" }, "grm", function()
					if #sel_stack <= 1 then return end
					table.remove(sel_stack)
					set_selection(sel_stack[#sel_stack])
				end, { desc = "TS: shrink to child node" })

				-- grc: climb to the nearest named ancestor whose type looks
				-- like a scope (function/block/loop/conditional). Falls
				-- through to plain parent if none match.
				local SCOPE_TYPES = {
					function_definition = true, function_declaration = true,
					method_definition = true, ["function"] = true,
					block = true, if_statement = true, for_statement = true,
					while_statement = true, do_statement = true,
					repeat_statement = true,
				}

				vim.keymap.set({ "x", "v" }, "grc", function()
					local top = sel_stack[#sel_stack]
					if not top then return end
					local node = top:parent()
					while node and not SCOPE_TYPES[node:type()] do
						node = node:parent()
					end
					node = node or (top:parent())
					if not node then return end
					table.insert(sel_stack, node)
					set_selection(node)
				end, { desc = "TS: expand to scope" })
			end,
		},

		--------------------------------------------------------------------
		-- Linting
		--------------------------------------------------------------------
		{
			src = "https://github.com/mfussenegger/nvim-lint",
			config = function()
				local lint = require("lint")
				lint.linters_by_ft = {
					lua = { "luacheck" },
					go = { "golangci-lint" },
					javascript = { "eslint_d" },
					javascriptreact = { "eslint_d" },
					typescript = { "eslint_d" },
					typescriptreact = { "eslint_d" },
					html = { "eslint_d" },
				}

				vim.api.nvim_create_autocmd(
					{ "BufWritePost", "InsertLeave", "TextChanged",
						"TextChangedI" },
					{
						callback = function() require("lint").try_lint() end,
					})
			end,
		},

		--------------------------------------------------------------------
		-- Formatting
		--------------------------------------------------------------------
		{
			src = "https://github.com/stevearc/conform.nvim",
			config = function()
				require("conform").setup({
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
				})
			end,
		},

		--------------------------------------------------------------------
		-- Lualine (bottom status bar)
		--------------------------------------------------------------------
		{
			src = "https://github.com/nvim-lualine/lualine.nvim",
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
						section_separators = { left = "", right = "" },
						component_separators = { left = "", right = "" },
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

		--------------------------------------------------------------------
		-- Claude Code
		--------------------------------------------------------------------
		{
			src = "https://github.com/coder/claudecode.nvim",
			config = function()
				require("claudecode").setup({})
				keybinds.apply("claude")
			end,
		},

		--------------------------------------------------------------------
		-- Copilot
		--------------------------------------------------------------------
		{
			src = "https://github.com/github/copilot.vim",
			version = "release",
			config = function()
				vim.g.copilot_no_tab_map = true
				keybinds.apply("copilot")
			end,
		},

		--------------------------------------------------------------------
		-- Plenary (dependency for CopilotChat)
		--------------------------------------------------------------------
		{
			src = "https://github.com/nvim-lua/plenary.nvim",
		},

		--------------------------------------------------------------------
		-- Copilot Chat
		--------------------------------------------------------------------
		{
			src = "https://github.com/CopilotC-Nvim/CopilotChat.nvim",
			config = function()
				require("CopilotChat").setup({
					model = "gpt-4o",
					window = {
						layout = "vertical",
						width = 0.4,
					},
				})
				keybinds.apply("copilot_chat")
			end,
		},
	})

	-- Editor groups (must run after pack() so any plugin-set keys are in place)
	require("editorgroup").setup({
		vsplit_key = "<leader>\\",
		close_group_key = "<leader>Q",
	})
end

return M
