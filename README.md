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

## Configuration

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

Stopping servers kills their processes and then deletes their buffers.

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

### Telescope integration

A telescope extension is included which allows you to quickly jump to the
buffers that butler is managing. To use it:

```vim
:Telescope butler buffers
```

or

```vim
lua require('telescope').extensions.butler.buffers()
```
