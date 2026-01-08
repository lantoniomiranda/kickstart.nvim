return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = { 'markdown' },
    opts = {
      enabled = false, -- start *disabled*, you toggle when needed[web:56][web:57]
    },
    keys = {
      {
        '<leader>mp',
        function()
          require('render-markdown').set_buf() -- nil = toggle current buffer[web:48]
        end,
        desc = 'Markdown preview toggle',
        ft = 'markdown',
      },
    },
  },
}
