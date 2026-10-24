return {
  {
    "folke/lazy.nvim",
    version = "^11.0",
  },
  {
    "nvim-lua/plenary.nvim",
    lazy = true,
  },
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Файлы / Files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Текст / Text" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Буферы / Buffers" },
      { "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>", desc = "Символы файла / Symbols" },
      { "<leader>fp", "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>", desc = "Символы проекта / Project symbols" },
      { "<leader>fk", "<cmd>Telescope keymaps<cr>", desc = "Найти клавишу" },
    },
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    -- `vimsharp .`: загрузить дерево сразу, иначе вместо него откроется netrw.
    init = function()
      local arg = vim.fn.argv(0)
      if vim.fn.argc() == 1 and type(arg) == "string" and vim.fn.isdirectory(arg) == 1 then
        require("lazy").load({ plugins = { "neo-tree.nvim" } })
      end
    end,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      close_if_last_window = true,
      popup_border_style = "rounded",
      filesystem = {
        follow_current_file = { enabled = true },
        hijack_netrw_behavior = "open_default",
        use_libuv_file_watcher = true,
      },
      window = {
        position = "left",
        width = 34,
        mappings = {
          ["<space>"] = "none",
          ["<cr>"] = "open",
          ["o"] = "open",
          ["s"] = "open_split",
          ["v"] = "open_vsplit",
          ["t"] = "open_tabnew",
          ["a"] = "add",
          ["d"] = "delete",
          ["r"] = "rename",
          ["c"] = "copy",
          ["m"] = "move",
          ["R"] = "refresh",
          ["q"] = "close_window",
        },
      },
    },
    keys = {
      { "<leader>e", "<cmd>Neotree toggle reveal<cr>", desc = "Дерево файлов" },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    opts = {
      ensure_installed = { "c_sharp", "lua", "vim", "vimdoc", "query", "json", "xml" },
      highlight = { enable = true },
      indent = { enable = true },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = function()
      return {
        delay = 200,
        preset = "modern",
        -- Порядок пунктов как в lua/hints.lua (по ходу работы), а не по алфавиту.
        sort = { "local", "manual", "group", "alphanum", "mod" },
        -- Группы и описания RU/EN: lua/hints.lua, переключение <leader>u.
        spec = require("hints").spec(),
      }
    end,
  },
  {
    "kylechui/nvim-surround",
    event = "VeryLazy",
    opts = {},
  },
  {
    "lewis6991/gitsigns.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      { "<leader>gj", function() require("gitsigns").next_hunk() end, desc = "Следующий hunk" },
      { "<leader>gk", function() require("gitsigns").prev_hunk() end, desc = "Предыдущий hunk" },
      { "<leader>gp", function() require("gitsigns").preview_hunk() end, desc = "Показать hunk" },
      { "<leader>gr", function() require("gitsigns").reset_hunk() end, desc = "Откатить hunk" },
      { "<leader>gs", function() require("gitsigns").stage_hunk() end, desc = "Добавить hunk" },
      { "<leader>gu", function() require("gitsigns").undo_stage_hunk() end, desc = "Убрать hunk из stage" },
    },
  },
  {
    "seblyng/roslyn.nvim",
    ft = { "cs", "razor" },
    dependencies = { "neovim/nvim-lspconfig" },
    opts = {
      filewatching = "auto",
      broad_search = true,
    },
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/nvim-cmp",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      vim.lsp.config("lua_ls", { capabilities = capabilities })
      -- roslyn.nvim owns the Roslyn configuration and enables it itself.
      -- Registering it here races with roslyn.nvim lazy-loading and produces
      -- an initial `cmd: ... got nil` error.
      vim.lsp.enable("lua_ls")
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client.name == "roslyn" and not vim.g.roslyn_announced then
            vim.g.roslyn_announced = true
            vim.notify("Roslyn подключён: gd, gr, K работают. Подсказки: пробел")
          end
          local o = { buffer = args.buf, silent = true }
          -- Через Telescope: один результат — сразу переход, несколько — всплывающий список,
          -- который сам закрывается после выбора (в отличие от quickfix-окна).
          local tb = function(name) return function() require("telescope.builtin")[name]({ reuse_win = true }) end end
          vim.keymap.set("n", "gd", tb("lsp_definitions"), vim.tbl_extend("force", o, { desc = "Определение" }))
          vim.keymap.set("n", "gD", vim.lsp.buf.declaration, vim.tbl_extend("force", o, { desc = "Объявление" }))
          vim.keymap.set("n", "gi", tb("lsp_implementations"), vim.tbl_extend("force", o, { desc = "Реализация" }))
          vim.keymap.set("n", "gr", tb("lsp_references"), vim.tbl_extend("force", o, { desc = "Ссылки" }))
          vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", o, { desc = "Документация" }))
          vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, vim.tbl_extend("force", o, { desc = "Переименовать" }))
          vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, vim.tbl_extend("force", o, { desc = "Code action" }))
          vim.keymap.set("n", "<leader>lf", function() vim.lsp.buf.format({ async = true }) end, vim.tbl_extend("force", o, { desc = "Форматировать" }))
          vim.keymap.set("n", "<leader>li", vim.lsp.buf.incoming_calls, vim.tbl_extend("force", o, { desc = "Входящие вызовы" }))
          vim.keymap.set("n", "<leader>lo", vim.lsp.buf.outgoing_calls, vim.tbl_extend("force", o, { desc = "Исходящие вызовы" }))
        end,
      })
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      cmp.setup({
        snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = false }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_next_item() elseif luasnip.expand_or_jumpable() then luasnip.expand_or_jump() else fallback() end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_prev_item() elseif luasnip.jumpable(-1) then luasnip.jump(-1) else fallback() end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({ { name = "nvim_lsp" }, { name = "luasnip" }, { name = "path" } }, { { name = "buffer" } }),
      })
    end,
  },
  {
    "mfussenegger/nvim-dap",
    keys = {
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Breakpoint" },
      { "<leader>dc", function() require("dap").continue() end, desc = "Продолжить" },
      { "<leader>do", function() require("dap").step_over() end, desc = "Step over" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step into" },
      { "<leader>du", function() require("dap").step_out() end, desc = "Step out" },
      { "<leader>dx", function() require("dap").terminate() end, desc = "Остановить" },
      { "<leader>dr", function() require("dap").repl.toggle() end, desc = "REPL" },
      { "<leader>dd", function()
        require("dapui").toggle()
        vim.defer_fn(function() require("debug_mode").normalize_sidebar() end, 100)
      end, desc = "Окна отладки показать/скрыть" },
      { "<leader>dh", function() require("dapui").float_element("scopes", { enter = true }) end, desc = "Переменные (всплывающее окно)" },
      { "<leader>de", function() _G.goto_code_window() end, desc = "Вернуться в код" },
      { "<leader>dm", function() require("debug_mode").toggle() end, desc = "Debug Mode: панель и клавиши" },
      -- F-клавиши как в Visual Studio. В терминале Windows Shift+F5 = <F17>, Shift+F11 = <F23>.
      { "<F5>", function() require("dap").continue() end, desc = "Отладка: старт / продолжить" },
      { "<S-F5>", function() require("dap").terminate() end, desc = "Отладка: остановить" },
      { "<F17>", function() require("dap").terminate() end, desc = "Отладка: остановить" },
      { "<F9>", function() require("dap").toggle_breakpoint() end, desc = "Breakpoint вкл/выкл" },
      { "<F10>", function() require("dap").step_over() end, desc = "Шаг через (over)" },
      { "<F11>", function() require("dap").step_into() end, desc = "Шаг внутрь (into)" },
      { "<S-F11>", function() require("dap").step_out() end, desc = "Шаг наружу (out)" },
      { "<F23>", function() require("dap").step_out() end, desc = "Шаг наружу (out)" },
    },
    -- DAP UI настраивается здесь, чтобы окна открывались при первом же <leader>dc,
    -- даже если dap-ui ещё не загружался.
    config = function()
      local dap, dapui = require("dap"), require("dapui")
      require("debug_mode").setup()
      -- Заметные значки: по умолчанию "B" серым цветом, его легко не увидеть.
      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "Visual" })
      dapui.setup({
        layouts = {
          -- Справа: слева уже дерево файлов.
          {
            position = "right",
            size = 40,
            elements = {
              { id = "scopes", size = 0.35 },
              { id = "stacks", size = 0.25 },
              { id = "watches", size = 0.2 },
              { id = "breakpoints", size = 0.2 },
            },
          },
          { position = "bottom", size = 10, elements = { "console" } },
        },
      })

      -- nvim-dap-ui прокручивает Console только когда она является текущим
      -- окном. При переходе в другой класс вывод продолжает поступать, но
      -- его окно перестаёт следовать за последней строкой. Держим follow-tail
      -- отдельно и обновляем все видимые окна консоли, не меняя сам плагин.
      local console_follow = {}
      local console_attached = {}

      local function console_at_tail(buf, win)
        local count = vim.api.nvim_buf_line_count(buf)
        return vim.api.nvim_win_get_cursor(win)[1] >= count
      end

      local function scroll_console_to_tail(buf)
        if console_follow[buf] == false then return end
        local count = vim.api.nvim_buf_line_count(buf)
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_is_valid(win)
            and vim.api.nvim_win_get_buf(win) == buf
            and vim.api.nvim_win_get_config(win).relative == "" then
            pcall(vim.api.nvim_win_call, win, function()
              vim.api.nvim_win_set_cursor(win, { count, 0 })
              vim.cmd("normal! zz")
            end)
          end
        end
      end

      local function attach_console(buf)
        if console_attached[buf] then return end
        console_attached[buf] = true
        console_follow[buf] = true

        vim.api.nvim_buf_attach(buf, false, {
          on_lines = function()
            vim.schedule(function()
              if vim.api.nvim_buf_is_valid(buf) then scroll_console_to_tail(buf) end
            end)
          end,
          on_detach = function()
            console_attached[buf] = nil
            console_follow[buf] = nil
          end,
        })
      end

      local console_group = vim.api.nvim_create_augroup("nvim_csharp_dap_console", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = console_group,
        pattern = "dapui_console",
        callback = function(args) attach_console(args.buf) end,
      })
      vim.api.nvim_create_autocmd({ "CursorMoved", "WinScrolled" }, {
        group = console_group,
        pattern = "*",
        callback = function(args)
          local buf = args.buf
          if vim.bo[buf].filetype ~= "dapui_console" then return end
          local win = vim.api.nvim_get_current_win()
          if vim.api.nvim_win_get_buf(win) == buf then
            console_follow[buf] = console_at_tail(buf, win)
          end
        end,
      })
      vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter", "BufEnter" }, {
        group = console_group,
        pattern = "*",
        callback = function(args)
          if vim.bo[args.buf].filetype == "dapui_console" then
            attach_console(args.buf)
            vim.schedule(function()
              if vim.api.nvim_buf_is_valid(args.buf) then scroll_console_to_tail(args.buf) end
            end)
          end
        end,
      })
      -- Окна не закрываются сами после остановки: вывод программы остаётся виден.
      -- Скрыть: <leader>dd.
      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
    end,
  },
  {
    "rcarriga/nvim-dap-ui",
    lazy = true,
    dependencies = { "nvim-neotest/nvim-nio" },
  },
  {
    "GustavEikaas/easy-dotnet.nvim",
    -- .sln имеет filetype "solution"; .csproj/.slnx — "xml" (их загружают клавиши ниже).
    ft = { "cs", "fs", "vb", "solution" },
    dependencies = { "nvim-lua/plenary.nvim", "mfussenegger/nvim-dap", "folke/snacks.nvim" },
    config = function()
      require("easy-dotnet").setup({
        auto_bootstrap = true,
        test_runner = { viewmode = "float", enable_buffer_test_execution = true },
        debugger = { engine = "netcoredbg", auto_register_dap = true, console = "integratedTerminal" },
        -- Свой Roslyn у easy-dotnet выключен: его уже запускает roslyn.nvim.
        -- Два сервера давали каждый ответ дважды (gd показывал два одинаковых места).
        lsp = { enabled = false },
      })
    end,
    keys = {
      { "<leader>rr", "<cmd>Dotnet run<cr>", desc = "Запустить проект" },
      { "<C-F5>", "<cmd>Dotnet run<cr>", desc = "Запустить без отладки" },
      { "<F29>", "<cmd>Dotnet run<cr>", desc = "Запустить без отладки" },
      { "<leader>rt", "<cmd>Dotnet test<cr>", desc = "Запустить тесты" },
      { "<leader>rs", "<cmd>Dotnet<cr>", desc = "Меню .NET" },
    },
  },
}
