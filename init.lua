-- Basic VIM config

vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")
vim.cmd("set number")
vim.cmd("set relativenumber")
vim.g.mapleader = " "
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"

-- Keep folds open by default
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99

-- Keep the first line of the fold syntax-highlighted instead of a flat color
vim.opt.foldtext = ""
--keymap for Neotree
vim.keymap.set('n', '<C-n>', ':Neotree filesystem reveal float<CR>')

-- Ensure lazy.nvim is installed

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)


-- Install lazy.nvim plugins

require("lazy").setup("plugins")

