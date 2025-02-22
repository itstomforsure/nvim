return {
    -- Copilot
    {
        "github/copilot.vim",
        lazy = true,
        cmd = "Copilot",
        keys = {
            -- { "<leader>cp", ":Copilot enable<CR>", desc = "Enable Copilot" },
            {
                "<leader>cp",
                function()
                local copilot_status = vim.fn["copilot#Enabled"]()
                if copilot_status == 1 then
                    vim.cmd("Copilot disable")
                    vim.cmd("edit")
                    print("Copilot Disabled")
                    else
                        vim.cmd("Copilot enable")
                        vim.cmd("edit")
                        print("Copilot Enabled")
                        end
                        end,
                        desc = "Toggle Copilot",
            },
        },
        config = function()
        vim.g.copilot_filetypes = {
            ["*"] = true,
            ["markdown"] = true,
            ["help"] = false,
        }

        vim.g.copilot_no_tab_map = false
        vim.keymap.set("i", "<M-[>", "<Plug>(copilot-next)")
        end,
    },

    -- Copilot chat
    {
        "CopilotC-Nvim/CopilotChat.nvim",
        branch = "main",
        dependencies = {
            { "nvim-lua/plenary.nvim", branch = "master" },
            "github/copilot.vim",
        },
        lazy = true,
        keys = {
            { "<leader>cp", ":CopilotChat<CR>", desc = "Enable Copilot chat" },
        },
        config = function()
        require("CopilotChat").setup({
            debug = false,

            window = {
                layout = "float",
                border = "single",
                size = {
                    width = "80%",
                    height = "60%",
                },
                win_options = {
                    wrap = true,
                    linebreak = true,
                    foldcolumn = "0",
                    winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
                },
            },
        })

        local function set_keymaps()
        vim.keymap.set("n", "<leader>cc", "<cmd>CopilotChat<cr>", { desc = "Open Copilot Chat" })
        vim.keymap.set({ "n", "v" }, "<leader>ce", "<cmd>CopilotChatExplain<cr>", { desc = "Explain code" })
        vim.keymap.set({ "n", "v" }, "<leader>cf", "<cmd>CopilotChatFix<cr>", { desc = "Fix code" })
        vim.keymap.set(
            { "n", "v" },
            "<leader>co",
            "<cmd>CopilotChatOptimize<cr>",
            { desc = "Optimize code" }
        )
        end

        set_keymaps()
        end,
    }
}
