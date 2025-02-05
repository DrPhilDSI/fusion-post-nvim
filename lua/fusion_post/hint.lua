local M = {}

-- Stores function-to-line mappings
M.hint_data = {}

-- 🛠️ Read the .nc file and extract function mappings
function M.extract_function_hints(nc_file)
	local hints = {}

	-- Open the NC file and read line-by-line
	local file = io.open(nc_file, "r")
	if not file then
		print("Error: Cannot open NC file for hint extraction.")
		return {}
	end

	local current_function = nil
	local line_number = 0

	for line in file:lines() do
		line_number = line_number + 1

		-- Look for debug function markers (example: `! function: onRapid()`)
		local function_name = line:match("! function: ([%w_]+)")
		if function_name then
			current_function = function_name
		end

		-- If we are in a function, attach the function name as a hint
		if current_function then
			hints[line_number] = current_function
		end
	end

	file:close()
	return hints
end

-- 🛠️ Add function hints as virtual text in Neovim
function M.add_function_hints(nc_file)
	local bufnr = vim.fn.bufnr("%") -- Get current buffer number
	if bufnr == -1 then
		return
	end -- If buffer not found, exit

	-- Extract hints from the NC file
	local hints = M.extract_function_hints(nc_file)
	if not hints or vim.tbl_isempty(hints) then
		print("No function hints found.")
		return
	end

	-- Store hints globally
	M.hint_data[bufnr] = hints

	-- Set virtual text hints in Neovim
	for line_number, function_name in pairs(hints) do
		vim.api.nvim_buf_set_extmark(bufnr, vim.api.nvim_create_namespace("FusionPostHints"), line_number - 1, 0, {
			virt_text = { { " → " .. function_name, "Comment" } },
			virt_text_pos = "eol",
		})
	end

	print("Function hints added to NC output.")
end

return M
