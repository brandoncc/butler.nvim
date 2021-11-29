local vim = vim
local processes_loaded, processes = pcall(require, 'brandoncc.processes')

if not processes_loaded then
  error("Could not load processes module, " .. processes)
end

if (vim.g.butler_loaded == 1) then
  return
end

vim.g.butler_loaded = 1

local json_decode = vim.fn.json_decode

local data_directory = vim.fn.expand("$HOME/.config/butler.nvim")
local data_file_name = "config.json"
local data_file_path = data_directory .. "/" .. data_file_name

M = {}

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

local function butler_buffers()
  local buffers = {}

  for _, bufnr in pairs(vim.api.nvim_list_bufs()) do
    local is_butler_buffer = pcall(vim.api.nvim_buf_get_var, bufnr, 'butler_path')

    if is_butler_buffer then
      table.insert(buffers, bufnr)
    end
  end

  return buffers
end

-- Shamelessly copied from ThePrimeagen/harpoon. Thanks Prime!
local function create_terminal(create_with)
    if not create_with then
        create_with = ":terminal"
    end
    local current_id = vim.api.nvim_get_current_buf()

    vim.cmd(create_with)
    local buf_id = vim.api.nvim_get_current_buf()
    local term_id = vim.b.terminal_job_id

    if term_id == nil then
        -- TODO: Throw an error?
        return nil
    end

    -- Make sure the term buffer has "hidden" set so it doesn't get thrown
    -- away and cause an error
    vim.api.nvim_buf_set_option(buf_id, "bufhidden", "hide")

    -- Resets the buffer back to the old one
    vim.api.nvim_set_current_buf(current_id)
    return buf_id, term_id
end


local function kill_process_tree(buffer)
  local ok, buffer_pid = pcall(vim.api.nvim_buf_get_var, buffer, 'terminal_job_pid')

  if ok and buffer_pid then
    processes.kill_tree(buffer_pid, 1)
  end
end

local function close_buffer(buffer)
  vim.api.nvim_buf_delete(buffer, { force = true })
end

local function start_servers()
  for _, command in ipairs(get_project_commands()) do
    local buffer_id, term_id = create_terminal()

    vim.api.nvim_chan_send(term_id, command.cmd .. "\n")
    vim.api.nvim_buf_set_var(buffer_id, 'butler_path', vim.fn.getcwd())
    vim.api.nvim_buf_set_var(buffer_id, 'butler_cmd_name', command.name)
  end
end

local function stop_servers ()
  for _, buffer in ipairs(butler_buffers()) do
    kill_process_tree(buffer)
    close_buffer(buffer)
  end
end

local function restart_servers()
  stop_servers()
  start_servers()
end

M.buffers = butler_buffers
M.restart = restart_servers
M.start = start_servers
M.stop = stop_servers

return M
