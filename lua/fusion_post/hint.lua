local M = {}

local log = require("fusion_post.log")

M.hint_data = {}
M.all_call_stacks = {}
M.cps_file = nil

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
			break
		end
	end

	return closest_function
end

function M.extract_function_hints(debug_nc_file, cps_file, inline_filter, call_stack_filter)
	local hints = {}
	local all_stacks = {}
	local function_definitions, sorted_line_numbers = M.extract_function_definitions(cps_file)

	local file = io.open(debug_nc_file, "r")
	if not file then
		print("Error: Cannot open debug NC file for hint extraction.")
		return {}, {}
	end

	local inline_stack = {}
	local full_stack = {}
	local nc_line_number = 0

	for line in file:lines() do
		local cps_line_number = tonumber(line:match("!DEBUG: %d+ .*%:(%d+)"))
		if cps_line_number then
			local function_name = find_closest_function(cps_line_number, function_definitions, sorted_line_numbers)

			if function_name then
				local func_entry = { name = function_name, line = cps_line_number }
				table.insert(full_stack, func_entry)

				if not inline_filter[function_name] then
					table.insert(inline_stack, func_entry)
				end
			end
		end

		if not line:match("!DEBUG") then
			nc_line_number = nc_line_number + 1
			hints[nc_line_number] = vim.deepcopy(inline_stack)
			all_stacks[nc_line_number] = vim.deepcopy(full_stack)
			inline_stack = {}
			full_stack = {}
		end
	end

	file:close()
	return hints, all_stacks
end

function M.add_function_hints(
	cps_file,
	clean_nc_file,
	debug_nc_file,
	bufnr,
	show_inline_hints,
	inline_filter,
	call_stack_filter
)
	if not bufnr then
		bufnr = vim.fn.bufnr("%")
	end
	if bufnr == -1 then
		return
	end

	M.cps_file = cps_file

	local hints, all_stacks = M.extract_function_hints(debug_nc_file, cps_file, inline_filter, call_stack_filter)
	if not hints or vim.tbl_isempty(hints) then
		log.log("No function hints found.")
		return
	end

	M.hint_data = hints
	M.all_call_stacks = all_stacks

	if not show_inline_hints then
		return
	end

	local nc_file = io.open(clean_nc_file, "r")
	if not nc_file then
		log.log("Error: Cannot open NC file.")
		return {}
	end

	local line_number = 0

	for line in nc_file:lines() do
		line_number = line_number + 1
		local function_stack = hints[line_number]

		if function_stack and #function_stack > 0 then
			local first_func = function_stack[1]
			local hint_text = string.format(" → %s at ln:%d", first_func.name, first_func.line)
			vim.api.nvim_buf_set_extmark(bufnr, vim.api.nvim_create_namespace("FusionPostHints"), line_number - 1, 0, {
				virt_text = { { hint_text, "Comment" } },
				virt_text_pos = "eol",
			})
		end
	end
end

function M.get_call_stack(nc_line_number)
	return M.all_call_stacks[nc_line_number] or nil
end

function M.jump_to_cps_line(cps_file, line_number)
	if not cps_file or cps_file == "" then
		vim.notify("No .cps file associated with this preview.", vim.log.levels.ERROR)
		return
	end

	if vim.fn.filereadable(cps_file) ~= 1 then
		vim.notify("Cannot find .cps file: " .. cps_file, vim.log.levels.ERROR)
		return
	end

	local cps_bufnr = vim.fn.bufnr(cps_file)
	if cps_bufnr == -1 then
		vim.cmd("edit " .. vim.fn.fnameescape(cps_file))
		cps_bufnr = vim.api.nvim_get_current_buf()
	else
		local cps_win = vim.fn.bufwinid(cps_bufnr)
		if cps_win == -1 then
			vim.cmd("sbuffer " .. cps_bufnr)
		else
			vim.api.nvim_set_current_win(cps_win)
		end
	end

	if line_number and line_number > 0 then
		vim.api.nvim_win_set_cursor(0, { line_number, 0 })
		vim.cmd("normal! zvzz")
	end
end

function M.show_call_stack_popup(cps_file, nc_bufnr)
	local nc_line = vim.api.nvim_win_get_cursor(0)[1]
	local call_stack = M.get_call_stack(nc_line)

	if not call_stack or #call_stack == 0 then
		vim.ui.select({ "No call stack available for this line" }, {
			prompt = "Call stack (NC line " .. nc_line .. "):",
		}, function() end)
		return
	end

	local items = {}
	for i, func in ipairs(call_stack) do
		table.insert(items, string.format("%s at line %d", func.name, func.line))
	end

	vim.ui.select(items, {
		prompt = "Select function to jump to (NC line " .. nc_line .. "):",
	}, function(choice)
		if choice then
			for i, item in ipairs(items) do
				if item == choice then
					local selected = call_stack[i]
					M.jump_to_cps_line(cps_file, selected.line)
					break
				end
			end
		end
	end)
end

return M
