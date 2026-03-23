local vim = vim

vim.notify = require("notify").notify
require("bufferline").setup()
require("error_window").setup("<leader>b")
require("cmdline").setup(";")
require("search").setup("/")
require("terminal").setup({
	keybind = "<leader>t",
	new_keybind = "<leader>T",
	prev_keybind =
	"[t",
	next_keybind = "]t"
})
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
			lagygit = { enabled = true },
			picker = { enabled = true },
			statuscolumn = { enabled = true },
			input = { enabled = true },
			quickfile = { enabled = true },
			scope = { enabled = true },
			scroll = { enabled = true },
			words = { enabled = true },
		},
		keys = {
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
			{ "<leader>ff",      function() Snacks.picker.files() end,              desc = "Find Files" },
			{ "<leader><space>", function() Snacks.picker.grep() end,               desc = "Grep" },
			{ "<leader>fr",      function() Snacks.picker.lsp_references() end,     nowait = true,                     desc = "LSP References" },
			{ "<leader>fd",      function() Snacks.picker.git_diff() end,           desc = "Git Diff (Hunks)" },
			{ "<leader>fw",      function() Snacks.picker.grep_word() end,          desc = "Visual selection or word", mode = { "n", "x" } },

			-- Git
			{ "<leader>gg",      function() Snacks.lazygit() end,                   desc = "Lazygit" },
			{ "<leader>gb",      function() Snacks.picker.git_branches() end,       desc = "Git Branches" },
			{ "<leader>gl",      function() Snacks.picker.git_log() end,            desc = "Git Log" },
			{ "<leader>gL",      function() Snacks.picker.git_log_line() end,       desc = "Git Log Line" },
			{ "<leader>gs",      function() Snacks.picker.git_status() end,         desc = "Git Status" },
			{ "<leader>gS",      function() Snacks.picker.git_stash() end,          desc = "Git Stash" },
			{ "<leader>gd",      function() Snacks.picker.git_diff() end,           desc = "Git Diff (Hunks)" },
			{ "<leader>gf",      function() Snacks.picker.git_log_file() end,       desc = "Git Log File" },

			-- search
			{ '<leader>hr',      function() Snacks.picker.registers() end,          desc = "Registers" },
			{ '<leader>hs',      function() Snacks.picker.search_history() end,     desc = "Search History" },
			{ "<leader>hu",      function() Snacks.picker.undo() end,               desc = "Undo History" },
			{ "<leader>sa",      function() Snacks.picker.autocmds() end,           desc = "Autocmds" },
			{ "<leader>sC",      function() Snacks.picker.commands() end,           desc = "Commands" },
			{ "<leader>sd",      function() Snacks.picker.diagnostics() end,        desc = "Diagnostics" },
			{ "<leader>sD",      function() Snacks.picker.diagnostics_buffer() end, desc = "Buffer Diagnostics" },
			{ "<leader>sh",      function() Snacks.picker.highlights() end,         desc = "Highlights" },

			-- Nice to haves
			{ "<leader>sk",      function() Snacks.picker.keymaps() end,            desc = "Keymaps" },
			{ "<leader>gB",      function() Snacks.gitbrowse() end,                 desc = "Git Browse",               mode = { "n", "v" } },
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
					Snacks.toggle.indent():map("<leader>ug")
					Snacks.toggle.dim():map("<leader>uD")
					Snacks.toggle.treesitter():map("<leader>uT")
				end,
			})
		end,
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
