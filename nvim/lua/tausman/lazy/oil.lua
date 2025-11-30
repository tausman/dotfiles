return {
    'stevearc/oil.nvim',
    -- dev = true,
    lazy = false,
    config = function()
        require("oil").setup({
            default_file_explorer = false,
            keymaps = {
                ["<M-q>"] = { "actions.send_to_qflist" },
                ["<C-d>"] = { "actions.preview_scroll_down" },
                ["<C-u>"] = { "actions.preview_scroll_up" },
                ["<C-l>"] = false,
                ["<C-h>"] = false,
                ["<C-s>"] = false,
            },
            view_options = {
                show_hidden = true,
            }
        })
        vim.keymap.set('n', '<leader>po', function()
            -- require("oil").open_float(nil, { preview = {} })
            require("oil").open(nil, { preview = { vertical = true, split = "botright" } })
        end, {})
    end
}
