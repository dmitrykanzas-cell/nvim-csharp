local M = {}

local action_state
local actions
local finders
local pickers
local conf

local theme = require("vimsharp_theme")
local state = require("vimsharp_theme_state")

local active = false
local original

local function title(filter)
  local suffix = filter and filter ~= "all" and " / " .. filter or ""
  return "VimSharp Themes" .. suffix
end

local function format_item(item)
  item = item.value or item
  local marker = item.name == theme.current() and "*" or " "
  return string.format("%s %-16s [%s] [%s]", marker, item.label or item.name, item.mode, item.group)
end

local function selected_name()
  local entry = action_state.get_selected_entry()
  return entry and entry.value and entry.value.name
end

local function preview()
  local name = selected_name()
  if not name then return end
  local ok, err = theme.apply(name)
  if not ok then
    vim.notify(err, vim.log.levels.WARN)
    return
  end
  vim.notify("Preview: " .. name .. " | Enter применить, Esc отменить")
end

local function commit()
  local name = selected_name()
  if not name then return end
  local ok, err = theme.apply(name)
  if not ok then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
  local saved, save_err = state.save(name)
  if not saved then
    theme.cancel_preview(original)
    vim.notify("Не удалось сохранить тему: " .. tostring(save_err), vim.log.levels.ERROR)
    return
  end
  theme.commit_preview()
  active = false
  actions.close(vim.api.nvim_get_current_buf())
  vim.notify("Тема сохранена: " .. name)
end

local function cancel()
  theme.cancel_preview(original)
  active = false
  actions.close(vim.api.nvim_get_current_buf())
end

local function open(filter)
  action_state = require("telescope.actions.state")
  actions = require("telescope.actions")
  finders = require("telescope.finders")
  pickers = require("telescope.pickers")
  conf = require("telescope.config").values

  local items = theme.list(filter or "all")
  if #items == 0 then
    vim.notify("Нет доступных тем для фильтра: " .. tostring(filter), vim.log.levels.WARN)
    return
  end

  pickers.new({}, {
    prompt_title = title(filter),
    finder = finders.new_table({
      results = items,
      entry_maker = function(item)
        return {
          value = item,
          ordinal = item.name .. " " .. item.label .. " " .. item.mode .. " " .. item.group,
          display = format_item,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = false,
    attach_mappings = function(_, map)
      map("i", "<C-p>", preview)
      map("n", "p", preview)
      map("n", "d", function()
        actions.close(vim.api.nvim_get_current_buf())
        open("dark")
      end)
      map("n", "l", function()
        actions.close(vim.api.nvim_get_current_buf())
        open("light")
      end)
      map("n", "a", function()
        actions.close(vim.api.nvim_get_current_buf())
        open("all")
      end)
      map("n", "s", function()
        actions.close(vim.api.nvim_get_current_buf())
        open("system")
      end)
      map("n", "f", function()
        vim.notify("Избранное появится после добавления пользовательских тем")
      end)
      map("i", "<CR>", function()
        commit()
      end)
      map("n", "<CR>", function()
        commit()
      end)
      map("i", "<Esc>", function()
        cancel()
      end)
      map("n", "<Esc>", function()
        cancel()
      end)
      map("i", "<C-c>", function()
        cancel()
      end)
      map("n", "q", function()
        cancel()
      end)
      return true
    end,
  }):find()
end

function M.open()
  if active then return end
  active = true
  original = theme.begin_preview()
  open("all")
end

vim.api.nvim_create_user_command("VimSharpThemes", function() M.open() end, {})

return M
