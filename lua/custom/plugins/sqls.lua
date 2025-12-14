return {
  'neovim/nvim-lspconfig',
  opts = {
    servers = {
      sqls = {
        settings = {
          sqls = {
            connections = {
              {
                driver = 'postgresql',
                dataSourceName = 'postgres://localhost/postgres',
              },
            },
          },
        },
      },
    },
  },
}
