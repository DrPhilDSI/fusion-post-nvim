local M = {}

M.hint_data = {}

-- 🛠️ Extract function names and their line numbers from the `.cps` file
function M.extract_function_definitions(cps_file)
	local functions = {}

	local file = io.open(cps_file, "r")
	if not file then
		print("Error: Cannot open CPS file for function extraction.")
		return {}
	end

	local line_number = 0
	for line in file:lines() do
		line_number = line_number + 1

		-- Look for function definitions (e.g., `function writeWCS()`)
		local function_name = line:match("function%s+([%w_]+)%s*%(")
		if function_name then
			functions[tonumber(line_number)] = function_name
		end
	end

	file:close()
	return functions
end

-- 🛠️ Extract function mappings from `!DEBUG` lines and match with `.cps` functions
function M.extract_function_hints(nc_file, cps_file)
	print("Extracting Hints")
	local hints = {}

	-- Get function mappings from the `.cps` file
	local function_definitions = M.extract_function_definitions(cps_file)

	local file = io.open(nc_file, "r")
	if not file then
		print("Error: Cannot open NC file for hint extraction.")
		return {}
	end

	local function_stack = {} -- Stores up to 3 function calls
	local line_number = 0

	for line in file:lines() do
		line_number = line_number + 1

		local cps_line_number = tonumber(line:match("!DEBUG: %d+ .*%:(%d+)"))

		if cps_line_number then
			local function_name = function_definitions[cps_line_number]
			if function_name then
				-- Store function call, limiting depth to 3
				table.insert(function_stack, function_name)
				if #function_stack > 3 then
					table.remove(function_stack, 1) -- Remove oldest if exceeding depth 3
				end
			end
		end

		-- If it's an actual NC command (not debug), attach the call stack
		if not line:match("!DEBUG") and line:match("%u") then
			-- Convert function stack into a readable hint
			if #function_stack > 0 then
				hints[line_number] = table.concat(function_stack, " → ")
			end
		end
	end

	file:close()
	return hints
end

-- 🛠️ Attach function hints as virtual text in Neovim
function M.add_function_hints(cps_file, nc_file)
	local bufnr = vim.fn.bufnr("%")
	if bufnr == -1 then
		return
	end

	local hints = M.extract_function_hints(nc_file, cps_file)
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

	print("Function hints added to NC output (Max Depth: 3).")
end

return M
