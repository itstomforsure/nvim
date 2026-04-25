# nvim

Personal Neovim config, structured as a small framework.

Requires Neovim 0.12+ (uses `vim.pack`, native `vim.lsp.config`, and the
experimental UI2 layer).

## Layout

```
init.lua            # options + entry point
lsp/                # LSP server configs, auto-discovered by Neovim
lua/
  framework.lua     # init pipeline
  plugins.lua       # plugin specs (vim.pack)
  lsp.lua           # diagnostics, on_attach, completion keymaps
  layout.lua        # zone-based window layout (explorer/editor/sidebar/terminal)
  keybindings.lua   # all keybinds, in one place
  symbols.lua       # icon table
  cmdline.lua       # custom ; cmdline picker
  search.lua        # custom / search picker
  sourcecontrol.lua # git panel
  terminal.lua      # tabbed terminal manager
  session.lua       # branch-scoped sessions
  editorgroup/      # split-group lifecycle + minimap glue
  utils.lua
```

## Boot order

`init.lua` sets options, then calls `framework.init()` which runs, in order:

1. UI2 (cmdline target, conservative)
2. autoread + checktime autocmds
3. save-toast autocmd (`BufWritePost` → `vim.notify`)
4. layout engine
5. plugins (`vim.pack.add` then per-spec config)
6. LSP (global on_attach, diagnostics, `vim.lsp.enable(...)`)
7. session manager
8. colorscheme

## Plugins

Managed by `vim.pack`, eager-loaded. Specs live in `lua/plugins.lua` as a flat
list; each entry pairs a `src` URL with a `config` callback that runs after the
plugin is on `runtimepath`.

```lua
{
  src = "https://github.com/foo/bar.nvim",
  version = vim.version.range("*"),  -- optional; latest tag
  config = function()
    require("bar").setup({ ... })
    keybinds.apply("bar")
  end,
},
```

`vim.pack` writes `nvim-pack-lock.json` automatically. Treesitter parsers are
re-synced via a `PackChanged` autocmd that runs `:TSUpdate` on install/update.

## LSP

Each server is a single file in `lsp/<name>.lua` returning a config table
(`cmd`, `filetypes`, `root_markers`, `settings`). Neovim auto-discovers them.
`lua/lsp.lua` sets up global capabilities, diagnostics, signs, completion-menu
keymaps, and a `LspAttach` autocmd that wires keybinds + the inlay-hint toggle.

To add a server: drop a new file in `lsp/`. Done.

## Keybindings

Everything lives in `lua/keybindings.lua` as a flat table per "feature":

```lua
M.bufferline = {
  binds = {
    next = { key = "<Tab>",   cmd = "<cmd>BufferLineCycleNext<cr>", desc = "..." },
    prev = { key = "<S-Tab>", cmd = "<cmd>BufferLineCyclePrev<cr>", desc = "..." },
  },
}
```

Plugins call `keybinds.apply("bufferline")` to bind them via `vim.keymap.set`.

## Notifications

`Snacks.notifier` owns `vim.notify`. Vim's built-in messages keep flowing
through the cmdline (now via UI2). The `BufWritePost` autocmd in
`framework.lua` is the only place that explicitly calls `vim.notify` for a
visible toast.
