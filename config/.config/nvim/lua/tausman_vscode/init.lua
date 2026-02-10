-- Command mode: Ctrl+p for command history
vim.keymap.set("c", "<C-p>", "<Up>")
vim.keymap.set("c", "<C-n>", "<Down>")

-- This is going to get me cancelled
vim.keymap.set({ "i", "c" }, "<C-c>", "<Esc>")

-- Scrolling - DOES NOT WORK bc scrolling is done in vscode
-- vim.keymap.set("n", "<C-u>", "<C-u>L")
-- vim.keymap.set("n", "<C-d>", "<C-d>L")

-- next greatest remap ever : asbjornHaland
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])

vim.keymap.set("n", "<C-s>", ":w<CR>")
