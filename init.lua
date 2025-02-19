local vim = vim
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
	vim.lsp.inlay_hint.enable()
	vim.diagnostic.config({
		update_in_insert = true,
		virtual_text = true,
	})

	vim.o.signcolumn = "yes"
	vim.cmd("set nocompatible")
end

local function remap(mode, input, result, opts)
	vim.keymap.set(mode, input, result, opts or {})
end

local function custom_keybindings()
	-- Tabs
	remap("n", "<Tab>", ":bnext<CR>", { desc = "Next buffer" })
	remap("n", "<S-Tab>", ":bprevious<CR>", { desc = "Previous buffer" })

	-- Visual mode indentation
	remap("v", "<Tab>", ">gv", { desc = "Indent selected lines right" })
	remap("v", "<S-Tab>", "<gv", { desc = "Indent selected lines right" })

	-- Splits
	remap({ "n", "t" }, "<leader>s", ":new<CR>")
	remap({ "n", "t" }, "<leader>v", ":vnew<CR>")

	-- Split navigation
	remap({ "n", "t" }, "<leader>h", "<C-w>h")
	remap({ "n", "t" }, "<leader>j", "<C-w>j")
	remap({ "n", "t" }, "<leader>k", "<C-w>k")
	remap({ "n", "t" }, "<leader>l", "<C-w>l")

	-- Navigation
	remap({ "n", "t" }, "<leader>e", function()
		local api = require("nvim-tree.api")
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

	-- Minimap
	remap({ "n", "t" }, "<leader>mm", ":MinimapToggle<CR>", { desc = "Toggle minimap window" })
	remap({ "n", "t" }, "<leader>mr", ":MinimapRefresh<CR>", { desc = "Force refresh minimap window" })
	remap({ "n", "t" }, "<leader>mu", ":MinimapUpdateHighlight<CR>", { desc = "Force update minimap highlight" })
	remap({ "n", "t" }, "<leader>me", ":MinimapRescan<CR>", { desc = "Force recalculation of minimap scaling ratio" })

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
						max_width = 40,
						border = "rounded",
						col_offset = 1,
						side_padding = 1,
						winhighlight = "Normal:Normal,FloatBorder:Normal",
						zindex = 1001,
					},
				}

				cmp.setup({
					window = window_config,
					completion = {
						completeopt = "menu,menuone,noinsert,noselect",
						keyword_length = 1,
					},
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

		-- -- LSP Configuration with Mason
		-- Mason
		{
			"williamboman/mason.nvim",
			config = function()
				require("mason").setup()
			end,
		},

		-- Mason lsp config
		{
			"williamboman/mason-lspconfig.nvim",
			config = function()
				require("mason-lspconfig").setup({
					ensure_installed = {
						"ts_ls",
						"angularls",
						"cssls",
						"html",
						"gopls",
						"lua_ls",
					},
				})
			end,
		},

		-- LspConfig
		{
			"neovim/nvim-lspconfig",
			dependencies = {
				"hrsh7th/cmp-nvim-lsp",
			},
			config = function()
				local lspconfig = require("lspconfig")
				local capabilities = require("cmp_nvim_lsp").default_capabilities()
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

				-- TypeScript configuration
				lspconfig.ts_ls.setup({
					capabilities = capabilities,
					on_attach = on_attach,
					settings = {
						typescript = {
							inlayHints = {
								includeInlayParameterNameHints = "all",
								includeInlayParameterNameHintsWhenArgumentMatchesName = false,
								includeInlayFunctionParameterTypeHints = true,
								includeInlayVariableTypeHints = true,
								includeInlayPropertyDeclarationTypeHints = true,
								includeInlayFunctionLikeReturnTypeHints = true,
								includeInlayEnumMemberValueHints = true,
							},
							updateImportsOnFileMove = {
								enabled = "always",
							},
						},
						javascript = {
							inlayHints = {
								includeInlayParameterNameHints = "all",
								includeInlayParameterNameHintsWhenArgumentMatchesName = false,
								includeInlayFunctionParameterTypeHints = true,
								includeInlayVariableTypeHints = true,
								includeInlayPropertyDeclarationTypeHints = true,
								includeInlayFunctionLikeReturnTypeHints = true,
								includeInlayEnumMemberValueHints = true,
							},
						},
					},
				})

				-- Angular configuration
				lspconfig.angularls.setup({
					capabilities = capabilities,
					on_attach = on_attach,
					root_dir = require("lspconfig").util.root_pattern("angular.json", "project.json"),
					on_new_config = function(new_config, new_root_dir)
						local global_ts = vim.fn.expand("~/.npm/lib/node_modules/typescript")
						local global_ng = vim.fn.expand("~/.npm/lib/node_modules/@angular/language-server")

						new_config.cmd = {
							"ngserver",
							"--stdio",
							"--tsProbeLocations",
							global_ts,
							"--ngProbeLocations",
							global_ng,
						}
					end,
				})

				-- Go configuration
				lspconfig.gopls.setup({
					capabilities = capabilities,
					on_attach = on_attach,
					settings = {
						gopls = {
							hints = {
								assignVariableTypes = true,
								compositeLiteralFields = true,
								compositeLiteralTypes = true,
								constantValues = true,
								functionTypeParameters = true,
								parameterNames = true,
								rangeVariableTypes = true,
							},
							analyses = {
								unusedparams = true,
								shadow = true,
							},
							codelenses = {
								generate = true,
								gc_details = true,
								test = true,
								tidy = true,
							},
							usePlaceholders = true,
							completionDocumentation = true,
							importShortcut = "Definition",
							experimentalPostfixCompletions = true,
						},
					},
				})

				-- Lua configuration
				lspconfig.lua_ls.setup({
					capabilities = capabilities,
					settings = {
						Lua = {
							completion = {
								callSnippet = "Replace",
								enable = true,
								keywordSnippet = "Replace",
								showWord = "Enable",
								workspaceWord = true,
							},
							diagnostics = {
								enable = true,
								globals = {
									"vim",
									"describe",
									"it",
									"before_each",
									"after_each",
								},
								disable = {
									"trailing-space",
								},
							},
							hover = {
								enable = true,
								viewNumber = true,
								viewString = true,
								viewStringMax = 1000,
							},
							workspace = {
								library = vim.api.nvim_get_runtime_file("", true),
								maxPreload = 2000,
								preloadFileSize = 50000,
								checkThirdParty = false,
							},
							runtime = {
								version = "LuaJIT",
								path = runtime_path,
								special = {
									include = "require",
								},
							},
							hint = {
								enable = true,
								arrayIndex = "Disable",
								setType = true,
								paramName = "All",
								paramType = true,
								semicolon = "SameLine",
							},
							telemetry = {
								enable = false,
							},
						},
					},
				})
			end,
		},

		-- Formatter
		{
			"stevearc/conform.nvim",
			config = function()
				require("conform").setup({
					formatters_by_ft = {
						typescript = { "eslint_d", "prettier" },
						javascript = { "eslint_d", "prettier" },
						typescriptreact = { "eslint_d", "prettier" },
						javascriptreact = { "eslint_d", "prettier" },
						html = { "prettier" },
						css = { "prettier" },
						scss = { "prettier" },
						json = { "prettier" },
						yaml = { "prettier" },
						markdown = { "prettier" },
						go = { "gofumpt", "goimports" },
						lua = { "stylua" },
					},
					format_on_save = {
						timeout_ms = 500,
						lsp_fallback = true,
					},
				})
			end,
		},

		-- Linter
		{
			"mfussenegger/nvim-lint",
			config = function()
				require("lint").linters_by_ft = {
					typescript = { "eslint" },
					javascript = { "eslint_d" },
					typescriptreact = { "eslint_d" },
					javascriptreact = { "eslint_d" },
					go = { "golangcilint" },
					lua = { "luacheck" },
				}

				local lint_augroup = vim.api.nvim_create_augroup("Linting", { clear = true })

				local function safe_lint()
					local lint_ok, lint_err = pcall(function()
						require("lint").try_lint()
					end)

					if not lint_ok then
						vim.notify("Linting failed: " .. tostring(lint_err), vim.log.levels.WARN)
					end
				end

				vim.api.nvim_create_autocmd({
					"BufWritePost",
					"BufEnter",
					"InsertLeave",
					"TextChanged",
					"CursorHold",
				}, {
					group = lint_augroup,
					callback = function()
						if vim.bo.modifiable and vim.bo.buftype == "" then
							safe_lint()
						end
					end,
				})

				vim.opt.updatetime = 1000
			end,
		},

		-- -- UI
		-- Theme
		{
			"catppuccin/nvim",
			name = "catppuccin",
			priority = 1000,
			config = function()
				require("catppuccin").setup({
					flavour = "mocha",
					transparent_background = true,
				})
				vim.cmd.colorscheme("catppuccin")
			end,
		},

		-- File explorer
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
					width = 35,
					side = "left",
					adaptive_size = false,
					number = false,
				},
			},
		},

		-- Code colorization
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

		-- Indentation lines
		{
			"lukas-reineke/indent-blankline.nvim",
			main = "ibl",
			---@module "ibl"
			---@type ibl.config
			opts = {},
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

		-- Minimap
		{
			"wfxr/minimap.vim",
			build = "cargo install --locked code-minimap",
			config = function()
				vim.g.minimap_width = 10
				vim.g.minimap_highlight_search = 1
				vim.g.minimap_git_colors = 1
				vim.g.minimap_range_color = "Search"
				-- :highlight minimapRange ctermbg=242 ctermfg=228 guibg=#004c68 guifg=#00d0ff
			end,
		},

		-- -- Applications
		-- Git
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

		-- Copilot
		{
			"github/copilot.vim",
			lazy = true,
			cmd = "Copilot",
			keys = {
				-- { "<leader>cp", ":Copilot enable<CR>", desc = "Enable Copilot" },
				{
					"<leader>cp",
					function()
						local copilot_status = vim.fn["copilot#Enabled"]()
						if copilot_status == 1 then
							vim.cmd("Copilot disable")
							vim.cmd("edit")
							print("Copilot Disabled")
						else
							vim.cmd("Copilot enable")
							vim.cmd("edit")
							print("Copilot Enabled")
						end
					end,
					desc = "Toggle Copilot",
				},
			},
			config = function()
				vim.g.copilot_filetypes = {
					["*"] = true,
					["markdown"] = true,
					["help"] = false,
				}

				vim.g.copilot_no_tab_map = false
				vim.keymap.set("i", "<M-[>", "<Plug>(copilot-next)")
			end,
		},

		-- Copilot chat
		{
			"CopilotC-Nvim/CopilotChat.nvim",
			branch = "main",
			dependencies = {
				{ "nvim-lua/plenary.nvim", branch = "master" },
				"github/copilot.vim",
			},
			lazy = true,
			keys = {
				{ "<leader>cp", ":CopilotChat<CR>", desc = "Enable Copilot chat" },
			},
			config = function()
				require("CopilotChat").setup({
					debug = false,

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

		-- -- Utils
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
	})
end

local function init()
	basic_config()
	custom_keybindings()
	setup_plugins()
end

init()
