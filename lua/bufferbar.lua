local vim = vim
local M = {}
local config = { show_close = true }
local managed_wins = {}
local refreshing = false
local close_guard = false

local function is_regular(buf)
    return vim.api.nvim_buf_is_valid(buf)
        and vim.bo[buf].buflisted
        and vim.bo[buf].buftype == ""
end

local function should_show_in_win(win)
    if not vim.api.nvim_win_is_valid(win) then
        return false
    end

    local buf = vim.api.nvim_win_get_buf(win)
    return is_regular(buf)
end

local function buffers()
    local out = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if is_regular(buf) then
            table.insert(out, buf)
        end
    end
    table.sort(out)
    return out
end

local function pick_regular_replacement(current_win, current_buf)
    local ok, alternate = pcall(vim.api.nvim_win_call, current_win, function()
        return vim.fn.bufnr("#")
    end)
    if ok and type(alternate) == "number" and alternate > 0 and
        alternate ~= current_buf and is_regular(alternate) then
        return alternate
    end

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if bufnr ~= current_buf and vim.bo[bufnr].buflisted and is_regular(bufnr) then
            return bufnr
        end
    end

    return nil
end

local function label(buf)
    local name = vim.api.nvim_buf_get_name(buf)
    name = (name == "") and "[No Name]" or vim.fn.fnamemodify(name, ":t")
    if vim.bo[buf].modified then
        name = name .. " [+]"
    end
    return name:gsub("%%", "%%%%")
end

function M.render(current)
    local parts = {}

    for _, buf in ipairs(buffers()) do
        local hl = (buf == current) and "%#TabLineSel#" or "%#TabLine#"
        local click = string.format("%%%d@v:lua.SimpleBufferlineClick@", buf)
        table.insert(parts, hl .. click .. " " .. label(buf) .. " " .. "%X")

        if config.show_close then
            local close = string.format("%%%d@v:lua.SimpleBufferlineClose@", buf)
            table.insert(parts, hl .. close .. " x " .. "%X")
        end
    end

    table.insert(parts, "%#TabLineFill#%=")
    return table.concat(parts, "")
end

function M.click(minwid, _, button, _)
    if button ~= "l" then
        return
    end
    local buf = tonumber(minwid)
    if buf and is_regular(buf) then
        vim.api.nvim_set_current_buf(buf)
    end
end

function M.close(minwid, _, button, _)
    if button ~= "l" then
        return
    end

    if close_guard then
        return
    end
    close_guard = true
    vim.schedule(function()
        close_guard = false
    end)

    local buf = tonumber(minwid)
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    if vim.bo[buf].modified then
        vim.notify("Buffer has unsaved changes", vim.log.levels.WARN)
        return
    end

    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
            local replacement = pick_regular_replacement(win, buf)
            if replacement then
                pcall(vim.api.nvim_win_set_buf, win, replacement)
            else
                pcall(vim.api.nvim_win_call, win, function()
                    vim.cmd("enew")
                end)
            end
        end
    end

    pcall(vim.api.nvim_buf_delete, buf, { force = false })
    vim.schedule(function()
        M.refresh()
    end)
end

function M.refresh()
    if refreshing then
        return
    end

    refreshing = true

    for win, _ in pairs(managed_wins) do
        if not vim.api.nvim_win_is_valid(win) then
            managed_wins[win] = nil
        end
    end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if should_show_in_win(win) then
            local current = vim.api.nvim_win_get_buf(win)
            local content = M.render(current)
            vim.api.nvim_set_option_value("winbar", content, { win = win })
            managed_wins[win] = true
        elseif managed_wins[win] then
            vim.api.nvim_set_option_value("winbar", "", { win = win })
            managed_wins[win] = nil
        end
    end

    refreshing = false
end

function M.setup(opts)
    config = vim.tbl_extend("force", config, opts or {})

    _G.SimpleBufferlineRender = function()
        return M.render(vim.api.nvim_get_current_buf())
    end
    _G.SimpleBufferlineClick = function(...)
        M.click(...)
    end
    _G.SimpleBufferlineClose = function(...)
        M.close(...)
    end

    if vim.o.tabline:find("SimpleBufferlineRender", 1, true) then
        vim.o.tabline = ""
    end
    if vim.o.showtabline == 2 then
        vim.o.showtabline = 1
    end

    local group = vim.api.nvim_create_augroup("SimpleBufferline", { clear = true })
    vim.api.nvim_create_autocmd(
        { "BufAdd", "BufDelete", "BufWipeout", "BufEnter", "BufModifiedSet", "BufFilePost", "BufWinEnter", "WinEnter", "WinClosed", "VimResized", "TabEnter" },
        {
            group = group,
            callback = function()
                vim.schedule(function()
                    M.refresh()
                end)
            end,
        }
    )

    M.refresh()
end

return M
