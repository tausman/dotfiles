return {
    'stevearc/oil.nvim',
    lazy = false,
    config = function()
        require("oil").setup({
            default_file_explorer = false,
            keymaps = {
                ["<C-q>"] = { "actions.send_to_qflist" }
            }
        })
        vim.keymap.set('n', '<leader>po', "<CMD>Oil<CR>", {})
    end
}
