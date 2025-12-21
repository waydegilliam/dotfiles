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

vim.lsp.config("*", {
	capabilities = capabilities,
	handlers = handlers,
})

local function enable(server, opts)
	if opts then
		vim.lsp.config(server, opts)
	end
	vim.lsp.enable(server)
end

enable("pyright", {
	filetypes = { "python" },
})

enable("vimls", {
	filetypes = { "vim" },
})

enable("lua_ls", {
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
		client.server_capabilities.documentFormattingProvider = false
	end,
})

enable("rust_analyzer", {
	filetypes = { "rust" },
})

enable("html", {
	filetypes = { "html" },
	init_options = {
		configurationSection = { "html", "css", "javascript" },
		embeddedLanguages = {
			css = true,
			javascript = true,
		},
	},
	on_attach = function(client)
		client.server_capabilities.documentFormattingProvider = false
	end,
})

enable("cssls", {
	filetypes = { "css", "scss", "less" },
})

enable("vuels", {
	filetypes = { "vue" },
})

enable("tailwindcss")

enable("svelte")

enable("ruff", {
	on_attach = function(client, bufnr)
		-- Format on save
		if client:supports_method("textDocument/formatting") then
			vim.api.nvim_create_autocmd("BufWritePre", {
				buffer = bufnr,
				callback = function()
					vim.lsp.buf.format({ bufnr = bufnr, async = false })
				end,
			})
		end
	end,
})
