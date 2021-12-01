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

M = {}

local function use_interface(interface)
  if interface == 'tmux' and vim.fn.system('printenv TMUX') == '' then
    print("Tmux is not running, butler is falling back to native interface")
    interface = 'native'
  end

  _config.interface = require('butler.interfaces.' .. interface):new(get_config)
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
  local config = vim.fn.readfile(data_file_path)
  if config == "" then
    return {}
  end

  local config_json = json_decode(config)
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
  _config.interface.start_servers(get_project_commands())
end

local function stop_servers ()
  _config.interface.stop_servers()
end

local function restart_servers()
  stop_servers()
  start_servers()
end

local function choose_process()
  if _config.interface.butler_buffers then
    return _config.interface.choose_process()
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
