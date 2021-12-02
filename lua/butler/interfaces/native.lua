local vim = vim
local processes_loaded, processes = pcall(require, 'brandoncc.processes')

if not processes_loaded then
  error("Could not load processes module, " .. processes)
end

local telescope_picker_loaded, telescope_picker = pcall(require, 'butler.telescope.native')

local _get_config

local M = {}

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

local function choose_process()
  if telescope_picker_loaded then
    return telescope_picker.picker(butler_buffers())
  else
    print("Telescope not installed, can't pick buffer")
  end
end

local function close_buffer(buffer)
  vim.api.nvim_buf_delete(buffer, { force = true })
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
    local config = _get_config()

    processes.kill_tree(buffer_pid, {
      signals = config.kill_signals,
      timeout = config.kill_timeout,
      log_signals = config.log_kill_signals,
    })
  end
end

function M:new(get_config)
  _get_config = get_config
  return self
end

M.start_servers = function(commands)
  for _, command in ipairs(commands) do
    local buffer_id, term_id = create_terminal()

    vim.api.nvim_chan_send(term_id, command.cmd .. "\n")
    vim.api.nvim_buf_set_var(buffer_id, 'butler_path', vim.fn.getcwd())
    vim.api.nvim_buf_set_var(buffer_id, 'butler_cmd_name', command.name)
  end
end

M.stop_servers = function()
  for _, buffer in ipairs(butler_buffers()) do
    kill_process_tree(buffer)
    close_buffer(buffer)
  end
end

M.is_available = function()
  return true
end

M.choose_process = choose_process

return M
