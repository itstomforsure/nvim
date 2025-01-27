local function basic_config()
	local settings = {
		background = dark,
		encoding = "utf-8",
		termguicolors = true,
		hlsearch = false,
		wrap = true,
		linebreak = true,
		breakindent = true,
		showbreak = "↪ ",
		incsearch = true,
		inccommand = "split",
		smartcase = true,
		expandtab = true,
		smartindent = true,
		scrolloff = 5,
		shiftwidth = 2,
		tabstop = 2,
		number = true,
		ruler = true,
		cursorline = true,
		relativenumber = false,
		mouse = "a",
		splitbelow = true,
		splitright = true,
	}

	for key, value in pairs(settings) do
		vim.opt[key] = value
	end

	vim.g.mapleader = " "
	vim.g.netrw_banner = 0
	vim.g.netrw_winsize = 25
	vim.g.netrw_liststyle = 3
	vim.g.inlay_hints = true
	vim.g.inlay_hints_visible = true
	vim.lsp.inlay_hint.enable()
	vim.diagnostic.config({
		update_in_insert = true,
	})

	vim.cmd("set nocompatible")
end

local function remap(mode, input, result, opts)
	vim.keymap.set(mode, input, result, opts or {})
end

local function smart_buffer_close()
	local bufs = vim.fn.getbufinfo({ buflisted = true })
	local current_buf = vim.fn.bufnr("%")
	local previous_buf = nil
	for i, buf in ipairs(bufs) do
		if buf.bufnr == current_buf and i > 1 then
			previous_buf = bufs[i - 1].bufnr
			break
		end
	end

	vim.cmd("bd")

	if #bufs <= 1 then
		vim.cmd("NvimTreeFocus")
	elseif previous_buf then
		vim.cmd("buffer " .. previous_buf)
	end
end

local function custom_keybindings()
	-- Tabs
	remap("n", "<Tab>", ":bnext<CR>", { desc = "Next buffer" })
	remap("n", "<S-Tab>", ":bprevious<CR>", { desc = "Previous buffer" })
	remap("n", "<leader>x", smart_buffer_close, { desc = "Smart buffer close" })

	-- Visual mode indentation
	remap("v", "<Tab>", ">gv", { desc = "Indent selected lines right" })
	remap("v", "<S-Tab>", "<gv", { desc = "Indent selected lines right" })

	-- Splits
	remap({ "n", "t" }, "<leader>s", ":new<CR>")
	remap({ "n", "t" }, "<leader>v", ":vnew<CR>")
	remap("n", "<leader>t", ":split | resize 15 | terminal<CR>", { desc = "Open terminal in split" })

	-- Split navigation
	remap({ "n", "t" }, "<leader>h", "<C-w>h")
	remap({ "n", "t" }, "<leader>j", "<C-w>j")
	remap({ "n", "t" }, "<leader>k", "<C-w>k")
	remap({ "n", "t" }, "<leader>l", "<C-w>l")

	-- Navigation
	remap({ "n", "t" }, "<leader>e", function()
		local api = require("nvim-tree.api")

		if vim.bo.filetype == "NvimTree" then
			return
		end

		if api.tree.is_visible() then
			api.tree.focus()
		else
			api.tree.open()
			api.tree.focus()
		end
	end, { desc = "Focus nvim-tree" })

	-- Additional Mappings
	remap({ "n", "t" }, ";", ":", { desc = "Enter command mode" })
	remap("n", "<C-s>", ":wa<CR>", { desc = "Save all buffers in normal mode" })
	remap("i", "<C-s>", "<Esc>:wa<CR>i", { desc = "Save all buffers in insert mode" })
	remap("v", "<C-s>", "<Esc>:wa<CR>v", { desc = "Save all buffers in visual mode" })
	remap("v", "<C-c>", '"+y', { desc = "Copy selection to system clipboard" })
	remap("n", "<C-a>", "ggVG", { desc = "Select all" })
	remap("n", "<C-d>", "yyp", { desc = "Duplicate line" })
	remap("v", "<C-d>", "y'>p", { desc = "Duplicate selected lines" })
	remap({ "n", "t", "v" }, "<C-v>", '"+p', { desc = "Paste from system clipboard" })
	remap({ "n", "t", "v" }, "<S-C-v>", "p", { desc = "Paste from default register" })

	-- Keymap for Telescope fuzzy finders
	local remap = vim.api.nvim_set_keymap

	remap("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { noremap = true, silent = true, desc = "Find files" })
	remap(
		"n",
		"<leader>fg",
		"<cmd>Telescope live_grep<cr>",
		{ noremap = true, silent = true, desc = "Live grep (search in files)" }
	)
	remap("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { noremap = true, silent = true, desc = "Switch buffers" })
	remap("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { noremap = true, silent = true, desc = "Find help tags" })
	remap(
		"n",
		"<leader>fl",
		"<cmd>Telescope lsp_references<cr>",
		{ noremap = true, silent = true, desc = "Find lsp references" }
	)
	remap(
		"n",
		"<leader>fk",
		"<cmd>Telescope git_branches<cr>",
		{ noremap = true, silent = true, desc = "Find git branches" }
	)
end

local function setup_plugins()
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
		-- Completion ecosystem
		{
			"hrsh7th/nvim-cmp",
			-- event = "InsertEnter",
			dependencies = {
				"hrsh7th/cmp-nvim-lsp",
				"hrsh7th/cmp-buffer",
				"hrsh7th/cmp-path",
				"hrsh7th/cmp-cmdline",
				"hrsh7th/cmp-nvim-lsp-signature-help",
				"hrsh7th/cmp-nvim-lsp-document-symbol",
			},
			config = function()
				local cmp = require("cmp")
				local window_config = {
					documentation = {
						max_height = 15,
						max_width = 60,
						border = "rounded",
						col_offset = 1,
						side_padding = 1,
						winhighlight = "Normal:Normal,FloatBorder:Normal",
						zindex = 1001,
					},
				}

				cmp.setup({
					window = window_config,
					-- This code makes the cmp_lsp crash
					-- formatting = {
					-- 	format = function(entry, vim_item)
					-- 		local docs = entry.completion_item.documentation
					-- 		if docs then
					-- 			vim_item.menu = docs
					-- 		end
					-- 		return vim_item
					-- 	end,
					-- },
					completion = {
						completeopt = "menu,menuone,noinsert,noselect",
						keyword_length = 1,
					},
					mapping = cmp.mapping.preset.insert({
						["<C-b>"] = cmp.mapping.scroll_docs(-4),
						["<C-f>"] = cmp.mapping.scroll_docs(4),
						["<C-Space>"] = cmp.mapping.complete(),
						["<C-e>"] = cmp.mapping.abort(),
						["<CR>"] = cmp.mapping.confirm({ select = true }),
					}),
					sources = cmp.config.sources({
						{ name = "nvim_lsp" },
						{ name = "buffer" },
						{ name = "path" },
					}),
				})
			end,
		},

		-- Telescope and its extensions
		{
			"nvim-telescope/telescope.nvim",
			dependencies = {
				"nvim-lua/plenary.nvim",
				{
					"nvim-telescope/telescope-fzf-native.nvim",
					build = "make",
				},
			},
			config = function()
				local telescope = require("telescope")
				telescope.setup({
					defaults = {
						prompt_prefix = " ",
						selection_caret = "❯ ",
						mappings = {
							i = {
								["<C-u>"] = false,
								["<C-d>"] = false,
							},
						},
					},
				})

				pcall(telescope.load_extension, "fzf")
			end,
		},

		-- LSP Configuration
		{
			"neovim/nvim-lspconfig",
			dependencies = {
				"hrsh7th/cmp-nvim-lsp",
				"ray-x/go.nvim",
			},
			config = function()
				vim.defer_fn(function()
					local function on_attach(client, bufnr)
						local function buf_set_keymap(mode, lhs, rhs, desc)
							vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
						end

						buf_set_keymap("n", "gd", vim.lsp.buf.definition, "Go to definition")
						buf_set_keymap("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
						buf_set_keymap("n", "gr", vim.lsp.buf.references, "Go to references")
						buf_set_keymap("n", "K", vim.lsp.buf.hover, "Show hover documentation")
						buf_set_keymap("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
						buf_set_keymap("n", "<leader>ca", vim.lsp.buf.code_action, "Code actions")

						vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

						-- Debug
						-- print(string.format("LSP %s initialized for buffer %s", client.name, bufnr))
					end

					local capabilities = vim.lsp.protocol.make_client_capabilities()
					local has_cmp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
					if has_cmp then
						capabilities = cmp_lsp.default_capabilities(capabilities)
					end

					local lspconfig = require("lspconfig")

					lspconfig.ts_ls.setup({
						capabilities = capabilities,
						on_attach = function(client, bufnr)
							if vim.lsp.get_active_clients({ name = "angularls" })[1] then
								client.server_capabilities.documentFormattingProvider = false
							end
							on_attach(client, bufnr)
						end,
						settings = {
							typescript = {
								inlayHints = {
									includeInlayParameterNameHints = "all",
									includeInlayParameterNameHintsWhenArgumentMatchesName = true,
									includeInlayVariableTypeHints = true,
									includeInlayFunctionParameterTypeHints = true,
									includeInlayVariableTypeHintsWhenTypeMatchesName = true,
									includeInlayPropertyDeclarationTypeHints = true,
									includeInlayFunctionLikeReturnTypeHints = true,
									includeInlayEnumMemberValueHints = true,
								},
								implementationsCodeLens = true,
								referencesCodeLens = true,
								displayPartsForJSDocs = true,
							},
						},
						handlers = {
							["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
								border = "rounded",
								max_width = 80,
								max_height = 20,
							}),
							["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
								border = "rounded",
								max_width = 80,
								max_height = 20,
							}),
						},
					})

					lspconfig.angularls.setup({
						capabilities = capabilities,
						on_attach = on_attach,
						root_dir = require("lspconfig").util.root_pattern("angular.json", "project.json"),
						on_new_config = function(new_config, new_root_dir)
							local global_ts = vim.fn.expand("~/.nvm/versions/node/v22.11.0/lib/node_modules/typescript")
							local global_ng =
								vim.fn.expand("~/.nvm/versions/node/v22.11.0/lib/node_modules/@angular/language-server")

							new_config.cmd = {
								"ngserver",
								"--stdio",
								"--tsProbeLocations",
								global_ts,
								"--ngProbeLocations",
								global_ng,
							}
						end,
						settings = {
							angular = {
								inlayHints = {
									includeInlayParameterNameHints = "all",
									includeInlayParameterNameHintsWhenArgumentMatchesName = true,
									includeInlayVariableTypeHints = true,
									includeInlayFunctionParameterTypeHints = true,
									includeInlayVariableTypeHintsWhenTypeMatchesName = true,
									includeInlayPropertyDeclarationTypeHints = true,
									includeInlayFunctionLikeReturnTypeHints = true,
									includeInlayEnumMemberValueHints = true,
								},
								implementationsCodeLens = true,
								referencesCodeLens = true,
								displayPartsForJSDocs = true,
							},
						},
						handlers = {
							["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
								border = "rounded",
								max_width = 80,
								max_height = 20,
							}),
							["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
								border = "rounded",
								max_width = 80,
								max_height = 20,
							}),
						},
					})

					lspconfig.gopls.setup({
						cmd = { vim.fn.expand("$GOPATH") .. "/bin/gopls" },
						capabilities = capabilities,
						on_attach = on_attach,
						on_init = function(client)
							-- Debug
							print("Go LSP initialized")
							print("Go LSP executable path: " .. vim.fn.exepath("gopls"))
							print("GOPATH: " .. (vim.fn.expand("$GOPATH") or "No path"))
						end,
						settings = {
							gopls = {
								analyses = {
									unusedparams = true,
									shadow = true,
								},
								hints = {
									assignVariableTypes = true,
									compositeLiteralFields = true,
									compositeLiteralTypes = true,
									constantValues = true,
									functionTypeParameters = true,
									parameterNames = true,
									rangeVariableTypes = true,
								},
								codelenses = {
									gc_details = false,
									generate = true,
									regenerate_cgo = true,
									run_govulncheck = true,
									test = true,
									tidy = true,
									upgrade_dependency = true,
									vendor = true,
								},
								usePlaceholders = true,
								completeUnimported = true,
								staticcheck = true,
								directoryFilters = { "-.git", "-.vscode", "-.idea", "-.vscode-test", "-node_modules" },
								semanticTokens = true,
								staticcheck = true,
								gofumpt = true,
							},
						},
						handlers = {
							["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
								border = "rounded",
								max_width = 80,
								max_height = 20,
							}),
							["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
								border = "rounded",
								max_width = 80,
								max_height = 20,
							}),
						},
					})
				end, 100)
			end,
		},

		-- General
		{
			"catppuccin/nvim",
			name = "catppuccin",
			priority = 1000,
			config = function()
				require("catppuccin").setup({
					flavour = "mocha",
				})
				vim.cmd.colorscheme("catppuccin")
			end,
		},
		{
			"stevearc/conform.nvim",
			event = "BufWritePre",
			cmd = { "ConformInfo" },
			keys = {
				{
					"<leader>fm",
					function()
						require("conform").format({ async = true, lsp_fallback = true })
					end,
					mode = "",
					desc = "Format buffer",
				},
			},
			opts = {
				formatters_by_ft = {
					lua = { "stylua" },
					css = { "prettier" },
					html = { "prettier" },
					typecript = { "prettier" },
					javascript = { "prettier" },
					json = { "prettier" },
					yaml = { "prettier" },
					markdown = { "prettier" },
					go = { "gofmt", "goimports" },
				},

				format_on_save = {
					lsp_fallback = true,
				},
			},
			init = function()
				vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
			end,
		},
		{
			"nvim-treesitter/nvim-treesitter",
			run = ":TSUpdate",
			config = function()
				require("nvim-treesitter.configs").setup({
					highlight = { enable = true },
					indent = { enable = true },
					ensure_installed = {
						"vim",
						"vimdoc",
						"lua",
						"go",
						"typescript",
						"html",
						"css",
						"javascript",
						"angular",
					},
				})
			end,
		},
		{
			"lukas-reineke/indent-blankline.nvim",
			main = "ibl",
			---@module "ibl"
			---@type ibl.config
			opts = {},
		},
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
					width = 50,
					side = "left",
					adaptive_size = false,
					number = true,
				},
			},
		},
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
						theme = "auto",
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
								symbols = { error = " ", warn = " ", info = " ", hint = " " },
							},
							{
								function()
									local buf_clients = vim.lsp.get_active_clients({ bufnr = 0 })
									if #buf_clients == 0 then
										return "No LSP"
									end

									local client_names = {}
									for _, client in pairs(buf_clients) do
										table.insert(client_names, client.name)
									end
									return table.concat(client_names, ", ")
								end,
								icon = "",
							},
							"filetype",
						},
						lualine_y = { "filetype" },
						lualine_z = { line_info },
					},
					extensions = { "fugitive", "nvim-tree" },
				})
			end,
		},
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
				{ "<leader>gg", ":LazyGit<CR>", desc = "Open LazyGit" },
			},
		},
		{
			"gorbit99/codewindow.nvim",
			config = function()
				local codewindow = require("codewindow")
				codewindow.setup({
					active_in_terminals = false,
					auto_enable = true,
					width = 15,
					use_lsp = true,
					use_git = true,
					use_treesitter = true,
					show_cursor = true,
					window_border = "none",
					minimap_window = {
						width = 15,
						height_percentage = 100,
						style = "minimal",
					},
					exclude_filetypes = {
						"NvimTree",
						"TelescopePrompt",
					},
				})

				vim.keymap.set("n", "<leader>mm", function()
					codewindow.toggle_minimap()
				end, { desc = "Toggle minimap" })
				vim.keymap.set("n", "<leader>mf", function()
					codewindow.toggle_focus()
				end, { desc = "Toggle focus minimap" })
			end,
		},
		{
			"github/copilot.vim",
			config = function()
				vim.g.copilot_filetypes = {
					["*"] = true,
					["markdown"] = true,
					["help"] = false,
				}

				vim.g.copilot_no_tab_map = false
				-- Use Alt-] to accept suggestion
				-- vim.keymap.set('i', '<M-]>', 'copilot#Accept("\\<CR>")', {
				--   expr = true,
				--   replace_keycodes = false
				-- })
				-- Use Alt-[ to cycle to next suggestion
				vim.keymap.set("i", "<M-[>", "<Plug>(copilot-next)")
			end,
		},
		{
			"CopilotC-Nvim/CopilotChat.nvim",
			branch = "main",
			dependencies = {
				{ "nvim-lua/plenary.nvim", branch = "master" },
				"github/copilot.vim",
			},
			config = function()
				require("CopilotChat").setup({
					debug = false,

					-- Configuration for floating chat window
					window = {
						layout = "float",
						border = "single",
						size = {
							width = "80%",
							height = "60%",
						},
						win_options = {
							wrap = true,
							linebreak = true,
							foldcolumn = "0",
							winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
						},
					},

					-- Configuration for split chat window -- NOTE: This breaks the plugin, for some reason it cannot open a new buffer due to invalid name
					-- window = {
					--   layout = 'vsplit',
					--   relative = 'editor',
					--   width = 50,
					--   position = 'right',
					--   border = 'none',
					--   title = "Copilot Chat",
					--   name = "copilot-chat",
					--   win_options = {
					--     wrap = true,
					--     linebreak = true,
					--     foldcolumn = '0',
					--     winhighlight = 'Normal:Normal',
					--     buftype = 'nofile',
					--     filetype = 'copilot-chat',
					--     title = "Copilot Chat",
					--   }
					-- },
					-- buf_options = {
					--   buflisted = false,
					--   buftype = 'nofile',
					--   swapfile = false,
					--   filetype = 'copilot-chat'
					-- },
				})

				local function set_keymaps()
					vim.keymap.set("n", "<leader>cc", "<cmd>CopilotChat<cr>", { desc = "Open Copilot Chat" })
					vim.keymap.set({ "n", "v" }, "<leader>ce", "<cmd>CopilotChatExplain<cr>", { desc = "Explain code" })
					vim.keymap.set({ "n", "v" }, "<leader>cf", "<cmd>CopilotChatFix<cr>", { desc = "Fix code" })
					vim.keymap.set(
						{ "n", "v" },
						"<leader>co",
						"<cmd>CopilotChatOptimize<cr>",
						{ desc = "Optimize code" }
					)
				end

				set_keymaps()
			end,
		},
	})
end

local function init()
	basic_config()
	custom_keybindings()
	setup_plugins()
end

init()
