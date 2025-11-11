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
    "eandrju/cellular-automaton.nvim",
    "christoomey/vim-tmux-navigator",
    "airblade/vim-gitgutter",
}
