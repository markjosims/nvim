local vault = vim.fn.expand "~/obsidian"

-- Run a command and return its (trimmed) stdout, or an inline error note.
local function run(cmd)
  local res = vim.system(cmd, { text = true }):wait()
  local out = (res.stdout or ""):gsub("^%s+", "")
  if res.code == 0 and out:match "%S" then
    return out:gsub("%s+$", "")
  end
  local why = (res.stderr or ""):gsub("%s+$", "")
  if why == "" then
    why = "exit code " .. res.code
  end
  return ("`%s` failed: %s"):format(table.concat(cmd, " "), why)
end

return {
  "epwalsh/obsidian.nvim",
  version = "*", -- recommended, use latest release instead of latest commit
  lazy = false,
  -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
  -- lazy = {
  --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
  --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/*.md"
  --   -- refer to `:h file-pattern` for more examples
  --   "BufReadPre path/to/my-vault/*.md",
  --   "BufNewFile path/to/my-vault/*.md",
  -- },
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  opts = {
    workspaces = {
      {
        name = "work",
        path = vault,
      },
    },
    daily_notes = {
      folder = "journals",
      template = "daily_note",
    },
    templates = {
      folder = "_meta/templates",
      substitutions = {
        calendar = function()
          return run {
            vault .. "/_meta/scripts/gcal_agenda.sh",
            "--timezone",
            "America/Los_Angeles",
          }
        end,
        tasks = function()
          return run { vim.fn.expand "$HOME" .. "/.local/bin/taskwarrior_linear", "sod" }
        end,
      },
    },
  },
}
