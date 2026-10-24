-- Описания клавиш для which-key с переключением RU/EN (<leader>u).
-- which-key вызывает функцию desc при каждой отрисовке, поэтому язык
-- и состояние отладки меняются сразу, без перезапуска.
local M = {}

M.lang = "ru"

-- Идёт ли сейчас сессия отладки (dap не загружаем ради проверки).
local function session()
  return package.loaded.dap ~= nil and require("dap").session() ~= nil
end

-- k = { lhs, ru, en, hotkey?, needs_session? }
local function desc(k)
  return function()
    local text = M.lang == "ru" and k[2] or k[3]
    if k[4] then
      text = text .. "   " .. k[4]
    end
    if k[5] and not session() then
      text = text .. (M.lang == "ru" and "  · нет сессии" or "  · no session")
    end
    return text
  end
end

-- Порядок в меню = порядок здесь (sort = "manual" в plugins/init.lua).
local groups = {
  { "<leader>r", "Запуск .NET", "Run .NET", icon = { icon = "", color = "green" } },
  {
    "<leader>d", "Отладка", "Debug", icon = { icon = "", color = "red" },
    -- Заголовок показывает, идёт ли отладка.
    status = function() return session() and (M.lang == "ru" and "  ● идёт сессия" or "  ● running") or "" end,
  },
  { "<leader>f", "Поиск", "Find", icon = { icon = "", color = "azure" } },
  { "<leader>l", "Код (LSP)", "Code (LSP)", icon = { icon = "", color = "purple" } },
  { "<leader>g", "Git", "Git", icon = { icon = "", color = "orange" } },
}

local keys = {
  { "<leader>e", "Дерево файлов", "File tree", icon = { icon = "󰙅", color = "yellow" } },
  { "<leader>u", "Язык подсказок RU/EN", "Hint language RU/EN", icon = { icon = "", color = "grey" } },
  -- Запуск: по частоте.
  { "<leader>rr", "Запустить проект", "Run project", "Ctrl+F5" },
  { "<leader>rt", "Запустить тесты", "Run tests" },
  { "<leader>rs", "Меню .NET (build, restore, проект)", ".NET menu (build, restore, project)" },
  -- Отладка: в порядке сценария.
  { "<leader>db", "Breakpoint вкл/выкл", "Toggle breakpoint", "F9" },
  { "<leader>dc", "Старт / продолжить", "Start / continue", "F5" },
  { "<leader>do", "Шаг через (over)", "Step over", "F10", true },
  { "<leader>di", "Шаг внутрь (into)", "Step into", "F11", true },
  { "<leader>du", "Шаг наружу (out)", "Step out", "Shift+F11", true },
  { "<leader>dx", "Остановить отладку", "Stop debugging", "Shift+F5", true },
  { "<leader>dD", "Режим отладки (меню не закрывается)", "Debug mode (sticky menu)" },
  { "<leader>dh", "Переменные (всплывающее окно)", "Variables (float)", nil, true },
  { "<leader>de", "Вернуться в код", "Back to code" },
  { "<leader>dd", "Окна отладки показать/скрыть", "Toggle debug windows" },
  { "<leader>dr", "REPL", "REPL" },
  { "<leader>ff", "Найти файл", "Find file" },
  { "<leader>fg", "Найти текст", "Find text" },
  { "<leader>fb", "Открытые файлы", "Open buffers" },
  { "<leader>fs", "Символы файла", "File symbols" },
  { "<leader>fp", "Символы проекта", "Project symbols" },
  { "<leader>fk", "Найти клавишу", "Find keymap" },
  { "<leader>lr", "Переименовать символ", "Rename symbol" },
  { "<leader>la", "Исправления (code action)", "Code action" },
  { "<leader>lf", "Форматировать", "Format" },
  { "<leader>ld", "Ошибка в строке", "Line diagnostic" },
  { "<leader>li", "Кто вызывает", "Incoming calls" },
  { "<leader>lo", "Что вызывает", "Outgoing calls" },
  { "<leader>gj", "Следующее изменение", "Next hunk" },
  { "<leader>gk", "Предыдущее изменение", "Previous hunk" },
  { "<leader>gp", "Показать изменение", "Preview hunk" },
  { "<leader>gr", "Откатить изменение", "Reset hunk" },
  { "<leader>gs", "Добавить в stage", "Stage hunk" },
  { "<leader>gu", "Убрать из stage", "Undo stage hunk" },
  -- F-клавиши как в Visual Studio.
  { "<F5>", "Отладка: старт / продолжить", "Debug: start / continue" },
  { "<S-F5>", "Отладка: остановить", "Debug: stop" },
  { "<F9>", "Breakpoint вкл/выкл", "Toggle breakpoint" },
  { "<F10>", "Шаг через (over)", "Step over" },
  { "<F11>", "Шаг внутрь (into)", "Step into" },
  { "<S-F11>", "Шаг наружу (out)", "Step out" },
  { "<C-F5>", "Запустить без отладки", "Run without debugging" },
}

-- Клавиша латиницы -> та же клавиша в русской раскладке ЙЦУКЕН.
M.ru = {
  q = "й", w = "ц", e = "у", r = "к", t = "е", y = "н", u = "г", i = "ш", o = "щ", p = "з",
  a = "ф", s = "ы", d = "в", f = "а", g = "п", h = "р", j = "о", k = "л", l = "д",
  z = "я", x = "ч", c = "с", v = "м", b = "и", n = "т", m = "ь",
}

local function group_desc(g)
  return function()
    return (M.lang == "ru" and g[2] or g[3]) .. (g.status and g.status() or "")
  end
end

function M.spec()
  local spec = {}
  for _, g in ipairs(groups) do
    table.insert(spec, { g[1], group = group_desc(g), icon = g.icon })
  end
  for _, k in ipairs(keys) do
    table.insert(spec, { k[1], desc = desc(k), icon = k.icon })
  end
  -- Русская раскладка: <leader>ви работает как <leader>db.
  -- Русские группы скрыты в главном меню (чтобы не было дублей),
  -- но внутри группы, например после <leader>в, подсказки видны.
  for _, k in ipairs(keys) do
    local rest = k[1]:match("^<leader>(%l+)$")
    if rest then
      local ru = rest:gsub("%l", M.ru)
      local en = vim.api.nvim_replace_termcodes(k[1], true, true, true)
      table.insert(spec, {
        "<leader>" .. ru,
        function() vim.api.nvim_feedkeys(en, "m", false) end,
        desc = desc(k),
        hidden = #rest == 1,
      })
    end
  end
  for _, g in ipairs(groups) do
    local ru = g[1]:sub(-1):gsub("%l", M.ru)
    table.insert(spec, { "<leader>" .. ru, group = group_desc(g), hidden = true })
  end
  return spec
end

function M.toggle()
  M.lang = M.lang == "ru" and "en" or "ru"
  vim.notify(M.lang == "ru" and "Подсказки: русский" or "Hints: English")
end

return M
