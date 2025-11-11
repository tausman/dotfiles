return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-cmdline",
        "hrsh7th/nvim-cmp",
        "L3MON4D3/LuaSnip",
        "saadparwaiz1/cmp_luasnip",
        "j-hui/fidget.nvim",
    },
    config = function()
        local cmp = require('cmp')
        local cmp_lsp = require("cmp_nvim_lsp")
        require("luasnip.loaders.from_vscode").lazy_load()
        local capabilities = vim.tbl_deep_extend(
            "force",
            {},
            vim.lsp.protocol.make_client_capabilities(),
            cmp_lsp.default_capabilities())

        require("fidget").setup({})
        require("mason").setup()
        require("mason-lspconfig").setup({
            ensure_installed = {
                "lua_ls",
                "rust_analyzer",
                -- "ts_ls",
                "gopls",
                "zls",
                "yamlls",
                -- "tailwindcss",
                -- "eslint",
                "clangd",
                "vimls",
                "pyright",
            },
        })
        vim.lsp.config("lua_ls", {
            capabilities = capabilities,
            settings = {
                Lua = {
                    runtime = { version = "Lua 5.1" },
                    diagnostics = {
                        globals = { "bit", "vim", "it", "describe", "before_each", "after_each" },
                    }
                }
            }
        })
        -- MANUALLY TRYING TO SET THESE UP -- NO MASON
        -- vim.lsp.config("eslint", {
        --     settings = {
        --         nodePath = ".yarn/sdks",
        --         packageManager = "yarn",
        --         rulesCustomizations = {
        --             -- Suppress noise from autofixable rules
        --             -- { rule = "prettier/prettier", severity = "off" },
        --             -- { rule = "arca/import-ordering", severity = "off" },
        --             -- { rule = "arca/newline-after-import-section", severity = "off" },
        --             -- { rule = "@typescript-eslint/consistent-type-imports", severity = "off" },
        --             -- { rule = "quotes", severity = "off" },
        --             -- { rule = "import/no-duplicates", severity = "off" },
        --             -- { rule = "unused-imports/no-unused-imports", severity = "off" },
        --         },
        --     },
        -- })

        -- THIS CONFIGURATION WORKS BUT IT IS NOT AS GOOD AS VTSLS -- PREFER THE .NVIM.LUA FILE IN WEB-UI
        -- vim.lsp.config("ts_ls", {
        --     -- capabilities = capabilities,
        --     cmd = { "yarn", "exec", "typescript-language-server", "--stdio" },
        --     -- This does some smart dependency resolution using tsconfig files so that
        --     -- you don't have to load the entire repo at once.
        --     root_dir = function(bufnr, cb)
        --         local util = require("lspconfig.util")
        --         local fname = vim.api.nvim_buf_get_name(bufnr)
        --         -- Look for tsconfig.json in current dir, then parent dirs
        --         -- This prevents loading the entire monorepo
        --         local root = util.root_pattern("tsconfig.json", "package.json")(fname)

        --         -- Debug: print what root we found
        --         -- if root then
        --         --     vim.notify("ts_ls root_dir found: " .. root, vim.log.levels.INFO)
        --         -- else
        --         --     vim.notify("ts_ls root_dir: NO ROOT FOUND FOR " .. fname, vim.log.levels.WARN)
        --         -- end

        --         cb(root)
        --     end,
        --     single_file_support = false,
        --     init_options = {
        --         hostInfo = "neovim",
        --         maxTsServerMemory = 32768,
        --         preferences = {
        --             importModuleSpecifier = "non-relative",
        --             autoImportSpecifierExcludeRegexes = { "^packages" },
        --         },
        --         tsserver = {
        --             path = "/Users/tausif.rahman/go/src/github.com/DataDog/web-ui/.yarn/sdks/typescript/bin/tsserver",
        --             watchOptions = {
        --                 excludeDirectories = { "**/node_modules", "**/.yarn", "**/.sarif" },
        --                 excludeFiles = { ".pnp.cjs" },
        --             },
        --             logDirectory = "/tmp/tsserver-logs",
        --             logVerbosity = "normal",
        --         },
        --     },
        --     settings = {
        --         typescript = {
        --             tsdk = "/Users/tausif.rahman/go/src/github.com/DataDog/web-ui/.yarn/sdks/typescript/lib",
        --         },
        --         -- javascript = {
        --         --     tsdk = "/Users/tausif.rahman/go/src/github.com/DataDog/web-ui/.yarn/sdks/typescript/lib",
        --         -- },
        --     },
        -- })

        -- vim.lsp.enable({ "ts_ls", "eslint" })

        local cmp_select = { behavior = cmp.SelectBehavior.Select }

        cmp.setup({
            snippet = {
                expand = function(args)
                    require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
                end,
            },
            mapping = cmp.mapping.preset.insert({
                ['<C-p>'] = cmp.mapping.select_prev_item(cmp_select),
                ['<C-n>'] = cmp.mapping.select_next_item(cmp_select),
                ['<C-y>'] = cmp.mapping.confirm({ select = true }),
                ["<C-Space>"] = cmp.mapping.complete(),
            }),
            sources = cmp.config.sources({
                { name = 'nvim_lsp' },
                { name = 'luasnip' }, -- For luasnip users.
            }, {
                { name = 'buffer' },
            })
        })

        vim.diagnostic.config({
            update_in_insert = true,
            float = {
                focusable = false,
                style = "minimal",
                border = "rounded",
                source = "always",
                header = "",
                prefix = "",
            },
        })
    end
}
