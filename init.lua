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
vim.keymap.set("n", "<C-n>", ":Neotree filesystem reveal float<CR>")

vim.keymap.set("n", "<leader>ov", ":ObsidianFollowLink vsplit<CR>")
vim.keymap.set("n", "<leader>ol", ":ObsidianLinks<CR>")
vim.keymap.set("n", "<leader>ob", ":ObsidianBacklinks<CR>")
vim.keymap.set("n", "<leader>ot", ":ObsidianToday<CR>")
vim.keymap.set("n", "<leader>cb", ":ObsidianToggleCheckbox<CR>")
vim.keymap.set("n", "<leader>oc", ":ObsidianTOC<CR>")
vim.keymap.set("n", "<leader>os", ":ObsidianSearch<CR>")
-- Needed for obsidian rendering
vim.opt.conceallevel = 1

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

-- Taskwarrior ↔ Linear ↔ Obsidian bridge (:LinearIssues, :TWTasks, :TWNote, <leader>tt)
-- Loaded straight from the bridge repo (TWL_REPO, default ~/projects/
-- taskwarrior-linear) via runtimepath — no vendored copy to keep in sync.
local twl_repo = vim.fn.expand(os.getenv("TWL_REPO") or "~/projects/taskwarrior-linear")
if vim.fn.isdirectory(twl_repo .. "/lua") == 1 then
  vim.opt.runtimepath:append(twl_repo)
  require("taskwarrior_linear").setup()
end
