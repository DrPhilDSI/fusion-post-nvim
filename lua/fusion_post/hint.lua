local M = {}

M.hint_data = {}

-- 🛠️ Extract function names and their line numbers from the `.cps` file
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

-- 🛠️ Find the closest function BEFORE a given line number
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

-- 🛠️ Extract function hints from `!DEBUG` lines and correctly match to `.nc` lines
function M.extract_function_hints(nc_file, cps_file)
	local hints = {}

	-- Get function mappings from the `.cps` file
	local function_definitions, sorted_line_numbers = M.extract_function_definitions(cps_file)

	local file = io.open(nc_file, "r")
	if not file then
		print("Error: Cannot open NC file for hint extraction.")
		return {}
	end

	local function_stack = {} -- Stores up to 3 function calls
	local nc_line_number = 0 -- Track the current NC file line

	for line in file:lines() do
		nc_line_number = nc_line_number + 1

		-- Extract only the CPS line number from the `!DEBUG` lines
		local cps_line_number = tonumber(line:match("!DEBUG: %d+ .*%:(%d+)"))

		if cps_line_number then
			-- Look up the function responsible for this line in the `.cps` file
			local function_name = find_closest_function(cps_line_number, function_definitions, sorted_line_numbers)

			if function_name then
				-- Store function call, limiting depth to 3
				table.insert(function_stack, function_name)
				if #function_stack > 3 then
					table.remove(function_stack, 1)
				end
			end
		end

		-- If it's an actual NC command (not debug), attach the call stack to the correct NC line
		if not line:match("!DEBUG") and line:match("%u") then
			if #function_stack > 0 then
				hints[nc_line_number] = table.concat(function_stack, " → ")
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

	-- 🛠️ Get the number of lines in the `.nc` buffer
	local total_lines = vim.api.nvim_buf_line_count(bufnr)

	for nc_line_number, function_name in pairs(hints) do
		-- Ensure the line exists in the NC buffer
		if nc_line_number <= total_lines then
			vim.api.nvim_buf_set_extmark(
				bufnr,
				vim.api.nvim_create_namespace("FusionPostHints"),
				nc_line_number - 1,
				0,
				{
					virt_text = { { " → " .. function_name, "Comment" } },
					virt_text_pos = "eol",
				}
			)
		else
			print(string.format("Skipping invalid hint line: %d (out of range)", nc_line_number))
		end
	end

	print("Function hints added to NC output (Max Depth: 3).")
end

return M
