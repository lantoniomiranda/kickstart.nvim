return {
  'nvim-tree/nvim-web-devicons',
  config = function(_, opts)
    local icons = require 'nvim-web-devicons'
    icons.setup(opts)

    -- Devicons matches exact filenames/extensions, so normalize Docker variants.
    -- Apply this to both APIs used by Neo-tree, Telescope and the statusline.
    for _, method in ipairs { 'get_icon', 'get_icon_colors' } do
      local get_icon = icons[method]
      icons[method] = function(name, extension, options)
        if type(name) == 'string' then
          local basename = vim.fn.fnamemodify(name, ':t'):lower()
          if basename:match '^dockerfile%.' or basename:match '^containerfile%.' then
            return get_icon('Dockerfile', nil, options)
          end
        end
        return get_icon(name, extension, options)
      end
    end
  end,
}
