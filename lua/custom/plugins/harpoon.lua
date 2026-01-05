return {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    local harpoon = require 'harpoon'
    harpoon:setup()

    local conf = require('telescope.config').values
    local function toggle_telescope(harpoon_files)
      local file_paths = {}
      for _, item in ipairs(harpoon_files.items) do
        table.insert(file_paths, item.value)
      end

      require('telescope.pickers')
        .new({}, {
          prompt_title = 'Harpoon',
          finder = require('telescope.finders').new_table {
            results = file_paths,
          },
          previewer = conf.file_previewer {},
          sorter = conf.generic_sorter {},
        })
        :find()
    end

    vim.keymap.set('n', '<leader>a', function()
      harpoon:list():add()
    end, { desc = 'harpoon add file' })

    vim.keymap.set('n', '<leader>ch', function()
      toggle_telescope(harpoon:list())
    end, { desc = 'harpoon telescope menu' })

    -- Quick navigate 1-4 (add more as needed)
    vim.keymap.set('n', '<C-1>', function()
      harpoon:list():select(1)
    end, { desc = 'harpoon to file 1' })
    vim.keymap.set('n', '<C-2>', function()
      harpoon:list():select(2)
    end, { desc = 'harpoon to file 2' })
    vim.keymap.set('n', '<C-3>', function()
      harpoon:list():select(3)
    end, { desc = 'harpoon to file 3' })
    vim.keymap.set('n', '<C-4>', function()
      harpoon:list():select(4)
    end, { desc = 'harpoon to file 4' })
  end,
}
