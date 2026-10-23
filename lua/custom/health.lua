local M = {}

function M.check()
  vim.health.start 'Language completion and formatting'
  local requirements = {
    { 'Dockerfiles', { 'node', 'docker-langserver', 'hadolint' }, 'Install Node/npm; run :MasonToolsInstall for Dockerfile editor tools.' },
    {
      'Makefiles',
      { 'make', require('lazy.core.config').plugins['make-ls'].dir .. '/make-ls' },
      'Install Make and Go; run :Lazy build make-ls for its language server.',
    },
    { 'Taskfiles', { 'task', 'yaml-language-server', 'prettier' }, 'Install Task and Node/npm; run :MasonToolsInstall for editor tools.' },
    { 'Go', { 'go', 'gopls', 'goimports', 'golines' }, 'Install Go; run :MasonToolsInstall for editor tools.' },
    { 'C/C++', { 'clangd', 'clang-format' }, 'Run :MasonToolsInstall; supply compile_commands.json for your project.' },
    { 'Python', { 'python3', 'pyright-langserver', 'ruff' }, 'Install Python; run :MasonToolsInstall and activate the project virtual environment.' },
    { 'JavaScript/TypeScript', { 'node', 'typescript-language-server', 'prettier' }, 'Install Node/npm; run :MasonToolsInstall.' },
    { 'Elixir', { 'elixir', 'mix', 'elixir-ls' }, 'Install Erlang/Elixir, run mix deps.get in the project, and run :MasonToolsInstall.' },
    { 'C#', { 'dotnet', 'csharp-ls' }, 'Install a compatible .NET SDK, restart Neovim, and run :MasonToolsInstall.' },
    {
      'OCaml',
      { 'ocamllsp', 'ocamlformat', 'dune' },
      'Run opam install ocaml-lsp-server ocamlformat dune in the project switch; launch with opam exec -- nvim.',
    },
    { 'TOML', { 'taplo' }, 'Run :MasonToolsInstall for the TOML language server.' },
    { 'Ruby', { 'ruby-lsp', 'rubocop' }, 'Select a supported Ruby via your version manager; run gem install ruby-lsp rubocop.' },
    { 'Rails', { 'erb-format' }, 'For .erb views, run gem install erb-formatter. In a Rails app, bundle add ruby-lsp-rails.' },
    { 'Odin', { 'odin', 'ols', 'odinfmt' }, 'Install Odin; run :MasonToolsInstall for OLS and odinfmt.' },
    { 'Markdown', { 'marksman', 'prettier', 'markdownlint' }, 'Run :MasonToolsInstall.' },
    { 'Lua', { 'lua-language-server', 'stylua' }, 'Run :MasonToolsInstall.' },
  }
  for _, requirement in ipairs(requirements) do
    local missing = {}
    for _, executable in ipairs(requirement[2]) do
      if vim.fn.executable(executable) == 0 then
        missing[#missing + 1] = executable
      end
    end
    if #missing == 0 then
      vim.health.ok(requirement[1] .. ': tools available')
    else
      vim.health.warn(requirement[1] .. ': missing ' .. table.concat(missing, ', '), { requirement[3] })
    end
  end
  vim.health.info 'Tool availability does not establish project setup or server attachment. See :checkhealth vim.lsp and :ConformInfo in the affected buffer.'
end

return M
