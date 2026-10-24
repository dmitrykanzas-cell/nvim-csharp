-- Описания клавиш для which-key с переключением RU/EN (<leader>u).
-- which-key вызывает функцию desc при каждой отрисовке, поэтому язык
-- меняется сразу, без перезапуска.
local M = {}

M.lang = "ru"

local function t(ru, en)
  return function()
    return M.lang == "ru" and ru or en
  end
end

local groups = {
  { "<leader>f", "Поиск", "Find" },
  { "<leader>l", "Код (LSP)", "Code (LSP)" },
  { "<leader>r", "Запуск .NET", "Run .NET" },
  { "<leader>d", "Отладка", "Debug" },
  { "<leader>g", "Git", "Git" },
}

local keys = {
  { "<leader>e", "Дерево файлов", "File tree" },
  { "<leader>u", "Язык подсказок RU/EN", "Hint language RU/EN" },
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
  { "<leader>rr", "Запустить проект", "Run project" },
  { "<leader>rt", "Запустить тесты", "Run tests" },
  { "<leader>rs", "Меню .NET", ".NET menu" },
  { "<leader>db", "Breakpoint вкл/выкл", "Toggle breakpoint" },
  { "<leader>dc", "Старт / продолжить", "Start / continue" },
  { "<leader>do", "Шаг через (over)", "Step over" },
  { "<leader>di", "Шаг внутрь (into)", "Step into" },
  { "<leader>du", "Шаг наружу (out)", "Step out" },
  { "<leader>dx", "Остановить отладку", "Stop debugging" },
  { "<leader>dd", "Окна отладки показать/скрыть", "Toggle debug windows" },
  { "<leader>dr", "REPL", "REPL" },
  { "<leader>dh", "Переменные (всплывающее окно)", "Variables (float)" },
  { "<leader>de", "Вернуться в код", "Back to code" },
  { "<F5>", "Отладка: старт / продолжить", "Debug: start / continue" },
  { "<S-F5>", "Отладка: остановить", "Debug: stop" },
  { "<F9>", "Breakpoint вкл/выкл", "Toggle breakpoint" },
  { "<F10>", "Шаг через (over)", "Step over" },
  { "<F11>", "Шаг внутрь (into)", "Step into" },
  { "<S-F11>", "Шаг наружу (out)", "Step out" },
  { "<C-F5>", "Запустить без отладки", "Run without debugging" },
  { "<leader>gj", "Следующее изменение", "Next hunk" },
  { "<leader>gk", "Предыдущее изменение", "Previous hunk" },
  { "<leader>gp", "Показать изменение", "Preview hunk" },
  { "<leader>gr", "Откатить изменение", "Reset hunk" },
  { "<leader>gs", "Добавить в stage", "Stage hunk" },
  { "<leader>gu", "Убрать из stage", "Undo stage hunk" },
}

function M.spec()
  local spec = {}
  for _, g in ipairs(groups) do
    table.insert(spec, { g[1], group = t(g[2], g[3]) })
  end
  for _, k in ipairs(keys) do
    table.insert(spec, { k[1], desc = t(k[2], k[3]) })
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
        desc = t(k[2], k[3]),
        hidden = #rest == 1,
      })
    end
  end
  for _, g in ipairs(groups) do
    local ru = g[1]:sub(-1):gsub("%l", M.ru)
    table.insert(spec, { "<leader>" .. ru, group = t(g[2], g[3]), hidden = true })
  end
  return spec
end

-- Клавиша латиницы -> та же клавиша в русской раскладке ЙЦУКЕН.
M.ru = {
  q = "й", w = "ц", e = "у", r = "к", t = "е", y = "н", u = "г", i = "ш", o = "щ", p = "з",
  a = "ф", s = "ы", d = "в", f = "а", g = "п", h = "р", j = "о", k = "л", l = "д",
  z = "я", x = "ч", c = "с", v = "м", b = "и", n = "т", m = "ь",
}

function M.toggle()
  M.lang = M.lang == "ru" and "en" or "ru"
  vim.notify(M.lang == "ru" and "Подсказки: русский" or "Hints: English")
end

return M
