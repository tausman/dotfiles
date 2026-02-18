require("tausman.set")
require("tausman.remap")
require("tausman.lazy_init")
require("tausman.custom_commands")
require("tausman.project_configs")

-- Set up some basic autocommands

local augroup = vim.api.nvim_create_augroup
local tausmangroup = augroup('tausmangroup', {})
local tausman_cursorline = augroup('tausmangroup', {})
local yank_group = augroup('HighlightYank', {})

local autocmd = vim.api.nvim_create_autocmd

autocmd({ "VimEnter", "WinEnter", "BufWinEnter" }, {
    group = tausman_cursorline,
    pattern = "*",
    callback = function()
        vim.opt_local.cursorline = true
    end,
})
autocmd({ "WinLeave" }, {
    group = tausman_cursorline,
    pattern = "*",
    callback = function()
        vim.opt_local.cursorline = false
    end,
})

autocmd('TextYankPost', {
    group = yank_group,
    pattern = '*',
    callback = function()
        vim.highlight.on_yank({
            higroup = 'IncSearch',
            timeout = 40,
        })
    end,
})

autocmd({ "BufWritePre" }, {
    group = tausmangroup,
    pattern = "*",
    command = [[%s/\s\+$//e]],
})

autocmd('LspAttach', {
    group = tausmangroup,
    callback = function(e)
        local opts = { buffer = e.buf }
        vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
        vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, opts)
        vim.keymap.set("n", "<leader>vws", function() vim.lsp.buf.workspace_symbol() end, opts)
        vim.keymap.set("n", "<leader>vd", function() vim.diagnostic.open_float() end, opts)
        vim.keymap.set("n", "<leader>vca", function() vim.lsp.buf.code_action() end, opts)
        vim.keymap.set("n", "<leader>vrr", function() vim.lsp.buf.references() end, opts)
        vim.keymap.set("n", "<leader>vrn", function() vim.lsp.buf.rename() end, opts)
        vim.keymap.set("i", "<C-h>", function() vim.lsp.buf.signature_help() end, opts)
        vim.keymap.set("n", "[d", function() vim.diagnostic.goto_next() end, opts)
        vim.keymap.set("n", "]d", function() vim.diagnostic.goto_prev() end, opts)

        local client = vim.lsp.get_client_by_id(e.data.client_id)
        -- Set up formatting
        if client.supports_method("textDocument/formatting") then
            vim.api.nvim_create_autocmd("BufWritePre", {
                buffer = e.buf,
                callback = function()
                    vim.lsp.buf.format({ bufnr = e.buf, id = client.id })
                end,
            })
        end

        -- Set up symbol highlighting
        if client.supports_method("textDocument/documentHighlight") then
            vim.api.nvim_create_autocmd("CursorHold", {
                buffer = 0,
                callback = function()
                    vim.lsp.buf.document_highlight()
                end,
            })
            vim.api.nvim_create_autocmd("CursorHoldI", {
                buffer = 0,
                callback = function()
                    vim.lsp.buf.document_highlight()
                end,
            })
            vim.api.nvim_create_autocmd("CursorMoved", {
                buffer = 0,
                callback = function()
                    vim.lsp.buf.clear_references()
                end,
            })
        end
    end,
})

vim.g.netrw_preview = 1
-- vim.g.netrw_liststyle = 3
-- vim.g.netrw_browse_split = 3
vim.g.netrw_banner = 0
vim.g.netrw_winsize = 25

-- Keey netrw in jumplist properly
vim.g.netrw_fastbrowse = 2
vim.g.netrw_keepj = ""
