-- Bootstrap lazy.nvim ---------------------------------------------------------
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { 'Failed to clone lazy.nvim:\n', 'ErrorMsg' },
      { out, 'WarningMsg' },
      { '\nPress any key to exit...' },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)
--------------------------------------------------------------------------------

-- Vim globals and options setup -----------------------------------------------
-- Leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'

-- We have a nerd-font installed
vim.g.have_nerd_font = true

-- Set up line numbers
vim.o.number = true

-- Enable mouse support
vim.o.mouse = 'a'

-- Sync clipboard with system clipboard
-- We do that after UI loads to speed up startup time
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)

-- Indent wrapped lines
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive search and smart case
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on (for breakpoints and other signs)
vim.o.signcolumn = 'yes'

-- Splits direction
vim.o.splitright = true
vim.o.splitbelow = true

-- special cases of whitespaces in a nicer way
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Debugger signs
vim.fn.sign_define("DapBreakpoint", { text = "", texthl = "Debug", linehl = "", numhl = "" })
vim.fn.sign_define("DapBreakpointCondition", { text = "", texthl = "Debug", linehl = "", numhl = "" })
vim.fn.sign_define("DapLogPoint", { text = "", texthl = "Debug", linehl = "", numhl = "" })
vim.fn.sign_define("DapStopped", { text = "", texthl = "Debug", linehl = "", numhl = "" })

-- Preview replace effect
vim.o.inccommand = 'split'

-- Show cursor line number
vim.o.cursorline = true

-- Minimum number of screen lines to keep above and below the cursor
vim.o.scrolloff = 10

-- Instead of failing an operation for an unsaved buffer, have a save dialog
vim.o.confirm = true

-- Fold using treesitter
vim.opt.foldcolumn = '1'
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99
-- 'zo' on <leader><Right> to open folds
vim.keymap.set('n', '<leader><Right>', 'zo', { desc = 'Open fold under cursor' })
-- 'zc' on <leader><Left> to close folds
vim.keymap.set('n', '<leader><Left>', 'zc', { desc = 'Close fold under cursor' })
-- Open all folds on <leader><leader><Right>
vim.keymap.set('n', '<leader><leader><Right>', 'zR', { desc = 'Open all folds' })
-- Close all folds on <leader><leader><Left>
vim.keymap.set('n', '<leader><leader><Left>', 'zM', { desc = 'Close all folds' })
vim.opt.fillchars = {
  foldopen = '',
  foldclose = '',
  foldsep = '│',
  fold = ' ',
  eob = ' ',
}

-- Allow for per-project configuration
vim.o.exrc = true
vim.o.secure = true
--------------------------------------------------------------------------------

-- Dotnet-specific build function
local function dotnet_rebuild_project(co, path)
  local spinner = require('easy-dotnet.ui-modules.spinner').new()
  spinner:start_spinner('Building')
  vim.fn.jobstart(string.format('dotnet build %s', path), {
    on_exit = function(_, return_code)
      if return_code == 0 then
        spinner:stop_spinner('Built successfully')
      else
        spinner:stop_spinner('Build failed with exit code ' .. return_code, vim.log.levels.ERROR)
        error('Build failed')
      end
      coroutine.resume(co)
    end,
  })
  coroutine.yield()
end

-- Setup lazy.nvim
require('lazy').setup({
  spec = {
    -- Add plugins here ------------------------------------------------------------
    -- Default theme with a high prio so freaking Lazy won't override it when the runtime is rebuilt
    {
      'folke/tokyonight.nvim',
      priority = 1000,
      config = function()
        ---@diagnostic disable-next-line: missing-fields
        require('tokyonight').setup({
          styles = {
            comments = { italic = false },
          },
        })

        -- Apply the color scheme
        vim.cmd.colorscheme('tokyonight-night')
      end,
    },
    -- Various small plugins collection
    {
      'echasnovski/mini.nvim',
      config = function()
        -- For now we'll only set up the statusline
        local statusline = require('mini.statusline')
        statusline.setup({ use_icons = vim.g.have_nerd_font })
      end,
    },
    -- Auto-detect indentation
    'NMAC427/guess-indent.nvim',
    -- Copilot
    {
      'github/copilot.vim',
      lazy = false,
    },
    -- Telescope for fuzzy finding basically everything
    {
      'nvim-telescope/telescope.nvim',
      tag = '0.1.8',
      dependencies = {
        'nvim-lua/plenary.nvim',
        { 'nvim-telescope/telescope-ui-select.nvim' },
        { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
      },
      config = function()
        require('telescope').setup({
          extensions = {
            ['ui-select'] = {
              require('telescope.themes').get_dropdown(),
            },
          },
        })

        -- Enable extensions that are installed
        -- NOTE: fzf is not installed yet but I'll leave the setup here
        pcall(require('telescope').load_extension, 'fzf')
        pcall(require('telescope').load_extension, 'ui-select')

        local builtin = require('telescope.builtin')
        vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
        vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
        vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
        vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
      end,
    },
    -- Lua lang server for configs
    {
      'folke/lazydev.nvim',
      ft = 'lua',
      opts = {
        library = {
          { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
        },
      },
    },
    -- Generic LSP setup
    {
      'neovim/nvim-lspconfig',
      dependencies = {
        { 'mason-org/mason.nvim', opts = {} },
        'mason-org/mason-lspconfig.nvim',
        'WhoIsSethDaniel/mason-tool-installer.nvim',
        { 'j-hui/fidget.nvim', opts = {} },
        'saghen/blink.cmp',
      },
      config = function()
        -- Diagnostic Config
        vim.diagnostic.config({
          severity_sort = true,
          float = { border = 'rounded', source = 'if_many' },
          underline = { severity = vim.diagnostic.severity.ERROR },
          signs = vim.g.have_nerd_font and {
            text = {
              [vim.diagnostic.severity.ERROR] = '󰅚 ',
              [vim.diagnostic.severity.WARN] = '󰀪 ',
              [vim.diagnostic.severity.INFO] = '󰋽 ',
              [vim.diagnostic.severity.HINT] = '󰌶 ',
            },
          } or {},
          virtual_text = {
            source = 'if_many',
            spacing = 2,
            format = function(diagnostic)
              local diagnostic_message = {
                [vim.diagnostic.severity.ERROR] = diagnostic.message,
                [vim.diagnostic.severity.WARN] = diagnostic.message,
                [vim.diagnostic.severity.INFO] = diagnostic.message,
                [vim.diagnostic.severity.HINT] = diagnostic.message,
              }
              return diagnostic_message[diagnostic.severity]
            end,
          },
        })

        local capabilities = require('blink.cmp').get_lsp_capabilities()

        -- Enable the following language servers
        local servers = {
          lua_ls = {
            settings = {
              Lua = {
                completion = {
                  callSnippet = 'Replace',
                },
              },
            },
          },
        }

        -- Ensure the servers and tools above are installed
        local ensure_installed = vim.tbl_keys(servers or {})
        vim.list_extend(ensure_installed, {
          'stylua', -- Used to format Lua code
        })
        require('mason-tool-installer').setup({ ensure_installed = ensure_installed })

        require('mason-lspconfig').setup({
          ensure_installed = {}, -- explicitly set to an empty table (Kickstart populates installs via mason-tool-installer)
          automatic_installation = false,
          handlers = {
            function(server_name)
              local server = servers[server_name] or {}
              -- This handles overriding only values explicitly passed
              -- by the server configuration above. Useful when disabling
              -- certain features of an LSP (for example, turning off formatting for ts_ls)
              server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
              require('lspconfig')[server_name].setup(server)
            end,
          },
        })
      end,
    },
    -- Treesitter for syntax highlighting and more
    {
      'nvim-treesitter/nvim-treesitter',
      build = ':TSUpdate',
      main = 'nvim-treesitter.configs',
      opts = {
        ensure_installed = {
          'lua',
          'c_sharp',
        },
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = { enable = true },
      },
    },
    -- Autoformat
    {
      'stevearc/conform.nvim',
      event = { 'BufWritePre' },
      cmd = { 'ConformInfo' },
      keys = {
        {
          '<leader>f',
          function()
            require('conform').format({ async = true, lsp_format = 'fallback' })
          end,
          mode = '',
          desc = '[F]ormat buffer',
        },
      },
      opts = {
        formatters_by_ft = {
          lua = { 'stylua' },
        },
      },
    },
    -- File-browser
    {
      'nvim-neo-tree/neo-tree.nvim',
      branch = 'v3.x',
      dependencies = {
        'nvim-lua/plenary.nvim',
        'MunifTanjim/nui.nvim',
        'nvim-tree/nvim-web-devicons', -- optional, but recommended
      },
      lazy = false, -- neo-tree will lazily load itself
      config = function()
        -- Neo-tree config
        require('neo-tree').setup({
          --- @module 'neo-tree'
          --- @type neotree.Config
          filesystem = {
            filtered_items = {
              visible = true,
              hide_dotfiles = false,
              hide_gitignored = false,
            },
          },
        })
        -- Toggle on <leader>s
        vim.keymap.set('n', '<leader>s', ':Neotree toggle<CR>', { noremap = true, silent = true })
      end,
    },
    -- Autocompletion
    {
      'saghen/blink.cmp',
      event = 'VimEnter',
      version = '1.*',
      dependencies = {
        -- Snippet Engine
        {
          'L3MON4D3/LuaSnip',
          version = '2.*',
          build = (function()
            if vim.fn.has('win32') == 1 or vim.fn.executable('make') == 0 then
              return
            end
            return 'make install_jsregexp'
          end)(),
          dependencies = {},
          opts = {},
        },
        'folke/lazydev.nvim',
      },
      --- @module 'blink.cmp'
      --- @type blink.cmp.Config
      opts = {
        keymap = {
          preset = 'default',
        },
        appearance = {
          nerd_font_variant = 'mono',
        },
        completion = {
          documentation = { auto_show = false, auto_show_delay_ms = 500 },
        },
        sources = {
          default = { 'lsp', 'path', 'snippets', 'lazydev' },
          providers = {
            lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
          },
        },
        snippets = { preset = 'luasnip' },
        fuzzy = { implementation = 'lua' },
        signature = { enabled = true },
      },
    },
    -- Highlight todo, notes, etc in comments
    { 'folke/todo-comments.nvim', event = 'VimEnter', dependencies = { 'nvim-lua/plenary.nvim' }, opts = { signs = false } },
    -- nvim-ufo for folding
    {
      'kevinhwang91/nvim-ufo',
      dependencies = {
        'kevinhwang91/promise-async',
      },
      opts = {
        provider_selector = function(bufnr, filetype, buftype)
          return { 'treesitter', 'indent' }
        end,
      },
    },
    -- Mason
    {
      'mason-org/mason.nvim',
      opts = {
        registries = {
          'github:mason-org/mason-registry',
          'github:Crashdummyy/mason-registry',
        },
      },
    },
    -- C# language support
    {
      'seblyng/roslyn.nvim',
      --- @module 'roslyn.config'
      --- @type RoslynNvimConfig
      opts = {},
    },
    -- Generic .NET tool integration
    {
      'GustavEikaas/easy-dotnet.nvim',
      dependencies = { 'nvim-lua/plenary.nvim', 'nvim-telescope/telescope.nvim' },
      config = function()
        require('easy-dotnet').setup()
      end,
    },
    -- DAP setup
    {
      'mfussenegger/nvim-dap',
      config = function()
        local dap = require('dap')

        -- Keymaps for controlling the debugger
        vim.keymap.set('n', 'q', function()
          dap.terminate()
          dap.clear_breakpoints()
        end, { desc = 'Terminate and clear breakpoints' })

        vim.keymap.set('n', '<F5>', dap.continue, { desc = 'Start/continue debugging' })
        vim.keymap.set('n', '<F10>', dap.step_over, { desc = 'Step over' })
        vim.keymap.set('n', '<F11>', dap.step_into, { desc = 'Step into' })
        vim.keymap.set('n', '<F12>', dap.step_out, { desc = 'Step out' })
        vim.keymap.set('n', '<leader>b', dap.toggle_breakpoint, { desc = 'Toggle breakpoint' })
        vim.keymap.set('n', '<leader>dO', dap.step_over, { desc = 'Step over (alt)' })
        vim.keymap.set('n', '<leader>dC', dap.run_to_cursor, { desc = 'Run to cursor' })
        vim.keymap.set('n', '<leader>dr', dap.repl.toggle, { desc = 'Toggle DAP REPL' })
        vim.keymap.set('n', '<leader>dj', dap.down, { desc = 'Go down stack frame' })
        vim.keymap.set('n', '<leader>dk', dap.up, { desc = 'Go up stack frame' })

        -- .NET specific setup using `easy-dotnet`
        require('easy-dotnet.netcoredbg').register_dap_variables_viewer() -- special variables viewer specific for .NET
        local dotnet = require('easy-dotnet')
        local debug_dll = nil

        local function ensure_dll()
          if debug_dll ~= nil then
            return debug_dll
          end
          local dll = dotnet.get_debug_dll(true)
          debug_dll = dll
          return dll
        end

        for _, value in ipairs({ 'cs', 'fsharp' }) do
          dap.configurations[value] = {
            {
              type = 'coreclr',
              name = 'Program',
              request = 'launch',
              env = function()
                local dll = ensure_dll()
                local vars = dotnet.get_environment_variables(dll.project_name, dll.relative_project_path)
                return vars or nil
              end,
              program = function()
                local dll = ensure_dll()
                local co = coroutine.running()
                dotnet_rebuild_project(co, dll.project_path)
                return dll.relative_dll_path
              end,
              cwd = function()
                local dll = ensure_dll()
                return dll.relative_project_path
              end,
            },
            {
              type = 'coreclr',
              name = 'Test',
              request = 'attach',
              processId = function()
                local res = require('easy-dotnet').experimental.start_debugging_test_project()
                return res.process_id
              end,
            },
          }
        end

        -- Reset debug_dll after each terminated session
        dap.listeners.before['event_terminated']['easy-dotnet'] = function()
          debug_dll = nil
        end

        dap.adapters.coreclr = {
          type = 'executable',
          command = 'netcoredbg',
          args = { '--interpreter=vscode' },
        }
      end,
    },
    --------------------------------------------------------------------------------
  },
  checker = { enabled = true },
})

-- Modeline
-- vim: ts=2 sts=2 sw=2 et
