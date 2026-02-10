local augroup = vim.api.nvim_create_augroup
local session_group = augroup('Session', {})
local autocmd = vim.api.nvim_create_autocmd

vim.api.nvim_create_user_command('Session',
    function()
        -- local current_dir, home_dir, common_session_dir = vim.loop.cwd(), vim.loop.os_homedir(),
        --     vim.fs.joinpath(vim.fn.stdpath("cache"), "sessions")
        -- local project_session_dir, count = string.gsub(current_dir, home_dir, common_session_dir, 1)
        -- assert(count == 1)
        -- local session_file = vim.fs.joinpath(project_session_dir, "Session.vim")
        -- if vim.uv.fs_stat(session_file) == nil then
        --     vim.fn.mkdir(project_session_dir, "p")
        --     vim.cmd.edit(current_dir)
        -- end
        local session_file = vim.fs.joinpath(vim.loop.cwd(), "Session.vim")
        print(string.format("Using Session: %s", session_file))
        autocmd("VimLeavePre", {
            group = session_group,
            pattern = "*",
            command = string.format(":mksession! %s", session_file)
        })

        autocmd("VimEnter", {
            group = session_group,
            pattern = "*",
            once = true,
            -- Used nesting here so that syntax (colors) are set via other autocmd
            nested = true,
            command = string.format(":silent! source %s", session_file)
        })
    end,
    {})
