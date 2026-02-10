return {
    "tpope/vim-rhubarb",
    dependencies = {
        "tpope/vim-fugitive",
    },
    config = function()
        vim.keymap.set({ "n", "v" }, "gb", ":GBrowse!<CR>")
    end
}
