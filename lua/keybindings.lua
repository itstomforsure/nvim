local vim = vim

-- General keybindings
vim.keymap.set("n", "<C-q>", function()
	pcall(function() require("session").save() end)
	vim.cmd("qa!")
end)

-- Save on Ctrl+s in normal and insert and visual modes
vim.keymap.set("n", "<C-s>", ":wa<CR>")
vim.keymap.set("i", "<C-s>", "<Esc>:wa<CR>a")
vim.keymap.set("v", "<C-s>", "<Esc>:wa<CR>v")

-- Copy and paste to system clipboard
vim.keymap.set("v", "<C-c>", '"+y')
vim.keymap.set({ "n", "t", "v" }, "<C-v>", '"+p')

local M = {
	comment = {
		binds = {
			toggle = { key = "<leader>/", mode = { "n", "v" }, desc = "Toggle comment" },
		},
	},
	terminal = {
		binds = {
			focus = {},
			toggle = {}
		}
	},
	lsp = {
		inlay_hint = {
			key = "<leader>uh",
			mode = { "n" }
		},
		binds = {
			-- definition = {
			-- 	key = "gd",
			-- 	cmd = vim.lsp.buf.definition,
			-- 	mode = { "n" }
			-- },
			-- declaration = {
			-- 	key = "gD",
			-- 	cmd = vim.lsp.buf.declaration,
			-- 	mode = { "n" }
			-- },
			-- implementation = {
			-- 	key = "gi",
			-- 	cmd = vim.lsp.buf.implementation,
			-- 	mode = { "n" }
			-- },
			-- references = {
			-- 	key = "gr",
			-- 	cmd = vim.lsp.buf.references,
			-- 	mode = { "n" }
			-- },
			hover = {
				key = "K",
				cmd = function()
					vim.lsp.buf.hover({
						border = "rounded",
						max_width = 80,
						max_height = 20,
					})
				end,
				mode = { "n" }
			},
			signature_help = {
				key = "<C-k>",
				cmd = function()
					vim.lsp.buf.signature_help({
						border = "rounded",
						max_width = 80,
						max_height = 20,
					})
				end,
				mode = { "n" }
			},
			code_action = {
				key = "<C-.>",
				cmd = vim.lsp.buf.code_action,
				mode = { "n" }
			},
			goto_prev = {
				key = "[d",
				cmd = vim.diagnostic.goto_prev,
				mode = { "n" }
			},
			goto_next = {
				key = "]d",
				cmd = vim.diagnostic.goto_next,
				mode = { "n" }
			},
		}
	},
	snacks = {
		binds = {
			-- Explorer
			explorerOpen = {
				key = "<leader>e",
				cmd = function()
					local sc = require("sourcecontrol")
					if sc.is_open() then sc.close() end
					local explorer = Snacks.picker.get({ source = "explorer" })
						[1]
					if explorer then
						explorer:focus()
					else
						Snacks.explorer.open()
					end
					vim.schedule(function() sc.apply_selector() end)
				end,
				mode = { "n", "v" },
				desc = "Open/focus File Explorer"
			},
			explorerToggle = {
				key = "<leader>E",
				cmd = function()
					local sc = require("sourcecontrol")
					if sc.is_open() then sc.close() end
					Snacks.explorer()
					vim.schedule(function() sc.apply_selector() end)
				end,
				mode = { "n", "v" },
				desc = "Toggle File Explorer"
			}, -- Notifications
			notifications = {
				key = "<leader>n",
				cmd = function()
					Snacks.picker
						.notifications()
				end,
				mode = { "n", "v" },
				desc = "Notification History"
			},

			-- Find
			find_files = {
				key = "<leader>ff",
				cmd = function()
					Snacks.picker
						.files()
				end,
				desc = "Find Files"
			},
			grep = {
				key = "<leader><space>",
				cmd = function()
					Snacks.picker
						.grep()
				end,
				desc = "Grep"
			},
			lsp_defs = {
				key = "gd",
				cmd = function() Snacks.picker.lsp_definitions() end,
				desc = "Goto Definition"
			},
			lsp_decs = {
				key = "gD",
				cmd = function() Snacks.picker.lsp_declarations() end,
				desc = "Goto Declaration"
			},
			lsp_refs = {
				key = "gr",
				cmd = function()
					Snacks.picker
						.lsp_references()
				end,
				nowait = true,
				desc = "LSP References"
			},
			lsp_impls = {
				key = "gi",
				cmd = function() Snacks.picker.lsp_implementations() end,
				desc = "Goto Implementation"
			},
			git_diff = {
				key = "<leader>fd",
				cmd = function()
					Snacks.picker
						.git_diff()
				end,
				desc = "Git Diff (Hunks)"
			},
			grep_word = {
				key = "<leader>fw",
				cmd = function()
					Snacks.picker
						.grep_word()
				end,
				desc = "Visual selection or word",
				mode = { "n", "x" }
			},

			-- Git
			lazygit = { key = "<leader>gg", cmd = function() Snacks.lazygit() end, desc = "Lazygit" },
			git_branches = {
				key = "<leader>gb",
				cmd = function()
					Snacks.picker
						.git_branches()
				end,
				desc = "Git Branches"
			},
			git_log = {
				key = "<leader>gl",
				cmd = function()
					Snacks.picker
						.git_log()
				end,
				desc = "Git Log"
			},
			git_log_line = {
				key = "<leader>gL",
				cmd = function()
					Snacks.picker
						.git_log_line()
				end,
				desc = "Git Log Line"
			},
			git_status = {
				key = "<leader>gs",
				cmd = function()
					Snacks.picker
						.git_status()
				end,
				desc = "Git Status"
			},
			git_stash = {
				key = "<leader>gS",
				cmd = function()
					Snacks.picker
						.git_stash()
				end,
				desc = "Git Stash"
			},
			git_log_file = {
				key = "<leader>gf",
				cmd = function()
					Snacks.picker
						.git_log_file()
				end,
				desc = "Git Log File"
			},

			-- Search
			registers = {
				key = "<leader>hr",
				cmd = function()
					Snacks.picker
						.registers()
				end,
				desc = "Registers"
			},
			search_history = {
				key = "<leader>hs",
				cmd = function()
					Snacks
						.picker.search_history()
				end,
				desc = "Search History"
			},
			undo = { key = "<leader>hu", cmd = function() Snacks.picker.undo() end, desc = "Undo History" },
			autocmds = {
				key = "<leader>sa",
				cmd = function()
					Snacks.picker
						.autocmds()
				end,
				desc = "Autocmds"
			},
			commands = {
				key = "<leader>sC",
				cmd = function()
					Snacks.picker
						.commands()
				end,
				desc = "Commands"
			},
			diagnostics = {
				key = "<leader>sd",
				cmd = function()
					Snacks.picker
						.diagnostics()
				end,
				desc = "Diagnostics"
			},
			diagnostics_buffer = {
				key = "<leader>sD",
				cmd = function()
					Snacks
						.picker.diagnostics_buffer()
				end,
				desc = "Buffer Diagnostics"
			},
			highlights = {
				key = "<leader>sh",
				cmd = function()
					Snacks.picker
						.highlights()
				end,
				desc = "Highlights"
			},

			-- Nice to haves
			keymaps = {
				key = "<leader>sk",
				cmd = function()
					Snacks.picker
						.keymaps()
				end,
				desc = "Keymaps"
			},
			gitbrowse = { key = "<leader>gB", cmd = function() Snacks.gitbrowse() end, desc = "Git Browse", mode = { "n", "v" } },
		},
		toggles = {
			{ option = "spell",          name = "Spelling",        key = "<leader>us" },
			{ option = "wrap",           name = "Wrap",            key = "<leader>uw" },
			{ option = "relativenumber", name = "Relative Number", key = "<leader>uL" },
			{ method = "diagnostics",    key = "<leader>ud" },
			{ method = "line_number",    key = "<leader>ul" },
			{ method = "indent",         key = "<leader>ug" },
			{ method = "dim",            key = "<leader>uD" },
			{ method = "treesitter",     key = "<leader>uT" },
		},
	},
	minimap = {
		binds = {
			toggle = { key = "<leader>m", cmd = function() MiniMap.toggle() end, desc = "Toggle minimap" },
		},
	},
	bufferline = {
		binds = {
			next = { key = "<Tab>", cmd = "<cmd>BufferLineCycleNext<cr>", desc = "Next buffer" },
			prev = { key = "<S-Tab>", cmd = "<cmd>BufferLineCyclePrev<cr>", desc = "Prev buffer" },
		},
	},
	claude = {
		binds = {
			toggle = { key = "<leader>v", cmd = "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
			focus = { key = "<leader>vf", cmd = "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
			resume = { key = "<leader>vr", cmd = "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
			continue_ = { key = "<leader>vc", cmd = "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
			model = { key = "<leader>vm", cmd = "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
			add_buffer = { key = "<leader>vb", cmd = "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
			send = { key = "<leader>vs", cmd = "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
			add_tree = { key = "<leader>vB", cmd = "<cmd>ClaudeCodeTreeAdd<cr>", desc = "Add file", ft = { "NvimTree", "neo-tree", "oil", "minifiles", "netrw" } },
			diff_accept = { key = "<leader>vv", cmd = "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
			diff_deny = { key = "<leader>vd", cmd = "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
		},
	},
	copilot = {
		binds = {
			accept = { key = "<C-l>", cmd = 'copilot#Accept("\\<CR>")', mode = "i", desc = "Accept Copilot suggestion", expr = true, replace_keycodes = false },
			accept_word = { key = "<M-l>", cmd = "<Plug>(copilot-accept-word)", mode = "i", desc = "Accept Copilot word" },
			dismiss = { key = "<C-]>", cmd = "<Plug>(copilot-dismiss)", mode = "i", desc = "Dismiss Copilot suggestion" },
			next = { key = "<M-n>", cmd = "<Plug>(copilot-next)", mode = "i", desc = "Next Copilot suggestion" },
			prev = { key = "<M-p>", cmd = "<Plug>(copilot-prev)", mode = "i", desc = "Prev Copilot suggestion" },
		},
	},
	copilot_chat = {
		binds = {
			toggle = { key = "<leader>cc", cmd = "<cmd>CopilotChatToggle<cr>", desc = "Toggle Copilot Chat" },
			models = { key = "<leader>cm", cmd = "<cmd>CopilotChatModels<cr>", desc = "Select Copilot Model" },
			explain = { key = "<leader>ce", cmd = "<cmd>CopilotChatExplain<cr>", mode = { "n", "v" }, desc = "Copilot Explain" },
			fix = { key = "<leader>cf", cmd = "<cmd>CopilotChatFix<cr>", mode = { "n", "v" }, desc = "Copilot Fix" },
			optimize = { key = "<leader>co", cmd = "<cmd>CopilotChatOptimize<cr>", mode = { "n", "v" }, desc = "Copilot Optimize" },
			review = { key = "<leader>cr", cmd = "<cmd>CopilotChatReview<cr>", mode = { "n", "v" }, desc = "Copilot Review" },
			tests = { key = "<leader>ct", cmd = "<cmd>CopilotChatTests<cr>", mode = { "n", "v" }, desc = "Copilot Tests" },
			quick = {
				key = "<leader>cq",
				cmd = function()
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
}

--- Apply a plugin's .binds table directly via vim.keymap.set.
function M.apply(plugin_name)
	local plugin = M[plugin_name]
	if not plugin or not plugin.binds then return end
	for _, bind in pairs(plugin.binds) do
		vim.keymap.set(bind.mode or "n", bind.key, bind.cmd, {
			desc = bind.desc,
			nowait = bind.nowait,
			expr = bind.expr,
			replace_keycodes = bind.replace_keycodes,
			silent = true,
		})
	end
end

-- Smart buffer close: navigate away cleanly, fall back to dashboard
local function is_regular_buf(bufnr)
	return bufnr and bufnr > 0
		and vim.api.nvim_buf_is_valid(bufnr)
		and vim.bo[bufnr].buftype == ""
end

local function pick_replacement(exclude_buf)
	local bufs = {}
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if b ~= exclude_buf and vim.bo[b].buflisted and is_regular_buf(b) then
			table.insert(bufs, b)
		end
	end
	if #bufs == 0 then return nil end
	table.sort(bufs)

	-- Prefer the nearest buffer to the left (lower ID), else go right
	local prev = nil
	for _, b in ipairs(bufs) do
		if b < exclude_buf then prev = b end
	end
	return prev or bufs[1]
end

local function smart_close_buf(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then return end

	if vim.bo[bufnr].buftype == "terminal" then
		vim.notify("Use terminal keymaps to close terminal buffers",
			vim.log.levels.INFO)
		return
	end

	if vim.bo[bufnr].modified then
		vim.notify("No write since last change", vim.log.levels.WARN)
		return
	end

	local replacement = pick_replacement(bufnr)
	for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
		if vim.api.nvim_win_is_valid(win) then
			if replacement then
				vim.api.nvim_win_set_buf(win, replacement)
			else
				vim.api.nvim_win_call(win, function() vim.cmd("enew") end)
			end
		end
	end

	pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
end



-- Expose for bufferline's close_command
_G.SmartCloseBuf = smart_close_buf

vim.keymap.set("n", "<leader>q", function()
	smart_close_buf()
end, { desc = "Close buffer and keep layout" })

-- Source control
vim.keymap.set("n", "<leader>g", function()
	local sc = require("sourcecontrol")
	if sc.is_open() then
		sc.focus()
	else
		sc.open()
	end
end, { desc = "Open/focus Source Control" })

vim.keymap.set("n", "<leader>G", function()
	require("sourcecontrol").toggle()
end, { desc = "Toggle Source Control" })

-- Show diagnostics
vim.keymap.set("n", "T", vim.diagnostic.open_float)

-- Format with Conform
vim.keymap.set("n", "<leader>f", function()
	require("conform").format({ async = true, lsp_fallback = true })
	vim.notify("Formatted with Conform", vim.log.levels.INFO)
end)

return M
