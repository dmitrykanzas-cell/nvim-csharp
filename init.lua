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

require("vimsharp_theme_state").load()
local theme_picker = require("vimsharp_theme_picker")

vim.keymap.set("n", "<leader>t", function()
  theme_picker.open()
end, { desc = "Темы / Themes" })

require("vimsharp_start")

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
  if vim.fn.argc() ~= 0 then return end
  local has_named_buffer = false
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted and vim.api.nvim_buf_get_name(buf) ~= "" then
      has_named_buffer = true
      break
    end
  end
  if not has_named_buffer then require("vimsharp_start").open() end
  end,
})

vim.api.nvim_create_user_command("DotnetHealth", function()
  vim.cmd("checkhealth easy-dotnet")
end, {})

vim.api.nvim_create_user_command("ConfigHealth", function()
  vim.cmd("checkhealth")
end, {})
