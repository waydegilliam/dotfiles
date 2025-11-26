local M = {}

M.statusline_filetype_exclude = { "", "NvimTree", "help", "Trouble", "fzf" }

local function align(alignment)
	if alignment == "right" then
		return "%="
	end
end

local function get_branch()
	local git_info = vim.b.gitsigns_status_dict
	if not git_info or git_info.head == "" then
		return ""
	end

	return table.concat({
		" %#StatuslineGitBranch#",
		"  ",
		git_info.head,
		" %#Statusline# ",
	})
end

local function get_filename()
	local fpath = vim.fn.fnamemodify(vim.fn.expand("%"), ":p:~")

	return table.concat({ " ", fpath, "%m " })
end

local function get_diagnostics()
	local count = {}
	local severity = vim.diagnostic and vim.diagnostic.severity or nil
	local levels = severity and {
		errors = severity.ERROR,
		warnings = severity.WARN,
		info = severity.INFO,
		hints = severity.HINT,
	} or {}

	for k, level in pairs(levels) do
		count[k] = vim.tbl_count(vim.diagnostic.get(0, { severity = level }))
	end

	local errors = ""
	local warnings = ""
	local hints = ""
	local info = ""

	if count["errors"] ~= 0 then
		errors = " %#StatuslineDiagnosticError# " .. count["errors"]
	end
	if count["warnings"] ~= 0 then
		warnings = " %#StatuslineDiagnosticWarn# " .. count["warnings"]
	end
	if count["hints"] ~= 0 then
		hints = " %#StatuslineDiagnosticHint# " .. count["hints"]
	end
	if count["info"] ~= 0 then
		info = " %#StatuslineDiagnosticInfo# " .. count["info"]
	end

	return " " .. errors .. warnings .. hints .. info .. "%#StatusLine# "
end

local function get_filetype()
	return " " .. string.format(" %s ", vim.bo.filetype) .. " "
end

local function get_line_info()
	return " Ln %l, Col %c "
end

local function get_zoomed_status()
	if vim.t.zoomed == 1 then
		return " %#StatuslineGitBranch# ZOOM %#Statusline#  "
	end

	return ""
end

local function get_lsp_status()
	local buf_clients = {}
	if vim.lsp and type(vim.lsp.get_clients) == "function" then
		buf_clients = vim.lsp.get_clients({ bufnr = 0 })
	elseif vim.lsp and type(vim.lsp.buf_get_clients) == "function" then
		buf_clients = vim.lsp.buf_get_clients(0)
	end
	if next(buf_clients) == nil then
		return ""
	end

	local buf_client_names = {}
	for _, client in pairs(buf_clients) do
		if client.name ~= "null-ls" then
			table.insert(buf_client_names, client.name)
		end
	end

	return "[" .. table.concat(buf_client_names, ", ") .. "]"
end

local function get_lsp_progress()
	if not vim.lsp then
		return ""
	end

	-- Prefer the built-in status function when available
	if type(vim.lsp.status) == "function" then
		local s = vim.lsp.status()
		if s and s ~= "" then
			return " " .. s .. " "
		end
	end

	-- Fallback to progress messages API when present
	local util = vim.lsp.util
	if util and type(util.get_progress_messages) == "function" then
		local messages = util.get_progress_messages()
		if #messages == 0 then
			return ""
		end

		local status = {}
		for _, msg in pairs(messages) do
			local title = ""
			if msg.title then
				title = msg.title
			end
			table.insert(status, (msg.percentage or 0) .. "%% " .. title)
		end

		local spinners = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
		local ms = vim.loop.hrtime() / 1000000
		local frame = math.floor(ms / 120) % #spinners

		return table.concat(status, "  ") .. " " .. spinners[frame + 1]
	end

	return ""
end

Statusline = {}

Statusline.setup = function()
	if vim.tbl_contains(M.statusline_filetype_exclude, vim.bo.filetype) then
		return ""
	end

	return table.concat({
		get_branch(),
		get_diagnostics(),
		get_filename(),
		align("right"),
		get_zoomed_status(),
		get_lsp_progress(),
		get_lsp_status(),
		get_line_info(),
		get_filetype(),
	})
end

M.setup = function()
	vim.api.nvim_exec("setlocal statusline=%!v:lua.Statusline.setup()", true)
end

return M
