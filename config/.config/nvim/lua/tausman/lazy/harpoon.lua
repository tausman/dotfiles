return {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim",
    },
    config = function()
        local harpoon = require("harpoon")
        harpoon:setup({
            settings = {
                save_on_toggle = true,
                sync_on_ui_close = true,
            },
            default = {
                -- SET THIS TO TRUE IF YOU DONT WANT TO PERSIST FILE LIST
                -- encode = false,
            }
        })

        -- BASIC SETUP
        vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end)
        vim.keymap.set("n", "<leader>h", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end)
        vim.keymap.set("n", "<C-c>", function() harpoon.ui:close_menu(harpoon:list()) end)

        -- Toggle previous & next buffers stored within Harpoon list
        -- Check to make sure that the buffer is "normal" -- not a prompt
        vim.keymap.set("n", "<C-p>", function()
            if vim.bo.buftype == "" then harpoon:list():prev() end
        end)
        vim.keymap.set("n", "<C-n>", function()
            if vim.bo.buftype == "" then harpoon:list():next() end
        end)

        vim.keymap.set("n", "<leader>1", function() harpoon:list():select(1) end)
        vim.keymap.set("n", "<leader>2", function() harpoon:list():select(2) end)
        vim.keymap.set("n", "<leader>3", function() harpoon:list():select(3) end)
        vim.keymap.set("n", "<leader>4", function() harpoon:list():select(4) end)
        vim.keymap.set("n", "<leader>5", function() harpoon:list():select(5) end)

        -- EXTENSIONS
        local extensions = require("harpoon.extensions");
        harpoon:extend(extensions.builtins.highlight_current_file())
        harpoon:extend(extensions.builtins.navigate_with_number());

        -- BASIC TELESCOPE SETUP
        local conf = require("telescope.config").values
        local function toggle_telescope(harpoon_files)
            local file_paths = {}
            local current_file = vim.api.nvim_buf_get_name(0)
            local current_relative = vim.fn.fnamemodify(current_file, ":.")
            local default_selection_index = 1

            for i, item in ipairs(harpoon_files.items) do
                table.insert(file_paths, item.value)
                if item.value == current_file or item.value == current_relative then
                    default_selection_index = i
                end
            end

            require("telescope.pickers").new({}, {
                prompt_title = "Harpoon",
                finder = require("telescope.finders").new_table({
                    results = file_paths,
                }),
                previewer = conf.file_previewer({}),
                sorter = conf.generic_sorter({}),
                default_selection_index = default_selection_index,
                -- CHANGE THIS TO START IN INSERT MODE
                -- initial_mode = "normal",
            }):find()
        end

        vim.keymap.set("n", "<leader>H", function() toggle_telescope(harpoon:list()) end,
            { desc = "Open harpoon window" })
    end
}
