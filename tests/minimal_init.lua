-- Minimal Neovim config for running specs: no user config, only this plugin and plenary.
local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"

vim.opt.runtimepath:append(vim.fn.getcwd())
vim.opt.runtimepath:append(plenary_path)

-- With a custom init, plugin/ files of appended runtimepath entries are not auto-sourced.
vim.cmd("runtime plugin/plenary.vim")
