return {
  'nvim-treesitter/nvim-treesitter',
  branch = 'main', -- Neovim 0.12 API; master is incompatible.
  lazy = false,
  dependencies = { 'mason-org/mason.nvim' },
  build = ':TSUpdate',
  config = function()
    local treesitter = require 'nvim-treesitter'
    treesitter.setup { install_dir = vim.fn.stdpath 'data' .. '/site' }

    vim.filetype.add {
      extension = { psql = 'sql', pgsql = 'sql', jbuilder = 'ruby' },
      filename = { Taskfile = 'yaml', taskfile = 'yaml' },
    }
    -- PostgreSQL fence labels and filetypes share the SQL grammar and queries.
    vim.treesitter.language.register('sql', { 'sql', 'psql', 'pgsql', 'postgres', 'postgresql' })

    local group = vim.api.nvim_create_augroup('custom-treesitter', { clear = true })
    local function attach(bufnr)
      local filetype = vim.bo[bufnr].filetype
      local language = vim.treesitter.language.get_lang(filetype)
      if not language or not vim.treesitter.language.add(language) then
        return
      end
      vim.treesitter.start(bufnr, language)
      if filetype ~= 'markdown' and filetype ~= 'ruby' and filetype ~= 'eruby' and filetype ~= 'make' then
        vim.bo[bufnr].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
      if filetype == 'ruby' then
        vim.bo[bufnr].syntax = 'ruby'
      end
    end

    vim.api.nvim_create_autocmd('FileType', {
      group = group,
      callback = function(event)
        attach(event.buf)
      end,
    })
    vim.api.nvim_create_autocmd('User', {
      group = group,
      pattern = 'TSUpdate',
      callback = function()
        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_loaded(bufnr) then
            attach(bufnr)
          end
        end
      end,
    })

    if vim.fn.executable 'tree-sitter' == 1 then
      treesitter.install(require('custom.languages').parsers)
    end
  end,
}
