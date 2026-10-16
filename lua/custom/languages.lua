-- Keep servers, formatting and syntax support together when adding a language.
-- OCaml and Ruby tools belong to the project's opam switch / Ruby environment.
return {
  servers = {
    dockerls = {
      root_markers = { 'Dockerfile', 'Containerfile', '.git' },
      settings = {
        docker = { languageserver = { formatter = { ignoreMultilineInstructions = true } } },
      },
    },
    make_ls = {
      cmd = function(dispatchers, config)
        local plugin = require('lazy.core.config').plugins['make-ls']
        return vim.lsp.rpc.start({ plugin.dir .. '/make-ls' }, dispatchers, { cwd = config.root_dir })
      end,
      filetypes = { 'make' },
      root_dir = function(bufnr, on_dir)
        local filename = vim.api.nvim_buf_get_name(bufnr)
        on_dir(vim.fs.root(bufnr, { 'Makefile', 'makefile', 'GNUmakefile', '.git' }) or vim.fs.dirname(filename))
      end,
    },
    yamlls = {
      settings = {
        yaml = {
          schemas = {
            ['https://taskfile.dev/schema.json'] = {
              '**/[Tt]askfile*.yml',
              '**/[Tt]askfile*.yaml',
              '**/Taskfile',
              '**/taskfile',
            },
          },
        },
      },
    },
    gopls = {},
    clangd = {},
    pyright = {},
    ruff = {
      on_attach = function(client)
        client.server_capabilities.hoverProvider = false -- Use Pyright's type information.
      end,
    },
    ts_ls = {},
    elixirls = {},
    csharp_ls = {},
    ocamllsp = {},
    ruby_lsp = {},
    ols = { init_options = { enable_snippets = true } },
    marksman = {},
    lua_ls = { settings = { Lua = { completion = { callSnippet = 'Replace' } } } },
  },
  mason_tools = {
    'dockerfile-language-server',
    'hadolint',
    'yaml-language-server',
    'gopls',
    'goimports',
    'clangd',
    'clang-format',
    'pyright',
    'ruff',
    'typescript-language-server',
    'prettier',
    'elixir-ls',
    {
      'csharp-language-server',
      condition = function()
        return vim.fn.executable 'dotnet' == 1
      end,
    },
    {
      'csharpier',
      condition = function()
        return vim.fn.executable 'dotnet' == 1
      end,
    },
    'marksman',
    'markdownlint',
    'lua-language-server',
    'stylua',
    'tree-sitter-cli', -- Native binary used by the Neovim 0.12 Treesitter installer.
    'ols', -- Also installs odinfmt.
  },
  formatters = {
    go = { 'goimports', 'gofmt' },
    c = { 'clang_format' },
    cpp = { 'clang_format' },
    python = { 'ruff_organize_imports', 'ruff_format' },
    javascript = { 'prettier' },
    javascriptreact = { 'prettier' },
    typescript = { 'prettier' },
    typescriptreact = { 'prettier' },
    elixir = { 'mix' },
    eelixir = { 'mix' },
    heex = { 'mix' },
    cs = { 'csharpier' },
    ocaml = { 'ocamlformat' },
    ocamlinterface = { 'ocamlformat' },
    ruby = { 'rubocop' },
    odin = { 'odinfmt' },
    markdown = { 'prettier' },
    json = { 'prettier' },
    jsonc = { 'prettier' },
    yaml = { 'prettier' },
    html = { 'prettier' },
    css = { 'prettier' },
    lua = { 'stylua' },
  },
  linters = {
    markdown = { 'markdownlint' },
    dockerfile = { 'hadolint' },
  },
  parsers = {
    'bash',
    'c',
    'cpp',
    'c_sharp',
    'css',
    'diff',
    'dockerfile',
    'elixir',
    'embedded_template',
    'go',
    'gomod',
    'gosum',
    'heex',
    'html',
    'javascript',
    'json',
    'lua',
    'luadoc',
    'make',
    'markdown',
    'markdown_inline',
    'ocaml',
    'ocaml_interface',
    'odin',
    'python',
    'query',
    'ruby',
    'sql',
    'tsx',
    'typescript',
    'vim',
    'vimdoc',
    'yaml',
  },
}
