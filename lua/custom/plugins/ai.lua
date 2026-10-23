-- The panel you last opened. <leader>ii toggles this instead of asking again.
local active ---@type { kind: 'cli'|'chat', id: string }|nil

local function hide_chat()
  local chat = require 'codecompanion.interactions.chat'
  if chat.is_visible() then
    local last = chat.last_chat()
    if last and last.ui then
      last.ui:hide()
    end
  end
end

local function hide_cli()
  local cli = require 'codecompanion.interactions.cli'
  local visible = cli.get_visible()
  if visible then
    visible.ui:hide()
  end
end

local function show_cli(agent)
  active = { kind = 'cli', id = agent }
  hide_chat()
  local cli = require 'codecompanion.interactions.cli'
  local instance = cli.find_by_agent(agent)
  if not instance then
    instance = cli.create { agent = agent }
  end
  if not instance then
    vim.notify('Could not start ' .. agent, vim.log.levels.WARN)
    return
  end
  if not instance.ui:is_visible() then
    instance.ui:open()
  end
  instance:focus()
end

local function show_chat(adapter)
  active = { kind = 'chat', id = adapter }
  hide_cli()
  local codecompanion = require 'codecompanion'
  local last = codecompanion.last_chat()
  if last and last.adapter and last.adapter.name == adapter and last.ui then
    if not last.ui:is_visible() then
      last.ui:open()
    end
    if last.ui.winnr and vim.api.nvim_win_is_valid(last.ui.winnr) then
      vim.api.nvim_set_current_win(last.ui.winnr)
    end
    return
  end
  hide_chat()
  codecompanion.chat { params = { adapter = adapter } }
end

local function choose_any_provider()
  show_chat 'anthropic'
  local last = require('codecompanion').last_chat()
  if not last then
    return
  end
  -- Chat opens into insert mode on the next tick. Open the adapter list after that.
  vim.schedule(function()
    if vim.fn.mode():find '^[it]' then
      vim.cmd.stopinsert()
    end
    require('codecompanion.interactions.chat.keymaps.change_adapter').callback(last)
  end)
end

local function provider_choices()
  local items = {}
  local function add(label, action)
    items[#items + 1] = { label = label, action = action }
  end

  if vim.fn.executable 'claude' == 1 then
    add('Claude Code', function()
      show_cli 'claude_code'
    end)
  end
  if vim.fn.executable 'codex' == 1 then
    add('Codex', function()
      show_cli 'codex'
    end)
  end
  if vim.fn.executable 'grok' == 1 then
    add('Grok', function()
      show_cli 'grok'
    end)
  end

  add('Claude API', function()
    show_chat 'anthropic'
  end)
  add('Grok API', function()
    show_chat 'xai'
  end)
  add('OpenAI', function()
    show_chat 'openai'
  end)
  add('Gemini', function()
    show_chat 'gemini'
  end)
  add('Copilot', function()
    show_chat 'copilot'
  end)
  add('OpenRouter', function()
    show_chat 'openrouter'
  end)
  add('Ollama', function()
    show_chat 'ollama'
  end)
  add('All providers…', choose_any_provider)

  return items
end

local function choose_provider()
  if vim.fn.mode() == 't' then
    vim.cmd.stopinsert()
  end
  local items = provider_choices()
  vim.ui.select(items, {
    prompt = 'AI provider',
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if choice then
      choice.action()
    end
  end)
end

---The card layout moves the CLI window, so CodeCompanion's saved window id can be stale.
local function tracked_cli()
  local cli = require 'codecompanion.interactions.cli'
  local instance = cli.get_visible() or cli.last_cli()
  if not instance or not instance.bufnr then
    return instance
  end
  if instance.ui and instance.ui:is_visible() then
    return instance
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == instance.bufnr and vim.api.nvim_win_get_config(win).relative ~= '' then
      instance.ui.winnr = win
      return instance
    end
  end
  return instance
end

local function hide_open_panel()
  local instance = tracked_cli()
  if instance and instance.ui and instance.ui:is_visible() then
    active = { kind = 'cli', id = instance.agent_name }
    instance.ui:hide()
    return true
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'codecompanion' then
      local chat = require('codecompanion').last_chat()
      if chat and chat.ui and chat.ui:is_visible() then
        local adapter = chat.adapter and chat.adapter.name
        if adapter then
          active = { kind = 'chat', id = adapter }
        end
        chat.ui:hide()
        return true
      end
    end
  end

  return false
end

local function reopen_active()
  if not active then
    local instance = tracked_cli()
    if instance and instance.agent_name then
      active = { kind = 'cli', id = instance.agent_name }
    end
  end
  if not active then
    return false
  end
  if active.kind == 'cli' then
    show_cli(active.id)
  else
    show_chat(active.id)
  end
  return true
end

local function toggle_panel()
  if vim.fn.mode() == 't' then
    vim.cmd.stopinsert()
  end
  if hide_open_panel() then
    return
  end
  if reopen_active() then
    return
  end
  choose_provider()
end

local function selection_text()
  local bufnr = vim.api.nvim_get_current_buf()
  local mode = vim.fn.mode()
  local visual = mode == 'v' or mode == 'V' or mode == '\22'
  local start_pos = vim.fn.getpos(visual and 'v' or "'<")
  local end_pos = vim.fn.getpos(visual and '.' or "'>")
  if start_pos[2] == 0 or end_pos[2] == 0 then
    return nil
  end

  local lines = require('codecompanion.utils.context').get_visual_selection(bufnr)
  if not lines or #lines == 0 then
    return nil
  end
  local body = table.concat(lines, '\n')
  if vim.trim(body) == '' then
    return nil
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  local path = name == '' and '[No Name]' or vim.fn.fnamemodify(name, ':.')
  local ft = vim.bo[bufnr].filetype
  return string.format('From %s:\n```%s\n%s\n```\n', path, ft, body)
end

---Codex and Claude read a raw newline as Enter. Bracketed paste stays in the composer.
---@param text string
---@return string
local function composer_text(text)
  local body = text:gsub('\r\n', '\n'):gsub('\r', '\n'):gsub('\n+$', '')
  return '\27[200~' .. body .. '\27[201~'
end

---Add the visual selection to the open provider's input. Nothing is submitted.
local function send_selection()
  local text = selection_text()
  if not text then
    vim.notify('Select some code first', vim.log.levels.WARN)
    return
  end

  if not active then
    local instance = tracked_cli()
    if instance and instance.agent_name then
      active = { kind = 'cli', id = instance.agent_name }
    end
  end
  if not active then
    vim.notify('Open the AI panel first', vim.log.levels.WARN)
    return
  end

  if active.kind == 'cli' then
    show_cli(active.id)
    local instance = require('codecompanion.interactions.cli').find_by_agent(active.id)
    if not instance then
      vim.notify('Could not open ' .. active.id, vim.log.levels.WARN)
      return
    end
    instance:send(composer_text(text), { submit = false })
    return
  end

  show_chat(active.id)
  local chat = require('codecompanion').last_chat()
  if not chat or not chat.adapter or chat.adapter.name ~= active.id then
    vim.notify('Could not open the AI chat', vim.log.levels.WARN)
    return
  end
  chat:add_buf_message { role = 'user', content = text }
end

return {
  'olimorris/codecompanion.nvim',
  version = '^20.0.0',
  cmd = { 'CodeCompanion', 'CodeCompanionChat', 'CodeCompanionActions', 'CodeCompanionCLI' },
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
  },
  opts = {
    display = {
      chat = {
        intro_message = 'Press ga to switch provider and model. Press ? for keys.',
        start_in_insert_mode = true,
        show_settings = false,
        window = {
          layout = 'float',
          border = 'rounded',
          relative = 'editor',
          width = function()
            return require('custom.panels').geometry({ right = true }).right.width
          end,
          height = function()
            return require('custom.panels').geometry({ right = true }).right.height
          end,
          row = 2,
          col = 2,
          opts = {
            breakindent = true,
            cursorline = false,
            linebreak = true,
            number = false,
            relativenumber = false,
            signcolumn = 'no',
            wrap = true,
          },
        },
      },
      cli = {
        window = {
          opts = {
            number = false,
            relativenumber = false,
            signcolumn = 'no',
          },
        },
      },
    },
    interactions = {
      chat = { adapter = 'anthropic' },
      inline = { adapter = 'anthropic' },
      cmd = { adapter = 'anthropic' },
      cli = {
        agent = 'claude_code',
        opts = { auto_insert = true },
        agents = {
          claude_code = {
            cmd = 'claude',
            args = {},
            description = 'Claude Code',
          },
          codex = {
            cmd = 'codex',
            args = {},
            description = 'Codex',
          },
          grok = {
            cmd = 'grok',
            args = {},
            description = 'Grok',
          },
        },
      },
    },
  },
  keys = {
    { '<leader>ii', toggle_panel, mode = { 'n', 't' }, desc = 'Toggle AI panel' },
    { '<leader>ip', choose_provider, mode = { 'n', 't' }, desc = 'Choose AI provider' },
    { '<leader>ia', '<cmd>CodeCompanionActions<cr>', mode = { 'n', 'x' }, desc = 'AI actions' },
    { '<leader>is', send_selection, mode = 'x', desc = 'Add selection to the AI input' },
  },
}
