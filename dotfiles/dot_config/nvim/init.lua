vim.g.mapleader = " "
vim.keymap.set('i', 'jk', '<Esc>', { noremap = true, silent = true })

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  {
    "shaunsingh/solarized.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.opt.termguicolors = true
      vim.o.background = "dark"
      vim.cmd("colorscheme solarized")

      local hl = vim.api.nvim_set_hl
      hl(0, "Identifier", { fg = "#2aa198" })
      hl(0, "Function", { fg = "#2aa198" })
      hl(0, "shDerefVar", { fg = "#2aa198" })
      hl(0, "shDerefSimple", { fg = "#2aa198" })
      hl(0, "shVariable", { fg = "#2aa198" })
      hl(0, "shComment", { fg = "#657b83" })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").install({ "bash", "markdown", "markdown_inline" })
    end,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      anti_conceal = { enabled = true },
    },
  },
})

vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
