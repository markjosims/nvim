return {
  "nvim-telescope/telescope.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("telescope").setup({
      defaults = {
        preview = { treesitter = false },
      },
    })
    local builtin = require("telescope.builtin")
    local function live_grep_no_ignore()
      builtin.live_grep({
        additional_args = function()
          return { "--no-ignore-vcs" }
        end,
      })
    end
    local function find_files_no_ignore()
      builtin.find_files({
        hidden = true,
        no_ignore = true,
      })
    end

    vim.keymap.set("n", "<leader>ff", builtin.find_files, {})
    vim.keymap.set("n", "<leader>fb", builtin.buffers, {})
    vim.keymap.set("n", "<leader>fg", builtin.live_grep, {})
    vim.keymap.set("n", "<leader>fG", live_grep_no_ignore, { desc = "Live grep, including ignored files" })
    vim.keymap.set("n", "<leader>fF", find_files_no_ignore, { desc = "Find files, including ignored files" })
  end,
}
