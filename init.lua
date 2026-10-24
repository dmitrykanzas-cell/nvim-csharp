local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local result = vim.fn.system({
    "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_err_writeln("Не удалось установить lazy.nvim: " .. result)
    return
  end
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("config")
require("lazy").setup("plugins", {
  change_detection = { notify = false },
  checker = { enabled = false },
  install = { colorscheme = { "habamax" } },
})

vim.cmd.colorscheme("habamax")

vim.api.nvim_create_user_command("DotnetHealth", function()
  vim.cmd("checkhealth easy-dotnet")
end, {})

vim.api.nvim_create_user_command("ConfigHealth", function()
  vim.cmd("checkhealth")
end, {})
