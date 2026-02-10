return {
    "nvim-telescope/telescope.nvim",
    dependencies = {
        "telescope-file-browser",
        "plenary",
        "fzf"
    },
    config = function()
        local fb_actions = require "telescope".extensions.file_browser.actions
        local trouble_telescope = require("trouble.sources.telescope")
        local ivy = require('telescope.themes').get_ivy()
        require('telescope').setup {
            defaults = {
                theme = "center",
                sorting_strategy = "ascending",
                -- layout_strategy = "bottom_pane",
                layout_config = {
                    horizontal = {
                        prompt_position = "top",
                        -- preview_width = 0.3,
                    },
                },
                mappings = {
                    i = {
                        ["<C-c>"] = false,
                        ["<C-q>"] = function(prompt_bufnr)
                            require("telescope.actions").smart_send_to_qflist(prompt_bufnr)
                            require("telescope.actions").open_qflist(prompt_bufnr)
                        end,
                        ["<C-w>-"] = function(prompt_bufnr)
                            require("telescope.actions").select_horizontal(prompt_bufnr)
                            vim.cmd("wincmd J")
                        end,
                        ["<C-w>\\"] = function(prompt_bufnr)
                            require("telescope.actions").select_vertical(prompt_bufnr)
                            vim.cmd("wincmd L")
                        end,
                        ["<C-w>t"] = require("telescope.actions").select_tab,
                        ["<C-t>"] = trouble_telescope.open,
                    },
                    n = {
                        ["<C-c>"] = function()
                            vim.api.nvim_win_close(0, true)
                        end,
                        ["<C-q>"] = function(prompt_bufnr)
                            require("telescope.actions").smart_send_to_qflist(prompt_bufnr)
                            require("telescope.actions").open_qflist(prompt_bufnr)
                        end,
                        ["<C-w>-"] = function(prompt_bufnr)
                            require("telescope.actions").select_horizontal(prompt_bufnr)
                            vim.cmd("wincmd J")
                        end,
                        ["<C-w>\\"] = function(prompt_bufnr)
                            require("telescope.actions").select_vertical(prompt_bufnr)
                            vim.cmd("wincmd L")
                        end,
                        ["<C-w>t"] = require("telescope.actions").select_tab,
                        ["<C-t>"] = trouble_telescope.open,
                    },
                },
            },
            extensions = {
                file_browser = {
                    cwd_to_path = true,
                    grouped = true,
                    respect_gitignore = false,
                    hidden = { file_browser = true, folder_browser = true },
                    -- theme = "ivy",
                    hijack_netrw = true,
                    mappings = {
                        ["i"] = {
                            ["<bs>"] = false,
                            ["<C-c>"] = false,
                            ["<C-q>"] = function(prompt_bufnr)
                                require("telescope.actions").smart_send_to_qflist(prompt_bufnr)
                                require("telescope.actions").open_qflist(prompt_bufnr)
                            end,
                            ["<C-w>-"] = function(prompt_bufnr)
                                require("telescope.actions").select_horizontal(prompt_bufnr)
                                vim.cmd("wincmd J")
                            end,
                            ["<C-w>\\"] = function(prompt_bufnr)
                                require("telescope.actions").select_vertical(prompt_bufnr)
                                vim.cmd("wincmd L")
                            end,
                            ["<C-w>t"] = require("telescope.actions").select_tab,
                            ["<C-t>"] = function(prompt_bufnr)
                                local current_picker = require("telescope.actions.state").get_current_picker(
                                    prompt_bufnr)
                                local finder = current_picker.finder
                                local current_dir = finder.path
                                vim.cmd("cd " .. current_dir)
                                vim.print("Changed CWD: " .. current_dir)
                                fb_actions.goto_cwd(prompt_bufnr)
                            end,
                            ["<C-g>"] = function(prompt_bufnr)
                                fb_actions.goto_parent_dir(prompt_bufnr, true)
                            end,
                        },
                        ["n"] = {
                            ["<C-c>"] = function()
                                vim.api.nvim_win_close(0, true)
                            end,
                            ["<C-q>"] = function(prompt_bufnr)
                                require("telescope.actions").smart_send_to_qflist(prompt_bufnr)
                                require("telescope.actions").open_qflist(prompt_bufnr)
                            end,
                            ["<C-w>-"] = function(prompt_bufnr)
                                require("telescope.actions").select_horizontal(prompt_bufnr)
                                vim.cmd("wincmd J")
                                require("telescope.actions").select_vertical(prompt_bufnr)
                                vim.cmd("wincmd L")
                            end,
                            ["<C-w>-t"] = require("telescope.actions").select_tab,
                            ["t"] = function(prompt_bufnr)
                                local current_picker = require("telescope.actions.state").get_current_picker(
                                    prompt_bufnr)
                                local finder = current_picker.finder
                                local current_dir = finder.path
                                vim.cmd("cd " .. current_dir)
                                vim.print("Changed CWD: " .. current_dir)
                                fb_actions.goto_cwd(prompt_bufnr)
                            end,
                            ["<C-g>"] = function(prompt_bufnr)
                                fb_actions.goto_parent_dir(prompt_bufnr, true)
                            end,
                        }
                    }
                },
            },
        }
        require('telescope').load_extension('file_browser')
        require('telescope').load_extension('fzf')
        local builtin = require('telescope.builtin')
        vim.keymap.set('n', '<leader>pf', function()
            builtin.find_files({ hidden = true })
        end)
        -- vim.keymap.set('n', '<leader>pf', function()
        --     builtin.find_files(ivy)
        -- end, {})
        vim.keymap.set('n', '<leader>pg', function()
            builtin.git_files({ show_untracked = true })
        end)
        vim.keymap.set('n', '<leader>ps', builtin.live_grep, {})
        vim.keymap.set('n', '<leader>pb', builtin.buffers, {})
        vim.keymap.set('n', '<leader>pm', builtin.marks, {})
        vim.keymap.set('n', '<leader>pr', builtin.lsp_references, {})
        -- vim.keymap.set('n', '<leader>ps', function()
        -- 	builtin.grep_string({ search = vim.fn.input("Grep > ") })
        -- end)
        vim.keymap.set('n', '<leader>vh', builtin.help_tags, {})
        vim.keymap.set('n', '<C-LeftMouse>', builtin.lsp_references, {})
        vim.keymap.set('n', '<2-LeftMouse>', builtin.lsp_definitions, {})

        -- Telescope file browser shortcuts
        -- vim.keymap.set("n", "<leader>pv", builtin.file_browser, { path = "%:p:h", select_buffer = true })
        -- vim.keymap.set("n", "<leader>ph", builtin.file_browser, {})
        vim.keymap.set('n', '<leader>pv', ":Telescope file_browser path=%:p:h select_buffer=true<CR>")
        vim.keymap.set("n", "<leader>ph", ":Telescope file_browser<CR>")

        -- Telescope misc shortcuts
        vim.keymap.set('n', "<leader>fs", builtin.current_buffer_fuzzy_find, {})
        vim.keymap.set("n", "<leader>pq", builtin.quickfix, {})
        vim.keymap.set("n", "<leader>pd", builtin.diagnostics, {})
        vim.keymap.set("n", "<leader>pt", ":Telescope<CR>")
    end
}
