local vim = vim
local utils = require("utils")
local M = {}

local uv = vim.uv or vim.loop

M.config = {
	host = "http://127.0.0.1:11434",
	container = nil,
	model = nil,
	debounce_ms = 250,
	max_ctx_lines = 40,
	max_tokens = 64,
	temperature = 0.2,
	accept_key = "<Tab>",
	debug = false,
	debug_notify = false,
	debug_log_buffer = false,
	max_log_lines = 500,
}

local ns = vim.api.nvim_create_namespace("llm_inline")
local state = { bufnr = nil, text = nil, row = nil, col = nil }
local timer = nil
local request_id = 0
local models = {}
local models_loaded = false
local log_bufnr = nil
local enabled = true
local active_provider = "ollama"
local feed_key
local clear
local function set_copilot_enabled(value)
	vim.g.copilot_enabled = value and true or false

	if vim.fn.exists("*copilot#Enable") == 1 and value then
		pcall(vim.fn["copilot#Enable"])
		return
	end

	if vim.fn.exists("*copilot#Disable") == 1 and not value then
		pcall(vim.fn["copilot#Disable"])
	end
end

local function now()
	return os.date("%H:%M:%S")
end

local function ensure_log_buf()
	if log_bufnr and vim.api.nvim_buf_is_valid(log_bufnr) then
		return log_bufnr
	end

	log_bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(log_bufnr, "LLM Inline Debug")
	vim.api.nvim_buf_set_option(log_bufnr, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(log_bufnr, "filetype", "log")
	return log_bufnr
end

local function log_line(line)
	if not M.config.debug then
		return
	end

	line = string.format("[%s] %s", now(), line)

	if M.config.debug_notify then
		vim.notify(line, vim.log.levels.INFO, { title = "LLM Inline" })
	end

	if M.config.debug_log_buffer then
		local b = ensure_log_buf()
		local lc = vim.api.nvim_buf_line_count(b)
		vim.api.nvim_buf_set_lines(b, lc, lc, false, { line })

		local maxl = M.config.max_log_lines
		local new_count = vim.api.nvim_buf_line_count(b)
		if maxl and maxl > 0 and new_count > maxl then
			vim.api.nvim_buf_set_lines(b, 0, new_count - maxl, false, {})
		end
	end
end

local function apply_accept_mapping()
	if not M.config.accept_key or M.config.accept_key == "" then
		return
	end

	pcall(vim.keymap.del, "i", M.config.accept_key)

	if M.config.accept_key == "<Tab>" then
		if active_provider == "copilot" then
			vim.keymap.set("i", M.config.accept_key, function()
				if vim.fn.pumvisible() == 1 then
					return "<C-n>"
				end
				if vim.fn.exists("*copilot#Accept") == 1 then
					return vim.fn["copilot#Accept"]()
				end
				return "\t"
			end, { expr = true, silent = true })
			return
		end

		vim.keymap.set("i", M.config.accept_key, function()
			if M.has_suggestion() then
				vim.schedule(function()
					if vim.fn.mode() == "i" then
						M.accept()
					end
				end)
				return ""
			end
			if vim.fn.pumvisible() == 1 then
				return "<C-n>"
			end
			return "\t"
		end, { expr = true, silent = true })
		return
	end

	if active_provider == "copilot" then
		return
	end

	vim.keymap.set("i", M.config.accept_key, function()
		if M.has_suggestion() then
			vim.schedule(function()
				if vim.fn.mode() == "i" then
					M.accept()
				end
			end)
			return
		end
		feed_key(M.config.accept_key)
	end, { silent = true })
end

local function set_enabled(value)
	enabled = value
	if not enabled then
		if timer then
			timer:stop()
		end
		clear()
	end
end

function M.set_provider(provider)
	if provider == "copilot" then
		active_provider = "copilot"
		set_enabled(false)
		set_copilot_enabled(true)
	else
		active_provider = "ollama"
		set_enabled(true)
		set_copilot_enabled(false)
	end
	apply_accept_mapping()
end

local function normalize_host(host)
	local value = host or "http://127.0.0.1:11434"
	if value:sub(-1) == "/" then
		value = value:sub(1, -2)
	end
	return value
end

local function build_curl_cmd(path, use_stdin)
	local host = normalize_host(M.config.host)
	local url = host .. path

	if M.config.container then
		if use_stdin then
			return {
				"docker",
				"exec",
				"-i",
				M.config.container,
				"curl",
				"-sS",
				"-X",
				"POST",
				"-H",
				"Content-Type: application/json",
				"--data-binary",
				"@-",
				url,
			}
		end
		return { "docker", "exec", M.config.container, "curl", "-sS", url }
	end

	if use_stdin then
		return {
			"curl",
			"-sS",
			"-X",
			"POST",
			"-H",
			"Content-Type: application/json",
			"--data-binary",
			"@-",
			url,
		}
	end

	return { "curl", "-sS", url }
end

local function run_command(cmd, input)
	local output = vim.fn.system(cmd, input)
	if vim.v.shell_error ~= 0 then
		return nil, output
	end
	return output, nil
end

local function run_command_async(cmd, input, callback)
	local function schedule_callback(out, err)
		vim.schedule(function()
			callback(out, err)
		end)
	end

	if vim.system then
		local opts = { text = true }
		if input then
			opts.stdin = input
		end
		vim.system(cmd, opts, function(result)
			local stdout = result.stdout or ""
			local stderr = result.stderr or ""
			if result.code ~= 0 then
				schedule_callback(nil, stderr ~= "" and stderr or stdout)
				return
			end
			schedule_callback(stdout, nil)
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
				schedule_callback(nil, err ~= "" and err or out)
				return
			end
			schedule_callback(out, nil)
		end,
	})

	if input and job_id > 0 then
		vim.fn.chansend(job_id, input)
		vim.fn.chanclose(job_id, "stdin")
	end
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

local function fetch_models()
	local cmd = build_curl_cmd("/api/tags", false)
	local output, err = run_command(cmd)
	if output then
		local list = parse_models_from_tags(output)
		if list and #list > 0 then
			return list
		end
	end

	if M.config.container then
		local list_output = run_command({ "docker", "exec", M.config.container, "ollama", "list" })
		local list = parse_models_from_ollama_list(list_output)
		if #list > 0 then
			return list
		end
	end

	if err and err ~= "" then
		log_line("Model fetch failed: " .. err)
	end

	return {}
end

local function get_chat_model()
	local ok, chat = pcall(require, "llm_chat")
	if not ok then
		return nil, nil
	end
	if type(chat.get_active_model) ~= "function" then
		return nil, nil
	end
	local model, provider = chat.get_active_model({ silent = true })
	return model, provider
end

local function ensure_model()
	local chat_model, provider = get_chat_model()
	if provider and provider ~= "ollama" then
		log_line("Chat provider is " .. provider .. "; inline uses Ollama")
		return nil
	end

	if chat_model and chat_model ~= "" then
		return chat_model
	end

	if M.config.model and M.config.model ~= "" then
		return M.config.model
	end

	if models_loaded then
		return models[1]
	end

	models = fetch_models()
	models_loaded = true

	if #models > 0 then
		M.config.model = models[1]
		log_line("Auto model: " .. M.config.model)
	end

	return M.config.model
end

clear = function()
	if utils.is_buf_valid(state.bufnr) then
		vim.api.nvim_buf_clear_namespace(state.bufnr, ns, 0, -1)
	end
	state = { bufnr = nil, text = nil, row = nil, col = nil }
end

local function show_at_pos(bufnr, row, col, text)
	if not utils.is_buf_valid(bufnr) then
		return
	end

	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

	vim.api.nvim_buf_set_extmark(bufnr, ns, row, col, {
		virt_text = { { text, "LspInlayHint" } },
		virt_text_pos = "inline",
		hl_mode = "combine",
		priority = 200,
	})

	state = { bufnr = bufnr, text = text, row = row, col = col }
end

local function suggestion_at_cursor()
	local bufnr = vim.api.nvim_get_current_buf()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	row = row - 1

	if state.text and state.bufnr == bufnr and state.row == row and state.col == col then
		return state.text, bufnr, row, col
	end

	local marks = vim.api.nvim_buf_get_extmarks(
		bufnr,
		ns,
		{ row, col },
		{ row, col },
		{ details = true, limit = 1 }
	)
	if #marks == 0 then
		return nil
	end

	local details = marks[1][4] or {}
	local virt = details.virt_text
	if type(virt) ~= "table" or #virt == 0 then
		return nil
	end

	local parts = {}
	for _, chunk in ipairs(virt) do
		if type(chunk) == "table" and chunk[1] then
			table.insert(parts, chunk[1])
		end
	end
	local text = table.concat(parts, "")
	if text == "" then
		return nil
	end

	return text, bufnr, row, col
end

function M.has_suggestion()
	local text = suggestion_at_cursor()
	return text ~= nil
end

function M.accept()
	local text, bufnr, row, col = suggestion_at_cursor()
	if not text then
		return false
	end
	if not utils.is_buf_valid(bufnr) then
		clear()
		return false
	end

	clear()
	vim.api.nvim_buf_set_text(bufnr, row, col, row, col, { text })
	vim.api.nvim_win_set_cursor(0, { row + 1, col + #text })
	return true
end

function M.get_accept_key()
	return M.config.accept_key
end

local function should_show()
	if not enabled then
		return false
	end
	if vim.fn.mode() ~= "i" then
		return false
	end
	if vim.fn.pumvisible() == 1 then
		return false
	end
	local bufnr = vim.api.nvim_get_current_buf()
	if vim.bo[bufnr].buftype ~= "" then
		return false
	end
	local line = vim.api.nvim_get_current_line()
	if not line:match("%S") then
		return false
	end
	return true
end

local function get_context()
	local bufnr = vim.api.nvim_get_current_buf()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	row = row - 1

	local max_ctx = M.config.max_ctx_lines
	if not max_ctx or max_ctx < 1 then
		max_ctx = 1
	end
	local start = math.max(0, row - max_ctx + 1)
	local ctx_lines = vim.api.nvim_buf_get_lines(bufnr, start, row, false)
	local ctx = table.concat(ctx_lines, "\n")

	local line = vim.api.nvim_get_current_line()
	local prefix = line:sub(1, col)
	local suffix = line:sub(col + 1)

	return {
		bufnr = bufnr,
		row = row,
		col = col,
		ctx = ctx,
		prefix = prefix,
		suffix = suffix,
		filetype = vim.bo[bufnr].filetype,
	}
end

local function build_prompt(ctx, prefix, filetype)
	local parts = {
		"You are a code completion engine.",
		"Return ONLY the code to be inserted next.",
		"Do NOT use markdown. Do NOT explain.",
	}

	if filetype and filetype ~= "" then
		table.insert(parts, "Filetype: " .. filetype)
	end

	table.insert(parts, "")
	table.insert(parts, "### Context")
	table.insert(parts, ctx)
	table.insert(parts, "")
	table.insert(parts, "### Continue this code (output only code):")
	table.insert(parts, prefix)

	return table.concat(parts, "\n")
end

local function parse_completion_text(raw)
	if not raw then
		return nil
	end
	local text = raw:gsub("\r", "")
	text = text:gsub("^\n+", "")
	local first = text:match("([^\n]*)") or ""
	first = first:gsub("%s+$", "")
	if first == "" then
		return nil
	end
	return first
end

local function request_ollama(ctx, callback)
	local model = ensure_model()
	if not model then
		callback(nil, "No model available")
		return
	end

	local payload = {
		model = model,
		prompt = build_prompt(ctx.ctx, ctx.prefix, ctx.filetype),
		suffix = ctx.suffix,
		stream = false,
		options = {
			num_predict = M.config.max_tokens,
			temperature = M.config.temperature,
		},
	}

	local json_encode = (vim.json and vim.json.encode) or vim.fn.json_encode
	local body = json_encode(payload)

	log_line("REQ model=" .. model .. " bytes=" .. tostring(#body))

	local cmd = build_curl_cmd("/api/generate", true)
	run_command_async(cmd, body, function(output, err)
		if not output or output == "" then
			callback(nil, err or "Empty response")
			return
		end

		local json_decode = (vim.json and vim.json.decode) or vim.fn.json_decode
		local ok, decoded = pcall(json_decode, output)
		if not ok or type(decoded) ~= "table" then
			callback(nil, "Invalid JSON response")
			return
		end

		local text = parse_completion_text(decoded.response)
		if not text then
			callback(nil, "Empty completion")
			return
		end

		callback(text, nil)
	end)
end

local function context_still_valid(ctx)
	if not should_show() then
		return false
	end
	if vim.api.nvim_get_current_buf() ~= ctx.bufnr then
		return false
	end
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	row = row - 1
	if row ~= ctx.row or col ~= ctx.col then
		return false
	end
	local line = vim.api.nvim_get_current_line()
	if line:sub(1, col) ~= ctx.prefix then
		return false
	end
	return true
end

local function schedule_show()
	if not enabled then
		clear()
		return
	end
	if timer then
		timer:stop()
	end
	if not timer then
		timer = uv.new_timer()
	end

	clear()

	timer:start(M.config.debounce_ms, 0, function()
		vim.schedule(function()
			if not should_show() then
				clear()
				return
			end

			local ctx = get_context()
			request_id = request_id + 1
			local my_id = request_id

			request_ollama(ctx, function(text, err)
				if my_id ~= request_id then
					return
				end
				if not text then
					log_line("RES empty: " .. tostring(err))
					clear()
					return
				end
				if not context_still_valid(ctx) then
					clear()
					return
				end
				log_line("RES chars=" .. tostring(#text))
				show_at_pos(ctx.bufnr, ctx.row, ctx.col, text)
			end)
		end)
	end)
end

feed_key = function(key)
	local term = vim.api.nvim_replace_termcodes(key, true, false, true)
	vim.api.nvim_feedkeys(term, "n", false)
end

function M.open_debug()
	local b = ensure_log_buf()
	vim.cmd("botright split")
	vim.api.nvim_win_set_buf(0, b)
	vim.cmd("normal! G")
end

function M.setup(opts)
	opts = opts or {}

	if opts.ollama_host ~= nil then
		M.config.host = opts.ollama_host
	end
	if opts.ollama_container ~= nil then
		M.config.container = opts.ollama_container
	end
	if opts.model ~= nil then
		M.config.model = opts.model
	end
	if opts.default_model ~= nil then
		M.config.model = opts.default_model
	end
	if opts.debounce_ms ~= nil then
		M.config.debounce_ms = opts.debounce_ms
	end
	if opts.max_ctx_lines ~= nil then
		M.config.max_ctx_lines = opts.max_ctx_lines
	end
	if opts.max_tokens ~= nil then
		M.config.max_tokens = opts.max_tokens
	end
	if opts.temperature ~= nil then
		M.config.temperature = opts.temperature
	end
	if opts.accept_key ~= nil then
		M.config.accept_key = opts.accept_key
	end
	if opts.debug ~= nil then
		M.config.debug = opts.debug
	end
	if opts.debug_notify ~= nil then
		M.config.debug_notify = opts.debug_notify
	end
	if opts.debug_log_buffer ~= nil then
		M.config.debug_log_buffer = opts.debug_log_buffer
	end
	if opts.max_log_lines ~= nil then
		M.config.max_log_lines = opts.max_log_lines
	end

	local aug = vim.api.nvim_create_augroup("LlmInline", { clear = true })

	vim.api.nvim_create_autocmd({ "InsertEnter", "TextChangedI", "CursorMovedI" }, {
		group = aug,
		callback = function()
			schedule_show()
		end,
	})

	vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave" }, {
		group = aug,
		callback = function()
			vim.schedule(clear)
		end,
	})

	if M.config.accept_key and M.config.accept_key ~= "" then
		apply_accept_mapping()
	end

	vim.api.nvim_create_user_command("LlmInlineDebug", function()
		M.open_debug()
	end, {})

	local _, provider = get_chat_model()
	if provider then
		M.set_provider(provider)
	end
end

return M
