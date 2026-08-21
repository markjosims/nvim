return {
	{
		"hrsh7th/cmp-nvim-lsp",
	},
	{
		"L3MON4D3/LuaSnip",
		dependencies = {
			"saadparwaiz1/cmp_luasnip",
			"rafamadriz/friendly-snippets",
		},
	},
	{
		"hrsh7th/nvim-cmp",
		config = function()
			local cmp = require("cmp")
			require("luasnip.loaders.from_vscode").lazy_load()
			cmp.setup({
				snippet = {
					expand = function(args)
						require("luasnip").lsp_expand(args.body)
					end,
				},
				window = {
					completion = cmp.config.window.bordered(),
					documentation = cmp.config.window.bordered(),
				},
				mapping = cmp.mapping.preset.insert({
					["&lt;C-b&gt;"] = cmp.mapping.scroll_docs(-4),
					["&lt;C-f&gt;"] = cmp.mapping.scroll_docs(4),
					["&lt;C-Space&gt;"] = cmp.mapping.complete(),
					["&lt;C-e&gt;"] = cmp.mapping.abort(),
					["&lt;CR&gt;"] = cmp.mapping.confirm({ select = true }),
				}),
				sources = cmp.config.sources({
					{ name = "nvim_lsp", group_index = 1 },
				}, {
					{ name = "buffer" },
				}),
			})
		end,
	},
}
