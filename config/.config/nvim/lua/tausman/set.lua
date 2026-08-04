-- vim.opt.guicursor = ""

-- Blinking cursor. Nvim's default guicursor sets blink timings only for terminal mode, so
-- every other mode asks for a STEADY cursor -- and Ghostty honours that (its
-- cursor-style-blink is only a default, unlike Alacritty's `blinking = "Always"`, which
-- ignores the app). In a TUI nvim sends just the cursor *shape* via the Ss/Se terminfo caps
-- (DECSCUSR), which carries no timing -- so these ms values only need to be NONZERO to ask
-- for blinking; the actual rate is the terminal's and Ghostty doesn't expose it. Shapes are
-- nvim's defaults; `a:` appends the blink to every mode.
vim.opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20,a:blinkwait200-blinkon200-blinkoff200"

vim.o.exrc = true

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.smartindent = true

vim.opt.wrap = false

vim.opt.swapfile = false
-- vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true
vim.opt.autoread = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
-- TODO: What exactly does this do?
-- vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50

-- vim.opt.colorcolumn = "80"

vim.opt.ignorecase = true
vim.opt.smartcase = true

-- session settings
vim.opt.sessionoptions = "buffers,curdir,folds,help,tabpages,winsize,terminal"

-- use a stack for the jumplist
-- vim.opt.jumpoptions:append { "stack" }

-- -- *** EXPERIMENTAL: Make it easer to use mouse in vim *** --
-- -- need to use select mode on mouse select to keep it distinct from visual mode
-- vim.opt.selectmode = "mouse,key"
--
-- -- allow clicking to insert
-- vim.keymap.set('n', '<LeftMouse>', '<LeftMouse>i')
--
-- -- hitting escape while in select mode goes back to normal mode instead of insert mode
-- vim.keymap.set('s', '<Esc>', '<C-\\><C-g>')
--
-- -- This maps all printable characters (space through ~) in select mode to:
-- -- 1. <C-g> - convert select mode to visual mode
-- -- 2. c - delete selection and enter insert mode
-- -- 3. {char} - type the character you pressed
-- for i = 32, 126 do
--     local char = string.char(i)
--     vim.keymap.set('s', char, '<C-g>c' .. char, { noremap = true })
-- end
-- -- *** END EXPERIMENTAL *** --
