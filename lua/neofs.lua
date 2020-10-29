-- TODO: Use a hidden "input" window that contains input focus so you don't have to see the cursor in the file manager

local devicons = require('nvim-web-devicons')
local M = {
  tabs = {},
  tab_idx = nil,
}

M.config = {
  devicons = false
}

M.util = {}

function M.util.map(array, f)
  local new = {}
  for _, x in ipairs(array) do
    table.insert(new, f(x))
  end
  return new
end

M.is_windows = jit.os == "Windows"

if M.is_windows then
  M.fs_seperator = "\\"
else
  M.fs_seperator = "/"
end

function M.util.fs_readdir(dir)
  return M.util.map(vim.fn.systemlist("dir /b " .. dir), function (x)
    local name = x:sub(1, -2)
    local path = dir .. M.fs_seperator .. name

    return {
      name = name,
      path = path,
      stat = vim.loop.fs_stat(path)
    }
  end)
end

function NeofsMove(direction)
  local move_handler = {
    right = function()
      local tab = M.tabs[M.tab_idx]
      local item = tab.items[tab.row]
      if item.stat.type == "file" then
        NeofsQuit()
        vim.cmd("e " .. item.path)
      else
        local tab = M.new_tab(M.tab_idx + 1, item.path)
      end
    end,
    left = function()
      if M.tab_idx ~= 1 then
        local tab = M.tabs[M.tab_idx]
        -- to avoid calling NeofsQuit
        vim.api.nvim_buf_call(tab.buffer, function()
          vim.cmd [[au! * <buffer>]]
        end)
        vim.api.nvim_win_close(tab.win, false)
        M.tabs[M.tab_idx] = nil
        M.tab_idx = #M.tabs
        NeofsReposition()
      end
    end,
    down = function()
      local tab = M.tabs[M.tab_idx]
      if tab.row ~= #tab.items then
        tab.row = tab.row + 1
        vim.api.nvim_win_set_cursor(tab.win, { tab.row, 0 })
      end
    end,
    up = function()
      local tab = M.tabs[M.tab_idx]
      if tab.row ~= 1 then
        tab.row = tab.row - 1
        vim.api.nvim_win_set_cursor(tab.win, { tab.row, 0 })
      end
    end,
  }

  move_handler[direction]()
end

function NeofsCreateFile()
  local tab = M.tabs[M.tab_idx]
  local name = vim.fn.input('New File: ')
  local file = vim.loop.fs_open(tab.path .. M.fs_seperator .. name, 'w', 777)
  vim.loop.fs_close(file)
  NeofsRefresh()
end

function NeofsCreateDirectory()
  local tab = M.tabs[M.tab_idx]
  local name = vim.fn.input('New Directory: ')
  vim.loop.fs_mkdir(tab.path .. M.fs_seperator .. name, 777)
  NeofsRefresh()
end

function NeofsDelete()
  local tab = M.tabs[M.tab_idx]
  local item = tab.items[tab.row]

  if item.stat.type == "file" then
    if vim.fn.confirm(string.format("Are you sure you want to delete the file '%s'?", item.name), '&Yes\n&No') == 1 then
      vim.loop.fs_unlink(item.path)
    end
  else
    if vim.fn.confirm(string.format("Are you sure you want to delete the directory '%s'?", item.name), '&Yes\n&No') == 1 then
      vim.loop.fs_rmdir(item.path)
    end
  end

  NeofsRefresh()
end

function NeofsReposition()
  local vim_height = vim.api.nvim_eval [[&lines]]
  local vim_width = vim.api.nvim_eval [[&columns]]
  local width = math.floor(vim_width * 0.6 / #M.tabs)
  local height = math.floor(vim_height * 0.6)

  for idx, tab in ipairs(M.tabs) do
    vim.api.nvim_win_set_config(tab.win, {
      relative = 'editor',
      width = width,
      height = height,
      col = (vim_width * 0.2) + width * (idx - 1),
      row = vim_height * 0.2
    })
  end
end

local function item_to_display_text(item)
  if item.stat.type == 'file' then
    local ext_tokens = vim.split(item.name, '.', true)
    local ext = ext_tokens[#ext_tokens]
    local icon = devicons.get_icon(item.name, ext, { default = true })
    return icon .. " " .. item.name
  else
    return " " .. item.name
  end
end

function NeofsRefresh()
  local tab = M.tabs[M.tab_idx]
  tab.items = M.util.fs_readdir(tab.path)

  vim.api.nvim_buf_set_lines(tab.buffer, 0, -1, false, M.util.map(tab.items, item_to_display_text))

  if tab.row > #tab.items then
    tab.row = tab.row - 1
  end

  vim.api.nvim_win_set_cursor(tab.win, { tab.row, 0 })
end

function NeofsQuit()
  local count = #M.tabs

  M.tabs = {}
  M.tab_idx = nil

  for i=1,count do
    vim.cmd [[:quit]]
  end
end

function M.new_tab(idx, path)
  local vim_height = vim.api.nvim_eval [[&lines]]
  local vim_width = vim.api.nvim_eval [[&columns]]
  local width = math.floor(vim_width * 0.6 / (#M.tabs + 1))
  local height = math.floor(vim_height * 0.6)
  local col = (vim_width * 0.2) + width * (idx - 1)
  local row = vim_height * 0.2

  local buffer = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buffer, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal'
  })

  vim.wo.cursorline = true

  local mappings = { n = {} }

  mappings['n']['h'] = [[:lua NeofsMove('left')<CR>]]
  mappings['n']['j'] = [[:lua NeofsMove('down')<CR>]]
  mappings['n']['k'] = [[:lua NeofsMove('up')<CR>]]
  mappings['n']['l'] = [[:lua NeofsMove('right')<CR>]]

  mappings['n']['f'] = [[:lua NeofsCreateFile()<CR>]]
  mappings['n']['d'] = [[:lua NeofsCreateDirectory()<CR>]]
  mappings['n']['<c-d>'] = [[:lua NeofsDelete()<CR>]]

  mappings['n']['q'] = [[:lua NeofsQuit()<CR>]]

  for mode, mappings in pairs(mappings) do
    for lhs, rhs in pairs(mappings) do
      vim.api.nvim_buf_set_keymap(buffer, mode, lhs, rhs, {
        noremap = true,
        silent = true
      })
    end
  end

  vim.cmd [[au WinClosed <buffer> lua NeofsQuit()]]

  local items = M.util.fs_readdir(path)

  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, M.util.map(items, item_to_display_text))
  
  M.tab_idx = idx

  local tab = {
    buffer = buffer,
    path = path,
    row = 1,
    win = win,
    items = items
  }

  NeofsReposition()

  table.insert(M.tabs, tab)

  return tab
end

function M.open() 
  M.new_tab(1, vim.loop.cwd())
end

function M.setup(opts)
  opts = opts or {}
  for key, val in pairs(opts) do
    M.config[key] = val
  end
end

return M
