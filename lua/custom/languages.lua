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
    taplo = {},
    gopls = {},
    clangd = {},
    pyright = {},
    ruff = {
      on_attach = function(client)
        client.server_capabilities.hoverProvider = false -- Use Pyright's type information.
      end,
    },
    ts_ls = {},
    elixirls = {
      -- The Mason shim is executable even when Elixir is not installed.
      -- launch.sh then exits and Neovim notifies on every Elixir buffer.
      root_dir = function(bufnr, on_dir)
        if vim.fn.executable 'elixir' == 0 then
          return
        end
        local fname = vim.api.nvim_buf_get_name(bufnr)
        local matches = vim.fs.find({ 'mix.exs' }, { upward = true, limit = 2, path = fname })
        local child_or_root_path, maybe_umbrella_path = unpack(matches)
        on_dir(vim.fs.dirname(maybe_umbrella_path or child_or_root_path))
      end,
    },
    csharp_ls = {
      -- lspconfig starts this server with a cmd function, so a missing `csharp-ls`
      -- skips Neovim's executable check and errors on every C# buffer.
      root_dir = function(bufnr, on_dir)
        if vim.fn.executable 'csharp-ls' == 0 then
          return
        end
        on_dir(vim.fs.root(bufnr, function(name, _)
          local ext = vim.fs.ext(name)
          return ext == 'sln' or ext == 'slnx' or ext == 'csproj'
        end))
      end,
    },
    ocamllsp = {},
    ruby_lsp = {
      -- lspconfig starts this server with a cmd function, so a missing `ruby-lsp`
      -- skips Neovim's executable check and errors on every Ruby buffer.
      -- eruby covers Rails views such as app/views/*/*.html.erb.
      filetypes = { 'ruby', 'eruby' },
      root_dir = function(bufnr, on_dir)
        if vim.fn.executable 'ruby-lsp' == 0 then
          return
        end
        on_dir(vim.fs.root(bufnr, { 'Gemfile', '.git' }))
      end,
    },
    ols = { init_options = { enable_snippets = true } },
    marksman = {},
    lua_ls = { settings = { Lua = { completion = { callSnippet = 'Replace' } } } },
  },
  mason_tools = {
    'dockerfile-language-server',
    'hadolint',
    'yaml-language-server',
    'taplo',
    'gopls',
    'goimports',
    'golines',
    'clangd',
    'clang-format',
    'pyright',
    'ruff',
    'typescript-language-server',
    'prettier',
    'elixir-ls',
    {
      -- 0.17+ does not install on the .NET 8 SDK. Mason reports that as a missing DotnetToolSettings.xml.
      'csharp-language-server',
      version = '0.16.0',
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
    -- golines splits lines over 100 columns. A long composite literal becomes one field per line.
    go = { 'goimports', 'golines' },
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
    -- erb-formatter gem. Used for Rails .erb views.
    eruby = { 'erb_format' },
    odin = { 'odinfmt' },
    markdown = { 'prettier' },
    json = { 'prettier' },
    jsonc = { 'prettier' },
    yaml = { 'prettier' },
    toml = { 'taplo' },
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
    'toml',
    'tsx',
    'typescript',
    'vim',
    'vimdoc',
    'yaml',
  },
}
