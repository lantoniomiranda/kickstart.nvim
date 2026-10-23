return {
  'stevearc/conform.nvim',
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  keys = {
    {
      '<leader>f',
      function()
        require('conform').format { async = true, lsp_format = vim.bo.filetype == 'make' and 'never' or 'fallback' }
      end,
      mode = '',
      desc = '[F]ormat buffer',
    },
  },
  init = function()
    vim.keymap.set('n', '<leader>tf', function()
      vim.b.disable_autoformat = not vim.b.disable_autoformat
      vim.notify('Format on save: ' .. (vim.b.disable_autoformat and 'off' or 'on'))
    end, { desc = '[T]oggle [F]ormat on save for this buffer' })
  end,
  opts = {
    notify_on_error = true,
    format_on_save = function(bufnr)
      if vim.b[bufnr].disable_autoformat then
        return
      end
      if vim.bo[bufnr].filetype == 'make' then
        return
      end
      return { timeout_ms = 3000, lsp_format = 'fallback' }
    end,
    formatters_by_ft = require('custom.languages').formatters,
    formatters = {
      prettier = {
        prepend_args = { '--prose-wrap', 'preserve' },
        options = { ft_parsers = { yaml = 'yaml' } },
      },
    },
  },
}
