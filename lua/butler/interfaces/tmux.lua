local vim = vim
local processes_loaded, processes = pcall(require, 'brandoncc.processes')

if not processes_loaded then
  error("Could not load processes module, " .. processes)
end

local native_interface_loaded, native_interface = pcall(require, 'butler.interfaces.native')

if not native_interface_loaded then
  error("Could not load native interface module, " .. native_interface)
end

local M = {}
local _get_config
local _active_pids = {}
local _active_pane_ids = {}

function M:new(get_config)
  _get_config = get_config
  return self
end

local function string_lines(str)
  local lines = {}

  for line in str:gmatch("([^\n]*)\n?") do
    if #line > 0 then
      table.insert(lines, line)
    end
  end

  return lines
end

-- this has terrible performance, but it shouldn't matter for lists as small as
-- tmux session pid lists
local function table_diff(t1, t2)
  local t = {}
  for _, v in pairs(t2) do
    local found = false

    for _, v1 in pairs(t1) do
      if v == v1 then
        found = true
      end
    end

    if not found then
      table.insert(t, v)
    end
  end

  return t
end

local function get_pids()
  local string_pids = string_lines(vim.fn.system("tmux list-panes -sF '#{pane_pid}'"))
  local pids = {}

  for _, pid in pairs(string_pids) do
    table.insert(pids, tonumber(pid))
  end

  return pids
end

local function get_pane_ids()
  return string_lines(vim.fn.system("tmux list-panes -sF '#{pane_id}'"))
end

local function get_window_ids()
  return string_lines(vim.fn.system("tmux list-windows -F '#{window_id}'"))
end

local function get_new_window_id_after(fn)
  local before = get_window_ids()

  fn()

  return table_diff(before, get_window_ids())[1]
end

local function create_window(command)
  local new_window_id = get_new_window_id_after(function()
    vim.fn.system("tmux neww -d -c \"" .. vim.fn.getcwd() .. "\"")
  end)

  local escaped_cmd = command.cmd:gsub('"', '\\"')
  vim.fn.system("tmux send-keys -t " .. new_window_id .. " \"" .. escaped_cmd .. "\" Enter")

  if command.name then
    vim.fn.system("tmux rename-window -t " .. new_window_id .. " \"" .. command.name .. "\"")
  end
end

local function kill_process_tree(pid)
  local config = _get_config()

  processes.kill_tree(pid, {
    signals = config.kill_signals,
    timeout = config.kill_timeout,
    log_signals = config.log_kill_signals,
  })
end

local function start_servers(commands)
  local pids_before = get_pids()
  local pane_ids_before = get_pane_ids()

  for _, command in ipairs(commands) do
    create_window(command)
  end

  _active_pids = table_diff(pids_before, get_pids())
  _active_pane_ids = table_diff(pane_ids_before, get_pane_ids())
end

M.start_servers = function(commands)
  start_servers(commands)
end

M.stop_servers = function()
  for _, pid in ipairs(_active_pids) do
    kill_process_tree(pid)
  end

  _active_pids = {}
  _active_pane_ids = {}
end

local function choose_process()
  if #_active_pane_ids == 0 then
    print("No butler panes found")
    return
  end

  local tmux_filter = ""

  for _, pane_id in ipairs(_active_pane_ids) do
    local pane_filter = '#{==:"#{session_id}#{pane_id}","#{session_id}' .. pane_id .. '"}'

    if #tmux_filter > 0 then
      tmux_filter = '#{||:' .. pane_filter .. ',' .. tmux_filter .. '}'
    else
      tmux_filter = pane_filter
    end
  end

  vim.fn.system("tmux choose-tree -Nwf'" .. tmux_filter .. "'")
end

M.choose_process = choose_process

return M
