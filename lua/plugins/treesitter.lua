return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	tag = "v0.10.0",
	config = function()
		local config_object = require("nvim-treesitter.config")
		config_object.setup({
			ensure_installed = { "lua", "javascript", "python" },
			sync_install = false,
			highlight = { enable = true },
			indent = { enable = true },
		})
	end,
}
