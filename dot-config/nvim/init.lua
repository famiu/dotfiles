vim.loader.enable()

-- Set mapleader and maplocalloader
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Better command line completion
vim.o.wildmode = 'longest,full'

-- Persistent undo, prevent Neovim from having Alzheimer's
vim.o.undofile = true

-- Use global statusline, not because I made it or anything
vim.o.laststatus = 3

-- Use statusline area for cmdline
vim.o.cmdheight = 0
require('vim._core.ui2').enable({})

-- Allow virtual editing
vim.o.virtualedit = 'all'

-- Spaces > Tabs
vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true

-- Linebreak and wrap behavior
vim.o.wrap = true
vim.o.linebreak = true
vim.o.breakindent = true
vim.o.showbreak = '↪ '

-- Fill column indicator
vim.o.colorcolumn = '+1'

-- Show inccommand preview with split
vim.o.inccommand = 'split'

-- Use transparent fold
vim.o.foldtext = ''
vim.o.foldlevelstart = 20

-- Session options
vim.o.sessionoptions = 'blank,folds,help,tabpages,winsize,winpos,terminal,localoptions'

-- Use smartcase for searching
vim.o.ignorecase = true
vim.o.smartcase = true

-- Make substitute global by default
vim.o.gdefault = true

-- Settings for insert mode completion
vim.o.completeopt = 'menuone,popup,noinsert,fuzzy'
vim.o.shortmess = vim.o.shortmess .. 'c'

-- Split behavior
vim.o.splitbelow = true
vim.o.splitright = true

-- Faster update time
vim.o.updatetime = 100

-- Highlight current line
vim.o.cursorline = true

-- Scroll offsets
vim.o.scrolloff = 10
vim.o.scrolloffpad = 1
vim.o.sidescrolloff = 5

-- Scroll based on screen lines instead of logical lines
vim.o.smoothscroll = true

-- Allow project specific configuration
vim.o.exrc = true

-- Show hybrid line numbers
vim.o.number = true
vim.o.relativenumber = true

-- Allow signcolumn to show up to 2 signs
vim.o.signcolumn = 'auto:2'

-- Enable foldcolumn
vim.o.foldcolumn = '1'

-- Allow conceal to use replacement characters to hide text
vim.o.conceallevel = 2

-- Better listchars
vim.o.list = true
vim.o.listchars = 'tab:» ,extends:›,precedes:‹,nbsp:␣'

-- Add border to floating windows
vim.o.winborder = 'single'

-- Use floating preview windows
vim.o.previewpopup = 'height:10,width:60,border:single'

-- Remove "How-to disable mouse" from right-click menu
pcall(vim.cmd.aunmenu, [[PopUp.How-to\ disable\ mouse]])
pcall(vim.cmd.aunmenu, [[PopUp.-2-]])

-- Map H and L to ^ and $
vim.keymap.set({ 'n', 'x', 'o' }, 'H', '^')
vim.keymap.set({ 'n', 'x', 'o' }, 'L', '$')

-- Search only visual area in Visual mode
vim.keymap.set('x', '/', '<Esc>/\\%V')

-- Apply the . command to all selected lines in visual mode
vim.keymap.set('x', '.', ':normal .<CR>', { silent = true })

-- Cycle through windows
vim.keymap.set('n', '[w', '<CMD>wincmd W<CR>')
vim.keymap.set('n', ']w', '<CMD>wincmd w<CR>')

-- Tab keybinds
-- Move current tab
vim.keymap.set('n', '<Leader>t[', '<CMD>tabmove -1<CR>')
vim.keymap.set('n', '<Leader>t]', '<CMD>tabmove +1<CR>')
-- New tab
vim.keymap.set('n', '<Leader>tn', '<CMD>tabnew<CR>')
-- Close tab
vim.keymap.set('n', '<Leader>tx', '<CMD>tabclose<CR>')
vim.keymap.set('n', '<Leader>tX', '<CMD>tabclose!<CR>')

-- Get out of Terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { silent = true, desc = 'Exit Terminal mode' })

-- Yank/paste to clipboard
vim.keymap.set({ 'n', 'x' }, '<Leader>y', '"+y')
vim.keymap.set({ 'n', 'x' }, '<Leader>p', '"+p')

vim.pack.add({
    'https://github.com/nvim-mini/mini.ai',
    'https://github.com/nvim-mini/mini.align',
    'https://github.com/nvim-mini/mini.surround',
    'https://github.com/nvim-mini/mini.pick',
    'https://github.com/tpope/vim-abolish',
    'https://github.com/tpope/vim-sleuth',
    'https://github.com/stevearc/oil.nvim',
})

require('mini.ai').setup({})
require('mini.align').setup({})
require('mini.surround').setup({})

require('oil').setup({
    columns = {},
    keymaps = {
        ['<C-s>'] = false,
        ['<C-h>'] = false,
        ['<C-v>'] = 'actions.select_vsplit',
        ['<C-x>'] = 'actions.select_split',
    },
})
vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Edit directory' })

local pick = require('mini.pick')
pick.setup({ source = { show = pick.default_show } })

vim.keymap.set('n', '<Leader><Space>', pick.builtin.files, { desc = 'Find files' })
vim.keymap.set('n', '<Leader>ff', pick.builtin.files, { desc = 'Find files' })
vim.keymap.set('n', '<Leader>,', pick.builtin.buffers, { desc = 'Find buffers' })
vim.keymap.set('n', '<Leader>/', pick.builtin.grep_live, { desc = 'Search files' })
vim.keymap.set('n', '<Leader>sh', pick.builtin.help, { desc = 'Find help' })
vim.keymap.set('n', '<Leader>sR', pick.builtin.resume, { desc = 'Resume picker' })

vim.cmd.packadd('nvim.undotree')
vim.keymap.set('n', '<Leader>ut', '<CMD>Undotree<CR>', { desc = 'Undo history' })

-- Make catppuccin background transparent
vim.api.nvim_create_autocmd('ColorScheme', {
  pattern = 'catppuccin',
  command = 'highlight Normal guibg=NONE ctermbg=NONE',
})
vim.cmd.colorscheme('catppuccin')

vim.pack.add({
    'https://github.com/nvim-mini/mini.ai',
    'https://github.com/nvim-mini/mini.align',
    'https://github.com/nvim-mini/mini.surround',
    'https://github.com/nvim-mini/mini.pick',
    'https://github.com/tpope/vim-abolish',
    'https://github.com/tpope/vim-sleuth',
    'https://github.com/stevearc/oil.nvim',
})

require('mini.ai').setup({})
require('mini.align').setup({})
require('mini.surround').setup({})

require('oil').setup({
    columns = {},
    keymaps = {
        ['<C-s>'] = false,
        ['<C-h>'] = false,
        ['<C-v>'] = 'actions.select_vsplit',
        ['<C-x>'] = 'actions.select_split',
    },
})
vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Edit directory' })

local pick = require('mini.pick')
pick.setup({ source = { show = pick.default_show } })

vim.keymap.set('n', '<Leader><Space>', pick.builtin.files, { desc = 'Find files' })
vim.keymap.set('n', '<Leader>ff', pick.builtin.files, { desc = 'Find files' })
vim.keymap.set('n', '<Leader>,', pick.builtin.buffers, { desc = 'Find buffers' })
vim.keymap.set('n', '<Leader>/', pick.builtin.grep_live, { desc = 'Search files' })
vim.keymap.set('n', '<Leader>sh', pick.builtin.help, { desc = 'Find help' })
vim.keymap.set('n', '<Leader>sR', pick.builtin.resume, { desc = 'Resume picker' })

vim.cmd.packadd('nvim.undotree')
vim.keymap.set('n', '<Leader>ut', '<CMD>Undotree<CR>', { desc = 'Undo history' })
