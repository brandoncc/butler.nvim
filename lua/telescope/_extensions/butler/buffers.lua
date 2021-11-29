local vim = vim
local butler = require('butler')

local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')
local finders = require('telescope.finders')
local action_state = require('telescope.actions.state')
local actions = require("telescope.actions")

return function (opts)
  local buffers = {}

  for _, buffer in ipairs(butler.buffers()) do
    local command = vim.api.nvim_buf_get_var(buffer, 'term_title')

    table.insert(buffers, {
      bufnr = buffer,
      display = command
    })
  end

  table.sort(buffers, function(a, b)
    return string.lower(a.display) > string.lower(b.display)
  end)

  local finder = finders.new_table({
    results = buffers,
    entry_maker = function(entry)
      return {
        value = entry,
        ordinal = entry.display,
        display = entry.display,
        filename = vim.api.nvim_buf_get_name(entry.bufnr),
        lnum = 100000000,
        col = 0,
      }
    end,
  })

  local function handle_complete(prompt_bufnr)
    local entry = action_state.get_selected_entry()

    print("Switching to " .. entry.display .. " (buffer " .. entry.value.bufnr .. ")")
    actions.close(prompt_bufnr)
    vim.cmd("b" .. entry.value.bufnr)
  end

  pickers.new(opts, {
    results_title = 'Butler buffers',
    finder = finder,
    sorter = sorters.get_fuzzy_file(),
    attach_mappings = function(_, map)
      map("i", "<CR>", handle_complete)
      map("n", "<CR>", handle_complete)

      return true
    end,
  }):find()
end

