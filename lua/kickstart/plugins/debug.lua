-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)

return {
  -- NOTE: Yes, you can install new plugins here!
  'mfussenegger/nvim-dap',
  -- NOTE: And you can specify dependencies as well
  dependencies = {
    -- Creates a beautiful debugger UI
    'rcarriga/nvim-dap-ui',

    -- Required dependency for nvim-dap-ui
    'nvim-neotest/nvim-nio',

    -- Installs the debug adapters for you
    'mason-org/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',

    -- Add your own debuggers here
    'leoluz/nvim-dap-go',
  },
  keys = {
    -- Basic debugging keymaps, feel free to change to your liking!
    {
      '<F5>',
      function() require('dap').continue() end,
      desc = 'Debug: Start/Continue',
    },
    {
      '<F1>',
      function() require('dap').step_into() end,
      desc = 'Debug: Step Into',
    },
    {
      '<F2>',
      function() require('dap').step_over() end,
      desc = 'Debug: Step Over',
    },
    {
      '<F3>',
      function() require('dap').step_out() end,
      desc = 'Debug: Step Out',
    },
    {
      '<leader>b',
      function() require('dap').toggle_breakpoint() end,
      desc = 'Debug: Toggle Breakpoint',
    },
    {
      '<leader>B',
      function() require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ') end,
      desc = 'Debug: Set Breakpoint',
    },
    -- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
    {
      '<F7>',
      function() require('dapui').toggle() end,
      desc = 'Debug: See last session result.',
    },
    -- -- VSCode-style: pick a debug configuration (from .vscode/launch.json + built-in).
    -- {
    --   '<leader>dc',
    --   function()
    --     local dap = require 'dap'
    --     local venv = require 'kickstart.venv'
    --     local ft = vim.bo.filetype

    --     -- Ensure Python adapter uses project venv before running.
    --     if ft == 'python' then
    --       local python_path = venv.get_python_path(venv.get_venv_path_for_buf())
    --       if python_path then
    --         dap.adapters.python = {
    --           type = 'executable',
    --           command = python_path,
    --           args = { '-m', 'debugpy.adapter' },
    --         }
    --       end
    --     end

    --     local configs = dap.configurations[ft] or {}
    --     if #configs == 0 then
    --       vim.notify('No debug configurations for ' .. ft .. '. Add .vscode/launch.json or use mason-nvim-dap defaults.', vim.log.levels.INFO)
    --       return
    --     end
    --     vim.ui.select(configs, {
    --       prompt = 'Debug configuration',
    --       format_item = function(c) return c.name or c.type end,
    --     }, function(choice)
    --       if choice then dap.run_config(choice) end
    --     end)
    --   end,
    --   desc = 'Debug: [C]hoose configuration (VSCode-style)',
    -- },
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'
    local venv = require 'kickstart.venv'

    -- Workaround: some adapters (e.g. debugpy) can report frame at line 0; Neovim uses 1-based lines,
    -- so nvim_win_set_cursor(win, {0, col}) triggers E474 "Cursor position outside buffer".
    -- Clamp line 0 -> 1 so the cursor stays at the first line of the buffer.
    local api = vim.api
    local orig_set_cursor = api.nvim_win_set_cursor
    api.nvim_win_set_cursor = function(win, pos)
      if type(pos) == 'table' and #pos >= 1 and (pos[1] == nil or pos[1] == 0) then
        pos = { 1, pos[2] or 0 }
      end
      return orig_set_cursor(win, pos)
    end

    -- Load .vscode/launch.json into dap.configurations (optional; some nvim-dap versions auto-load).
    pcall(function()
      require('dap.ext.vscode').load_launchjs(nil, { ['python'] = { 'python' } })
    end)

    require('mason-nvim-dap').setup {
      automatic_installation = true,
      handlers = {
        -- Use project .venv/venv for Python debugger.
        python = function(config)
          local python_path = venv.get_python_path(venv.get_venv_path(vim.fn.getcwd()))
          if python_path then
            config.adapters = {
              type = 'executable',
              command = python_path,
              args = { '-m', 'debugpy.adapter' },
            }
          end
          require('mason-nvim-dap').default_setup(config)
        end,
      },
      ensure_installed = {
        'python',
        'delve',
      },
    }

    -- Dap UI setup
    -- For more information, see |:help nvim-dap-ui|
    dapui.setup {
      -- Set icons to characters that are more likely to work in every terminal.
      --    Feel free to remove or use ones that you like more! :)
      --    Don't feel like these are good choices.
      icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
      controls = {
        icons = {
          pause = '⏸',
          play = '▶',
          step_into = '⏎',
          step_over = '⏭',
          step_out = '⏮',
          step_back = 'b',
          run_last = '▶▶',
          terminate = '⏹',
          disconnect = '⏏',
        },
      },
    }

    -- Change breakpoint icons
    -- vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
    -- vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
    -- local breakpoint_icons = vim.g.have_nerd_font
    --     and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
    --   or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
    -- for type, icon in pairs(breakpoint_icons) do
    --   local tp = 'Dap' .. type
    --   local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
    --   vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
    -- end

    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    -- Keep the debugger UI open after the session ends (don't auto-close on terminate/exit).
    -- dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    -- dap.listeners.before.event_exited['dapui_config'] = dapui.close

    -- Install golang specific config
    require('dap-go').setup {
      delve = {
        -- On Windows delve must be run attached or it crashes.
        -- See https://github.com/leoluz/nvim-dap-go/blob/main/README.md#configuring
        detached = vim.fn.has 'win32' == 0,
      },
    }
  end,
}
