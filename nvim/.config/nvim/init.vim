" Install vim-plug
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" Plugins
call plug#begin()

" Core
Plug 'nvim-lua/plenary.nvim', {'commit': '74b06c6c75e4eeb3108ec01852001636d85a932b'}

" Filetree
Plug 'nvim-tree/nvim-tree.lua', {'commit': 'a2aaf8b430c11af36b869cf1c0ad2f7c8ceeaf2c'} 
Plug 'nvim-tree/nvim-web-devicons', {'commit': '47103b80c38c59f7a1b5408c232b92bf5d018651'}

" LSP
Plug 'neovim/nvim-lspconfig', {'commit': '7d22e678970d95d8d18494ec389c52b07111c53a'}

" Treesitter
Plug 'nvim-treesitter/nvim-treesitter', {'commit': '8996612bfbebe1657e1bb55a95201c96cab945c6', 'do': 'TSUpdate'}

" Language-specific plugins
Plug 'dag/vim-fish', {'commit': '50b95cbbcd09c046121367d49039710e9dc9c15f'}
Plug 'windwp/nvim-ts-autotag', {'commit': '6be1192965df35f94b8ea6d323354f7dc7a557e4'}
Plug 'JoosepAlviste/nvim-ts-context-commentstring', {'commit': '92e688f013c69f90c9bbd596019ec10235bc51de'}
Plug 'maxmellon/vim-jsx-pretty', {'commit': '6989f1663cc03d7da72b5ef1c03f87e6ddb70b41'}

" Misc
Plug 'lewis6991/gitsigns.nvim', {'commit': 'c0862d382a35b7b45757d8d151a6a634c09bf3ce'}
Plug 'windwp/nvim-autopairs', {'commit': '3172f40c16563db871a58f20d205c710ad782311'}
Plug 'jpalardy/vim-slime', {'commit': '375999b91aa9bd227350140d4aedc6d2ff8554ac'}
" Plug 'kevinhwang91/nvim-ufo', {'commit': 'a346e88c776a7089291c883705c5cd8a6ce67558'}
" Plug 'kevinhwang91/promise-async', {'commit': '70b09063cdf029079b25c7925e4494e7416ee995'}
Plug 'dhruvasagar/vim-zoom', {'commit': '9f281ac7766c3931cb87698602eeb33a62660ae2'}
Plug 'christoomey/vim-tmux-navigator', {'commit': 'afb45a55b452b9238159047ce7c6e161bd4a9907'}
Plug 'rmagatti/auto-session', {'commit': '02a5588f677970a9bc784115c62bef9e5855499b'}

Plug 'junegunn/fzf', {'commit': '9a0705815cc690552ac5e2c0a6b51fd4ed3e831a', 'do': { -> fzf#install() }}
Plug 'junegunn/fzf.vim', {'commit': 'fe5f1fd45418c1a4d905f44a59357008058cc789'}

Plug 'numToStr/Comment.nvim', {'commit': '5f01c1a89adafc52bf34e3bf690f80d9d726715d'}
Plug 'ruanyl/vim-gh-line', {'commit': '731751fdfa4f64a061dbc7088cb7b2f12e828ad'}

Plug 'vim-scripts/AutoComplPop', {'commit': '0b075cf5e6ef05584ef6377e116e8d0fe1f8f788'}

call plug#end()

" Local plugins
packadd jump
packadd osc52
packadd github-light

" Load configs
lua require("config.autocmd")

" Load plugin configs (preserve order)
lua require("config.plugins.lsp-config")
" lua require("config.plugins.ufo")
lua require("config.plugins.nvim-tree")
lua require("config.plugins.gitsigns")
" lua require("config.plugins.cmp")
lua require("config.plugins.treesitter")
lua require("config.plugins.autopairs")
lua require("config.plugins.comment")

" Options
set clipboard=unnamedplus
set number
set numberwidth=4
set scrolloff=10
set sidescrolloff=10
set mouse=a
set noshowmode
set ignorecase
set smartcase
set splitbelow
set undofile
set updatetime=300
set expandtab
set shiftwidth=2
set tabstop=2
set cursorline
set signcolumn=yes
set termguicolors
set guioptions-=m
set gdefault
set pumheight=10
set foldcolumn=0
set foldlevel=99
set foldenable
set nowrap
set textwidth=120
set formatoptions+=t
set background=light
set laststatus=3
set sessionoptions+=tabpages,globals
set shell=/bin/bash\ -i

" Colorscheme
colorscheme github-light

" Python venv
let g:python3_host_prog = stdpath('config') . '/venv/bin/python'

" FZF
let g:fzf_vim = {}
let g:fzf_vim.preview_window = []

" --- Keybinds ----------------------------------------------------------------
let mapleader = ' '
let maplocalleader = ' '

" Source init.vim
nnoremap <silent> <leader>r <cmd>source $MYVIMRC<cr>

" Disable <space> in normal mode
nnoremap <space> <nop>

" Exit insert mode
inoremap jk <esc>l
inoremap <esc> <nop>

" Select all
nnoremap <c-a> ggVG

" Horizontal split
nnoremap <c-w>b <c-w>s

" Stay in visual mode when indenting
vnoremap < <gv
vnoremap > >gv

" Replace selected text without replacing the clipboard
vnoremap p "_dP

" Navigate buffers
nnoremap gb <cmd>bnext<cr>
nnoremap gB <cmd>bprevious<cr>

" Nvim Tree
nnoremap <leader>e <cmd>NvimTreeToggle<cr>

" Gitsigns
nnoremap <leader>gh <cmd>Gitsigns preview_hunk<cr>

" Jump
nnoremap f <cmd>JumpWord<cr>
nnoremap F <cmd>JumpLine<cr>
vnoremap f <cmd>JumpWord<cr>
vnoremap F <cmd>JumpLine<cr>
onoremap f <cmd>JumpWord<cr>
onoremap F <cmd>JumpLine<cr>

" FZF
nnoremap <leader>ff <cmd>Files<cr>
nnoremap <leader>fg <cmd>Rg<cr> 

" " Show LSP info
" nnoremap gd <cmd>lua vim.lsp.buf.definition()<cr>
" nnoremap gh <cmd>lua vim.lsp.buf.hover()<cr>

" Slime
nnoremap <leader>s <plug>SlimeSendCell

" Go to start/end of line
nnoremap H ^
nnoremap L g_

" Jump to tabpage
nnoremap <leader>1 1gt
nnoremap <leader>2 2gt
nnoremap <leader>3 3gt
nnoremap <leader>4 4gt
nnoremap <leader>5 5gt
nnoremap <leader>6 6gt
nnoremap <leader>7 7gt
nnoremap <leader>8 8gt
nnoremap <leader>9 9gt

" Rename tabpage
nnoremap <leader>, <cmd>lua require("config.ui.tabline").rename_tabline_label()<cr>

" Move window to its own tab
nnoremap T <c-w>T

" Zoom window
nnoremap <leader>m <plug>(zoom-toggle)

" Comment stuff
nnoremap gc <Plug>(comment_toggle_linewise_current)
vnoremap gc <Plug>(comment_toggle_linewise_visual)

" " Toggle Zen Mode
" nnoremap <leader>z <cmd>ZenMode<cr>

" Tab page controls
nnoremap <leader>n <cmd>tabnext<cr>
nnoremap <leader>p <cmd>tabprevious<cr>
nnoremap <leader>c <cmd>tabnew<cr>
nnoremap <leader>x <cmd>tabclose<cr>
