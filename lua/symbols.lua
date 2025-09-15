local M = {}

M.os = {
	unix = " ", -- e712
	dos = " ", -- e70f
	mac = " ", -- e711
	linux = " ", -- f17c
	windows = " ", -- f17a
	apple = " ", -- f179
}

M.vcs = {
	git = " ", -- e702
	github = " ", -- f09b
	gitlab = " ", -- f296
	branch = " ", -- e0a0
	merge = " ", -- e727
	compare = " ", -- f45f
}

M.lang = {
	lua = " ", -- e720
	javascript = " ", -- e74e
	typescript = " ", -- e7b8
	python = " ", -- e73c
	go = " ", -- e7a7
	java = " ", -- e256
	rust = " ", -- e7a8
	c = " ", -- e61e
	cpp = " ", -- e61d
	cs = " ", -- f81a
	php = " ", -- e608
	ruby = " ", -- e791
	swift = " ", -- e755
	kotlin = " ", -- e7b4
	dart = " ", -- e798
	scala = " ", -- e737
	haskell = " ", -- e61f
	html = " ", -- e736
	css = " ", -- e749
	sass = " ", -- e603
	markdown = " ", -- e609
	json = " ", -- e60b
	yaml = " ", -- e615
	docker = " ", -- f308
}

M.ui = {
	vim = " ", -- e745
	neovim = " ", -- f36f
	terminal = " ", -- e795
	settings = " ", -- f013
	search = " ", -- f002
	error = " ", -- f057
	warn = " ", -- f071
	info = " ", -- f05a
	hint = " ", -- f0eb
}

M.misc = {
	lock = " ", -- f023
	unlock = " ", -- f09c
	folder = " ", -- f07b
	file = " ", -- f0f6
	rocket = " ", -- f135
	star = " ", -- f005
	fire = " ", -- f490
	check = " ", -- f058
}

M.dev = {
	lsp = " ", -- gear
	formatter = " ", -- scissors
	linter = " ", -- alert
	command = " ", -- command line
}

return M
