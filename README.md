butler.nvim
---

Butler is a tool that allows you to easily start and stop a predefined list of
processes based on your working directory. I created it because I started using
ThePrimeagen's
[git-worktree.nvim](http://github.com/ThePrimeagen/git-worktree.nvim) plugin
and it made my previous tmux workflow more or less impossible to use.

When switching worktrees, I need my servers to be running from the correct
directories. If I don't kill them and restart them from the new worktree
directory, they continue serving code from a previous worktree that I'm not
working with at the moment.

## Installation

Install using your favorite plugin manager. For example in vim-plug:

```vim
" butler.nvim depends on processes.nvim
Plug 'brandoncc/processes.nvim'
Plug 'brandoncc/butler.nvim'
```

## Plugin configuration

### Defaults

The plugin has the following default configuration:

```lua
local config = {
  -- Signals to send to the process to kill it, starting on the left.
  kill_signals = { 'TERM', 'KILL' },

  -- Each signal is given the kill_timeout length of time in seconds to exit
  -- before trying the next signal.
  kill_timeout = 1,

  -- If you would like to see messages such as "Killing process 123 with signal
  -- TERM", enable this.
  log_kill_signals = false,

  -- Butler currently supports tmux and native neovim terminals.
  interface = 'native'
}
```

### Customization

You can customize the plugin with the `setup()` function:

```lua
lua require("butler").setup({ kill_timeout = 0.5 })
```

## Configuration file

Butler is configured using a json file that is located at
`$HOME/.config/butler.nvim/config.json` (pull requests to improve flexibility are welcome).

### Structure

Paths are expanded using the vim `expand()` function, so `$HOME`, `~`, etc work
as expected.

```json
{
  "$HOME/dev/project-a": [
    {
      "name": "dev server",
      "cmd": "bin/server"
    },
    {
      "name": "dev repl",
      "cmd": "bin/console"
    }
  ],
  "$HOME/dev/project-b": [
    {
      "name": "dev server",
      "cmd": "bin/other-server"
    }
  ],
  "$HOME/dev": [
    {
      "name": "work timer",
      "cmd": "timer"
    }
  ]
}
```

### Nesting

Project paths can be nested, and all paths which match (are a substring of) your
current working directory will be used. This is particularly useful with
worktrees since you can use your bare repo directory in the configuration and
all worktree subdirectories will inherit the processes. You can also set
processes for specific worktrees by adding configurations for their exact paths.

In the configuration example above,
the following is a list of the servers that will be started for different
working directories:

#### ~/dev/project-a

- `bin/server`
- `timer`

#### ~/dev/project-b

- `bin/other-server`
- `timer`

#### ~/dev/project-c

- `timer`

## Usage

### Starting project servers

Processes are started in specially-marked buffers. When stopping processes,
butler looks for these specially-marked buffers, *not* buffers that happen to be
running the same command.

That means butler will stop any process running in these specially-marked
buffers, even if it isn't the process that butler originally started.

This also means you can run the same command in a different terminal buffer and
butler will not stop it. Butler only stops processes in buffers it creates.

```vim
lua require("butler").start()
```

### Stopping project servers

Stopping servers kills their processes and then deletes their buffers. The
processes are stopped using the kill signals provided in the configuration. The
signals are each tried until the process is successfully killed or there are no
more signals to try.

```vim
lua require("butler").stop()
```

### Restarting project servers

Restarting servers stops them, which deletes their buffers, and then starts new
ones. If you have changed your working directory (with worktrees, for example),
the new servers will be running in the new working directory.

```vim
lua require("butler").restart()
```

### With git-worktree.nvim

I have the following configuration for git-worktree.nvim:

```lua
local Worktree = require("git-worktree")

Worktree.on_tree_change(function(op)
  if op == Worktree.Operations.Switch then
    require("butler").restart()
  end
end)
```

This configuration has the effect of starting servers the first time you enter a
worktree, and restarting them as you move into other worktrees.

### Jumping to processes

Each interface provides its own way to jump to processes, which can be accessed
with:

```vim
lua require("butler").processes()
```

#### Native interface

When using the native interface, a telescope picker is provided to assist in
jumping between processes. If telescope is not installed, the `processes()`
function simply say that.

#### tmux interface

When using the tmux interface, the tmux `choose-tree` command is used to assist
in choosing a process. The interface is filtered so that only butler-managed
tmux panes are shown.

## Interfaces

Butler can be easily extended by adding more interfaces. At this time, there are
two interfaces: 'native' and 'tmux'.

### Directory structure

The main interface file should be located at
`lua/butler/interfaces/your-interface.lua`. For this file name, you would use:

```vim
lua require("butler").setup({ interface = 'your-interface' })
```

### Required API

Interfaces must return a table which has `:new(fn)` defined on it, with the
following structure:

```lua
{
  start_servers: function(commands),
  stop_servers: function(),
}
```

`start_servers()` will be called with the commands from your json config that
match the current working directory. The list will contain the full command
table for each, not just the `command.cmd` strings.

The function that gets passed to `:new()` returns a copy of the butler config
when called.

### Optional API

If you would like your interface to offer a way to jump to processes that butler
is managing, you can also export a function on your interface table called
`choose_process()`. This function is called by `require("butler").processes()`.

### Minimal example

A minimal interface example is available
[here](lua/butler/interfaces/minimal-example.lua).

## Contributing

If you have any ideas how the plugin could be improved or extended, please open
an issue so we can discuss them. Contributions are welcome!
