local vim = vim

local _get_config

local M = {}

-- function M:new(get_config)
--   print("get_config:", get_config)
--   print("minimal-example:new called with config: " .. vim.inspect(get_config()))
--   _get_config = get_config
--   return self
-- end
--
function M:new(get_config)
  print("minimal-example:new called with config: " .. vim.inspect(get_config()))

  _get_config = get_config
  return self
end

-- start_servers should handle any commands that should be run, and track
-- processes so that stop_servers can kill them.
function M.start_servers(commands)
  print("minimal-example:start_servers called with commands:\n".. vim.inspect(commands))
end

-- stop_servers should do any process cleanup necessary, and should kill any
-- running servers.
function M.stop_servers()
  print("minimal-example:stop_servers called")
end

-- choose_process should launch a process picker that lets the user choose
-- which process to jump to. This picker can be anything. For example, the
-- native interface uses telescope, but the tmux interface uses tmux's
-- choose-tree.
function M.choose_process()
  print("minimal-example:choose_process called")
end

return M
