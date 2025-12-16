return {
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    opts = {
      indent = {
        char = '▏', -- the vertical line character
        tab_char = '▏', -- use the same char for real tabs (Go uses tabs)
      },
      whitespace = {
        remove_blankline_trail = false,
      },
      scope = {
        enabled = true,
        show_start = false, -- removes underline at scope start
        show_end = false,
        highlight = nil, -- disables underline highlight
      },
    },
  },
}
