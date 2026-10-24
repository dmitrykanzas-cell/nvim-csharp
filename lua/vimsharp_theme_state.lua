local M = {}

local theme = require("vimsharp_theme")
local path = vim.fn.stdpath("state") .. "/vimsharp-theme.json"

local function read()
  local file = io.open(path, "r")
  if not file then return {} end
  local content = file:read("*a")
  file:close()
  local ok, value = pcall(vim.json.decode, content)
  return ok and type(value) == "table" and value or {}
end

local function write(value)
  vim.fn.mkdir(vim.fn.stdpath("state"), "p")
  local file, err = io.open(path, "w")
  if not file then return false, err end
  file:write(vim.json.encode(value))
  file:close()
  return true
end

function M.load()
  local value = read()
  local selected = value.selected
  if type(selected) ~= "string" or not theme.available(selected) then
    selected = theme.fallback()
  end
  local ok, err = theme.apply(selected)
  if not ok then
    theme.apply_fallback()
    return false, err
  end
  return true, selected
end

function M.save(selected)
  if type(selected) ~= "string" or not theme.available(selected) then
    return false, "Тема недоступна: " .. tostring(selected)
  end
  return write({ selected = selected })
end

function M.path()
  return path
end

return M
