# pensieve.nvim

> A lightweight, distraction-free task and notes manager for Neovim - store your thoughts without cluttering your code.

---

## ✨ Features

- Add quick tasks tied to your current file and line.
- View all or per-project tasks in a clean, focused pane.
- Toggle, delete, or jump directly to task sources.
- JSON-based storage (persistent across sessions).
- Optional [which-key](https://github.com/folke/which-key.nvim) labels.
- Optional integration with [Snacks Dashboard](https://github.com/folke/snacks.nvim).

---

## ⚙️ Requirements

- **Neovim ≥ 0.9.0**

---

## 📦 Installation

**Example (lazy.nvim):**

```lua
{
    "udayanKashyap/pensieve.nvim",
    lazy = false,
    priority = 1000,
    config = function()
        require("pensieve").setup({
            pane_height = 12,
        })
    end,
},
```

---

## 🧠 Usage

### Keymaps (auto-created)

| Action               | Default Key  |
| -------------------- | ------------ |
| Open all tasks       | `<leader>tp` |
| Open project tasks   | `<leader>tP` |
| Add task from cursor | `<leader>ta` |

Inside the task pane:

- `<CR>` - Jump to task source
- `x` - Toggle done/undone
- `dd` - Delete task
- `r` - Refresh
- `q` - Close

### Commands

- `:PensieveOpen` - Open task pane
- `:PensieveAdd` - Add a new task

Optional toggle mapping:

```lua
vim.keymap.set("n", "<leader>tt", require("pensieve").toggleTaskPane, { desc = "Toggle Task Pane" })
```

---

## 🧩 Snacks Dashboard Integration

Add recent Pensieve tasks to your dashboard:

```lua
{
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      sections = {

         -- other sections

        function()
          local ok, pensieve = pcall(require, "pensieve")
          if not ok then return end
          local tasks = pensieve.recent_tasks({ limit = 10 })
          return {
            {
              -- title = "Tasks\n",
              -- pane = 2,
              -- gap = 1,
              -- padding = 2,
              { tasks },
            },
          }
        end,

        -- other sections

      },
    },
  },
}
```

---

## 🧾 License

[MIT](LICENSE)

---

> _pensieve.nvim - a place for your tasks and notes to rest until you’re ready to revisit them._
