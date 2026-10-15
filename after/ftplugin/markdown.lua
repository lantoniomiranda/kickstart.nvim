vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true
-- Wrap visually without inserting paragraph line breaks while typing.
vim.opt_local.textwidth = 0
vim.opt_local.formatoptions:remove { 't', 'c' }

for _, key in ipairs { 'j', 'k' } do
  vim.keymap.set('n', key, function()
    return vim.v.count == 0 and 'g' .. key or key
  end, { buffer = true, expr = true, desc = 'Move through displayed Markdown lines' })
end

-- Restore options and mappings if the buffer changes to another filetype.
vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
  .. '\nsetlocal wrap< linebreak< breakindent< textwidth< formatoptions<'
  .. '\nsilent! nunmap <buffer> j'
  .. '\nsilent! nunmap <buffer> k'
