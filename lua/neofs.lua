local M = {
  fm = nil,
  config = {
    devicons = false,
    mappings = {}
  }
}

NeofsCustomMappings = {}

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
    root = function()
      M.fm.path = vim.loop.cwd()
      M.fm.refresh()
    end,
    right = function()
      local item = M.fm.navigator.item()

      if not item then
        return
      end

      if item.stat.type == "file" then
        NeofsQuit()
        vim.cmd("e " .. item.path)
      else
        M.fm.path = item.path
        M.fm.refresh()
      end
    end,
    left = function()
      M.fm.path = M.fm.parent()
      M.fm.refresh()
    end,
    down = function()
      local navigator = M.fm.navigator
      if navigator.row ~= #navigator.items then
        navigator.row = navigator.row + 1
        vim.api.nvim_win_set_cursor(navigator.window, { navigator.row, 0 })
        M.fm.refresh_preview()
      end
    end,
    up = function()
      local navigator = M.fm.navigator
      if navigator.row ~= 1 then
        navigator.row = navigator.row - 1
        vim.api.nvim_win_set_cursor(navigator.window, { navigator.row, 0 })
        M.fm.refresh_preview()
      end
    end,
  }

  move_handler[direction]()
end

function NeofsCreateFile()
  local name = vim.fn.input('New File: ')
  if name == "" then
    return
  end
  local file = vim.loop.fs_open(M.fm.path .. M.fs_seperator .. name, 'w', 0640)
  vim.loop.fs_close(file)
  NeofsRefresh()
end

function NeofsCreateDirectory()
  local name = vim.fn.input('New Directory: ')
  if name == "" then
    return
  end
  vim.loop.fs_mkdir(M.fm.path .. M.fs_seperator .. name, 0640)
  NeofsRefresh()
end

local function fs_delete_rec(item)
  if item.stat.type == "file" then
    vim.loop.fs_unlink(item.path)
  else
    for _, item in ipairs(M.util.fs_readdir(item.path)) do
      fs_delete_rec(item)
    end
    vim.loop.fs_rmdir(item.path)
  end
end

function NeofsDelete(recursive)
  local item = M.fm.navigator.item()
  local message = string.format("Are you sure you want to delete '%s'?", item.name)

  if recursive then
    message = message .. " [RECURSIVE]"
  end

  if vim.fn.confirm(message, '&Yes\n&No') == 1 then
    if item.stat.type == "file" then
      vim.loop.fs_unlink(item.path)
    else
      if recursive then
        fs_delete_rec(item)
      else
        vim.loop.fs_rmdir(item.path)
      end
    end

    M.fm.refresh()
  end
end

local function item_to_display_text(item)
  if M.config.devicons then
    local devicons = require('nvim-web-devicons')
    if item.stat.type == 'file' then
      local ext_tokens = vim.split(item.name, '.', true)
      local ext = ext_tokens[#ext_tokens]
      local icon = devicons.get_icon(item.name, ext, { default = true })
      return icon .. " " .. item.name
    else
      return " " .. item.name
    end
  else
    if item.stat.type == 'file' then
      return "F " .. item.name
    else
      return "D " .. item.name
    end
  end
end

function NeofsRefresh()
  if M.fm then
    M.fm.refresh()
  end
end

function NeofsRename()
  if M.fm then
    local item = M.fm.navigator.item()
    local name = vim.fn.input {
      prompt = 'Rename: ',
      default = item.path,
      cancelreturn = item.path
    }

    if name == "" then
      return
    end

    vim.loop.fs_rename(item.path, name)

    M.fm.refresh()
  end
end

function NeofsCallCustomMapping(id)
  NeofsCustomMappings[id](M.fm)
end

function NeofsQuit()
  if M.fm then
    vim.api.nvim_win_close(M.fm.decorations.window, false)

    vim.api.nvim_buf_call(M.fm.navigator.buffer, function()
      vim.cmd [[au! * <buffer>]]
    end)
    vim.api.nvim_win_close(M.fm.navigator.window, false)

    vim.api.nvim_buf_call(M.fm.preview.buffer, function()
      vim.cmd [[au! * <buffer>]]
    end)
    vim.api.nvim_win_close(M.fm.preview.window, false)
    M.fm = nil
  end
end

function NeofsOnCursorMoved()
  if M.fm then
    local pos = vim.api.nvim_win_get_cursor(M.fm.navigator.window)
    M.fm.navigator.row = pos[1]
    M.fm.refresh_preview()
  end
end

local function define_mappings(buffer)
    local mappings = { n = {} }

    mappings['n']['0'] = [[:lua NeofsMove('root')<CR>]]
    mappings['n']['h'] = [[:lua NeofsMove('left')<CR>]]
    mappings['n']['j'] = [[:lua NeofsMove('down')<CR>]]
    mappings['n']['k'] = [[:lua NeofsMove('up')<CR>]]
    mappings['n']['l'] = [[:lua NeofsMove('right')<CR>]]
    mappings['n']['<cr>'] = [[:lua NeofsMove('right')<CR>]]

    mappings['n']['f'] = [[:lua NeofsCreateFile()<CR>]]
    mappings['n']['d'] = [[:lua NeofsCreateDirectory()<CR>]]
    mappings['n']['<c-r>'] = [[:lua NeofsRename()<CR>]]
    mappings['n']['<c-d>'] = [[:lua NeofsDelete(false)<CR>]]
    mappings['n']['<m-c-d>'] = [[:lua NeofsDelete(true)<CR>]]

    mappings['n']['q'] = [[:lua NeofsQuit()<CR>]]

    for lhs, rhs in pairs(M.config.mappings) do
      table.insert(NeofsCustomMappings, rhs)
      mappings['n'][lhs] = string.format([[:lua NeofsCallCustomMapping(%d)<CR>]], #NeofsCustomMappings)
    end

    for mode, mappings in pairs(mappings) do
      for lhs, rhs in pairs(mappings) do
        vim.api.nvim_buf_set_keymap(buffer, mode, lhs, rhs, {
          noremap = true,
          silent = true
        })
      end
    end
end

local function display_items(buffer, items)
  vim.api.nvim_buf_call(buffer, function()
    vim.bo.readonly = false
    vim.bo.modifiable = true
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, M.util.map(items, item_to_display_text))
    vim.bo.readonly = true
    vim.bo.modifiable = false
  end)
end

local function fm_new(path)
  local fm = {
    path = path,
    decorations = {
      buffer = nil,
      window = nil,
    },
    navigator = {
      window = nil,
      buffer = nil,
      items = {},
      row = 1,
    },
    preview = {
      window = nil,
      buffer = nil,
    }
  }

  function fm.navigator.item()
    return fm.navigator.items[fm.navigator.row]
  end

  function fm.parent()
    return vim.fn.fnamemodify(fm.path, ':h')
  end

  function fm.refresh_preview()
    local item = fm.navigator.item()

    if not item then
      return
    end

    if item.stat.type == "file" then
      local file = vim.loop.fs_open(item.path, "r", 777)
      local content = vim.loop.fs_read(file, item.stat.size, 0)
      local lines = vim.split(content, "\r?\n")
      vim.loop.fs_close(file)
      vim.api.nvim_buf_call(fm.preview.buffer, function()
        vim.bo.readonly = false
        vim.bo.modifiable = true
        vim.api.nvim_buf_set_lines(fm.preview.buffer, 0, -1, false, lines)
        vim.bo.readonly = true
        vim.bo.modifiable = false
      end)
    else
      display_items(fm.preview.buffer, M.util.fs_readdir(item.path))
    end
  end

  function fm.refresh()
    fm.navigator.items = M.util.fs_readdir(fm.path)

    display_items(fm.navigator.buffer, fm.navigator.items)

    local item_count = #fm.navigator.items

    if fm.navigator.row > item_count then
      fm.navigator.row = item_count 

      if fm.navigator.row == 0 then
        fm.navigator.row = 1
      end
    end

    vim.api.nvim_win_set_cursor(fm.navigator.window, { fm.navigator.row, 0 })

    fm.refresh_preview()
  end

  return fm
end

function M.open(path) 
  path = path or vim.loop.cwd()
  if not M.fm then
    local fm = fm_new(path)
    local vim_height = vim.api.nvim_eval [[&lines]]
    local vim_width = vim.api.nvim_eval [[&columns]]

    local width = math.floor(vim_width * 0.8) + 5
    local height = math.floor(vim_height * 0.7) + 2
    local col = vim_width * 0.1 - 2
    local row = vim_height * 0.15 - 1

    fm.decorations.buffer = vim.api.nvim_create_buf(false, true)
    fm.decorations.window = vim.api.nvim_open_win(fm.decorations.buffer, true, {
      relative = 'editor',
      width = width,
      height = height,
      col = col,
      row = row,
      style = 'minimal',
      focusable = false
    })

    vim.wo.winhl = "Normal:Normal"

    vim.api.nvim_buf_set_lines(fm.decorations.buffer, 0, 1, false, { "┌" .. string.rep('─', width - 2) .. "┐" })
    for i=2,height-1 do
      vim.api.nvim_buf_set_lines(fm.decorations.buffer, i - 1, i, false, { "│" .. string.rep(' ', width - 2) .. "│"})
    end
    vim.api.nvim_buf_set_lines(fm.decorations.buffer, height - 1, -1, false, { "└" .. string.rep('─', width - 2) .. "┘" })

    local width = math.floor(vim_width * 0.4)
    local height = math.floor(vim_height * 0.7)
    local col = vim_width * 0.1
    local row = vim_height * 0.15

    fm.navigator.buffer = vim.api.nvim_create_buf(false, true)
    fm.navigator.window = vim.api.nvim_open_win(fm.navigator.buffer, true, {
      relative = 'editor',
      width = width,
      height = height,
      col = col,
      row = row,
      style = 'minimal'
    })

    define_mappings(fm.navigator.buffer)

    vim.wo.winhl = "Normal:Normal"
    vim.wo[fm.navigator.window].cursorline = true
    vim.bo.readonly = true
    vim.bo.modifiable = false
    vim.cmd [[au WinClosed <buffer> lua NeofsQuit()]]
    vim.cmd [[au CursorMoved <buffer> lua NeofsOnCursorMoved()]]

    local width = math.floor(vim_width * 0.4)
    local height = math.floor(vim_height * 0.7)
    local col = vim_width * 0.1 + width + 1
    local row = vim_height * 0.15

    fm.preview.buffer = vim.api.nvim_create_buf(false, true)
    fm.preview.window = vim.api.nvim_open_win(fm.preview.buffer, true, {
      relative = 'editor',
      width = width,
      height = height,
      col = col,
      row = row,
      style = 'minimal',
      focusable = false
    })

    vim.wo.winhl = "Normal:Normal"
    vim.wo[fm.preview.window].cursorline = false
    vim.bo.readonly = true
    vim.bo.modifiable = false
    vim.cmd [[au WinClosed <buffer> lua NeofsQuit()]]

    fm.refresh()

    -- Have to defer this, else the preview window disappears ??? like what the fuck
    vim.defer_fn(function()
      vim.api.nvim_set_current_win(fm.navigator.window)
    end, 10)

    M.fm = fm
  end
end

function M.setup(opts)
  opts = opts or {}
  for key, val in pairs(opts) do
    M.config[key] = val
  end
end

return M
