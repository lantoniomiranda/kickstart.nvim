-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  lazy = false,
  keys = {
    { '\\', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
  },
  opts = {
    popup_border_style = 'rounded',
    open_files_do_not_replace_types = { 'terminal', 'trouble', 'qf', 'panel-canvas', 'codecompanion', 'codecompanion_cli' },
    event_handlers = {
      {
        event = 'file_open_requested',
        handler = function(args)
          local command = args.open_cmd or 'edit'
          local split = command == 'split' or command == 'vsplit'
          if command ~= 'edit' and command ~= 'drop' and not split then
            return
          end
          local opened = require('custom.panels').open_in_editor(args.path, { split = split })
          if opened then
            return { handled = true }
          end
        end,
      },
    },
    window = {
      position = 'float',
      relative = 'editor',
      popup = {
        -- A string border stays one frame. A title here is drawn again by the card layout.
        border = 'rounded',
        size = function()
          local box = require('custom.panels').geometry({ left = true }).left
          return { width = box.width, height = box.height }
        end,
        position = function()
          local box = require('custom.panels').geometry({ left = true }).left
          return { row = box.row, col = box.col }
        end,
      },
    },
    filesystem = {
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = true,
        hide_by_name = {
          'node_modules',
          '.git',
          '.github',
          'dist',
          'coverage',
        },
      },
      window = {
        mappings = {
          ['\\'] = 'close_window',
        },
      },
    },
  },
}
