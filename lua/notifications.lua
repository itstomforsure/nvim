local vim = vim
local M = {}
local unpack = table.unpack or unpack

local ns = vim.api.nvim_create_namespace("notifications_bridge")
local attached = false
local forwarding = false

local kind_to_level = {
	emsg = vim.log.levels.ERROR,
	echoerr = vim.log.levels.ERROR,
	lua_error = vim.log.levels.ERROR,
	rpc_error = vim.log.levels.ERROR,
	shell_err = vim.log.levels.ERROR,
	wmsg = vim.log.levels.WARN,
	shell_ret = vim.log.levels.WARN,
}

local always_forward = {
	emsg = true,
	echoerr = true,
	lua_error = true,
	rpc_error = true,
	shell_err = true,
	shell_ret = true,
	wmsg = true,
}

local skip_kind = {
	empty = true,
	search_cmd = true,
	search_count = true,
	bufwrite = true,
}

local function content_to_text(content)
	if type(content) ~= "table" then
		return ""
	end

	local chunks = {}
	for _, chunk in ipairs(content) do
		chunks[#chunks + 1] = chunk[2] or ""
	end

	local msg = table.concat(chunks)
	msg = msg:gsub("^%s+", "")
	msg = msg:gsub("%s+$", "")
	return msg
end

local function title_for_kind(kind)
	if not kind or kind == "" then
		return "Vim"
	end
	return "Vim " .. kind
end

local function forward_msg(kind, content, replace_last, history, append, id)
	if forwarding then
		return
	end
	if skip_kind[kind] then
		return
	end
	if not history and not always_forward[kind] then
		return
	end

	local msg = content_to_text(content)
	if msg == "" then
		return
	end

	local notify_id = nil
	if id ~= nil then
		notify_id = "vim_msg:" .. tostring(id)
	elseif replace_last or append then
		notify_id = "vim_msg:last"
	end

	local opts = {
		title = title_for_kind(kind),
		id = notify_id,
		history = true,
	}

	if kind == "progress" then
		opts.timeout = 1000
	end

	forwarding = true
	pcall(vim.notify, msg, kind_to_level[kind] or vim.log.levels.INFO, opts)
	forwarding = false
end

function M.init()
	if attached then
		return
	end
	attached = true

	local ok = pcall(vim.ui_attach, ns, { ext_messages = true, set_cmdheight = false }, function(event, ...)
		if event ~= "msg_show" then return end

		local args = { ... }
		local cb = function() forward_msg(unpack(args)) end

		if vim.in_fast_event() then vim.schedule(cb) else cb() end
	end)
	if not ok then
		attached = false
	end
end

return M
