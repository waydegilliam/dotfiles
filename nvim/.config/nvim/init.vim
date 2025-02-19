" Plugins
call plug#begin()

" Core
Plug 'nvim-lua/plenary.nvim'

" Filetree
Plug 'nvim-tree/nvim-tree.lua', {'commit': 'a2aaf8b430c11af36b869cf1c0ad2f7c8ceeaf2c'} 
Plug 'nvim-tree/nvim-web-devicons', {'commit': '47103b80c38c59f7a1b5408c232b92bf5d018651'}

" " Completions
" Plug 'hrsh7th/nvim-cmp', {'commit': '0b751f6beef40fd47375eaf53d3057e0bfa317e4'}
" Plug 'hrsh7th/cmp-buffer', {'commit': '3022dbc9166796b644a841a02de8dd1cc1d311fa'}
" Plug 'hrsh7th/cmp-path', {'commit': '91ff86cd9c29299a64f968ebb45846c485725f23'}
" Plug 'hrsh7th/cmp-nvim-lsp', {'commit': '44b16d11215dce86f253ce0c30949813c0a90765'}
" Plug 'L3MON4D3/LuaSnip', {'commit': 'a4de64570b9620875c8ea04175cd07ed8e32ac99'}

" " LSP
" Plug 'neovim/nvim-lspconfig', {'commit': 'b0852218bc5fa6514a71a9da6d5cfa63a263c83d'}

" Treesitter
Plug 'nvim-treesitter/nvim-treesitter', {'commit': '8996612bfbebe1657e1bb55a95201c96cab945c6', 'do': 'TSUpdate'}

" Language-specific plugins
Plug 'dag/vim-fish', {'commit': '50b95cbbcd09c046121367d49039710e9dc9c15f'}
Plug 'windwp/nvim-ts-autotag', {'commit': '6be1192965df35f94b8ea6d323354f7dc7a557e4'}
Plug 'jose-elias-alvarez/typescript.nvim', {'commit': '4de85ef699d7e6010528dcfbddc2ed4c2c421467'}
Plug 'JoosepAlviste/nvim-ts-context-commentstring', {'commit': '92e688f013c69f90c9bbd596019ec10235bc51de'}
Plug 'maxmellon/vim-jsx-pretty', {'commit': '6989f1663cc03d7da72b5ef1c03f87e6ddb70b41'}

" Misc
Plug 'phaazon/hop.nvim'
" Plug 'lewis6991/gitsigns.nvim'
Plug 'windwp/nvim-autopairs'
Plug 'jpalardy/vim-slime'
Plug 'jose-elias-alvarez/null-ls.nvim'
" Plug 'kevinhwang91/nvim-ufo', {'commit': 'a346e88c776a7089291c883705c5cd8a6ce67558'}
" Plug 'kevinhwang91/promise-async', {'commit': '70b09063cdf029079b25c7925e4494e7416ee995'}
Plug 'dhruvasagar/vim-zoom', {'commit': '9f281ac7766c3931cb87698602eeb33a62660ae2'}
Plug 'christoomey/vim-tmux-navigator', {'commit': 'afb45a55b452b9238159047ce7c6e161bd4a9907'}
Plug 'rmagatti/auto-session' 
Plug 'junegunn/fzf' 
Plug 'numToStr/Comment.nvim', {'commit': '5f01c1a89adafc52bf34e3bf690f80d9d726715d'}
" Plug 'folke/zen-mode.nvim'
Plug 'ruanyl/vim-gh-line'
Plug 'ojroques/vim-oscyank', {'branch': 'main'}
Plug 'evanleck/vim-svelte'

Plug 'vim-scripts/AutoComplPop'
Plug 'easymotion/vim-easymotion'

call plug#end()

" Load configs
lua require("config.autocmd")
lua require("config.clipboard")

" Load plugin configs (preserve order)
" lua require("config.plugins.lsp-config")
" lua require("config.plugins.ufo")
lua require("config.plugins.nvim-tree")
" lua require("config.plugins.gitsigns")
" lua require("config.plugins.cmp")
lua require("config.plugins.hop")
lua require("config.plugins.treesitter")
lua require("config.plugins.autopairs")
lua require("config.plugins.null-ls")
lua require("config.plugins.nvim-web-devicons")
lua require("config.plugins.fzf")
lua require("config.plugins.comment")
" lua require("config.plugins.zen-mode")

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
set background=light
set laststatus=3
set sessionoptions+=tabpages,globals
set shell=/bin/bash\ -i

" Colorscheme
colorscheme solarized

" Python venv
let g:python3_host_prog = stdpath('config') . '/venv/bin/python'

" Easymotion 
let g:EasyMotion_do_mapping=0
let g:EasyMotion_keys='etovxqpdygfblzhckisuran'

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

" " Gitsigns
" nnoremap <leader>gh <cmd>Gitsigns preview_hunk<cr>

" " Hop
nnoremap f <cmd>HopWord<cr>
nnoremap F <cmd>HopLine<cr>
vnoremap f <cmd>HopWord<cr>
vnoremap F <cmd>HopLine<cr>

" Easymotion
" nnoremap f <Plug>(easymotion-f) 
" nnoremap F <cmd>HopLine<cr>
" vnoremap f <cmd>HopWord<cr>
" vnoremap F <cmd>HopLine<cr>

" FZF
nnoremap <leader>ff <cmd>FzfFiles<cr>
nnoremap <leader>fg <cmd>FzfGrep<cr>

" " Show LSP info
" nnoremap gd <cmd>lua vim.lsp.buf.definition()<cr>
" nnoremap gh <cmd>lua vim.lsp.buf.hover()<cr>

" Slime
nnoremap <leader>s <plug>SlimeSendCell

" " Rename (LSP)
" nnoremap R <cmd>Lspsaga rename<cr>

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

