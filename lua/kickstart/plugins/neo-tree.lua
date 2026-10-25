-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

local state_path = vim.fn.stdpath 'state' .. '/file-tree'

local function file_tree_enabled()
  if vim.g.file_tree_enabled == nil then
    local saved = vim.fn.filereadable(state_path) == 1 and vim.fn.readfile(state_path)[1] or nil
    vim.g.file_tree_enabled = saved ~= '0'
  end
  return vim.g.file_tree_enabled ~= false
end

local function set_file_tree_enabled(on)
  vim.g.file_tree_enabled = on
  pcall(function()
    vim.fn.mkdir(vim.fn.fnamemodify(state_path, ':h'), 'p')
    vim.fn.writefile({ on and '1' or '0' }, state_path)
  end)
end

local function close_file_tree()
  vim.schedule(function()
    if file_tree_enabled() then
      return
    end
    pcall(vim.cmd, 'Neotree close')
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) and vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'neo-tree' then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
  end)
end

local function reveal_file_tree()
  if not file_tree_enabled() then
    vim.notify 'File tree is off'
    return
  end
  vim.cmd 'Neotree reveal'
end

return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  lazy = false,
  init = function()
    file_tree_enabled()
    vim.keymap.set('n', '<leader>te', function()
      local on = not file_tree_enabled()
      set_file_tree_enabled(on)
      if not on then
        close_file_tree()
      end
      vim.notify('File tree: ' .. (on and 'on' or 'off'))
    end, { desc = '[T]oggle [E]xplorer' })
  end,
  keys = {
    { '\\', reveal_file_tree, desc = 'NeoTree reveal', silent = true },
  },
  config = function(_, opts)
    require('neo-tree').setup(opts)

    -- :Neotree and opening a directory both reach this command or the netrw hook.
    local command = require 'neo-tree.command'
    vim.api.nvim_create_user_command('Neotree', function(ctx)
      if not file_tree_enabled() and ctx.fargs[1] ~= 'close' then
        vim.notify 'File tree is off'
        return
      end
      command._command(unpack(ctx.fargs))
    end, {
      nargs = '*',
      complete = "custom,v:lua.require'neo-tree.command'.complete_args",
    })

    local netrw = require 'neo-tree.setup.netrw'
    local hijack = netrw.hijack
    netrw.hijack = function(...)
      if not file_tree_enabled() then
        return false
      end
      return hijack(...)
    end
  end,
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
