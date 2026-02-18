-- Project-specific configurations that apply across all worktrees/workspaces

-- Helper to get the repository name
-- Works with both jj workspaces and root repos
local function get_repo_name()
    local cwd = vim.fn.getcwd()

    -- Check if we're in a jj workspace/repo
    local jj_repo_file = cwd .. "/.jj/repo"
    local jj_repo_dir = cwd .. "/.jj/repo"

    local repo_path = nil

    -- Determine if .jj/repo is a file (workspace) or directory (root repo)
    if vim.fn.filereadable(jj_repo_file) == 1 then
        -- It's a workspace - read the file to get the actual repo path
        local f = io.open(jj_repo_file, "r")
        if f then
            repo_path = f:read("*line")
            f:close()
        end
    elseif vim.fn.isdirectory(jj_repo_dir) == 1 then
        -- It's a root repo - use the path directly
        repo_path = ".jj/repo"
    end

    if repo_path then
        -- Read the git_target file to find where the git directory is
        local git_target_file = repo_path .. "/store/git_target"
        local f = io.open(git_target_file, "r")
        if f then
            local git_target = f:read("*line")
            f:close()

            -- Resolve the git directory path
            local git_dir = vim.fn.resolve(repo_path .. "/store/" .. git_target)

            -- Get the remote URL
            local remote_url = vim.fn.systemlist("git --git-dir=" ..
                vim.fn.shellescape(git_dir) .. " remote get-url origin 2>/dev/null")[1]
            if remote_url and remote_url ~= "" then
                -- Extract repo name from URL (e.g., git@github.com:DataDog/dd-go.git -> dd-go)
                local repo = remote_url:match("/([^/]+)%.git$") or remote_url:match(":([^/:]+)%.git$")
                return repo
            end
        end
    end

    -- Fall back to regular git if not a jj repo
    local git_root = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")[1]
    if git_root and git_root ~= "" then
        local remote_url = vim.fn.systemlist("git remote get-url origin 2>/dev/null")[1]
        if remote_url and remote_url ~= "" then
            local repo = remote_url:match("/([^/]+)%.git$") or remote_url:match(":([^/:]+)%.git$")
            return repo
        end
    end

    return nil
end

-- DataDog web-ui configuration
if get_repo_name() == "web-ui" then
    vim.lsp.config("eslint", {
        settings = {
            nodePath = ".yarn/sdks",
            packageManager = "yarn",
            rulesCustomizations = {
                -- Suppress noise from autofixable rules
                { rule = "prettier/prettier",                          severity = "off" },
                { rule = "arca/import-ordering",                       severity = "off" },
                { rule = "arca/newline-after-import-section",          severity = "off" },
                { rule = "@typescript-eslint/consistent-type-imports", severity = "off" },
                { rule = "quotes",                                     severity = "off" },
                { rule = "import/no-duplicates",                       severity = "off" },
                { rule = "unused-imports/no-unused-imports",           severity = "off" },
            },
        },
    })

    vim.lsp.config("vtsls", {
        settings = {
            vtsls = { autoUseWorkspaceTsdk = true },
            typescript = {
                -- We use Yarn PnP, so we need to specially configure the tsdk location.
                -- Assuming you are editing a file in javascript/datadog, vtsls is
                -- finding tsdk relative to the javascript/tsconfig.json file
                tsdk = vim.fn.getcwd() .. "/.yarn/sdks/typescript/lib",
                preferences = {
                    importModuleSpecifier = "non-relative",
                    autoImportSpecifierExcludeRegexes = { "^packages" },
                },
                tsserver = {
                    maxTsServerMemory = 32768,
                    watchOptions = {
                        excludeDirectories = { "**/node_modules", "**/.yarn", "**/.sarif" },
                        excludeFiles = { ".pnp.cjs" },
                    },
                },
            },
        },
    })

    vim.lsp.enable({ "eslint", "vtsls" })
end
