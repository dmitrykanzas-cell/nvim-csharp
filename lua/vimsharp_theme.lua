local M = {}

local fallback = "habamax"
local original_hl = {}
local managed_groups = {
  "DebugModePanel",
  "DebugModeBorder",
}

local catalog = {
  { name = "habamax", mode = "dark", group = "system", label = "Habamax" },
  { name = "default", mode = "light", group = "system", label = "Default" },
  { name = "vim", mode = "light", group = "system", label = "Vim" },
  { name = "quiet", mode = "dark", group = "system", label = "Quiet" },
  { name = "zaibatsu", mode = "dark", group = "system", label = "Zaibatsu" },
  { name = "lunaperche", mode = "dark", group = "system", label = "Lunaperche" },
  { name = "catppuccin-mocha", mode = "dark", group = "popular", label = "Catppuccin Mocha" },
  { name = "catppuccin-macchiato", mode = "dark", group = "popular", label = "Catppuccin Macchiato" },
  { name = "catppuccin-frappe", mode = "dark", group = "popular", label = "Catppuccin Frappe" },
  { name = "catppuccin-latte", mode = "light", group = "popular", label = "Catppuccin Latte" },
  { name = "tokyonight-night", mode = "dark", group = "popular", label = "Tokyo Night" },
  { name = "tokyonight-storm", mode = "dark", group = "popular", label = "Tokyo Night Storm" },
  { name = "tokyonight-moon", mode = "dark", group = "popular", label = "Tokyo Night Moon" },
  { name = "tokyonight-day", mode = "light", group = "popular", label = "Tokyo Night Day" },
  { name = "gruvbox", mode = "dark", group = "popular", label = "Gruvbox" },
  { name = "kanagawa-wave", mode = "dark", group = "popular", label = "Kanagawa Wave" },
  { name = "kanagawa-dragon", mode = "dark", group = "popular", label = "Kanagawa Dragon" },
  { name = "kanagawa-lotus", mode = "light", group = "popular", label = "Kanagawa Lotus" },
  { name = "rose-pine-main", mode = "dark", group = "popular", label = "Rose Pine" },
  { name = "rose-pine-moon", mode = "dark", group = "popular", label = "Rose Pine Moon" },
  { name = "rose-pine-dawn", mode = "light", group = "popular", label = "Rose Pine Dawn" },
  { name = "nightfox", mode = "dark", group = "popular", label = "Nightfox" },
  { name = "carbonfox", mode = "dark", group = "popular", label = "Nightfox" },
  { name = "dawnfox", mode = "light", group = "popular", label = "Dawnfox" },
  { name = "dayfox", mode = "light", group = "popular", label = "Dayfox" },
  { name = "nordfox", mode = "dark", group = "popular", label = "Nordfox" },
  { name = "everforest", mode = "dark", group = "popular", label = "Everforest" },
  { name = "onedark", mode = "dark", group = "popular", label = "OneDark" },
}

local function is_available(name)
  return vim.fn.empty(vim.fn.globpath(vim.o.runtimepath, "colors/" .. name .. ".vim", true, true)) == 0
    or vim.fn.empty(vim.fn.globpath(vim.o.runtimepath, "colors/" .. name .. ".lua", true, true)) == 0
end

local function restore_managed_highlights()
  if vim.tbl_isempty(original_hl) then return end
  for group, value in pairs(original_hl) do
    vim.api.nvim_set_hl(0, group, value)
  end
end

local function capture_managed_highlights()
  original_hl = {}
  for _, group in ipairs(managed_groups) do
    original_hl[group] = vim.api.nvim_get_hl(0, { name = group, link = false })
  end
end

local function apply_vimsharp_highlights()
  vim.api.nvim_set_hl(0, "DebugModePanel", { link = "NormalFloat" })
  vim.api.nvim_set_hl(0, "DebugModeBorder", { fg = "Yellow", bold = true })
end

function M.list(filter)
  local result = {}
  for _, theme in ipairs(catalog) do
    if is_available(theme.name)
      and (not filter or filter == "all" or filter == theme.mode or filter == theme.group)
    then
      local item = vim.deepcopy(theme)
      item.available = true
      table.insert(result, item)
    end
  end
  return result
end

function M.available(name)
  return is_available(name)
end

function M.current()
  return vim.g.colors_name or fallback
end

function M.fallback()
  return fallback
end

function M.apply(name)
  if not is_available(name) then
    return false, "Цветовая схема не установлена: " .. name
  end

  local ok, err = pcall(vim.cmd.colorscheme, name)
  if not ok then
    return false, "Не удалось применить тему " .. name .. ": " .. tostring(err)
  end

  apply_vimsharp_highlights()
  return true
end

function M.begin_preview()
  capture_managed_highlights()
  return M.current()
end

function M.cancel_preview(original)
  local ok = M.apply(original or fallback)
  if ok then
    restore_managed_highlights()
    apply_vimsharp_highlights()
  end
  original_hl = {}
  return ok
end

function M.commit_preview()
  original_hl = {}
end

function M.apply_fallback()
  local ok = M.apply(fallback)
  if not ok then
    vim.cmd("highlight clear")
    vim.g.colors_name = fallback
    apply_vimsharp_highlights()
  end
end

return M
