return {
    "folke/trouble.nvim",
    config = function()
        local trouble = require("trouble")
        trouble.setup({
            focus = true,
            win = {
                size = 0.4,
                position = "right",
            },
        })
        vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>")
        vim.keymap.set("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>")
        vim.keymap.set("n", "<leader>cs", "<cmd>Trouble symbols toggle focus=false<cr>")
        vim.keymap.set("n", "<leader>cl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>")
        vim.keymap.set("n", "<leader>xL", "<cmd>Trouble loclist toggle<cr>")
        vim.keymap.set("n", "<leader>xQ", "<cmd>Trouble qflist toggle<cr>")

        vim.keymap.set("n", "<leader>tt", function()
            require("trouble").focus();
        end)
        vim.keymap.set("n", "[t", function()
            require("trouble").next({ skip_groups = true, jump = true });
        end)

        vim.keymap.set("n", "]t", function()
            require("trouble").prev({ skip_groups = true, jump = true });
        end)
    end
}
