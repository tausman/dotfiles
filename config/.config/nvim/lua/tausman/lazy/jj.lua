return {
    "nicolasgb/jj.nvim",
    version = "*",
    dependencies = {
        "folke/snacks.nvim",
        {
            "esmuellert/codediff.nvim",
            dependencies = { "MunifTanjim/nui.nvim" },
        },
    },
    config = function()
        local jj = require("jj")
        jj.setup({
            diff = {
                backend = "codediff"
            },
        })

        -- Core commands
        local cmd = require("jj.cmd")
        vim.keymap.set("n", "<leader>gd", cmd.diff, { desc = "JJ describe" })
        vim.keymap.set("n", "<leader>jd", function()
            -- Get current and parent commit hashes
            local current_commit = vim.fn.system("jj log -r @ -T commit_id --no-graph"):gsub("%s+$", "")
            local parent_commit = vim.fn.system("jj log -r @- -T commit_id --no-graph"):gsub("%s+$", "")

            -- Call codediff with explicit revisions
            cmd.diff({ from = parent_commit, to = current_commit })
        end, { desc = "JJ diff @ vs @-" })
        vim.keymap.set("n", "<leader>jD", cmd.describe, { desc = "JJ describe" })
        vim.keymap.set("n", "<leader>jl", cmd.log, { desc = "JJ log" })
        vim.keymap.set("n", "<leader>je", cmd.edit, { desc = "JJ edit" })
        vim.keymap.set("n", "<leader>jn", cmd.new, { desc = "JJ new" })
        vim.keymap.set("n", "<leader>js", cmd.status, { desc = "JJ status" })
        vim.keymap.set("n", "<leader>sj", cmd.squash, { desc = "JJ squash" })
        vim.keymap.set("n", "<leader>ju", cmd.undo, { desc = "JJ undo" })
        vim.keymap.set("n", "<leader>jy", cmd.redo, { desc = "JJ redo" })
        vim.keymap.set("n", "<leader>jr", cmd.rebase, { desc = "JJ rebase" })
        vim.keymap.set("n", "<leader>jbc", cmd.bookmark_create, { desc = "JJ bookmark create" })
        vim.keymap.set("n", "<leader>jbd", cmd.bookmark_delete, { desc = "JJ bookmark delete" })
        vim.keymap.set("n", "<leader>jbm", cmd.bookmark_move, { desc = "JJ bookmark move" })
        vim.keymap.set("n", "<leader>jbs", cmd.bookmark_set, { desc = "JJ bookmark set" })
        vim.keymap.set("n", "<leader>ja", cmd.abandon, { desc = "JJ abandon" })
        vim.keymap.set("n", "<leader>jf", cmd.fetch, { desc = "JJ fetch" })
        vim.keymap.set("n", "<leader>jp", cmd.push, { desc = "JJ push" })

        -- Diff commands
        local diff = require("jj.diff")
        vim.keymap.set("n", "<leader>df", function() diff.open_vdiff() end, { desc = "JJ diff current buffer" })
        vim.keymap.set("n", "<leader>dF", function() diff.open_hsplit() end, { desc = "JJ hdiff current buffer" })

        -- Pickers
        local picker = require("jj.picker")
        vim.keymap.set("n", "<leader>gj", function() picker.status() end, { desc = "JJ Picker status" })
        vim.keymap.set("n", "<leader>jgh", function() picker.file_history() end, { desc = "JJ Picker history" })

        -- Some functions like `log` can take parameters
        vim.keymap.set("n", "<leader>jL", function()
            cmd.log {
                revisions = "'all()'", -- equivalent to jj log -r ::
            }
        end, { desc = "JJ log all" })

        -- Open file from codediff buffer
        vim.keymap.set("n", "<leader>gf", function()
            local bufname = vim.api.nvim_buf_get_name(0)

            if bufname:match("^codediff:///") then
                -- Format: codediff:////repo_root///commit_hash/relative_path
                local repo_root, relative_path = bufname:match("^codediff:///(/[^/]+/.-)///[^/]+/(.+)$")
                if repo_root and relative_path then
                    local file_path = repo_root .. "/" .. relative_path
                    local line_num = vim.api.nvim_win_get_cursor(0)[1]

                    -- If in a separate tab, close it and return to previous tab
                    if vim.fn.tabpagenr('$') > 1 then
                        vim.cmd("tabclose")
                        vim.cmd("edit +" .. line_num .. " " .. vim.fn.fnameescape(file_path))
                    else
                        -- Otherwise, close splits and open file
                        vim.cmd("only")
                        vim.cmd("edit +" .. line_num .. " " .. vim.fn.fnameescape(file_path))
                    end
                else
                    vim.notify("Could not parse codediff buffer name", vim.log.levels.ERROR)
                end
            else
                vim.notify("Not in a codediff buffer", vim.log.levels.WARN)
            end
        end, { desc = "JJ open file from codediff" })

        -- Open file from codediff buffer in new tab
        vim.keymap.set("n", "<leader>gF", function()
            local bufname = vim.api.nvim_buf_get_name(0)

            if bufname:match("^codediff:///") then
                -- Format: codediff:////repo_root///commit_hash/relative_path
                local repo_root, relative_path = bufname:match("^codediff:///(/[^/]+/.-)///[^/]+/(.+)$")
                if repo_root and relative_path then
                    local file_path = repo_root .. "/" .. relative_path
                    local line_num = vim.api.nvim_win_get_cursor(0)[1]

                    vim.cmd("tabnew +" .. line_num .. " " .. vim.fn.fnameescape(file_path))
                else
                    vim.notify("Could not parse codediff buffer name", vim.log.levels.ERROR)
                end
            else
                vim.notify("Not in a codediff buffer", vim.log.levels.WARN)
            end
        end, { desc = "JJ open file from codediff in new tab" })
    end,
}
