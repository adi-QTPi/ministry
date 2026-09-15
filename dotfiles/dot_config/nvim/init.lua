vim.g.mapleader = " "
vim.keymap.set('i', 'jk', '<Esc>', { noremap = true, silent = true })

vim.o.background = "dark"
vim.cmd("colorscheme solarized")
vim.opt.termguicolors = true
vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true