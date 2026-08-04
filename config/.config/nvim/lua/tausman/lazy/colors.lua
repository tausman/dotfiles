-- Transparency + statusline tweaks, keyed off whatever colorscheme is currently active.
-- Idempotent, so it can safely be re-applied as often as needed.
local function apply_theme_overrides()
    -- Inactive statusline needs an explicit colour to stay legible, and it has to differ per
    -- theme: the light gray/black pair below is unreadable on the dark background.
    if vim.g.colors_name == "github_light_high_contrast" then
        vim.api.nvim_set_hl(0, "StatusLineNC", { fg = "black", bg = "gray" })
        -- vim.api.nvim_set_hl(0, "StatusLineNC", { fg = "#03060b", bg = "#5082b6" })
    elseif vim.g.colors_name == "github_dark_high_contrast" then
        vim.api.nvim_set_hl(0, "StatusLineNC", { fg = "#d9dee3", bg = "#30363d" })
    end
    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
end

-- Re-assert the overrides whenever ANY colorscheme is applied, not just via ColorMyPencils.
-- Setting highlights doesn't itself fire ColorScheme, so this can't loop.
vim.api.nvim_create_autocmd("ColorScheme", { callback = apply_theme_overrides })

function ColorMyPencils(color)
    color = color or "rose-pine"
    vim.cmd.colorscheme(color)
    apply_theme_overrides()
    -- ...and again on the next tick. A colorscheme plugin can finish applying its own
    -- highlights after this function returns, which restores an opaque background -- that's
    -- the "switches correctly for a moment, then goes wrong" symptom when toggling at
    -- runtime. A fresh nvim never showed it because nothing raced the startup apply.
    vim.schedule(apply_theme_overrides)
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
        return { "rose-pine", "gruvbox", "tokyonight", "github_light_high_contrast", "github_dark_high_contrast",
            "kanagawa", "alabaster", "brightburn" }
    end
})

-- Manual light/dark switch: <leader>bg. Nothing is detected automatically -- nvim always
-- starts in the light scheme below, and only this keymap changes it. (Auto-detecting the
-- macOS appearance would be wrong over SSH: on a remote workspace nvim can't see the
-- appearance of the terminal you're actually looking at.)
--
-- On macOS it also flips the system appearance, which is what Ghostty follows via
-- `theme = light:...,dark:...`, so one keystroke switches the terminal and nvim together.
-- Elsewhere (the remote Linux workspaces) it just swaps nvim's own colorscheme.
local LIGHT_SCHEME = "github_light_high_contrast"
local DARK_SCHEME = "github_dark_high_contrast"
-- Cursor colours matching each theme's foreground. These have to be pushed to tmux, which
-- owns the cursor colour inside a pane (the terminal's own cursor-color never gets used
-- there) -- see the cursor-colour note in tmux/.tmux.conf.
local LIGHT_CURSOR = "#000000"
local DARK_CURSOR = "#f0f3f6"

local is_mac = vim.fn.has("mac") == 1
local dark_mode = false

local function macos_is_dark()
    -- The key is absent entirely in light mode, so a non-zero exit means light.
    local out = vim.fn.system({ "defaults", "read", "-g", "AppleInterfaceStyle" })
    return vim.v.shell_error == 0 and out:match("Dark") ~= nil
end

-- Applied once at startup (see the github-theme spec below) so a fresh nvim doesn't come up
-- light on a dark terminal. Reading the appearance is macOS-only and deliberately not done
-- over SSH: on a remote workspace nvim can't see the appearance of the terminal you're
-- actually looking at, so those hosts just start light and use <leader>bg.
function ApplyThemeMode()
    if is_mac then
        dark_mode = macos_is_dark()
    end
    ColorMyPencils(dark_mode and DARK_SCHEME or LIGHT_SCHEME)
end

-- Nvim detects the terminal's background colour and sets 'background' itself. Changing the
-- macOS appearance changes Ghostty's background, so that detection fires a second or two
-- AFTER <leader>bg has applied our scheme -- and setting 'background' clears colors_name and
-- resets every highlight to nvim's built-in default (the grey that used to appear, since
-- nothing re-applied a scheme afterwards). Re-assert our choice whenever that happens.
-- Guarded on colors_name being nil so our own colorscheme calls -- which also set
-- 'background' -- can't recurse.
vim.api.nvim_create_autocmd("OptionSet", {
    pattern = "background",
    callback = function()
        if vim.g.colors_name ~= nil then
            return
        end
        vim.schedule(function()
            if vim.g.colors_name == nil then
                ColorMyPencils(dark_mode and DARK_SCHEME or LIGHT_SCHEME)
            end
        end)
    end,
})

vim.keymap.set("n", "<leader>bg", function()
    if is_mac then
        -- Read the real appearance at press time so the flip is always relative to what
        -- the system is actually showing (no drift if it was changed elsewhere).
        dark_mode = not macos_is_dark()
        vim.fn.system({ "osascript", "-e",
            'tell application "System Events" to tell appearance preferences to set dark mode to '
            .. tostring(dark_mode) })
    else
        dark_mode = not dark_mode
    end
    ColorMyPencils(dark_mode and DARK_SCHEME or LIGHT_SCHEME)
    if vim.env.TMUX then
        vim.fn.system({ "tmux", "set", "-g", "cursor-colour",
            dark_mode and DARK_CURSOR or LIGHT_CURSOR })
    end
end, { desc = "Toggle light/dark theme" })

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
        -- This is the ACTIVE colorscheme, so load it eagerly and first: without this a
        -- fast/fresh nvim (jj/git commit editor, quick file open) can draw before the
        -- theme applies and show the built-in dark scheme's opaque bg — see the transparent
        -- Normal in ColorMyPencils. lazy=false + priority=1000 is lazy.nvim's standard
        -- pattern for the active theme.
        -- lazy = false,
        -- priority = 1000,
        config = function()
            require('github-theme').setup({
                disable_background = true,
                styles = {
                    italic = false,
                },
            })
            -- Picks github_light/dark_high_contrast to match the current mode.
            ApplyThemeMode()
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
