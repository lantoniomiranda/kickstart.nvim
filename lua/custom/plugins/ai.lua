return {
  'ThePrimeagen/99',
  dependencies = {
    'saghen/blink.cmp',
    { 'saghen/blink.compat', version = '2.*', opts = {} },
    'nvim-telescope/telescope.nvim',
  },
  config = function()
    local ai = require '99'
    ai.setup {
      provider = ai.Providers.ClaudeCodeProvider,
      tmp_dir = './.99', -- Keep request files inside the project for CLI permissions.
      display_errors = true,
      completion = { source = 'blink', custom_rules = {} },
      md_files = { 'AGENTS.md', 'AGENT.md' },
    }
  end,
  keys = {
    {
      '<leader>9v',
      function()
        require('99').visual()
      end,
      mode = 'x',
      desc = 'AI: edit visual selection',
    },
    {
      '<leader>9s',
      function()
        require('99').search()
      end,
      desc = 'AI: search project',
    },
    {
      '<leader>9x',
      function()
        require('99').stop_all_requests()
      end,
      desc = 'AI: cancel requests',
    },
    {
      '<leader>9o',
      function()
        require('99').open()
      end,
      desc = 'AI: previous interactions',
    },
    {
      '<leader>9m',
      function()
        require('99.extensions.telescope').select_model()
      end,
      desc = 'AI: select model',
    },
    {
      '<leader>9p',
      function()
        require('99.extensions.telescope').select_provider()
      end,
      desc = 'AI: select provider',
    },
  },
}
