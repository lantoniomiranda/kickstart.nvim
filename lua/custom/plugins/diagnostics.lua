return {
  'folke/trouble.nvim',
  cmd = 'Trouble',
  init = function()
    vim.diagnostic.config {
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
          local message = diagnostic.message:gsub('%s+', ' ')
          return vim.fn.strcharpart(message, 0, 80) .. (vim.fn.strchars(message) > 80 and '…' or '')
        end,
      },
    }

    vim.keymap.set('n', '<leader>dl', vim.diagnostic.setloclist, { desc = '[D]iagnostics [L]ocation list' })
    vim.keymap.set('n', '<leader>de', function()
      local _, win = vim.diagnostic.open_float(nil, { scope = 'cursor', focus = true, border = 'rounded' })
      if win then
        vim.wo[win].wrap = true
        vim.wo[win].linebreak = true
        vim.api.nvim_set_current_win(win)
      end
    end, { desc = '[D]iagnostic [E]xpanded message' })
  end,
  opts = {
    focus = true,
    multiline = true,
    max_items = 1000,
    auto_preview = false,
    win = {
      type = 'float',
      relative = 'editor',
      position = { 0.5, 0.5 },
      size = { width = 0.85, height = 0.75 },
      border = 'rounded',
      wo = { wrap = true, linebreak = true },
    },
    keys = {
      j = 'next',
      k = 'prev',
      ['<cr>'] = 'jump_close',
      ['<esc>'] = 'close',
    },
    modes = {
      diagnostics_buffer = {
        mode = 'diagnostics',
        filter = { buf = 0 },
        pinned = true,
      },
    },
  },
  keys = {
    { '<leader>dd', '<cmd>Trouble diagnostics_buffer toggle<cr>', desc = '[D]iagnostics for this [D]ocument' },
    { '<leader>dw', '<cmd>Trouble diagnostics toggle<cr>', desc = '[D]iagnostics for [W]orkspace' },
  },
}
