-- Floating cards. One normal window stays as the canvas, because Neovim
-- cannot turn the last window into a float and cannot round a split.
-- The file, the file tree, and the AI panel are rounded floats on top of it.
local M = {}

local canvas_role = 'canvas'
local editor_role = 'editor'
local overlay_role = 'overlay'

local canvas
local last_editor
local ready = false
local placing = false
local place_queued = false

local function role_of(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return nil
  end
  local ok, value = pcall(vim.api.nvim_win_get_var, win, 'panel_role')
  if ok then
    return value
  end
  return nil
end

local function set_role(win, role)
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_var(win, 'panel_role', role)
  end
end

local function tab_wins()
  return vim.api.nvim_tabpage_list_wins(0)
end

local function find_canvas()
  for _, win in ipairs(tab_wins()) do
    if role_of(win) == canvas_role then
      return win
    end
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == 'panel-canvas' and vim.api.nvim_win_get_config(win).relative == '' then
      return win
    end
  end
end

local function filetype_of(win)
  return vim.bo[vim.api.nvim_win_get_buf(win)].filetype
end

local function each_role(wanted)
  local list = {}
  for _, win in ipairs(tab_wins()) do
    if role_of(win) == wanted and vim.api.nvim_win_is_valid(win) then
      list[#list + 1] = win
    end
  end
  return list
end

local function left_window()
  for _, win in ipairs(tab_wins()) do
    if filetype_of(win) == 'neo-tree' and vim.api.nvim_win_get_config(win).relative ~= '' then
      return win
    end
  end
end

local function right_window()
  local found
  for _, win in ipairs(tab_wins()) do
    local ft = filetype_of(win)
    if ft == 'codecompanion' or ft == 'codecompanion_cli' then
      if win == vim.api.nvim_get_current_win() then
        return win
      end
      found = found or win
    end
  end
  return found
end

---Screen boxes for the cards. `opts.left` / `opts.right` mean that side is about to open.
---@param opts? { left?: boolean, right?: boolean }
function M.geometry(opts)
  opts = opts or {}
  local tab = (vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)) and 1 or 0
  local bottom = vim.o.cmdheight + ((vim.o.laststatus == 0) and 0 or 1)
  local row = tab
  local height = math.max(5, vim.o.lines - bottom - row - 1)
  local columns = vim.o.columns
  local left_open = opts.left or left_window() ~= nil
  local right_open = opts.right or right_window() ~= nil

  local left_w = left_open and 32 or 0
  local right_w = right_open and math.max(32, math.floor(columns * 0.32)) or 0
  local cards = 1 + (left_open and 1 or 0) + (right_open and 1 or 0)
  local available = columns - (4 + (cards - 1) * 3)
  local editor_w = available - left_w - right_w
  local min_editor = 24
  local min_side = 20
  while editor_w < min_editor and (left_w > min_side or right_w > min_side) do
    if right_w >= left_w and right_w > min_side then
      right_w = right_w - 1
    elseif left_w > min_side then
      left_w = left_w - 1
    else
      break
    end
    editor_w = available - left_w - right_w
  end
  editor_w = math.max(8, editor_w)

  local col = 2
  local left
  if left_open then
    left = { row = row, col = col, width = left_w, height = height }
    col = col + left_w + 3
  end
  local editor = { row = row, col = col, width = editor_w, height = height }
  col = col + editor_w + 3
  local right
  if right_open then
    right = { row = row, col = col, width = right_w, height = height }
  end

  local function clamp(box)
    if not box then
      return nil
    end
    box.col = math.max(0, box.col)
    box.row = math.max(0, box.row)
    box.width = math.max(1, math.min(box.width, math.max(1, columns - box.col - 1)))
    box.height = math.max(1, math.min(box.height, math.max(1, vim.o.lines - box.row - 1)))
    return box
  end

  return {
    row = row,
    height = height,
    left = clamp(left),
    editor = clamp(editor),
    right = clamp(right),
  }
end

---Path from the repository root. The statusline uses this instead of the absolute path.
function M.repo_path()
  if vim.bo.buftype == 'terminal' then
    return vim.fn.expand '%:t'
  end

  local name = vim.api.nvim_buf_get_name(0)
  if name == '' then
    return '[No Name]'
  end

  local root = vim.fs.root(name, { '.git', '.hg' })
  local relative = root and vim.fs.relpath(root, name) or nil
  relative = relative or vim.fn.fnamemodify(name, ':t')
  if vim.bo.modified then
    relative = relative .. ' [+]'
  end
  if vim.bo.readonly then
    relative = relative .. ' [RO]'
  end
  return (relative:gsub('%%', '%%%%'))
end

---A small step away from the editor color, for themes other than Tokyo Night.
local function shade(color, amount)
  if type(color) ~= 'number' then
    return nil
  end
  amount = amount or 8
  local r = math.floor(color / 65536) % 256
  local g = math.floor(color / 256) % 256
  local b = color % 256
  local shift = (0.299 * r + 0.587 * g + 0.114 * b) > 150 and amount or -amount
  local function clamp(channel)
    return math.max(0, math.min(255, math.floor(channel + shift)))
  end
  return clamp(r) * 65536 + clamp(g) * 256 + clamp(b)
end

local function mix(base, accent, amount)
  if type(base) ~= 'number' or type(accent) ~= 'number' then
    return base
  end
  local function blend(shift)
    local from = math.floor(base / shift) % 256
    local toward = math.floor(accent / shift) % 256
    return math.max(0, math.min(255, math.floor(from + (toward - from) * amount + 0.5)))
  end
  return blend(65536) * 65536 + blend(256) * 256 + blend(1)
end

local function color_of(name)
  local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
  return hl.fg
end

local card

-- Tokyo Night's own tokens. The night gutter is one step below `bg_dark`
-- (`#16161e`) so the rounded cards sit on a quiet surround.
local theme_chrome = {
  [0x1a1b26] = {
    canvas = 0x13141c,
    hairline = 0x414868,
    selection = 0x292e42,
    linenr = 0x414868,
    cursor_nr = 0xff9e64,
    directory = 0x7aa2f7,
    muted = 0x565f89,
  },
  [0xe1e2e7] = {
    canvas = 0xd0d5e3,
    hairline = 0xa1a6c5,
    selection = 0xc4c8da,
    linenr = 0xa8aecb,
    cursor_nr = 0xb15c00,
    directory = 0x2e7de9,
    muted = 0x848cb5,
  },
}

local function capture()
  local normal = vim.api.nvim_get_hl(0, { name = 'Normal', link = false })
  if not normal.bg then
    return nil
  end
  local comment = vim.api.nvim_get_hl(0, { name = 'Comment', link = false })
  local cursorline = vim.api.nvim_get_hl(0, { name = 'CursorLine', link = false })
  local tuned = theme_chrome[normal.bg]
  local editor_bg = normal.bg
  local muted = (tuned and tuned.muted) or comment.fg or normal.fg
  local blue = (tuned and tuned.directory) or color_of 'Function' or color_of 'DiagnosticInfo' or muted
  local canvas = (tuned and tuned.canvas) or shade(editor_bg, 8) or editor_bg
  local hairline = (tuned and tuned.hairline) or mix(canvas, muted, 0.55) or muted
  return {
    editor_bg = editor_bg,
    canvas = canvas,
    status_bg = canvas,
    text = normal.fg,
    muted = muted,
    hairline = hairline,
    selection = (tuned and tuned.selection) or cursorline.bg or mix(editor_bg, normal.fg or hairline, 0.12),
    linenr = (tuned and tuned.linenr) or hairline,
    cursor_nr = (tuned and tuned.cursor_nr) or color_of 'Number' or normal.fg,
    directory = blue,
    border = (tuned and tuned.cursor_nr) or color_of 'Number' or color_of 'DiagnosticWarn' or hairline,
    active = (tuned and tuned.cursor_nr) or color_of 'Number' or color_of 'DiagnosticWarn' or hairline,
    blue = blue,
    green = color_of 'String' or blue,
    purple = color_of 'Statement' or blue,
    red = color_of 'DiagnosticError' or blue,
    yellow = color_of 'DiagnosticWarn' or blue,
  }
end

local function paint_canvas(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end
  local highlight =
    'Normal:PanelCanvas,NormalNC:PanelCanvas,EndOfBuffer:PanelCanvas,SignColumn:PanelCanvas,LineNr:PanelCanvas,CursorLine:PanelCanvas,WinBar:PanelCanvas'
  vim.api.nvim_set_option_value('winhighlight', highlight, { scope = 'local', win = win })
  vim.api.nvim_set_option_value('winbar', '', { scope = 'local', win = win })
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].cursorline = false
  vim.wo[win].list = false
end

local function style_editor(win)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  local highlight =
    'Normal:EditorPanel,NormalNC:EditorPanel,NormalFloat:EditorPanel,SignColumn:EditorPanel,EndOfBuffer:EditorPanelEnd,LineNr:LineNr,CursorLine:CursorLine'
  vim.api.nvim_set_option_value('winhighlight', highlight, { scope = 'local', win = win })
  vim.api.nvim_set_option_value('winbar', '', { scope = 'local', win = win })
  local buf = vim.api.nvim_win_get_buf(win)
  local terminal = vim.bo[buf].buftype == 'terminal'
  vim.wo[win].number = not terminal
  vim.wo[win].relativenumber = not terminal
  vim.wo[win].signcolumn = terminal and 'no' or 'yes'
  vim.wo[win].cursorline = not terminal
  vim.wo[win].winblend = 0
  set_role(win, editor_role)
end

local function style_side(win)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  if filetype_of(win) == 'neo-tree' then
    vim.api.nvim_set_option_value('winbar', '', { scope = 'local', win = win })
    return
  end
  local highlight = 'Normal:SidePanel,NormalNC:SidePanel,NormalFloat:SidePanel,SignColumn:SidePanel,EndOfBuffer:SidePanelEnd'
  vim.api.nvim_set_option_value('winhighlight', highlight, { scope = 'local', win = win })
  vim.api.nvim_set_option_value('winbar', '', { scope = 'local', win = win })
  vim.wo[win].cursorline = false
  vim.wo[win].winblend = 0
end

local function side_title(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local ft = vim.bo[buf].filetype
  if ft == 'codecompanion_cli' then
    local meta = _G.codecompanion_cli_metadata and _G.codecompanion_cli_metadata[buf]
    local name = meta and (meta.description or meta.agent)
    return ' ' .. (name or 'AI') .. ' '
  end
  if ft == 'codecompanion' then
    local meta = _G.codecompanion_chat_metadata and _G.codecompanion_chat_metadata[buf]
    local adapter = meta and meta.adapter
    local name = adapter and adapter.name
    return ' ' .. (name or 'AI') .. ' '
  end
  return ' AI '
end

local function config_number(value)
  if type(value) == 'number' then
    return value
  end
  if type(value) == 'table' then
    return value[false] or value[1] or value.row or value.col or 0
  end
  return 0
end

local function title_text(title)
  if type(title) == 'string' then
    return title
  end
  if type(title) ~= 'table' then
    return nil
  end
  local chunk = title[1]
  if type(chunk) == 'table' then
    return chunk[1]
  end
  if type(chunk) == 'string' then
    return chunk
  end
end

local function apply_box(win, box, extra)
  if not win or not box or not vim.api.nvim_win_is_valid(win) then
    return
  end
  local cfg = vim.api.nvim_win_get_config(win)
  local same = cfg.relative == 'editor'
    and config_number(cfg.row) == box.row
    and config_number(cfg.col) == box.col
    and cfg.width == box.width
    and cfg.height == box.height
  local title_same = not extra or extra.title == nil or title_text(cfg.title) == extra.title
  local title_pos_same = not extra or extra.title_pos == nil or cfg.title_pos == extra.title_pos
  local footer_same = not extra or extra.footer == nil or title_text(cfg.footer) == title_text(extra.footer)
  local footer_pos_same = not extra or extra.footer_pos == nil or cfg.footer_pos == extra.footer_pos
  if same and title_same and title_pos_same and footer_same and footer_pos_same then
    return
  end
  local next_config = {
    relative = 'editor',
    row = box.row,
    col = box.col,
    width = box.width,
    height = box.height,
    border = 'rounded',
  }
  if extra then
    next_config = vim.tbl_extend('force', next_config, extra)
  end
  pcall(vim.api.nvim_win_set_config, win, next_config)
end

local function open_float(buf, box, zindex)
  return vim.api.nvim_open_win(buf, false, {
    relative = 'editor',
    row = box.row,
    col = box.col,
    width = box.width,
    height = box.height,
    border = 'rounded',
    zindex = zindex or 20,
    focusable = true,
  })
end

local function editor_windows()
  return each_role(editor_role)
end

---Short name for the current mode, drawn like the Explorer title.
function M.mode_label()
  local mode = vim.fn.mode()
  local first = mode:sub(1, 1)
  if mode == 'nt' or first == 'n' then
    return 'Normal'
  end
  if first == 'i' then
    return 'Insert'
  end
  if first == 'v' or first == 'V' or first == '\22' then
    return 'Visual'
  end
  if first == 't' then
    return 'Terminal'
  end
  if first == 'R' then
    return 'Replace'
  end
  if first == 'c' then
    return 'Command'
  end
  if first == 's' or first == 'S' or first == '\19' then
    return 'Select'
  end
  return 'Normal'
end

local mode_groups = {
  Normal = 'PanelModeNormal',
  Insert = 'PanelModeInsert',
  Visual = 'PanelModeVisual',
  Terminal = 'PanelModeTerminal',
  Replace = 'PanelModeReplace',
  Command = 'PanelModeCommand',
  Select = 'PanelModeSelect',
}

function M.mode_footer()
  local label = M.mode_label()
  return { { ' ' .. label .. ' ', mode_groups[label] or 'PanelModeNormal' } }
end

function M.refresh_mode()
  local footer = M.mode_footer()
  for _, win in ipairs(editor_windows()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= '' then
      local cfg = vim.api.nvim_win_get_config(win)
      if title_text(cfg.footer) ~= title_text(footer) or cfg.footer_pos ~= 'left' then
        pcall(vim.api.nvim_win_set_config, win, { footer = footer, footer_pos = 'left' })
      end
    end
  end
end

local function place_editors(region)
  local editors = editor_windows()
  if #editors == 0 or not region then
    return
  end
  local gaps = #editors - 1
  local inner = math.max(#editors, region.width - gaps * 3)
  local each = math.max(8, math.floor(inner / #editors))
  local col = region.col
  for index, win in ipairs(editors) do
    local width = index == #editors and math.max(8, region.col + region.width - col) or each
    apply_box(win, {
      row = region.row,
      col = col,
      width = width,
      height = region.height,
    }, { footer = M.mode_footer(), footer_pos = 'left' })
    style_editor(win)
    col = col + width + 3
  end
end

local function place_overlays(region)
  if not region then
    return
  end
  local width = math.max(20, math.min(region.width, math.floor(vim.o.columns * 0.72)))
  local height = math.max(6, region.height - 2)
  local box = {
    row = region.row + 1,
    col = math.max(1, math.floor((vim.o.columns - width) / 2)),
    width = width,
    height = height,
  }
  for _, win in ipairs(each_role(overlay_role)) do
    apply_box(win, box)
  end
end

function M.relayout()
  if placing or not ready then
    return
  end
  placing = true
  canvas = find_canvas() or canvas
  if canvas and vim.api.nvim_win_is_valid(canvas) then
    paint_canvas(canvas)
  end
  local g = M.geometry()
  place_editors(g.editor)
  local left = left_window()
  if left and g.left then
    apply_box(left, g.left, { title = ' Explorer ', title_pos = 'center' })
    style_side(left)
  end
  local right = right_window()
  if right and g.right then
    apply_box(right, g.right, { title = side_title(right), title_pos = 'center' })
    style_side(right)
  end
  place_overlays(g.editor)
  placing = false
  M.refresh_mode()
  M.paint_focus()
end

local function queue_relayout()
  if place_queued or not ready then
    return
  end
  place_queued = true
  vim.schedule(function()
    place_queued = false
    M.relayout()
  end)
end

local function centered_box()
  local g = M.geometry()
  local width = math.max(24, math.min(g.editor.width, math.floor(vim.o.columns * 0.7)))
  local height = math.max(8, g.editor.height - 2)
  return {
    row = g.editor.row,
    col = math.max(1, math.floor((vim.o.columns - width) / 2)),
    width = width,
    height = height,
  }
end

local function convert_window(win)
  if not ready or not vim.api.nvim_win_is_valid(win) or win == canvas or role_of(win) == canvas_role then
    return
  end
  local cfg = vim.api.nvim_win_get_config(win)
  if cfg.relative ~= '' then
    return
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local bt = vim.bo[buf].buftype
  local ft = vim.bo[buf].filetype
  if ft == 'panel-canvas' then
    -- :split from a float splits the canvas and can show the blank buffer.
    buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_win_set_buf(win, buf)
    bt = ''
    ft = ''
  end
  if ft == 'neo-tree' or ft == 'codecompanion' or ft == 'codecompanion_cli' then
    return
  end
  if bt == 'help' or bt == 'quickfix' or ft == 'qf' or ft == 'man' then
    apply_box(win, centered_box())
    set_role(win, overlay_role)
    vim.api.nvim_set_option_value('winbar', '', { scope = 'local', win = win })
    return
  end
  local g = M.geometry()
  apply_box(win, g.editor)
  style_editor(win)
  last_editor = win
end

local function primary_editor()
  local function usable(win)
    return win and vim.api.nvim_win_is_valid(win) and role_of(win) == editor_role and vim.bo[vim.api.nvim_win_get_buf(win)].buftype ~= 'terminal'
  end
  if usable(last_editor) then
    return last_editor
  end
  for _, win in ipairs(editor_windows()) do
    if usable(win) then
      return win
    end
  end
  local editors = editor_windows()
  return editors[1]
end

---Open a file in the editor card. Used by the file tree so it does not land on the canvas.
---@param path string
---@param opts? { split?: boolean }
---@return boolean
function M.open_in_editor(path, opts)
  opts = opts or {}
  if type(path) ~= 'string' or path == '' or vim.fn.isdirectory(path) == 1 then
    return false
  end
  local win = primary_editor()
  if opts.split or not win then
    local buf = vim.api.nvim_create_buf(true, false)
    local g = M.geometry()
    win = open_float(buf, g.editor, 20)
    style_editor(win)
  end
  if not win or not vim.api.nvim_win_is_valid(win) then
    return false
  end
  last_editor = win
  vim.api.nvim_set_current_win(win)
  local ok = pcall(vim.cmd.edit, path)
  M.relayout()
  return ok
end

local function exiting()
  local code = vim.v.exiting
  return code ~= nil and code ~= vim.NIL
end

local function ensure_layout()
  local existing = find_canvas()
  if existing then
    canvas = existing
    ready = true
    M.relayout()
    return
  end

  local normals = {}
  for _, win in ipairs(tab_wins()) do
    if vim.api.nvim_win_get_config(win).relative == '' then
      normals[#normals + 1] = win
    end
  end
  if #normals == 0 then
    return
  end

  local host = normals[1]
  local original = vim.api.nvim_win_get_buf(host)
  local scratch = vim.api.nvim_create_buf(false, true)
  vim.bo[scratch].buftype = 'nofile'
  vim.bo[scratch].bufhidden = 'hide'
  vim.bo[scratch].swapfile = false
  vim.bo[scratch].buflisted = false
  vim.bo[scratch].filetype = 'panel-canvas'
  vim.api.nvim_buf_set_name(scratch, 'panel-canvas-' .. vim.api.nvim_get_current_tabpage())
  vim.api.nvim_win_set_buf(host, scratch)
  canvas = host
  set_role(canvas, canvas_role)
  paint_canvas(canvas)

  local g = M.geometry()
  local editor = open_float(original, g.editor, 20)
  style_editor(editor)
  last_editor = editor

  ready = true
  for index = 2, #normals do
    convert_window(normals[index])
  end
  pcall(vim.api.nvim_win_set_config, canvas, { focusable = false })
  if vim.api.nvim_win_is_valid(editor) then
    vim.api.nvim_set_current_win(editor)
  end
  M.relayout()
end

local function focus_card(direction)
  local current = vim.api.nvim_get_current_win()
  local origin = vim.api.nvim_win_get_position(current)
  local best, best_score
  for _, win in ipairs(tab_wins()) do
    if win ~= current and win ~= canvas and role_of(win) ~= canvas_role then
      local cfg = vim.api.nvim_win_get_config(win)
      local ft = filetype_of(win)
      local card_win = role_of(win) == editor_role or ft == 'neo-tree' or ft == 'codecompanion' or ft == 'codecompanion_cli'
      if card_win and cfg.relative ~= '' and cfg.focusable ~= false then
        local pos = vim.api.nvim_win_get_position(win)
        local row_delta = pos[1] - origin[1]
        local col_delta = pos[2] - origin[2]
        local toward = (direction == 'h' and col_delta < -1)
          or (direction == 'l' and col_delta > 1)
          or (direction == 'j' and row_delta > 1)
          or (direction == 'k' and row_delta < -1)
        if toward then
          local score = (direction == 'h' or direction == 'l') and (math.abs(col_delta) * 2 + math.abs(row_delta))
            or (math.abs(row_delta) * 2 + math.abs(col_delta))
          if not best_score or score < best_score then
            best, best_score = win, score
          end
        end
      end
    end
  end
  if best then
    vim.api.nvim_set_current_win(best)
  end
end

function M.focus(direction)
  if vim.fn.mode() == 't' then
    return
  end
  focus_card(direction)
end

local function set_border_hl(win, active)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  local current = vim.wo[win].winhighlight or ''
  local group = active and 'PanelBorderActive' or 'PanelBorder'
  local stripped = current:gsub(',?FloatBorder:[^,]+', ''):gsub('^,', ''):gsub(',,', ',')
  local next_hl = stripped == '' and ('FloatBorder:' .. group) or (stripped .. ',FloatBorder:' .. group)
  if next_hl ~= current then
    vim.wo[win].winhighlight = next_hl
  end
end

---Card strokes stay the same orange as the current line number.
function M.paint_focus()
  if not card then
    return
  end
  local current = vim.api.nvim_get_current_win()
  for _, win in ipairs(tab_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= '' then
      set_border_hl(win, win == current)
    end
  end
  vim.api.nvim_set_hl(0, 'NeoTreeFloatBorder', { fg = card.border or card.active, bg = card.canvas })
end

function M.apply()
  card = capture() or card
  if not card then
    return
  end

  local editor_bg = card.editor_bg
  local canvas_bg = card.canvas
  local text = card.text
  local muted = card.muted
  local status_bg = card.status_bg or canvas_bg
  local directory = card.directory or card.blue
  local selection = card.selection or editor_bg
  local border = card.border or card.cursor_nr or card.active

  vim.api.nvim_set_hl(0, 'PanelCanvas', { fg = canvas_bg, bg = canvas_bg })
  vim.api.nvim_set_hl(0, 'EditorPanel', { fg = text, bg = editor_bg })
  vim.api.nvim_set_hl(0, 'EditorPanelEnd', { fg = editor_bg, bg = editor_bg })
  vim.api.nvim_set_hl(0, 'SidePanel', { fg = text, bg = editor_bg })
  vim.api.nvim_set_hl(0, 'SidePanelEnd', { fg = editor_bg, bg = editor_bg })
  vim.api.nvim_set_hl(0, 'PanelBorder', { fg = border, bg = canvas_bg })
  vim.api.nvim_set_hl(0, 'PanelBorderActive', { fg = border, bg = canvas_bg })

  vim.api.nvim_set_hl(0, 'WinSeparator', { fg = canvas_bg, bg = canvas_bg })
  vim.api.nvim_set_hl(0, 'FloatBorder', { fg = border, bg = canvas_bg })
  vim.api.nvim_set_hl(0, 'FloatTitle', { fg = text, bg = canvas_bg })
  vim.api.nvim_set_hl(0, 'FloatFooter', { fg = text, bg = canvas_bg })
  local function mode_hl(group, accent)
    if accent then
      vim.api.nvim_set_hl(0, group, { fg = editor_bg, bg = accent, bold = true })
    end
  end
  mode_hl('PanelModeNormal', card.blue)
  mode_hl('PanelModeInsert', card.green)
  mode_hl('PanelModeVisual', card.purple)
  mode_hl('PanelModeTerminal', card.yellow)
  mode_hl('PanelModeReplace', card.red)
  mode_hl('PanelModeCommand', card.yellow)
  mode_hl('PanelModeSelect', card.purple)
  vim.api.nvim_set_hl(0, 'WinBar', { fg = muted, bg = editor_bg })
  vim.api.nvim_set_hl(0, 'WinBarNC', { fg = muted, bg = editor_bg })
  vim.api.nvim_set_hl(0, 'NormalFloat', { fg = text, bg = editor_bg })
  vim.api.nvim_set_hl(0, 'Pmenu', { fg = text, bg = canvas_bg })
  vim.api.nvim_set_hl(0, 'PmenuSel', { fg = text, bg = selection })
  vim.api.nvim_set_hl(0, 'PmenuThumb', { bg = card.hairline })
  vim.api.nvim_set_hl(0, 'CursorLine', { bg = selection })
  vim.api.nvim_set_hl(0, 'SignColumn', { bg = editor_bg })
  vim.api.nvim_set_hl(0, 'LineNr', { fg = card.linenr or muted })
  vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = card.cursor_nr or text, bold = true })
  vim.api.nvim_set_hl(0, 'IblIndent', { fg = card.hairline })
  vim.api.nvim_set_hl(0, 'IblScope', { fg = muted })
  vim.api.nvim_set_hl(0, 'StatusLine', { fg = text, bg = status_bg })
  vim.api.nvim_set_hl(0, 'StatusLineNC', { fg = muted, bg = status_bg })
  vim.api.nvim_set_hl(0, 'MiniStatuslineFilename', { fg = text, bg = status_bg })
  vim.api.nvim_set_hl(0, 'MiniStatuslineDevinfo', { fg = muted, bg = status_bg })
  vim.api.nvim_set_hl(0, 'MiniStatuslineInactive', { fg = muted, bg = status_bg })
  vim.api.nvim_set_hl(0, 'NeoTreeFloatNormal', { fg = text, bg = editor_bg })
  vim.api.nvim_set_hl(0, 'NeoTreeFloatBorder', { fg = border, bg = canvas_bg })
  vim.api.nvim_set_hl(0, 'NeoTreeFloatTitle', { fg = text, bg = canvas_bg })
  vim.api.nvim_set_hl(0, 'NeoTreeNormal', { fg = text, bg = editor_bg })
  vim.api.nvim_set_hl(0, 'NeoTreeNormalNC', { fg = text, bg = editor_bg })
  vim.api.nvim_set_hl(0, 'NeoTreeEndOfBuffer', { fg = editor_bg, bg = editor_bg })
  vim.api.nvim_set_hl(0, 'NeoTreeWinSeparator', { fg = canvas_bg, bg = canvas_bg })
  vim.api.nvim_set_hl(0, 'NeoTreeCursorLine', { bg = selection })
  vim.api.nvim_set_hl(0, 'NeoTreeRootName', { fg = directory, bold = true })
  vim.api.nvim_set_hl(0, 'NeoTreeDirectoryName', { fg = directory })
  vim.api.nvim_set_hl(0, 'NeoTreeDirectoryIcon', { fg = directory })
  vim.api.nvim_set_hl(0, 'NeoTreeDimText', { fg = card.hairline })
  vim.api.nvim_set_hl(0, 'NeoTreeFileName', { fg = text })
  vim.api.nvim_set_hl(0, 'Directory', { fg = directory })

  if canvas and vim.api.nvim_win_is_valid(canvas) then
    paint_canvas(canvas)
  end
end

function M.setup()
  vim.o.winborder = 'rounded'
  vim.o.laststatus = 3
  vim.o.winbar = ''
  vim.opt.fillchars:append {
    eob = ' ',
    vert = ' ',
    horiz = ' ',
  }

  local group = vim.api.nvim_create_augroup('custom-panels', { clear = true })
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = group,
    callback = function()
      M.apply()
      vim.schedule(function()
        M.apply()
        queue_relayout()
      end)
    end,
  })
  vim.api.nvim_create_autocmd('VimEnter', {
    group = group,
    callback = ensure_layout,
  })
  vim.api.nvim_create_autocmd('TabEnter', {
    group = group,
    callback = function()
      if ready then
        ensure_layout()
      end
    end,
  })
  vim.api.nvim_create_autocmd('WinNew', {
    group = group,
    callback = function()
      -- A split from a float splits the canvas. Convert it before WinEnter so
      -- the file tree does not treat it as a normal window and close itself.
      local tab = vim.api.nvim_get_current_tabpage()
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        convert_window(win)
      end
      queue_relayout()
    end,
  })
  vim.api.nvim_create_autocmd('WinEnter', {
    group = group,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      if role_of(win) == editor_role then
        last_editor = win
      end
      if win == canvas or role_of(win) == canvas_role then
        local editor = primary_editor()
        if editor and vim.api.nvim_win_is_valid(editor) then
          vim.api.nvim_set_current_win(editor)
        end
        return
      end
      M.paint_focus()
      queue_relayout()
    end,
  })
  vim.api.nvim_create_autocmd('ModeChanged', {
    group = group,
    callback = function()
      if ready then
        M.refresh_mode()
      end
    end,
  })
  vim.api.nvim_create_autocmd('WinClosed', {
    group = group,
    callback = function()
      vim.schedule(function()
        if exiting() or not ready then
          return
        end
        canvas = find_canvas()
        if not canvas or not vim.api.nvim_win_is_valid(canvas) then
          return
        end
        if #editor_windows() == 0 and not left_window() and not right_window() then
          -- :q on the last file quits. A cancelled prompt (unsaved changes) leaves an editor card.
          if not pcall(vim.cmd.quitall) then
            local buf = vim.api.nvim_create_buf(true, false)
            local g = M.geometry()
            local editor = open_float(buf, g.editor, 20)
            style_editor(editor)
            last_editor = editor
            vim.api.nvim_set_current_win(editor)
            M.relayout()
          end
          return
        end
        if #editor_windows() == 0 then
          local buf = vim.api.nvim_create_buf(true, false)
          local g = M.geometry()
          local editor = open_float(buf, g.editor, 20)
          style_editor(editor)
          last_editor = editor
          vim.api.nvim_set_current_win(editor)
        end
        M.relayout()
      end)
    end,
  })
  vim.api.nvim_create_autocmd('VimResized', {
    group = group,
    callback = function()
      M.relayout()
      -- Neo-tree rewrites its float to `relative = "win"` shortly after this.
      vim.defer_fn(M.relayout, 180)
    end,
  })
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = { 'CodeCompanionChatOpened', 'CodeCompanionCLIOpened', 'CodeCompanionChatHidden', 'CodeCompanionCLIHidden' },
    callback = function()
      M.relayout()
    end,
  })
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = { 'neo-tree', 'codecompanion', 'codecompanion_cli' },
    callback = function()
      queue_relayout()
    end,
  })

  M.apply()
  if vim.v.vim_did_enter == 1 then
    ensure_layout()
  end
end

return M
