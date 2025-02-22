return {
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
}
