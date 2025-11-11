vim.g.mapleader = " "
-- vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- vim.keymap.set("n", "<C-d>", "<C-d>zz")
-- vim.keymap.set("n", "<C-u>", "<C-u>zz")
-- vim.keymap.set("n", "n", "nzzzv")
-- vim.keymap.set("n", "N", "Nzzzv")

-- vim.keymap.set("n", "]q", "<cmd>cnext<CR>zz")
-- vim.keymap.set("n", "[q", "<cmd>cprev<CR>zz")
vim.keymap.set("n", "]q", "<cmd>cnext<CR>")
vim.keymap.set("n", "[q", "<cmd>cprev<CR>")

-- greatest remap ever
vim.keymap.set("x", "<leader>p", [["_dP]])

-- next greatest remap ever : asbjornHaland
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])
vim.keymap.set("n", "<leader>yy", [["+yy]])

vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]])
vim.keymap.set("n", "<leader>D", [["_D]])
vim.keymap.set("n", "<leader>dd", [["_dd]])

-- This is going to get me cancelled
vim.keymap.set("i", "<C-c>", "<Esc>")

-- Splitting windows same way as TMUX
vim.keymap.set("n", "<C-w>-", ":split<CR>")
vim.keymap.set("n", "<C-w>\\", ":vsplit<CR>")
vim.keymap.set("n", "<C-w>t", "<C-w><S-t>")
vim.keymap.set("n", "<C-w>p", ":tabprevious<CR>")
vim.keymap.set("n", "<C-w>n", ":tabnext<CR>")
vim.keymap.set("n", "<C-w>s", "<C-w>g<Tab>")
vim.keymap.set("n", "<C-w>;", "<C-w><C-p>")
vim.keymap.set("n", "<C-w>1", "1gt")
vim.keymap.set("n", "<C-w>2", "2gt")
vim.keymap.set("n", "<C-w>3", "3gt")
vim.keymap.set("n", "<C-w>4", "4gt")
vim.keymap.set("n", "<C-w>5", "5gt")
vim.keymap.set("n", "<C-w>6", "6gt")
vim.keymap.set("n", "<C-w>7", "7gt")
vim.keymap.set("n", "<C-w>8", "8gt")
vim.keymap.set("n", "<C-w>9", "9gt")

-- Get current filepath
vim.keymap.set("n", "<leader>ff", function()
    vim.fn.setreg("+", vim.fn.expand("%"))
end)

vim.keymap.set("v", "<leader>ff", function()
    vim.cmd('normal! V')
    local start_line = vim.fn.getpos("'<")[2]
    local end_line = vim.fn.getpos("'>")[2]
    local file = vim.fn.expand("%")
    if start_line == end_line then
        vim.fn.setreg("+", file .. ":" .. start_line)
    else
        vim.fn.setreg("+", file .. ":" .. start_line .. "-" .. end_line)
    end
end)


-- Refresh windows
vim.keymap.set("n", "<leader>ee", ":e!<CR>")
vim.keymap.set("n", "<leader>E", ":bufdo e!<CR>")

-- Git
vim.keymap.set("n", "<leader>gr", ":G rebase -i --update-refs ")

-- Save and quit remps
vim.keymap.set("n", "<C-s>", ":w<CR>")
vim.keymap.set("n", "<C-q>", ":q<CR>")
-- Couldn't get shift keys working...
-- vim.keymap.set("n", "<C-S-s>", ":mksession!<CR>:wqa<CR>")
-- vim.keymap.set("n", "<C-S-q>", ":wqa<CR>")


-- Command mode: Ctrl+p for command history
vim.keymap.set("c", "<C-p>", "<Up>")
vim.keymap.set("c", "<C-n>", "<Down>")

-- Add j,k jumps to jumplist
vim.keymap.set('n', 'j', function()
    return vim.v.count > 5 and "m'" .. vim.v.count .. 'j' or 'j'
end, { expr = true })

vim.keymap.set('n', 'k', function()
    return vim.v.count > 5 and "m'" .. vim.v.count .. 'k' or 'k'
end, { expr = true })


-- Open & Close quickfix menu
vim.keymap.set("n", "<leader>q", function()
    local qf_exists = false
    for _, win in pairs(vim.fn.getwininfo()) do
        if win.quickfix == 1 then
            qf_exists = true
        end
    end
    if qf_exists then
        vim.cmd("cclose")
    else
        vim.cmd("copen")
    end
end)

-- Search with input prompt
vim.keymap.set('n', '<leader>/', function()
    vim.ui.input({ prompt = "Search: " }, function(search_term)
        if search_term and search_term ~= "" then
            -- Escape special characters for search
            search_term = search_term:gsub("([^%w])", "\\%1")
            -- Set the search register and execute the search
            vim.fn.setreg('/', search_term)
            vim.cmd('normal! n')
        end
    end)
end)
