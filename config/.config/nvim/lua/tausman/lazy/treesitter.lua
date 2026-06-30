-- nvim-treesitter `main` branch (the rewrite).
--
-- The legacy `master` branch was archived in 2025 and is incompatible with
-- Neovim 0.11+/0.12: its custom query directives (e.g. `set-lang-from-info-string!`)
-- assume the old single-node directive `match`, which became a list of nodes,
-- so they crash on markdown injection parsing.
--
-- `main` is a full rewrite. It only installs parsers + queries; features are
-- enabled with core APIs:
--   * highlighting -> vim.treesitter.start()
--   * indentation  -> indentexpr (experimental on main)
-- Requires the `tree-sitter` CLI (>= 0.26.1) on PATH to compile parsers.
return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false, -- main does not support lazy-loading
	build = ":TSUpdate",
	config = function()
		require("nvim-treesitter").install({
			"vimdoc", "javascript", "typescript", "c", "lua", "rust",
			"jsdoc", "bash", "go", "python", "markdown", "markdown_inline",
		})

		vim.api.nvim_create_autocmd("FileType", {
			callback = function(args)
				-- Highlighting (provided by Neovim core). pcall keeps filetypes
				-- without an installed parser quiet.
				pcall(vim.treesitter.start, args.buf)

				-- Tree-sitter indentation (experimental on main). Preserves the
				-- old `indent = { enable = true }`. Drop this line to fall back
				-- to Vim's built-in indent if it misbehaves.
				vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end,
		})
	end,
}
