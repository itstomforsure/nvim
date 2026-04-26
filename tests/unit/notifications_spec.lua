local function load_notifications()
	package.loaded["notifications"] = nil
	return require("notifications")
end

describe("notifications", function()
	local orig_ui_attach
	local orig_notify
	local orig_schedule
	local orig_in_fast_event

	local attach_calls
	local attach_opts
	local ui_cb
	local attach_outcomes

	local notify_calls
	local scheduled
	local fast_event

	before_each(function()
		orig_ui_attach = vim.ui_attach
		orig_notify = vim.notify
		orig_schedule = vim.schedule
		orig_in_fast_event = vim.in_fast_event

		attach_calls = 0
		attach_opts = nil
		ui_cb = nil
		attach_outcomes = { true }

		notify_calls = {}
		scheduled = {}
		fast_event = false

		vim.ui_attach = function(_, opts, cb)
			attach_calls = attach_calls + 1
			attach_opts = opts
			ui_cb = cb

			local outcome = table.remove(attach_outcomes, 1)
			if outcome == nil then outcome = true end
			if not outcome then
				error("ui_attach failed")
			end
			return true
		end

		vim.notify = function(msg, level, opts)
			table.insert(notify_calls, { msg = msg, level = level, opts = opts })
			return #notify_calls
		end

		vim.schedule = function(fn)
			table.insert(scheduled, fn)
		end

		vim.in_fast_event = function()
			return fast_event
		end
	end)

	after_each(function()
		vim.ui_attach = orig_ui_attach
		vim.notify = orig_notify
		vim.schedule = orig_schedule
		vim.in_fast_event = orig_in_fast_event
		package.loaded["notifications"] = nil
	end)

	it("attaches an ext_messages callback exactly once on repeated init", function()
		local notifications = load_notifications()

		notifications.init()
		notifications.init()

		assert.equals(1, attach_calls)
		assert.same({ ext_messages = true, set_cmdheight = false }, attach_opts)
		assert.is_function(ui_cb)
	end)

	it("retries init when ui_attach errors", function()
		attach_outcomes = { false, true }
		local notifications = load_notifications()

		notifications.init()
		notifications.init()

		assert.equals(2, attach_calls)
	end)

	it("forwards history messages to vim.notify with title and id", function()
		local notifications = load_notifications()
		notifications.init()

		ui_cb("msg_show", "echo", {
			{ 0, " hello", 0 },
			{ 0, " world ", 0 },
		}, false, true, false, 42, "")

		assert.equals(1, #notify_calls)
		assert.equals("hello world", notify_calls[1].msg)
		assert.equals(vim.log.levels.INFO, notify_calls[1].level)
		assert.equals("Vim echo", notify_calls[1].opts.title)
		assert.equals("vim_msg:42", notify_calls[1].opts.id)
		assert.is_true(notify_calls[1].opts.history)
	end)

	it("skips bufwrite and non-history non-critical messages", function()
		local notifications = load_notifications()
		notifications.init()

		ui_cb("msg_show", "bufwrite", { { 0, "written", 0 } }, false, true, false, 1, "")
		ui_cb("msg_show", "echo", { { 0, "temporary", 0 } }, false, false, false, 2, "")

		assert.equals(0, #notify_calls)
	end)

	it("forwards emsg even when history=false and maps it to ERROR", function()
		local notifications = load_notifications()
		notifications.init()

		ui_cb("msg_show", "emsg", { { 0, "boom", 0 } }, false, false, false, 3, "")

		assert.equals(1, #notify_calls)
		assert.equals("boom", notify_calls[1].msg)
		assert.equals(vim.log.levels.ERROR, notify_calls[1].level)
		assert.equals("Vim emsg", notify_calls[1].opts.title)
	end)

	it("uses vim_msg:last when replace_last/append is set without an id", function()
		local notifications = load_notifications()
		notifications.init()

		ui_cb("msg_show", "echo", { { 0, "updated", 0 } }, true, true, false, nil, "")

		assert.equals(1, #notify_calls)
		assert.equals("vim_msg:last", notify_calls[1].opts.id)
	end)

	it("adds short timeout for progress notifications", function()
		local notifications = load_notifications()
		notifications.init()

		ui_cb("msg_show", "progress", { { 0, "working", 0 } }, false, true, false, 55, "")

		assert.equals(1, #notify_calls)
		assert.equals(1000, notify_calls[1].opts.timeout)
	end)

	it("schedules processing in fast-event context", function()
		local notifications = load_notifications()
		notifications.init()
		fast_event = true

		ui_cb("msg_show", "echo", { { 0, "async", 0 } }, false, true, false, 10, "")

		assert.equals(0, #notify_calls)
		assert.equals(1, #scheduled)

		scheduled[1]()
		assert.equals(1, #notify_calls)
		assert.equals("async", notify_calls[1].msg)
	end)

	it("prevents recursive forwarding loops", function()
		local notifications = load_notifications()
		notifications.init()

		local depth = 0
		vim.notify = function(msg, level, opts)
			table.insert(notify_calls, { msg = msg, level = level, opts = opts })
			if depth == 0 then
				depth = 1
				ui_cb("msg_show", "echo", { { 0, "inner", 0 } }, false, true, false, 99, "")
			end
			return #notify_calls
		end

		ui_cb("msg_show", "echo", { { 0, "outer", 0 } }, false, true, false, 98, "")
		assert.equals(1, #notify_calls)
		assert.equals("outer", notify_calls[1].msg)
	end)
end)
