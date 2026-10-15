return {
  'MeanderingProgrammer/render-markdown.nvim',
  ft = 'markdown',
  opts = { enabled = false },
  keys = {
    {
      '<leader>mp',
      function()
        require('render-markdown').buf_toggle()
      end,
      desc = 'Markdown preview toggle',
      ft = 'markdown',
    },
  },
}
