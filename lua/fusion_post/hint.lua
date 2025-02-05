local M = {}

M.hint_data = {}

-- 🛠️ Extract function mappings from `!DEBUG` lines
function M.extract_function_hints(nc_file)
	local hints = {}

	local file = io.open(nc_file, "r")
	if not file then
		print("Error: Cannot open NC file for hint extraction.")
		return {}
	end

	local current_function = nil
	local line_number = 0

	for line in file:lines() do
		line_number = line_number + 1

		-- Look for function call stack markers (Example: `!DEBUG: 3 Connection moves machine sim.cps:1553`)
		local post_line = line:match("!DEBUG: %d+ .* ([%w_]+%.cps):(%d+)")
		if post_line then
			current_function = post_line -- Example: "machine sim.cps:1553"
		end

		-- Attach the function hint to this line
		if current_function then
			hints[line_number] = current_function
		end
	end

	file:close()
	return hints
end

-- 🛠️ Attach function hints as virtual text in Neovim
function M.add_function_hints(nc_file)
	local bufnr = vim.fn.bufnr("%")
	if bufnr == -1 then
		return
	end

	local hints = M.extract_function_hints(nc_file)
	if not hints or vim.tbl_isempty(hints) then
		print("No function hints found.")
		return
	end

	M.hint_data[bufnr] = hints

	for line_number, function_name in pairs(hints) do
		vim.api.nvim_buf_set_extmark(bufnr, vim.api.nvim_create_namespace("FusionPostHints"), line_number - 1, 0, {
			virt_text = { { " → " .. function_name, "Comment" } },
			virt_text_pos = "eol",
		})
	end

	print("Function hints added to NC output.")
end

return M
