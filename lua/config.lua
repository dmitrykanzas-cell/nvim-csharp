vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.clipboard = "unnamedplus"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.termguicolors = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.timeoutlen = 500
vim.opt.updatetime = 250
vim.opt.splitright = true
vim.opt.splitbelow = true

vim.keymap.set("i", "jj", "<Esc>", { desc = "Выйти из режима вставки" })
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Убрать подсветку поиска" })
vim.keymap.set("n", "U", "<C-r>", { desc = "Повторить отменённое действие" })
vim.keymap.set("n", "j", "gj", { desc = "Строка ниже" })
vim.keymap.set("n", "k", "gk", { desc = "Строка выше" })
vim.keymap.set("v", "p", "P", { desc = "Вставить без замены буфера" })
vim.keymap.set("v", "P", "p", { desc = "Вставить с заменой буфера" })

vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({ timeout = 150 })
  end,
})

vim.diagnostic.config({
  virtual_text = { spacing = 2, prefix = "●" },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = { border = "rounded", source = "if_many" },
})

-- [d / ]d встроены в Neovim 0.12, свои не нужны.
vim.keymap.set("n", "<leader>ld", vim.diagnostic.open_float, { desc = "Ошибка в строке" })

-- Переход между окнами. Режим "t" нужен для REPL/Console отладки и терминала.
for key, dir in pairs({ ["<C-h>"] = "h", ["<C-j>"] = "j", ["<C-k>"] = "k", ["<C-l>"] = "l" }) do
  vim.keymap.set("n", key, "<C-w>" .. dir, { desc = "Окно " .. dir })
  vim.keymap.set("t", key, "<C-\\><C-n><C-w>" .. dir, { desc = "Окно " .. dir })
end

-- Активное окно видно по подсветке строки: cursorline только в нём.
local function is_code_win(win)
  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].buftype == "" and vim.api.nvim_win_get_config(win).relative == ""
    and vim.bo[buf].filetype ~= "neo-tree"
end

local last_code_win
vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
  callback = function()
    vim.wo.cursorline = true
    local win = vim.api.nvim_get_current_win()
    if is_code_win(win) then last_code_win = win end
  end,
})
vim.api.nvim_create_autocmd("WinLeave", {
  callback = function()
    vim.wo.cursorline = false
    -- При уходе из окна его буфер уже окончательный (в отличие от WinEnter,
    -- когда плагин мог ещё не подставить свой буфер).
    local win = vim.api.nvim_get_current_win()
    if is_code_win(win) then last_code_win = win end
  end,
})

-- Вернуться в последнее окно с кодом (из дерева, DAP, REPL).
function _G.goto_code_window()
  if is_code_win(vim.api.nvim_get_current_win()) then return end
  if last_code_win and vim.api.nvim_win_is_valid(last_code_win) and is_code_win(last_code_win) then
    vim.api.nvim_set_current_win(last_code_win)
    return
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_code_win(win) then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
  vim.notify("Нет открытого окна с кодом")
end

-- Действие над кодом: если фокус в дереве/DAP/REPL, сначала вернуться в код.
-- Иначе, например, breakpoint из Neo-tree молча не ставится.
function _G.in_code(fn)
  _G.goto_code_window()
  fn()
end

-- Breakpoint с подтверждением: без сообщения непонятно, сработала ли клавиша.
function _G.toggle_breakpoint()
  _G.in_code(function()
    local dap = require("dap")
    dap.toggle_breakpoint()
    local buf, line = vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0)[1]
    local set = false
    for _, bp in ipairs(require("dap.breakpoints").get(buf)[buf] or {}) do
      if bp.line == line then set = true end
    end
    vim.notify((set and "Breakpoint поставлен" or "Breakpoint снят") .. ": строка " .. line)
  end)
end

vim.keymap.set("n", "<leader>u", function() require("hints").toggle() end, { desc = "Язык подсказок RU/EN" })
