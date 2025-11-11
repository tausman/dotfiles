syntax on
set nu ru et
set ts=2 sts=2 sw=2
set cursorline
set hlsearch
set nocompatible   " be improved, required
filetype off       " required
" store the plugins in plugged dir
call plug#begin('~/.config/nvim/plugged')
" Plug 'morhetz/gruvbox'
" Plug 'tpope/vim-fugitive'
" Plug 'preservim/nerdtree'
" Plug 'kien/ctrlp.vim'
" Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
" Use release branch (recommended)
" Plug 'neoclide/coc.nvim', {'branch': 'release'}
call plug#end()
" select the color scheme
" colorscheme gruvbox
" Mirror the NERDTree before showing it. This makes it the same on all tabs.
" map <silent> <C-n> :NERDTreeFocus<CR>
nnoremap k kzz
nnoremap j jzz
nnoremap G Gzz
