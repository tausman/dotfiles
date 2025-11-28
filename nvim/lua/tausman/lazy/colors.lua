function ColorMyPencils(color)
    color = color or "rose-pine"
    vim.cmd.colorscheme(color)

    if (color == "github_dark_high_contrast" or color == "github_light_high_contrast")
    then
        vim.api.nvim_set_hl(0, "StatusLineNC", { fg = "black", bg = "gray" })
        -- vim.api.nvim_set_hl(0, "StatusLineNC", { fg = "#03060b", bg = "#5082b6" })
    end
    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
end

-- Create user command to easily switch colorschemes
vim.api.nvim_create_user_command('ColorScheme', function(opts)
    local schemes = {
        "rose-pine",
        "gruvbox", 
        "tokyonight",
        "github_light_high_contrast",
        "github_dark_high_contrast",
        "kanagawa",
        "alabaster",
        "brightburn"
    }
    
    if opts.args == "" then
        print("Available colorschemes: " .. table.concat(schemes, ", "))
    else
        ColorMyPencils(opts.args)
    end
end, {
    nargs = '?',
    complete = function()
        return {"rose-pine", "gruvbox", "tokyonight", "github_light_high_contrast", "github_dark_high_contrast", "kanagawa", "alabaster", "brightburn"}
    end
})

return {
    {
        "p00f/alabaster.nvim",
    },
    {
        "erikbackman/brightburn.vim",
    },

    {
        "ellisonleao/gruvbox.nvim",
        name = "gruvbox",
        config = function()
            require("gruvbox").setup({
                terminal_colors = true, -- add neovim terminal colors
                undercurl = true,
                underline = false,
                bold = true,
                italic = {
                    strings = false,
                    emphasis = false,
                    comments = false,
                    operators = false,
                    folds = false,
                },
                strikethrough = true,
                invert_selection = false,
                invert_signs = false,
                invert_tabline = false,
                invert_intend_guides = false,
                inverse = true, -- invert background for search, diffs, statuslines and errors
                contrast = "",  -- can be "hard", "soft" or empty string
                palette_overrides = {},
                overrides = {},
                dim_inactive = false,
                transparent_mode = false,
            })
            -- ColorMyPencils('gruvbox')
        end,
    },
    {
        "folke/tokyonight.nvim",
        name = "tokyonight",
        config = function()
            require("tokyonight").setup({
                -- your configuration comes here
                -- or leave it empty to use the default settings
                style = "storm",        -- The theme comes in three styles, `storm`, `moon`, a darker variant `night` and `day`
                transparent = true,     -- Enable this to disable setting the background color
                terminal_colors = true, -- Configure the colors used when opening a `:terminal` in Neovim
                styles = {
                    -- Style to be applied to different syntax groups
                    -- Value is any valid attr-list value for `:help nvim_set_hl`
                    comments = { italic = false },
                    keywords = { italic = false },
                    -- Background styles. Can be "dark", "transparent" or "normal"
                    sidebars = "dark", -- style for sidebars, see below
                    floats = "dark",   -- style for floating windows
                },
            })
        end
    },

    {
        "rose-pine/neovim",
        name = "rose-pine",
        config = function()
            require('rose-pine').setup({
                disable_background = true,
                styles = {
                    italic = false,
                },
            })
            -- ColorMyPencils('rose-pine')
        end
    },
    {
        "projekt0n/github-nvim-theme",
        name = "github-theme",
        config = function()
            require('github-theme').setup({
                disable_background = true,
                styles = {
                    italic = false,
                },
            })
            ColorMyPencils('github_light_high_contrast')
            -- ColorMyPencils('github_dark_high_contrast')
        end
    },
    {
        "rebelot/kanagawa.nvim",
        name = "kanagawa",
        config = function()
            require('kanagawa').setup({
                transparent = true,
                dimInactive = true,
                background = {
                    light = "dragon",
                    dark = "dragon"
                },
                colors = {
                    theme = {
                        all = {
                            ui = {
                                bg_gutter = "none"
                            }
                        }
                    }
                }
            })
            -- ColorMyPencils('kanagawa')
        end
    }
}
