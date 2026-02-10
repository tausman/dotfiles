return {
    {
        "nvim-lua/plenary.nvim",
        name = "plenary"
    },
    {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release',
        name = "fzf"
    },
    {
        "nvim-telescope/telescope-file-browser.nvim",
        name = "telescope-file-browser"
    },
    {
        "folke/lazydev.nvim",
        ft = "lua", -- only load on lua files
        opts = {
            library = {
                -- See the configuration section for more details
                -- Load luvit types when the `vim.uv` word is found
                { path = "${3rd}/luv/library", words = { "vim%.uv" } },
            },
        },
    },
    "eandrju/cellular-automaton.nvim",
    "christoomey/vim-tmux-navigator",
    "airblade/vim-gitgutter",
}
