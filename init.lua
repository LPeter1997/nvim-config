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

-- Preview replace effect
vim.o.inccommand = 'split'

-- Show cursor line number
vim.o.cursorline = true

-- Minimum number of screen lines to keep above and below the cursor
vim.o.scrolloff = 10

-- Instead of failing an operation for an unsaved buffer, have a save dialog
vim.o.confirm = true
--------------------------------------------------------------------------------

-- Setup lazy.nvim
require('lazy').setup({
  spec = {
    -- Add plugins here ------------------------------------------------------------
    -- Default theme with a high prio so freaking Lazy won't override it when the runtime is rebuilt
    {
      'folke/tokyonight.nvim',
      priority = 1000,
      config = function()
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
    -- LSP setup for Lua
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
    -- TODO: LSP for C#
    -- TODO: Debugging
    -- TODO: Autocompletion
    -- TODO: Highlight TODO and such in comments
    --------------------------------------------------------------------------------
  },
  checker = { enabled = true },
})
