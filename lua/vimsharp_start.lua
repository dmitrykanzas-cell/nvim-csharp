local M = {}

local ns = vim.api.nvim_create_namespace("vimsharp_start")
local title = "VimSharp Start"

local function workspace()
  return vim.fn.getcwd()
end

local function path_display(path, width)
  path = vim.fn.fnamemodify(path, ":~")
  if #path <= width then return path end
  return "…" .. path:sub(-(width - 1))
end

local function has_active_dap()
  local ok, dap = pcall(require, "dap")
  return ok and dap.session() ~= nil
end

local function roslyn_status()
  local clients = vim.lsp.get_clients()
  for _, client in ipairs(clients) do
    if client.name == "roslyn" then return "connected" end
  end
  return "not attached"
end

local function git_status()
  local output = vim.fn.systemlist({ "git", "-C", workspace(), "status", "--porcelain" })
  if vim.v.shell_error ~= 0 then return "unavailable" end
  return #output == 0 and "clean" or "modified"
end

local function dotnet_status()
  vim.fn.system({ "dotnet", "--version" })
  return vim.v.shell_error == 0 and "available" or "not found"
end

local function status_lines()
  local root = workspace()
  local width = math.max(24, vim.o.columns - 10)
  local lines = {
    "Workspace: " .. path_display(root, width),
    "Roslyn: " .. roslyn_status() .. "    DAP: " .. (has_active_dap() and "active" or "no session"),
    ".NET: " .. dotnet_status() .. "    Git: " .. git_status(),
  }
  return lines
end

local function project_files()
  local result = {}
  local seen = {}
  for _, pattern in ipairs({ "**/*.sln", "**/*.slnx", "**/*.csproj" }) do
    for _, path in ipairs(vim.fn.globpath(workspace(), pattern, true, true)) do
      if not seen[path] then
        seen[path] = true
        table.insert(result, path)
      end
    end
  end
  table.sort(result)
  return result
end

local function choose_project()
  local files = project_files()
  if #files == 0 then
    vim.notify("В текущем каталоге solution/project не найден", vim.log.levels.WARN)
    return
  end
  vim.ui.select(files, {
    prompt = "Solution / project: ",
    format_item = function(path) return vim.fn.fnamemodify(path, ":~:.") end,
  }, function(path)
    if not path then return end
    vim.cmd("edit " .. vim.fn.fnameescape(path))
  end)
end

local function action_at_cursor(buf)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
  local number = line:match("%[(%d)%]")
  if number then
    return ({
      ["1"] = "workspace", ["2"] = "project", ["3"] = "workspace",
      ["4"] = "file", ["5"] = "buffers", ["6"] = "dotnet",
      ["7"] = "test", ["8"] = "lsp", ["9"] = "dap", ["T"] = "themes",
    })[number]
  end
  if line:match("%[T%]") then return "themes" end
  if line:match("%[%?%]") then return "help" end
end

local function move_to_action(buf, direction)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local step = direction > 0 and 1 or -1
  for index = row + step, direction > 0 and #lines or 1, step do
    if lines[index]:match("%[%d%]") or lines[index]:match("%[%?%]") then
      vim.api.nvim_win_set_cursor(0, { index, 0 })
      return
    end
  end
end

local function run(action)
  if action == "workspace" then
    require("vimsharp_start").close()
    vim.cmd("Neotree toggle reveal")
  elseif action == "project" then
    require("vimsharp_start").close()
    choose_project()
  elseif action == "file" then
    require("vimsharp_start").close()
    vim.cmd("Telescope find_files")
  elseif action == "buffers" then
    require("vimsharp_start").close()
    vim.cmd("Telescope buffers")
  elseif action == "dotnet" then
    require("vimsharp_start").close()
    vim.cmd("Dotnet")
  elseif action == "test" then
    require("vimsharp_start").close()
    vim.cmd("Dotnet test")
  elseif action == "lsp" then
    vim.cmd("LspInfo")
  elseif action == "dap" then
    local active = has_active_dap()
    vim.notify("DAP: " .. (active and "активная сессия" or "сессии нет"))
  elseif action == "themes" then
    require("vimsharp_theme_picker").open()
  elseif action == "help" then
    vim.notify("<leader>e Neo-tree | <leader>ff файл | <leader>rr run | <leader>rt тесты | <leader>dm DebugMode")
  end
end

local function render(buf)
  local compact = vim.o.columns < 80 or vim.o.lines < 22
  local lines = { title, "C# / .NET workspace launcher", "" }
  if compact then
    vim.list_extend(lines, {
      "ACTIONS",
      "> [1] Open current workspace",
      "  [2] Open solution / project",
      "  [3] Open Neo-tree",
      "  [4] Find file",
      "  [5] Recent buffers",
      "  [6] .NET menu",
      "  [7] Run tests",
      "  [8] LSP / Roslyn status",
      "  [9] DAP status",
      "  [T] Themes / Темы",
      "  [?] Keymap help",
      "",
      "Workspace: " .. path_display(workspace(), math.max(24, vim.o.columns - 14)),
      "",
      "Enter/o open   j/k move   r refresh   q quit",
    })
  else
    vim.list_extend(lines, {
      "ACTIONS",
      "> [1] Open current workspace",
      "  [2] Open solution / project",
      "  [3] Open Neo-tree",
      "  [4] Find file",
      "  [5] Recent buffers",
      "",
      ".NET",
      "  [6] .NET menu",
      "  [7] Run tests",
      "",
      "TOOLS",
      "  [8] LSP / Roslyn status",
      "  [9] DAP status",
      "  [T] Themes / Темы",
      "  [?] Keymap help",
      "",
      "STATUS",
    })
    vim.list_extend(lines, status_lines())
    vim.list_extend(lines, {
      "",
      "Enter/o open   j/k move   r refresh   q quit",
    })
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, ns, "Title", 0, 0, -1)
  for index, line in ipairs(lines) do
    if line == "ACTIONS" or line == ".NET" or line == "TOOLS" or line == "STATUS" then
      vim.api.nvim_buf_add_highlight(buf, ns, "Directory", index - 1, 0, -1)
    end
  end
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
end

function M.close()
  if vim.api.nvim_buf_is_valid(vim.api.nvim_get_current_buf()) and vim.bo.filetype == "vimsharp-start" then
    vim.cmd("enew")
  end
end

function M.open()
  local current = vim.api.nvim_get_current_buf()
  if vim.bo[current].modified then
    vim.notify("Нельзя открыть VimSharp Start поверх несохранённых изменений", vim.log.levels.WARN)
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "vimsharp-start"
  vim.bo[buf].modifiable = true
  render(buf)

  local opts = { buffer = buf, silent = true, nowait = true }
  local actions = {
    ["1"] = "workspace", ["2"] = "project", ["3"] = "workspace",
    ["4"] = "file", ["5"] = "buffers", ["6"] = "dotnet",
    ["7"] = "test", ["8"] = "lsp", ["9"] = "dap", ["T"] = "themes", ["?"] = "help",
  }
  for key, action in pairs(actions) do
    vim.keymap.set("n", key, function() run(action) end, opts)
  end
  vim.keymap.set("n", "<CR>", function()
    local action = action_at_cursor(buf)
    if action then run(action) end
  end, opts)
  vim.keymap.set("n", "o", function()
    local action = action_at_cursor(buf)
    if action then run(action) end
  end, opts)
  vim.keymap.set("n", "j", function() move_to_action(buf, 1) end, opts)
  vim.keymap.set("n", "k", function() move_to_action(buf, -1) end, opts)
  vim.keymap.set("n", "r", function() render(buf) end, opts)
  vim.keymap.set("n", "q", function() M.close() end, opts)
  vim.keymap.set("n", "<Esc>", function() M.close() end, opts)
end

vim.api.nvim_create_user_command("VimSharpStart", function() M.open() end, {})

return M
