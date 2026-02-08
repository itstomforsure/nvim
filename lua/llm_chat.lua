local vim = vim
local utils = require("utils")
local M = {}
local buf = nil
local win = nil
local input_buf = nil
local input_win = nil
local chats = {}
local current_index = nil
local last_win = nil
local last_buf = nil
local models = {}
local models_loaded = false
local chat_state = {}
local provider = "ollama"
local bubble_ns = vim.api.nvim_create_namespace("llm_chat_bubbles")
local provider_notified = { ollama = false, copilot = false }
local keybinds = {
	open = "<leader>g",
	new = nil,
	prev = nil,
	next = nil,
	add_buffer = nil,
	add_buffers = nil,
	add_nvim_tree = nil,
	add_telescope = nil,
	model_selector = nil,
}
local panel_opts = {
	width = nil,
	width_ratio = 0.3,
	max_width = 80,
	input_height = 4,
}
local context_opts = {
	max_files = 12,
	max_lines_per_file = 400,
	max_total_lines = 2000,
	max_label_len = 28,
}
local ollama_opts = {
	host = "http://127.0.0.1:11434",
	container = nil,
	default_model = nil,
	system_prompt = nil,
}
local copilot_opts = {
	default_model = nil,
	system_prompt = nil,
	sticky = nil,
}

local close
local show_current
local chat_tab_click
local chat_tab_close
local chat_model_select
local chat_context_remove
local prune_chats
local set_input_winbar
local send_message

local function resolve_width()
	if panel_opts.width then
		return panel_opts.width
	end

	return math.min(panel_opts.max_width, math.floor(vim.o.columns * panel_opts.width_ratio))
end

local function normalize_host()
	if not ollama_opts.host then
		return "http://127.0.0.1:11434"
	end

	local host = ollama_opts.host
	if host:sub(-1) == "/" then
		host = host:sub(1, -2)
	end
	return host
end

local function normalize_provider(value)
	if value == "copilot" then
		return "copilot"
	end
	if value == "ollama" then
		return "ollama"
	end
	if value == "auto" then
		local ok = pcall(require, "CopilotChat")
		if ok then
			return "copilot"
		end
		return "ollama"
	end
	return "ollama"
end

local function run_command(cmd, input)
	local output = vim.fn.system(cmd, input)
	if vim.v.shell_error ~= 0 then
		return nil, output
	end
	return output, nil
end

local function run_command_async(cmd, input, callback)
	if vim.system then
		local opts = { text = true }
		if input then
			opts.stdin = input
		end
		vim.system(cmd, opts, function(result)
			local stdout = result.stdout or ""
			local stderr = result.stderr or ""
			if result.code ~= 0 then
				callback(nil, stderr ~= "" and stderr or stdout)
				return
			end
			callback(stdout, nil)
		end)
		return
	end

	local stdout = {}
	local stderr = {}
	local job_id = vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if not data then
				return
			end
			for _, line in ipairs(data) do
				if line ~= "" then
					table.insert(stdout, line)
				end
			end
		end,
		on_stderr = function(_, data)
			if not data then
				return
			end
			for _, line in ipairs(data) do
				if line ~= "" then
					table.insert(stderr, line)
				end
			end
		end,
		on_exit = function(_, code)
			local out = table.concat(stdout, "\n")
			local err = table.concat(stderr, "\n")
			if code ~= 0 then
				callback(nil, err ~= "" and err or out)
				return
			end
			callback(out, nil)
		end,
	})

	if input and job_id > 0 then
		vim.fn.chansend(job_id, input)
		vim.fn.chanclose(job_id, "stdin")
	end
end

local function build_curl_cmd(path, use_stdin)
	local host = normalize_host()
	local url = host .. path

	if ollama_opts.container then
		if use_stdin then
			return {
				"docker",
				"exec",
				"-i",
				ollama_opts.container,
				"curl",
				"-s",
				"-X",
				"POST",
				"-H",
				"Content-Type: application/json",
				"--data-binary",
				"@-",
				url,
			}
		end
		return {
			"docker",
			"exec",
			ollama_opts.container,
			"curl",
			"-s",
			url,
		}
	end

	if use_stdin then
		return {
			"curl",
			"-s",
			"-X",
			"POST",
			"-H",
			"Content-Type: application/json",
			"--data-binary",
			"@-",
			url,
		}
	end
	return { "curl", "-s", url }
end

local function parse_models_from_tags(raw)
	local ok, data = pcall(vim.fn.json_decode, raw)
	if not ok or type(data) ~= "table" then
		return nil
	end

	local list = {}
	for _, entry in ipairs(data.models or {}) do
		if entry.name then
			table.insert(list, entry.name)
		end
	end
	return list
end

local function parse_models_from_ollama_list(raw)
	local list = {}
	local lines = vim.split(raw or "", "\n", { trimempty = true })
	for i = 2, #lines do
		local name = vim.split(lines[i], "%s+")[1]
		if name and name ~= "" then
			table.insert(list, name)
		end
	end
	return list
end

local function fetch_models(silent)
	local cmd = build_curl_cmd("/api/tags", false)
	local output, err = run_command(cmd)
	if output then
		local list = parse_models_from_tags(output)
		if list and #list > 0 then
			return list
		end
	end

	if ollama_opts.container then
		local list_output = run_command({ "docker", "exec", ollama_opts.container, "ollama", "list" })
		local list = parse_models_from_ollama_list(list_output)
		if #list > 0 then
			return list
		end
	end

	if err and err ~= "" and not silent then
		vim.notify(err, vim.log.levels.WARN)
	end
	return {}
end

local function ensure_models(force, silent)
	if models_loaded and not force then
		return
	end

	models = fetch_models(silent)
	models_loaded = true
end

local function notify_once(kind, message)
	if provider_notified[kind] then
		return
	end
	provider_notified[kind] = true
	vim.notify(message, vim.log.levels.WARN)
end

local function check_copilot_available()
	local ok = pcall(require, "CopilotChat")
	if ok then
		return
	end
	notify_once("copilot", "CopilotChat.nvim not available. The chat will still open.")
end

local function check_ollama_models()
	ensure_models(true, true)
	if #models > 0 then
		return
	end
	notify_once("ollama", "No Ollama models found. The chat will still open.")
end

local function notify_provider_status()
	vim.defer_fn(function()
		check_copilot_available()
		check_ollama_models()
	end, 10)
end

local function is_chat_buf(target_buf)
	return utils.is_buf_valid(target_buf) and vim.b[target_buf].llm_chat == true
end

local function escape_statusline(text)
	return (text or ""):gsub("%%", "%%%%")
end

local function ensure_bubble_highlights()
	vim.api.nvim_set_hl(0, "LlmChatUserBubble", {
		fg = "#ffffff",
		bg = "#3b82f6",
	})
	vim.api.nvim_set_hl(0, "LlmChatAssistantBubble", {
		fg = "#e5e7eb",
		bg = "#1f2937",
	})
end

local function truncate_label(text)
	if not text then
		return ""
	end

	local max_len = context_opts.max_label_len
	if not max_len or max_len <= 0 then
		return text
	end

	if #text <= max_len then
		return text
	end

	if max_len <= 3 then
		return text:sub(1, max_len)
	end

	return text:sub(1, max_len - 3) .. "..."
end

local function get_chat_width()
	if utils.is_win_valid(win) then
		return vim.api.nvim_win_get_width(win)
	end
	return vim.o.columns
end

local function wrap_line(line, width)
	if width <= 0 then
		return { line }
	end

	if #line <= width then
		return { line }
	end

	local out = {}
	local current = ""
	for word in line:gmatch("%S+") do
		if #word > width then
			if current ~= "" then
				table.insert(out, current)
				current = ""
			end
			local start = 1
			while start <= #word do
				table.insert(out, word:sub(start, start + width - 1))
				start = start + width
			end
		elseif current == "" then
			current = word
		elseif #current + 1 + #word <= width then
			current = current .. " " .. word
		else
			table.insert(out, current)
			current = word
		end
	end

	if current ~= "" then
		table.insert(out, current)
	end

	if #out == 0 then
		table.insert(out, line:sub(1, width))
	end

	return out
end

local function wrap_text(text, width)
	local lines = {}
	for _, line in ipairs(vim.split(text or "", "\n", { plain = true })) do
		local wrapped = wrap_line(line, width)
		for _, chunk in ipairs(wrapped) do
			table.insert(lines, chunk)
		end
	end

	if #lines == 0 then
		table.insert(lines, "")
	end

	return lines
end

local function build_bubble(role, content)
	local win_width = get_chat_width()
	local max_width = math.max(24, win_width - 6)
	local padding = 2
	local inner_width = math.max(8, max_width - (padding * 2))

	local wrapped = wrap_text(content, inner_width)
	local bubble_inner = 0
	for _, line in ipairs(wrapped) do
		if #line > bubble_inner then
			bubble_inner = #line
		end
	end
	if bubble_inner < 1 then
		bubble_inner = 1
	end

	local bubble_width = bubble_inner + (padding * 2)
	if bubble_width > max_width then
		bubble_width = max_width
	end

	local lines = {}
	local highlights = {}
	for i, line in ipairs(wrapped) do
		local trimmed = line
		if #trimmed > bubble_inner then
			trimmed = trimmed:sub(1, bubble_inner)
		end

		local pad_right = bubble_inner - #trimmed
		local padded = string.rep(" ", padding) .. trimmed .. string.rep(" ", padding + pad_right)
		local left_pad = 0
		if role == "user" then
			left_pad = math.max(0, max_width - bubble_width)
		end
		local full = string.rep(" ", left_pad) .. padded
		table.insert(lines, full)
		highlights[i] = {
			start_col = left_pad,
			end_col = left_pad + bubble_width,
		}
	end

	return lines, highlights
end

local function remember_focus()
	local current_win = vim.api.nvim_get_current_win()
	if utils.is_win_valid(win) and current_win == win then
		return
	end

	if utils.is_win_valid(current_win) then
		last_win = current_win
		last_buf = vim.api.nvim_win_get_buf(current_win)
	end
end

local function focus_last_target()
	if utils.is_win_valid(last_win) then
		vim.api.nvim_set_current_win(last_win)
		return
	end

	if utils.is_buf_valid(last_buf) then
		local wins = vim.fn.win_findbuf(last_buf)
		if #wins > 0 and utils.is_win_valid(wins[1]) then
			vim.api.nvim_set_current_win(wins[1])
		end
	end
end

local function get_chat_state(chat_buf)
	if not chat_state[chat_buf] then
		local active_provider = provider
		local default_model = nil
		if active_provider == "ollama" then
			default_model = ollama_opts.default_model
		elseif active_provider == "copilot" then
			default_model = copilot_opts.default_model
		end
		chat_state[chat_buf] = {
			messages = {},
			model = default_model,
			context = {},
			provider = active_provider,
		}
		if active_provider == "ollama" and ollama_opts.system_prompt then
			table.insert(chat_state[chat_buf].messages, {
				role = "system",
				content = ollama_opts.system_prompt,
			})
		elseif active_provider == "copilot" and copilot_opts.system_prompt then
			table.insert(chat_state[chat_buf].messages, {
				role = "system",
				content = copilot_opts.system_prompt,
			})
		end
	end
	return chat_state[chat_buf]
end

local function provider_for_state(state)
	return state.provider or provider
end

local function ensure_model_for_chat(chat_buf)
	local state = get_chat_state(chat_buf)
	local active_provider = provider_for_state(state)

	if active_provider == "copilot" then
		if state.model then
			return state.model
		end
		if copilot_opts.default_model then
			state.model = copilot_opts.default_model
		end
		return state.model
	end

	ensure_models(false)

	if state.model then
		return state.model
	end

	if #models > 0 then
		state.model = models[1]
	elseif ollama_opts.default_model then
		state.model = ollama_opts.default_model
	end

	return state.model
end

local function notify_inline_provider(provider_name)
	local ok, inline = pcall(require, "llm_inline")
	if ok and type(inline.set_provider) == "function" then
		inline.set_provider(provider_name)
	end
end

function M.get_active_model(opts)
	opts = opts or {}
	local silent = opts.silent == true
	local active_provider = provider
	local chat_buf = nil

	if is_chat_buf(buf) then
		chat_buf = buf
	elseif #chats > 0 then
		chat_buf = chats[#chats]
	end

	if chat_buf and is_chat_buf(chat_buf) then
		local state = get_chat_state(chat_buf)
		active_provider = provider_for_state(state)
		if active_provider == "ollama" then
			ensure_models(false, true)
		end
		return ensure_model_for_chat(chat_buf), active_provider
	end

	if active_provider == "ollama" then
		ensure_models(false, true)
		if #models > 0 then
			return models[1], active_provider
		end
		if ollama_opts.default_model then
			return ollama_opts.default_model, active_provider
		end
		if not silent then
			vim.notify("No Ollama models available", vim.log.levels.WARN)
		end
		return nil, active_provider
	end

	if active_provider == "copilot" then
		return copilot_opts.default_model, active_provider
	end

	return nil, active_provider
end

local function ensure_active_chat()
	prune_chats()
	if is_chat_buf(buf) then
		return buf
	end

	if #chats > 0 then
		current_index = #chats
		buf = chats[current_index]
		return buf
	end

	vim.notify("Open the chat panel before adding context", vim.log.levels.WARN)
	return nil
end

local function add_context_entry(path, bufnr)
	local chat_buf = ensure_active_chat()
	if not chat_buf then
		return false
	end

	if not path or path == "" then
		return false
	end

	local abs_path = vim.fn.fnamemodify(path, ":p")
	local state = get_chat_state(chat_buf)
	state.context = state.context or {}

	for _, entry in ipairs(state.context) do
		if entry.path == abs_path then
			return false
		end
	end

	if context_opts.max_files and #state.context >= context_opts.max_files then
		vim.notify("Context limit reached", vim.log.levels.WARN)
		return false
	end

	local label = vim.fn.fnamemodify(abs_path, ":t")
	table.insert(state.context, {
		path = abs_path,
		label = label,
		bufnr = bufnr,
	})

	set_input_winbar()
	return true
end

local function add_buffer_context(target_buf)
	if not utils.is_buf_valid(target_buf) then
		return false
	end

	if vim.bo[target_buf].buftype ~= "" then
		return false
	end

	if vim.b[target_buf].llm_chat then
		return false
	end

	local name = vim.api.nvim_buf_get_name(target_buf)
	if name == "" then
		return false
	end

	return add_context_entry(name, target_buf)
end

local function add_current_buffer_context()
	local chat_buf = ensure_active_chat()
	if not chat_buf then
		return
	end

	local target_buf = vim.api.nvim_get_current_buf()
	if target_buf == input_buf or is_chat_buf(target_buf) then
		target_buf = last_buf
	end

	if not add_buffer_context(target_buf) then
		vim.notify("No file buffer to add", vim.log.levels.WARN)
	end
end

local function add_open_buffers_context()
	local chat_buf = ensure_active_chat()
	if not chat_buf then
		return
	end

	local added = 0
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.bo[bufnr].buflisted and vim.api.nvim_buf_is_loaded(bufnr) then
			if add_buffer_context(bufnr) then
				added = added + 1
			end
		end
	end

	if added == 0 then
		vim.notify("No open file buffers to add", vim.log.levels.WARN)
	end
end

local function add_nvim_tree_context()
	local chat_buf = ensure_active_chat()
	if not chat_buf then
		return
	end

	local ok, api = pcall(require, "nvim-tree.api")
	if not ok then
		vim.notify("nvim-tree not available", vim.log.levels.WARN)
		return
	end

	local nodes = {}
	if api.marks and api.marks.list then
		nodes = api.marks.list()
	end

	if #nodes == 0 and api.tree and api.tree.get_node_under_cursor then
		local node = api.tree.get_node_under_cursor()
		if node then
			nodes = { node }
		end
	end

	local added = 0
	for _, node in ipairs(nodes) do
		local path = node.absolute_path or node.link_to or node.path or node.name
		if path and node.type ~= "directory" then
			if add_context_entry(path, nil) then
				added = added + 1
			end
		end
	end

	if added == 0 then
		vim.notify("No files selected in nvim-tree", vim.log.levels.WARN)
	end
end

local function add_telescope_context(prompt_bufnr)
	local chat_buf = ensure_active_chat()
	if not chat_buf then
		return
	end

	local ok, action_state = pcall(require, "telescope.actions.state")
	if not ok then
		vim.notify("Telescope not available", vim.log.levels.WARN)
		return
	end

	local entry = action_state.get_selected_entry()
	if not entry then
		vim.notify("No telescope entry selected", vim.log.levels.WARN)
		return
	end

	local path = entry.path or entry.filename or entry.value
	if type(path) == "table" then
		path = path.path or path.filename or path[1]
	end

	if type(path) ~= "string" or path == "" then
		vim.notify("Selected entry has no file path", vim.log.levels.WARN)
		return
	end

	add_context_entry(path, nil)
	if prompt_bufnr then
		local ok_actions, actions = pcall(require, "telescope.actions")
		if ok_actions then
			actions.close(prompt_bufnr)
		end
	end
end

local function append_lines(target_buf, lines)
	if not utils.is_buf_valid(target_buf) then
		return
	end

	local line_count = vim.api.nvim_buf_line_count(target_buf)
	vim.api.nvim_buf_set_lines(target_buf, line_count, line_count, false, lines)
end

local function append_message(target_buf, role, content)
	local text = content
	if type(text) ~= "string" then
		text = tostring(text or "")
	end

	local bubble_lines, highlights = build_bubble(role, text)
	local start_line = vim.api.nvim_buf_line_count(target_buf)
	vim.api.nvim_buf_set_lines(target_buf, start_line, start_line, false, bubble_lines)

	local hl_group = role == "user" and "LlmChatUserBubble" or "LlmChatAssistantBubble"
	for i, range in ipairs(highlights) do
		local line = start_line + i - 1
		vim.api.nvim_buf_add_highlight(target_buf, bubble_ns, hl_group, line, range.start_col, range.end_col)
	end

	vim.api.nvim_buf_set_lines(target_buf, start_line + #bubble_lines, start_line + #bubble_lines, false, { "" })
	return {
		start = start_line,
		finish = start_line + #bubble_lines,
	}
end

local function replace_message(target_buf, range, role, content)
	if not range then
		return append_message(target_buf, role, content)
	end

	local text = content
	if type(text) ~= "string" then
		text = tostring(text or "")
	end

	local bubble_lines, highlights = build_bubble(role, text)
	local start_line = range.start or 0
	local finish_line = range.finish or start_line
	vim.api.nvim_buf_clear_namespace(target_buf, bubble_ns, start_line, finish_line + 1)
	vim.api.nvim_buf_set_lines(target_buf, start_line, finish_line + 1, false, bubble_lines)

	local hl_group = role == "user" and "LlmChatUserBubble" or "LlmChatAssistantBubble"
	for i, highlight in ipairs(highlights) do
		local line = start_line + i - 1
		vim.api.nvim_buf_add_highlight(target_buf, bubble_ns, hl_group, line, highlight.start_col, highlight.end_col)
	end

	vim.api.nvim_buf_set_lines(target_buf, start_line + #bubble_lines, start_line + #bubble_lines, false, { "" })
	return {
		start = start_line,
		finish = start_line + #bubble_lines,
	}
end

local function read_context_entry(entry)
	if entry.bufnr and utils.is_buf_valid(entry.bufnr) then
		return vim.api.nvim_buf_get_lines(entry.bufnr, 0, -1, false)
	end

	if entry.path and vim.fn.filereadable(entry.path) == 1 then
		return vim.fn.readfile(entry.path)
	end

	return nil
end

local function build_context_message(state)
	local context = state.context or {}
	if #context == 0 then
		return nil
	end

	local lines = { "Context files (read-only):" }
	local remaining = context_opts.max_total_lines or 0
	local has_limit = remaining > 0

	for _, entry in ipairs(context) do
		if has_limit and remaining <= 0 then
			break
		end

		local content_lines = read_context_entry(entry)
		if content_lines and #content_lines > 0 then
			local header = "File: " .. entry.path
			table.insert(lines, header)
			table.insert(lines, "```")

			local max_lines = context_opts.max_lines_per_file or #content_lines
			if has_limit then
				max_lines = math.min(max_lines, remaining)
			end
			local limit = math.min(#content_lines, max_lines)
			for i = 1, limit do
				table.insert(lines, content_lines[i])
			end

			table.insert(lines, "```")
			table.insert(lines, "")

			if has_limit then
				remaining = remaining - limit
			end
		end
	end

	if #lines == 1 then
		return nil
	end

	return {
		role = "system",
		content = table.concat(lines, "\n"),
	}
end

local function build_request_messages(state)
	local messages = vim.deepcopy(state.messages)
	local context_message = build_context_message(state)
	if not context_message then
		return messages
	end

	local insert_at = 1
	if #messages > 0 and messages[1].role == "system" then
		insert_at = 2
	end
	table.insert(messages, insert_at, context_message)
	return messages
end

local function parse_chat_response(output)
	if not output or output == "" then
		return nil, "Empty response from Ollama"
	end

	local ok, data = pcall(vim.fn.json_decode, output)
	if ok and type(data) == "table" and data.message and data.message.content then
		return data.message.content, nil
	end

	local last_content = nil
	local lines = vim.split(output, "\n", { trimempty = true })
	for _, line in ipairs(lines) do
		local trimmed = vim.trim(line)
		if trimmed ~= "" then
			local ok_line, data_line = pcall(vim.fn.json_decode, trimmed)
			if ok_line and type(data_line) == "table" and data_line.message and data_line.message.content then
				last_content = data_line.message.content
			end
		end
	end

	if last_content then
		return last_content, nil
	end

	local buffer = {}
	local depth = 0
	local in_string = false
	local escape = false

	for i = 1, #output do
		local ch = output:sub(i, i)

		if in_string then
			table.insert(buffer, ch)
			if escape then
				escape = false
			elseif ch == "\\" then
				escape = true
			elseif ch == "\"" then
				in_string = false
			end
		else
			if ch == "\"" then
				in_string = true
				if depth > 0 then
					table.insert(buffer, ch)
				end
			elseif ch == "{" then
				if depth == 0 then
					buffer = { "{" }
				else
					table.insert(buffer, ch)
				end
				depth = depth + 1
			elseif ch == "}" and depth > 0 then
				table.insert(buffer, ch)
				depth = depth - 1
				if depth == 0 then
					local chunk = table.concat(buffer)
					buffer = {}
					local ok_chunk, data_chunk = pcall(vim.fn.json_decode, chunk)
					if ok_chunk and type(data_chunk) == "table" and data_chunk.message and data_chunk.message.content then
						last_content = data_chunk.message.content
					end
				end
			elseif depth > 0 then
				table.insert(buffer, ch)
			end
		end
	end

	if last_content then
		return last_content, nil
	end

	return nil, "Invalid response from Ollama"
end

local function scroll_chat_to_bottom()
	if utils.is_win_valid(win) and utils.is_buf_valid(buf) then
		local line_count = vim.api.nvim_buf_line_count(buf)
		vim.api.nvim_win_set_cursor(win, { line_count, 0 })
	end
end

local function request_chat(payload)
	local body = vim.fn.json_encode(payload)
	local cmd = build_curl_cmd("/api/chat", true)
	local output, err = run_command(cmd, body)
	if not output then
		return nil, err or "Failed to contact Ollama"
	end

	local response, parse_err = parse_chat_response(output)
	if response then
		return response, nil
	end
	return nil, parse_err or "Invalid response from Ollama"
end

local function request_chat_async(payload, callback)
	local body = vim.fn.json_encode(payload)
	local cmd = build_curl_cmd("/api/chat", true)
	run_command_async(cmd, body, function(output, err)
		if not output then
			callback(nil, err or "Failed to contact Ollama")
			return
		end

		local response, parse_err = parse_chat_response(output)
		if response then
			callback(response, nil)
			return
		end
		callback(nil, parse_err or "Invalid response from Ollama")
	end)
end

local function build_copilot_prompt(state)
	local parts = {}

	for _, msg in ipairs(state.messages or {}) do
		local content = msg.content or ""
		if msg.role == "user" then
			table.insert(parts, "User: " .. content)
		elseif msg.role == "assistant" then
			table.insert(parts, "Assistant: " .. content)
		end
	end

	return table.concat(parts, "\n")
end

local function build_copilot_sticky(state)
	local sticky = {}
	local seen = {}

	if copilot_opts.sticky then
		for _, item in ipairs(copilot_opts.sticky) do
			if item and item ~= "" and not seen[item] then
				table.insert(sticky, item)
				seen[item] = true
			end
		end
	end

	for _, entry in ipairs(state.context or {}) do
		if entry.path and entry.path ~= "" then
			local token = "#file:" .. entry.path
			if not seen[token] then
				table.insert(sticky, token)
				seen[token] = true
			end
		end
	end

	return sticky
end

local function request_copilot(prompt, model, state, callback)
	local ok, copilot = pcall(require, "CopilotChat")
	if not ok then
		return nil, "CopilotChat.nvim not available"
	end

	local opts = {
		callback = function(response)
			if type(response) == "table" then
				response = response.content
			end
			return callback(response)
		end,
		headless = true,
	}
	if model then
		opts.model = model
	end
	if copilot_opts.system_prompt then
		opts.system_prompt = copilot_opts.system_prompt
	end
	local sticky = build_copilot_sticky(state)
	if #sticky > 0 then
		opts.sticky = sticky
	end

	local ok_call, err = pcall(copilot.ask, prompt, opts)
	if not ok_call then
		return nil, err or "CopilotChat request failed"
	end

	return true, nil
end

local function reset_prompt()
	if utils.is_buf_valid(input_buf) then
		vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, {})
	end
end

local function send_input_buffer()
	if not utils.is_buf_valid(input_buf) then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(input_buf, 0, -1, false)
	local text = table.concat(lines, "\n")
	reset_prompt()
	if utils.is_win_valid(input_win) then
		vim.api.nvim_set_current_win(input_win)
		vim.cmd("startinsert")
	end
	send_message(text)
end

send_message = function(text)
	if not utils.is_buf_valid(buf) then
		return
	end

	local trimmed = vim.trim(text or "")
	if trimmed == "" then
		return
	end

	local state = get_chat_state(buf)
	local active_provider = provider_for_state(state)
	local model = ensure_model_for_chat(buf)
	if active_provider == "ollama" and not model then
		vim.notify("No Ollama models available", vim.log.levels.WARN)
		return
	end
	append_message(buf, "user", trimmed)
	table.insert(state.messages, { role = "user", content = trimmed })
	scroll_chat_to_bottom()

	if active_provider == "copilot" then
		local prompt = build_copilot_prompt(state)
		local ok, err = request_copilot(prompt, model, state, function(response)
			vim.schedule(function()
				if not response or response == "" then
					append_message(buf, "assistant", "Error: empty response from Copilot")
					scroll_chat_to_bottom()
					return
				end

				table.insert(state.messages, { role = "assistant", content = response })
				append_message(buf, "assistant", response)
				scroll_chat_to_bottom()
			end)
			return response
		end)

		if not ok then
			append_message(buf, "assistant", "Error: " .. (err or "request failed"))
			scroll_chat_to_bottom()
		end
		return
	end

	local target_buf = buf
	local placeholder_range = append_message(target_buf, "assistant", "…")
	scroll_chat_to_bottom()
	local payload = {
		model = model,
		messages = build_request_messages(state),
		stream = false,
	}

	vim.cmd("redraw")

	local response, err = request_chat(payload)
	if not utils.is_buf_valid(target_buf) then
		return
	end

	if not response then
		replace_message(target_buf, placeholder_range, "assistant", "Error: " .. (err or "request failed"))
		scroll_chat_to_bottom()
		return
	end

	table.insert(state.messages, { role = "assistant", content = response })
	replace_message(target_buf, placeholder_range, "assistant", response)
	scroll_chat_to_bottom()
end

local function ensure_input_buf()
	if utils.is_buf_valid(input_buf) then
		return
	end

	input_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[input_buf].buftype = "nofile"
	vim.bo[input_buf].bufhidden = "hide"
	vim.bo[input_buf].buflisted = false
	vim.bo[input_buf].swapfile = false
	vim.bo[input_buf].filetype = "llm_chat_input"
end

prune_chats = function()
	local next_list = {}
	for _, chat_buf in ipairs(chats) do
		if is_chat_buf(chat_buf) then
			table.insert(next_list, chat_buf)
		end
	end
	chats = next_list

	current_index = nil
	if is_chat_buf(buf) then
		for i, chat_buf in ipairs(chats) do
			if chat_buf == buf then
				current_index = i
				break
			end
		end
	end

	if not current_index and #chats > 0 then
		current_index = #chats
		buf = chats[current_index]
	elseif not current_index then
		buf = nil
	end
end

local function add_chat(chat_buf)
	for i, existing in ipairs(chats) do
		if existing == chat_buf then
			current_index = i
			buf = chat_buf
			return
		end
	end

	table.insert(chats, chat_buf)
	current_index = #chats
	buf = chat_buf
end

local function remove_chat(chat_buf)
	local removed_index = nil
	for i, existing in ipairs(chats) do
		if existing == chat_buf then
			table.remove(chats, i)
			removed_index = i
			break
		end
	end

	if not removed_index then
		return
	end

	if #chats == 0 then
		current_index = nil
		buf = nil
		return
	end

	if current_index then
		if removed_index < current_index then
			current_index = current_index - 1
		elseif removed_index == current_index and current_index > #chats then
			current_index = #chats
		end
	end

	if current_index then
		buf = chats[current_index]
	end
end

local function build_context_chips()
	if not is_chat_buf(buf) then
		return ""
	end

	local state = get_chat_state(buf)
	local context = state.context or {}
	if #context == 0 then
		return ""
	end

	local parts = { "Ctx:" }
	for i, entry in ipairs(context) do
		local label = truncate_label(entry.label or entry.path)
		label = escape_statusline(label)
		local hl = "%#TabLine#"
		local close_click = string.format("%%%d@v:lua.LlmChatRemoveContext@", i)
		table.insert(parts, hl .. " " .. label .. " " .. close_click .. "x" .. "%X" .. "%#WinBar#")
	end

	return table.concat(parts, " ")
end

local function build_tabline()
	local total = #chats
	if total <= 1 then
		return ""
	end

	local parts = {}
	for i = 1, total do
		local hl = (i == current_index) and "%#TabLineSel#" or "%#TabLine#"
		local click = string.format("%%%d@v:lua.LlmChatTabClick@", i)
		local close_click = string.format("%%%d@v:lua.LlmChatTabClose@", i)
		table.insert(parts, hl .. click .. " " .. i .. " " .. "%X")
		table.insert(parts, hl .. close_click .. " x " .. "%X")
	end
	table.insert(parts, "%#WinBar#")
	return table.concat(parts, "")
end

local function build_close_button(index)
	if not index then
		return ""
	end

	local hl = "%#TabLineSel#"
	local click = string.format("%%%d@v:lua.LlmChatTabClose@", index)
	return hl .. click .. " x " .. "%X" .. "%#WinBar#"
end

local function build_hints()
	local parts = {
		"[Esc] hide",
		"[q] close",
	}

	if keybinds.add_buffer then
		table.insert(parts, "[" .. keybinds.add_buffer .. "] add buf")
	end
	if keybinds.add_buffers then
		table.insert(parts, "[" .. keybinds.add_buffers .. "] add bufs")
	end
	if keybinds.new then
		table.insert(parts, "[" .. keybinds.new .. "] new")
	end
	if keybinds.prev then
		table.insert(parts, "[" .. keybinds.prev .. "] prev")
	end
	if keybinds.next then
		table.insert(parts, "[" .. keybinds.next .. "] next")
	end

	return table.concat(parts, "  ")
end

local function set_chat_winbar()
	if not utils.is_win_valid(win) then
		return
	end

	prune_chats()

	local label = " Chat "
	local tabs = build_tabline()
	local close_button = ""
	if #chats == 1 and current_index then
		close_button = " " .. build_close_button(current_index)
	end
	local winbar = label .. close_button .. tabs .. "%=" .. build_hints()
	vim.api.nvim_set_option_value("winbar", winbar, { win = win })
end

set_input_winbar = function()
	if not utils.is_win_valid(input_win) then
		return
	end
	if not is_chat_buf(buf) then
		return
	end

	local state = get_chat_state(buf)
	local active_provider = provider_for_state(state)
	local chips = build_context_chips()
	local model = ensure_model_for_chat(buf) or "no-model"
	if active_provider == "copilot" then
		model = state.model or copilot_opts.default_model or "Copilot"
	end
	local click = "%@v:lua.LlmChatModelSelect@" .. "Model: " .. escape_statusline(model) .. " ▼" .. "%X"
	local right = click .. "  [Enter] send (normal)"
	local winbar = chips
	if chips ~= "" then
		winbar = winbar .. " "
	end
	winbar = winbar .. "%=" .. right
	vim.api.nvim_set_option_value("winbar", winbar, { win = input_win })
end

close = function()
	if utils.is_win_valid(input_win) then
		vim.api.nvim_win_close(input_win, true)
		input_win = nil
	end

	if utils.is_win_valid(win) then
		vim.api.nvim_win_close(win, true)
		win = nil
	end

	vim.cmd("stopinsert")
	vim.schedule(focus_last_target)
end

local function delete()
	local target_buf = buf
	prune_chats()
	local keep_window = utils.is_win_valid(win) and #chats > 1

	if not keep_window then
		if utils.is_win_valid(input_win) then
			vim.api.nvim_win_close(input_win, true)
			input_win = nil
		end
		if utils.is_win_valid(win) then
			vim.api.nvim_win_close(win, true)
			win = nil
		end
	end

	if utils.is_buf_valid(target_buf) then
		vim.api.nvim_buf_delete(target_buf, { force = true })
	end

	remove_chat(target_buf)
	chat_state[target_buf] = nil

	if keep_window and is_chat_buf(buf) then
		show_current()
		return
	end

	vim.cmd("stopinsert")
	vim.schedule(focus_last_target)
end

local function buf_keybinds(target_buf)
	local opts = { buffer = target_buf, silent = true }
	vim.keymap.set("n", "<Esc>", function()
		close()
	end, opts)
	vim.keymap.set("n", "q", function()
		delete()
	end, opts)
end

local function input_keybinds()
	if not utils.is_buf_valid(input_buf) then
		return
	end

	local opts = { buffer = input_buf, silent = true }
	vim.keymap.set("n", "<Esc>", function()
		close()
	end, opts)
	vim.keymap.set("n", "q", function()
		delete()
	end, opts)
	vim.keymap.set("n", "<CR>", function()
		send_input_buffer()
	end, opts)
end

local function ensure_windows()
	if utils.is_win_valid(win) and utils.is_win_valid(input_win) then
		return
	end

	if utils.is_win_valid(win) then
		vim.api.nvim_set_current_win(win)
	else
		win = utils.create_right_win(buf, win, {
			width = resolve_width(),
			focus = true,
		})
	end

	if utils.is_win_valid(win) then
		vim.api.nvim_win_set_buf(win, buf)
		vim.api.nvim_set_current_win(win)
	end

	ensure_input_buf()

	if not utils.is_win_valid(input_win) then
		vim.cmd("belowright split")
		input_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_height(input_win, panel_opts.input_height)
	end

	if utils.is_win_valid(input_win) then
		vim.api.nvim_win_set_buf(input_win, input_buf)
	end
end

show_current = function()
	if not is_chat_buf(buf) then
		return
	end

	ensure_windows()

	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].buflisted = false
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].modifiable = true

	set_chat_winbar()
	set_input_winbar()
	buf_keybinds(buf)
	input_keybinds()

	if utils.is_win_valid(input_win) then
		vim.api.nvim_set_current_win(input_win)
		vim.cmd("startinsert")
	end
end

local function open_new()
	remember_focus()
	prune_chats()

	buf = utils.create_scratch_buf(nil)
	vim.b[buf].llm_chat = true
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].buflisted = false
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].modifiable = true
	add_chat(buf)

	ensure_windows()
	set_chat_winbar()
	set_input_winbar()
	buf_keybinds(buf)
	input_keybinds()

	if utils.is_win_valid(input_win) then
		vim.api.nvim_set_current_win(input_win)
		vim.cmd("startinsert")
	end

	notify_provider_status()
end

local function open_win()
	remember_focus()
	prune_chats()

	if not is_chat_buf(buf) then
		if #chats == 0 then
			open_new()
			return
		end
		current_index = #chats
		buf = chats[current_index]
	end

	show_current()
	notify_provider_status()
end

local function cycle_chat(direction)
	remember_focus()
	prune_chats()

	if #chats == 0 then
		open_new()
		return
	end

	if not current_index then
		current_index = #chats
	end

	local total = #chats
	current_index = ((current_index - 1 + direction) % total) + 1
	buf = chats[current_index]
	show_current()
end

local function next_chat()
	cycle_chat(1)
end

local function prev_chat()
	cycle_chat(-1)
end

chat_tab_click = function(minwid, clicks, button, mods)
	if button ~= "l" then
		return
	end

	prune_chats()
	local index = tonumber(minwid)
	if not index or index < 1 or index > #chats then
		return
	end

	current_index = index
	buf = chats[current_index]
	show_current()
end

chat_tab_close = function(minwid, clicks, button, mods)
	if button ~= "l" then
		return
	end

	prune_chats()
	local index = tonumber(minwid)
	if not index or index < 1 or index > #chats then
		return
	end

	local target_buf = chats[index]
	local target_is_current = target_buf == buf

	if utils.is_buf_valid(target_buf) then
		vim.api.nvim_buf_delete(target_buf, { force = true })
	end

	remove_chat(target_buf)
	chat_state[target_buf] = nil

	if #chats == 0 then
		close()
		return
	end

	if target_is_current then
		show_current()
		return
	end

	if utils.is_win_valid(win) then
		set_chat_winbar()
	end
end

chat_model_select = function()
	if not is_chat_buf(buf) then
		return
	end

	local state = get_chat_state(buf)
	local active_provider = provider_for_state(state)
	local items = {}

	local function add_item(label, provider_name, model_name)
		table.insert(items, {
			label = label,
			provider = provider_name,
			model = model_name,
		})
	end

	local silent = active_provider ~= "ollama"
	ensure_models(true, silent)
	if #models > 0 then
		for _, model in ipairs(models) do
			add_item("Ollama: " .. model, "ollama", model)
		end
	end

	local has_copilot, copilot = pcall(require, "CopilotChat")
	if has_copilot then
		add_item("Copilot", "copilot", nil)
	else
		add_item("Copilot (not installed)", "copilot", nil)
	end

	if #items == 0 then
		vim.notify("No models available", vim.log.levels.WARN)
		return
	end

	vim.ui.select(items, {
		prompt = "Select model",
		format_item = function(item)
			return item.label
		end,
	}, function(choice)
		if not choice then
			return
		end
		if choice.provider == "copilot" then
			if not has_copilot then
				vim.notify("CopilotChat.nvim not available", vim.log.levels.WARN)
				return
			end
			local ok_call, err = pcall(copilot.select_model)
			if not ok_call then
				vim.notify(err or "Copilot model selection failed", vim.log.levels.WARN)
				return
			end
			state.provider = "copilot"
			state.model = nil
			set_input_winbar()
			notify_inline_provider(state.provider)
			return
		end

		state.provider = "ollama"
		state.model = choice.model
		set_input_winbar()
		notify_inline_provider(state.provider)
	end)
end

chat_context_remove = function(minwid, clicks, button, mods)
	if button ~= "l" then
		return
	end

	if not is_chat_buf(buf) then
		return
	end

	local state = get_chat_state(buf)
	local index = tonumber(minwid)
	if not index or not state.context or not state.context[index] then
		return
	end

	table.remove(state.context, index)
	set_input_winbar()
end

function M.setup(config)
	if type(config) == "string" then
		config = { keybind = config }
	end
	config = config or {}

	ensure_bubble_highlights()
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("LlmChatHighlights", { clear = true }),
		callback = function()
			ensure_bubble_highlights()
		end,
	})

	_G.LlmChatTabClick = chat_tab_click
	_G.LlmChatTabClose = chat_tab_close
	_G.LlmChatModelSelect = chat_model_select
	_G.LlmChatRemoveContext = chat_context_remove

	if config.keybind ~= nil then
		keybinds.open = config.keybind
	end
	if config.new_keybind ~= nil then
		keybinds.new = config.new_keybind
	end
	if config.prev_keybind ~= nil then
		keybinds.prev = config.prev_keybind
	end
	if config.next_keybind ~= nil then
		keybinds.next = config.next_keybind
	end
	if config.add_buffer_keybind ~= nil then
		keybinds.add_buffer = config.add_buffer_keybind
	end
	if config.add_buffers_keybind ~= nil then
		keybinds.add_buffers = config.add_buffers_keybind
	end
	if config.add_nvim_tree_keybind ~= nil then
		keybinds.add_nvim_tree = config.add_nvim_tree_keybind
	end
	if config.add_telescope_keybind ~= nil then
		keybinds.add_telescope = config.add_telescope_keybind
	end
	if config.model_selector_keybind ~= nil then
		keybinds.model_selector = config.model_selector_keybind
	end

	if config.width ~= nil then
		panel_opts.width = config.width
	end
	if config.width_ratio ~= nil then
		panel_opts.width_ratio = config.width_ratio
	end
	if config.max_width ~= nil then
		panel_opts.max_width = config.max_width
	end
	if config.input_height ~= nil then
		panel_opts.input_height = config.input_height
	end
	if config.context_max_files ~= nil then
		context_opts.max_files = config.context_max_files
	end
	if config.context_max_lines ~= nil then
		context_opts.max_lines_per_file = config.context_max_lines
	end
	if config.context_max_total_lines ~= nil then
		context_opts.max_total_lines = config.context_max_total_lines
	end
	if config.context_max_label_len ~= nil then
		context_opts.max_label_len = config.context_max_label_len
	end

	if config.provider ~= nil then
		provider = normalize_provider(config.provider)
	else
		provider = normalize_provider(provider)
	end

	if config.ollama_host ~= nil then
		ollama_opts.host = config.ollama_host
	end
	if config.ollama_container ~= nil then
		ollama_opts.container = config.ollama_container
	end
	if config.default_model ~= nil then
		ollama_opts.default_model = config.default_model
	end
	if config.system_prompt ~= nil then
		ollama_opts.system_prompt = config.system_prompt
	end
	if config.copilot_model ~= nil then
		copilot_opts.default_model = config.copilot_model
	end
	if config.copilot_system_prompt ~= nil then
		copilot_opts.system_prompt = config.copilot_system_prompt
	end
	if config.copilot_sticky ~= nil then
		copilot_opts.sticky = config.copilot_sticky
	end

	notify_inline_provider(provider)

	local opts = {
		noremap = true,
		silent = true,
		desc = "Open LLM chat window",
	}
	if keybinds.open then
		vim.keymap.set({ "n", "v" }, keybinds.open, open_win, opts)
	end

	if keybinds.new then
		local create_opts = {
			noremap = true,
			silent = true,
			desc = "Open new LLM chat window",
		}
		vim.keymap.set({ "n", "v" }, keybinds.new, open_new, create_opts)
	end

	if keybinds.prev then
		local prev_opts = {
			noremap = true,
			silent = true,
			desc = "Previous LLM chat",
		}
		vim.keymap.set({ "n", "v" }, keybinds.prev, prev_chat, prev_opts)
	end

	if keybinds.next then
		local next_opts = {
			noremap = true,
			silent = true,
			desc = "Next LLM chat",
		}
		vim.keymap.set({ "n", "v" }, keybinds.next, next_chat, next_opts)
	end

	if keybinds.add_buffer then
		local add_opts = {
			noremap = true,
			silent = true,
			desc = "Add current buffer to chat context",
		}
		vim.keymap.set({ "n", "v" }, keybinds.add_buffer, add_current_buffer_context, add_opts)
	end

	if keybinds.add_buffers then
		local add_opts = {
			noremap = true,
			silent = true,
			desc = "Add open buffers to chat context",
		}
		vim.keymap.set({ "n", "v" }, keybinds.add_buffers, add_open_buffers_context, add_opts)
	end

	if keybinds.add_nvim_tree then
		local add_opts = {
			noremap = true,
			silent = true,
			desc = "Add nvim-tree selection to chat context",
		}
		vim.keymap.set({ "n", "v" }, keybinds.add_nvim_tree, add_nvim_tree_context, add_opts)
	end

	if keybinds.add_telescope then
		local add_opts = {
			noremap = true,
			silent = true,
			desc = "Add telescope selection to chat context",
		}
		vim.keymap.set({ "n", "v" }, keybinds.add_telescope, add_telescope_context, add_opts)
	end

	if keybinds.model_selector then
		local model_opts = {
			noremap = true,
			silent = true,
			desc = "Select LLM model",
		}
		vim.keymap.set({ "n", "v" }, keybinds.model_selector, chat_model_select, model_opts)
	end

	vim.api.nvim_create_user_command("LlmChatAddBuffer", add_current_buffer_context, { force = true })
	vim.api.nvim_create_user_command("LlmChatAddBuffers", add_open_buffers_context, { force = true })
	vim.api.nvim_create_user_command("LlmChatAddNvimTree", add_nvim_tree_context, { force = true })
	vim.api.nvim_create_user_command("LlmChatAddTelescope", function(opts)
		add_telescope_context(tonumber(opts.args) or nil)
	end, { force = true, nargs = "?" })
end

M.add_current_buffer = add_current_buffer_context
M.add_open_buffers = add_open_buffers_context
M.add_nvim_tree_selection = add_nvim_tree_context
M.add_telescope_selection = add_telescope_context

return M
