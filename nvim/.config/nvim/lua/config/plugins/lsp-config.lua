local lspconfig_ok, lspconfig = pcall(require, "lspconfig")
if not lspconfig_ok then
	print("'lspconfig' not installed")
	return
end

-- Diagnostic signs

local signs = {
	{ name = "DiagnosticSignError", text = "" },
	{ name = "DiagnosticSignWarn", text = "" },
	{ name = "DiagnosticSignHint", text = "" },
	{ name = "DiagnosticSignInfo", text = "" },
}
for _, sign in ipairs(signs) do
	vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = "" })
end

vim.diagnostic.config({
	virtual_text = true,
	signs = {
		active = signs,
	},
	severity_sort = true,
	float = {
		border = true,
	},
})

-- Hover doc & signature handlers

local border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
local handlers = {
	["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = border }),
	["textDocument/signatureHelp"] = vim.lsp.with(
		vim.lsp.handlers.signature_help,
		{ border = border }
	),
}

-- Capabilities

-- Used for UFO
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.foldingRange = {
	dynamicRegistration = false,
	lineFoldingOnly = true,
}

-- Used for CMP?
capabilities.textDocument.completion.completionItem.snippetSupport = true

-- LSP config

lspconfig.pyright.setup({
	capabilities = capabilities,
	filetypes = { "python" },
	handlers = handlers,
})

lspconfig.vimls.setup({
	capabilities = capabilities,
	filetypes = { "vim" },
})

lspconfig.lua_ls.setup({
	capabilities = capabilities,
	filetypes = { "lua" },
	settings = {
		Lua = {
			runtime = {
				version = "LuaJIT",
			},
			diagnostics = {
				globals = { "vim" },
			},
			workspace = {
				library = vim.api.nvim_get_runtime_file("", true),
			},
			telemetry = {
				enable = false,
			},
		},
	},
	on_attach = function(client)
		client.server_capabilities.document_formatting = false
	end,
})

lspconfig.rust_analyzer.setup({
	capabilities = capabilities,
	filetypes = { "rust" },
})

lspconfig.html.setup({
	capabilities = capabilities,
	filetypes = { "html" },
	init_options = {
		configurationSection = { "html", "css", "javascript" },
		embeddedLanguages = {
			css = true,
			javascript = true,
		},
	},
	on_attach = function(client)
		client.server_capabilities.document_formatting = false
	end,
})

lspconfig.cssls.setup({
	capabilities = capabilities,
	filetypes = { "css", "scss", "less" },
})

lspconfig.vuels.setup({
	capabilities = capabilities,
	filetypes = { "vue" },
})

lspconfig.tailwindcss.setup({
	capabilities = capabilities,
})

lspconfig.svelte.setup({
	capabilities = capabilities,
})

lspconfig.ruff.setup({
	capabilities = capabilities,
	on_attach = function(client, bufnr)
		-- Format on save
		if client.supports_method("textDocument/formatting") then
			vim.api.nvim_create_autocmd("BufWritePre", {
				buffer = bufnr,
				callback = function()
					vim.lsp.buf.format({ bufnr = bufnr, async = false })
				end,
			})
		end
	end,
})
