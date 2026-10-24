local M = {}

M.active = false
M.panel_buf = nil
M.panel_win = nil
M.target_win = nil
M.history = {}
M.max_history = 8
M.log_file = vim.fn.stdpath("data") .. "/debug-mode.log"

local keys = { "o", "i", "u", "c", "b", "x", "r", "e", "l", "<Esc>" }
local saved_maps = { n = {}, t = {} }
local dap_events = {
  "event_initialized",
  "event_continued",
  "event_stopped",
  "event_terminated",
  "event_exited",
}

local function safe_name(value)
  return value and tostring(value):gsub("\n", " ") or "-"
end

local function current_location()
  local ok, dap = pcall(require, "dap")
  if not ok then return "no dap" end
  local session = dap.session()
  if not session then return "no session" end
  local frame = session.current_frame
  if not frame then return "paused / frame unavailable" end
  local source = frame.source and (frame.source.path or frame.source.name) or "?"
  return string.format("%s:%s  %s()", safe_name(source), frame.line or "?", safe_name(frame.name))
end

local function focus_name()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local ft = vim.bo[buf].filetype
  local bt = vim.bo[buf].buftype
  if ft == "neo-tree" then return "Neo-tree" end
  if bt == "terminal" then return "terminal / REPL" end
  if ft == "dapui_stacks" or ft == "dapui_scopes" or ft == "dapui_watches" then return "DAP UI" end
  return string.format("code #%d  %s:%d", win, vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t"), vim.api.nvim_win_get_cursor(win)[1])
end

local function target_name()
  if M.target_win and vim.api.nvim_win_is_valid(M.target_win) then
    local buf = vim.api.nvim_win_get_buf(M.target_win)
    return string.format("code #%d  %s:%d", M.target_win, vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t"), vim.api.nvim_win_get_cursor(M.target_win)[1])
  end
  return "code window unavailable"
end

local function goto_target()
  if M.target_win and vim.api.nvim_win_is_valid(M.target_win) then
    vim.api.nvim_set_current_win(M.target_win)
  else
    _G.goto_code_window()
    M.target_win = vim.api.nvim_get_current_win()
  end
end

local function append_log(line)
  local ok, err = pcall(vim.fn.writefile, { os.date("%Y-%m-%d %H:%M:%S ") .. line }, M.log_file, "a")
  if not ok then vim.notify("Debug Mode: не удалось записать лог: " .. tostring(err), vim.log.levels.WARN) end
end

local function event(text)
  text = safe_name(text)
  table.insert(M.history, text)
  while #M.history > M.max_history do table.remove(M.history, 1) end
  append_log(text)
  M.refresh()
end

local function run(name, action)
  local before = current_location()
  local target = focus_name()
  local ok, err = pcall(function()
    if name ~= "open repl" and name ~= "code window" then
      goto_target()
    end
    action()
  end)
  if ok then
    event(name .. " | focus=" .. target .. " | " .. before .. " -> " .. current_location())
  else
    event(name .. " | ERROR: " .. tostring(err))
    vim.notify("Debug Mode: " .. tostring(err), vim.log.levels.ERROR)
  end
end

local function map_active(mode, key, callback, desc)
  local existing = vim.fn.maparg(key, mode, false, true)
  saved_maps[mode][key] = existing and next(existing) and existing or false
  pcall(vim.keymap.del, mode, key)
  vim.keymap.set(mode, key, callback, { silent = true, desc = desc })
end

local function restore_maps()
  for _, mode in ipairs({ "n", "t" }) do
    for _, key in ipairs(keys) do
      pcall(vim.keymap.del, mode, key)
      local map = saved_maps[mode][key]
      if map then
        vim.keymap.set(mode, key, map.rhs, {
          expr = map.expr == 1,
          noremap = map.noremap == 1,
          silent = map.silent == 1,
          nowait = map.nowait == 1,
          desc = map.desc,
        })
      end
    end
  end
  saved_maps = { n = {}, t = {} }
end

local function panel_lines()
  local ok, dap = pcall(require, "dap")
  local session = ok and dap.session() or nil
  local state = session and (session.stopped_thread_id and "PAUSED" or "RUNNING") or "NO SESSION"
  local lines = {
    " DEBUG MODE  " .. (M.active and "● ACTIVE" or "○ OFF") .. "  |  " .. state,
    " target: " .. target_name(),
    " location: " .. current_location(),
    "",
    " o step over    i step into    u step out",
    " c continue     b breakpoint   x stop",
    " r REPL         e code window   l full log",
    " Esc close mode",
    "",
    " HISTORY (latest first):",
  }
  for i = #M.history, 1, -1 do table.insert(lines, " " .. M.history[i]) end
  return lines
end

function M.refresh()
  if not M.panel_buf or not vim.api.nvim_buf_is_valid(M.panel_buf) then return end
  vim.bo[M.panel_buf].modifiable = true
  vim.api.nvim_buf_set_lines(M.panel_buf, 0, -1, false, panel_lines())
  vim.bo[M.panel_buf].modifiable = false
  if M.panel_win and vim.api.nvim_win_is_valid(M.panel_win) then
    vim.api.nvim_win_set_option(M.panel_win, "winhl", "Normal:DebugModePanel,FloatBorder:DebugModeBorder")
  end
end

local function open_panel()
  if M.panel_win and vim.api.nvim_win_is_valid(M.panel_win) then return end
  M.panel_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[M.panel_buf].filetype = "debug_mode"
  vim.bo[M.panel_buf].bufhidden = "wipe"
  vim.bo[M.panel_buf].modifiable = false
  local width = math.min(82, math.max(60, vim.o.columns - 8))
  local height = math.min(16, math.max(10, vim.o.lines - 8))
  M.panel_win = vim.api.nvim_open_win(M.panel_buf, false, {
    relative = "editor", row = vim.o.lines - height - 3, col = vim.o.columns - width - 2,
    width = width, height = height, style = "minimal", border = "rounded",
    title = " Debug control panel ", title_pos = "center",
  })
  vim.api.nvim_win_set_option(M.panel_win, "wrap", false)
  M.refresh()
end

local function close_panel()
  if M.panel_win and vim.api.nvim_win_is_valid(M.panel_win) then vim.api.nvim_win_close(M.panel_win, true) end
  M.panel_win, M.panel_buf = nil, nil
end

function M.toggle()
  if M.active then return M.stop() end
  M.active = true
  M.target_win = vim.api.nvim_get_current_win()
  if vim.bo[vim.api.nvim_win_get_buf(M.target_win)].buftype ~= "" then
    _G.goto_code_window()
    M.target_win = vim.api.nvim_get_current_win()
  end
  vim.api.nvim_set_hl(0, "DebugModePanel", { link = "NormalFloat" })
  vim.api.nvim_set_hl(0, "DebugModeBorder", { fg = "Yellow", bold = true })
  open_panel()
  local actions = {
    o = function() run("step_over", function() require("dap").step_over() end) end,
    i = function() run("step_into", function() require("dap").step_into() end) end,
    u = function() run("step_out", function() require("dap").step_out() end) end,
    c = function() run("continue", function() require("dap").continue() end) end,
    b = function() run("breakpoint", function() _G.toggle_breakpoint() end) end,
    x = function() run("terminate", function() require("dap").terminate() end) end,
    r = function() run("open repl", function() require("dap").repl.toggle() end) end,
    e = function() run("code window", function() _G.goto_code_window() end) end,
    l = function() vim.cmd("edit " .. vim.fn.fnameescape(M.log_file)) end,
    ["<Esc>"] = M.stop,
  }
  for _, key in ipairs(keys) do
    map_active("n", key, actions[key], "Debug Mode: " .. key)
    map_active("t", key, actions[key], "Debug Mode: " .. key)
  end
  event("MODE ON | target=" .. target_name())
end

function M.stop()
  if not M.active then return end
  event("MODE OFF | target=" .. target_name())
  M.active = false
  M.target_win = nil
  restore_maps()
  pcall(vim.keymap.del, "n", "<Esc>")
  close_panel()
end

function M.on_dap(name)
  return function()
    if M.active then event("DAP " .. name .. " | " .. current_location()) end
  end
end

function M.setup()
  local dap = require("dap")
  for _, name in ipairs(dap_events) do
    dap.listeners.after[name]["debug_mode"] = M.on_dap(name)
  end
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "VimResized" }, { callback = function() if M.active then M.refresh() end end })
  vim.api.nvim_create_autocmd("VimLeavePre", { callback = function() if M.active then append_log("MODE EXIT | Neovim closed") end end })
end

return M


