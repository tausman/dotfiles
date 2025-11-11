return {
    "epwalsh/obsidian.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",

    },
    config = function()
        require("obsidian").setup {
            version = "*", -- recommended, use latest release instead of latest commit
            workspaces = {
                {
                    name = "work",
                    path = "~/vaults/work",
                },
            },
            notes_subdir = "notes",
            log_level = vim.log.levels.INFO,
            daily_notes = {
                folder = "dailies"
            },
            ui = {
                enable = false
            },
            templates = {
                folder = "~/vaults/templates",
                substitutions = {
                    extracted_title = function()
                        return vim.fn.expand('%:t:r'):sub(12):gsub("_", " ")
                    end
                }
            },
            note_id_func = function(title)
                local suffix = ""
                if title ~= nil then
                    -- If title is given, transform it into valid file name.
                    suffix = title:gsub(" ", "_"):gsub("[^A-Za-z0-9-_]", "")
                else
                    -- If title is nil, just add 4 random uppercase letters to the suffix.
                    for _ = 1, 4 do
                        suffix = suffix .. string.char(math.random(65, 90))
                    end
                end
                return tostring(os.time()) .. "-" .. suffix
            end,
        }
        vim.keymap.set('n', '<leader>od', ":ObsidianToday<CR>")
        vim.keymap.set('n', '<leader>ot', ":ObsidianTomorrow<CR>")
        vim.keymap.set('n', '<leader>os', ":ObsidianSearch<CR>")
        vim.keymap.set('n', '<leader>of', ":ObsidianQuickSwitch<CR>")
        -- Custom function bc some stuff was broken (https://github.com/epwalsh/obsidian.nvim/blob/ae1f76a75c7ce36866e1d9342a8f6f5b9c2caf9b/lua/obsidian/commands/new_from_template.lua#L5-L40)
        vim.keymap.set('n', '<leader>oo', function()
            local client = require('obsidian').get_client()
            local util = require("obsidian.util")
            local log = require("obsidian.log")
            if not client:templates_dir() then
                log.err "Templates folder is not defined or does not exist"
                return
            end

            local picker = client:picker()
            if not picker then
                log.err "No picker configured"
                return
            end

            picker:find_templates {
                callback = function(name)
                    local note
                    local title = util.input("Enter title or path (optional): ", { completion = "file" })
                    if not title then
                        log.warn "Aborted"
                        return
                    elseif title == "" then
                        title = nil
                    end
                    local vault_dir = vim.fn.fnamemodify(name, ":t:r"):match("^(%S+)")
                    note = client:create_note { title = title, dir = vault_dir, no_write = true }

                    -- Open the note in a new buffer.
                    client:open_note(note, { sync = true })

                    client:write_note_to_buffer(note, { template = name })
                end,
            }
        end)
    end
}
