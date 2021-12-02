local vim = vim

if (vim.g.butler_loaded == 1) then
  return
end

vim.g.butler_loaded = 1

local json_decode = vim.fn.json_decode

local data_directory = vim.fn.expand("$HOME/.config/butler.nvim")
local data_file_name = "config.json"
local data_file_path = data_directory .. "/" .. data_file_name

local _config = {}

local function get_config()
  return vim.tbl_extend("force", {}, _config)
end

_config = {
  -- Signals to send to the process to kill it, starting on the left.
  kill_signals = { 'TERM', 'KILL' },

  -- Each signal is given the kill_timeout length of time in seconds to exit
  -- before trying the next signal.
  kill_timeout = 1,

  -- If you would like to see messages such as "Killing process 123 with signal
  -- TERM", enable this.
  log_kill_signals = false,
}

local M = {}

local function use_interface(new_interface)
  local exists, interface = pcall(require, 'butler.interfaces.' .. new_interface)
  local available
  local message

  if exists then
    available, message = interface.is_available()

    if available then
      _config.interface = interface:new(get_config)
      return
    end
  end

  message = (message or new_interface .. ' is not available') .. ', butler is falling back to native'

  print(message)
  _config.interface = require('butler.interfaces.native'):new(get_config)
end

local function setup(opts)
  for k, v in pairs(opts) do
    if k == "interface" then
      use_interface(v)
    else
      _config[k] = v
    end
  end
end

local function get_project_commands()
  local read_okay, config = pcall(vim.fn.readfile, data_file_path)

  if not read_okay then
    print("Butler could not read config file at " .. data_file_path)
    return {}
  end

  local decode_okay, config_json = pcall(json_decode, config)

  if not decode_okay then
    print("Error reading json content from butler config file")
    return {}
  end

  local configurations_matching_current_directory_tree = {}

  for key, value in pairs(config_json) do
    local expanded_path = vim.fn.expand(key)

    if string.find(vim.fn.getcwd(), expanded_path, 1, true) then
      for _, command in pairs(value) do
        table.insert(configurations_matching_current_directory_tree, command)
      end
    end
  end

  return configurations_matching_current_directory_tree
end

local function start_servers ()
  if not _config.interface then
    print("Butler doesn't have an active interface, use setup() to set one")
    return
  end

  local success, err = pcall(_config.interface.start_servers, get_project_commands())

  if not success then
    print('Butler failed to start servers, ' .. err)
  end
end

local function stop_servers ()
  if not _config.interface then
    print("Butler doesn't have an active interface, use setup() to set one")
    return
  end

  local success, err = pcall(_config.interface.stop_servers, get_project_commands())

  if not success then
    print('Butler failed to stop servers, ' .. err)
  end
end

local function restart_servers()
  stop_servers()
  start_servers()
end

local function choose_process()
  if not _config.interface then
    print("Butler doesn't have an active interface, use setup() to set one")
    return
  end

  if _config.interface.choose_process then
    local success, err = pcall(_config.interface.choose_process)

    if not success then
      print('Butler failed to execute choose_process, ' .. err)
    end
  else
    vim.api.nvim_err_writeln("choose_process not implemented for this interface")
  end
end

-- Set native interface as the default
setup({ interface = 'native' })

M.processes = choose_process
M.restart = restart_servers
M.setup = setup
M.start = start_servers
M.stop = stop_servers

return M
