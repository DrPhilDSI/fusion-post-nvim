local M = {}

M.hint_data = {}

function M.extract_function_definitions(cps_file)
	local functions = {}
	local sorted_line_numbers = {}

	local file = io.open(cps_file, "r")
	if not file then
		print("Error: Cannot open CPS file for function extraction.")
		return {}, {}
	end

	local line_number = 0
	for line in file:lines() do
		line_number = line_number + 1

		-- Look for function definitions (e.g., `function writeWCS()`)
		local function_name = line:match("function%s+([%w_]+)%s*%(")
		if function_name then
			functions[line_number] = function_name
			table.insert(sorted_line_numbers, line_number)
		end
	end

	file:close()
	table.sort(sorted_line_numbers)
	return functions, sorted_line_numbers
end

local function find_closest_function(cps_line_number, function_definitions, sorted_line_numbers)
	local closest_function = nil

	for _, defined_line in ipairs(sorted_line_numbers) do
		if defined_line <= cps_line_number then
			closest_function = function_definitions[defined_line]
		else
			break -- Stop once we pass the target line
		end
	end

	return closest_function
end

function M.extract_function_hints(debug_nc_file, cps_file)
	local hints = {}
	local function_definitions, sorted_line_numbers = M.extract_function_definitions(cps_file)
	local skip_functions = {
		writeBlock = true,
		writeLn = true,
		writeComment = true,
		onLinear = true,
		onLinear5D = true,
		onRapid = true,
		onRapid5D = true,
		onCircular = true,
	}

	local file = io.open(debug_nc_file, "r")
	if not file then
		print("Error: Cannot open debug NC file for hint extraction.")
		return {}
	end

	local function_stack = {}
	local nc_line_number = 0

	for line in file:lines() do
		local cps_line_number = tonumber(line:match("!DEBUG: %d+ .*%:(%d+)"))
		if cps_line_number then
			local function_name = find_closest_function(cps_line_number, function_definitions, sorted_line_numbers)

			if function_name and not skip_functions[function_name] then
				local function_line = string.format("%s ln:%d", function_name, cps_line_number)
				table.insert(function_stack, function_line)
			end
		end

		if not line:match("!DEBUG") then
			nc_line_number = nc_line_number + 1
			hints[nc_line_number] = function_stack[1] -- table.concat(function_stack, " → ")
			print(hints[nc_line_number])
			function_stack = {}
		end
	end

	file:close()
	return hints
end

function M.add_function_hints(cps_file, clean_nc_file, debug_nc_file)
	local bufnr = vim.fn.bufnr("%")
	if bufnr == -1 then
		return
	end

	-- Extract function hints from debug NC file
	local hints = M.extract_function_hints(debug_nc_file, cps_file)
	if not hints or vim.tbl_isempty(hints) then
		print("No function hints found.")
		return
	end

	local nc_file = io.open(clean_nc_file, "r")
	if not nc_file then
		print("Error: Cannot open NC file.")
		return {}
	end

	local line_number = 0

	for line in nc_file:lines() do
		line_number = line_number + 1
		local function_name = hints[line_number]

		-- Ensure the line exists in the NC buffer
		if function_name then
			vim.api.nvim_buf_set_extmark(bufnr, vim.api.nvim_create_namespace("FusionPostHints"), line_number - 1, 0, {
				virt_text = { { " → " .. function_name, "Comment" } },
				virt_text_pos = "eol",
			})
		else
			print(string.format("Skipping invalid hint line: %s", line))
		end
	end

	print("Function hints added to NC output.")
end

return M
