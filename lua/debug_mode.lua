local M = {}

M.active = false
M.panel_buf = nil
M.panel_win = nil
M.target_win = nil
M.neo_win = nil
M.neo_buf = nil
M.neo_winhl = nil
M.neo_wrap = nil
M.neo_winfixwidth = nil
M.neo_was_open = false
M.neo_width = 34
M.history = {}
M.max_history = 8
M.log_file = vim.fn.stdpath("data") .. "/debug-mode.log"
M.pending = nil
M.frame_ns = vim.api.nvim_create_namespace("debug_mode_frame")

local keys = { "o", "i", "u", "c", "b", "x", "r", "e", "l", "<Esc>" }
local saved_maps = { n = {}, t = {} }
local dap_events = {
  "event_initialized",
  "event_continued",
  "event_stopped",
  "event_terminated",
  "event_exited",
}
local async_commands = { step_over = true, step_into = true, step_out = true, continue = true }

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

local function short_location()
  local location = current_location()
  if location == "no session" or location == "paused / frame unavailable" or location == "no dap" then
    return location
  end
  local file, line = location:match("([^/\\]+):([^ ]+)")
  return file and string.format("%s:%s", file, line) or location
end

local function short_event(text)
  local command, before, after = text:match("RESULT%s+(%S+)%s+|%s+focus=[^|]+|%s+([^|]+)%s+->%s+(.+)")
  if command then
    local before_line = before:match(":(%d+)") or "?"
    local after_line = after:match(":(%d+)") or "?"
    return string.format("✓ %s  %s→%s", command:gsub("step_", ""), before_line, after_line)
  end
  local request = text:match("(%S+)%s+REQUEST")
  if request then return "· " .. request:gsub("step_", "") .. " request" end
  local dap_name = text:match("DAP event_(%S+)")
  if dap_name then return "● " .. dap_name:gsub("_", " ") end
  if text:find("ERROR") or text:find("session ended") then return "! " .. text:gsub("^.-|%s*", "") end
  return text:sub(1, 34)
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
  if async_commands[name] then
    local ok, dap = pcall(require, "dap")
    local session = ok and dap.session() or nil
    if not session then
      event(name .. " | ERROR: no active session")
      vim.notify("Debug Mode: нет активной сессии", vim.log.levels.WARN)
      return
    end
    if not session.stopped_thread_id then
      event(name .. " | ERROR: no stopped thread")
      vim.notify("Debug Mode: нет остановленного потока", vim.log.levels.WARN)
      return
    end
  end
  local before = current_location()
  local target = focus_name()
  local ok, err = pcall(function()
    if name ~= "open repl" and name ~= "code window" then
      goto_target()
    end
    action()
  end)
  if ok then
    if async_commands[name] then
      M.pending = { name = name, target = target, before = before }
      event(name .. " REQUEST | focus=" .. target .. " | " .. before)
    else
      event(name .. " | focus=" .. target .. " | " .. before .. " -> " .. current_location())
    end
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
  local thread = session and (session.stopped_thread_id and "thread: stopped" or "thread: none") or "thread: -"
  local lines = {
    "╭─ DEBUG MODE ───────────────╮",
    "│ " .. (M.active and "● ACTIVE" or "○ OFF") .. " | " .. state,
    "│ " .. thread,
    "│ target: " .. target_name():sub(1, 22),
    "│ location: " .. short_location():sub(1, 20),
    "",
    "│ o over  i into  u out",
    "│ c cont  b break x stop",
    "│ r repl  e code  l log",
    "│ Esc close",
    "",
    "│ LAST / HISTORY",
  }
  for i = #M.history, 1, -1 do table.insert(lines, "│ " .. short_event(M.history[i])) end
  table.insert(lines, "╰─────────────────────────────╯")
  return lines
end

function M.refresh()
  if not M.panel_buf or not vim.api.nvim_buf_is_valid(M.panel_buf) then return end
  vim.bo[M.panel_buf].modifiable = true
  local lines = panel_lines()
  vim.api.nvim_buf_set_lines(M.panel_buf, 0, -1, false, lines)
  vim.bo[M.panel_buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(M.panel_buf, M.frame_ns, 0, -1)
  vim.api.nvim_buf_add_highlight(M.panel_buf, M.frame_ns, "DebugModeBorder", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(M.panel_buf, M.frame_ns, "DebugModeBorder", #lines - 1, 0, -1)
  for row = 1, #lines - 2 do
    vim.api.nvim_buf_add_highlight(M.panel_buf, M.frame_ns, "DebugModeBorder", row, 0, 1)
  end
  if M.panel_win and vim.api.nvim_win_is_valid(M.panel_win) then
    vim.api.nvim_win_set_option(M.panel_win, "winhl", "Normal:DebugModePanel,EndOfBuffer:DebugModePanel,WinSeparator:DebugModeBorder,StatusLine:DebugModeBorder")
  end
end

local function find_neo_window()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "neo-tree" then return win, buf end
  end
end

local function open_panel()
  if M.panel_win and vim.api.nvim_win_is_valid(M.panel_win) then return end
  M.neo_win, M.neo_buf = find_neo_window()
  if M.neo_win and vim.api.nvim_win_is_valid(M.neo_win) then
    M.neo_was_open = true
    M.neo_width = vim.api.nvim_win_get_width(M.neo_win)
    M.neo_winhl = vim.wo[M.neo_win].winhl
    M.neo_wrap = vim.wo[M.neo_win].wrap
    M.neo_winfixwidth = vim.wo[M.neo_win].winfixwidth
    pcall(vim.cmd, "Neotree close")
    M.neo_win, M.neo_buf = nil, nil
  end
  M.panel_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[M.panel_buf].filetype = "debug_mode"
  vim.bo[M.panel_buf].bufhidden = "wipe"
  vim.bo[M.panel_buf].modifiable = false
  vim.cmd("topleft vertical " .. tostring(M.neo_width) .. "new")
  M.panel_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(M.panel_win, M.panel_buf)
  vim.api.nvim_win_set_option(M.panel_win, "winfixwidth", true)
  vim.api.nvim_win_set_option(M.panel_win, "wrap", false)
  M.refresh()
end

local function close_panel()
  if M.panel_win and vim.api.nvim_win_is_valid(M.panel_win) then
    vim.api.nvim_win_close(M.panel_win, true)
    if M.neo_was_open then
      pcall(vim.cmd, "Neotree show left")
    end
  end
  M.panel_win, M.panel_buf = nil, nil
  M.neo_win, M.neo_buf = nil, nil
  M.neo_winhl, M.neo_wrap, M.neo_winfixwidth = nil, nil, nil
  M.neo_was_open, M.neo_width = false, 34
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
  M.pending = nil
  M.target_win = nil
  restore_maps()
  pcall(vim.keymap.del, "n", "<Esc>")
  close_panel()
end

function M.on_dap(name)
  return function()
    if not M.active then return end
    if name == "event_stopped" and M.pending then
      local pending = M.pending
      M.pending = nil
      event(string.format("RESULT %s | focus=%s | %s -> %s", pending.name, pending.target, pending.before, current_location()))
    elseif (name == "event_terminated" or name == "event_exited") and M.pending then
      local pending = M.pending
      M.pending = nil
      event(string.format("RESULT %s | session ended before stop | %s", pending.name, current_location()))
      event("DAP " .. name .. " | " .. current_location())
    else
      event("DAP " .. name .. " | " .. current_location())
    end
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


