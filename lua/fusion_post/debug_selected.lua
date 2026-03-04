local M = {}

local log = require("fusion_post.log")
local utils = require("fusion_post.utils")
local ui = require("fusion_post.ui")

local function get_selected_lines()
	local bufnr = vim.api.nvim_get_current_buf()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")

	if start_pos[2] == 0 and end_pos[2] == 0 then
		vim.notify("No lines selected. Select lines in visual mode and run command again.", vim.log.levels.WARN)
		return nil
	end

	local start_line = start_pos[2]
	local end_line = end_pos[2]

	local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
	return lines, start_line, end_line
end

local function parse_and_inject_debug(lines)
	local debug_lines = {}
	local function split_args(arg_str)
		local args = {}
		local current = {}
		local depth = 0
		local quote = nil
		local escape = false

		for i = 1, #arg_str do
			local ch = arg_str:sub(i, i)

			if escape then
				table.insert(current, ch)
				escape = false
			elseif ch == "\\" and quote then
				escape = true
				table.insert(current, ch)
			elseif quote then
				if ch == quote then
					quote = nil
				end
				table.insert(current, ch)
			elseif ch == "\"" or ch == "'" then
				quote = ch
				table.insert(current, ch)
			elseif ch == "(" or ch == "[" or ch == "{" then
				depth = depth + 1
				table.insert(current, ch)
			elseif ch == ")" or ch == "]" or ch == "}" then
				depth = math.max(depth - 1, 0)
				table.insert(current, ch)
			elseif ch == "," and depth == 0 then
				local arg = table.concat(current):gsub("^%s*", ""):gsub("%s*$", "")
				if arg ~= "" then
					table.insert(args, arg)
				end
				current = {}
			else
				table.insert(current, ch)
			end
		end

		local arg = table.concat(current):gsub("^%s*", ""):gsub("%s*$", "")
		if arg ~= "" then
			table.insert(args, arg)
		end

		return args
	end

	local function build_function_debug_line(func_name, args)
		if #args == 0 then
			return string.format('writeln("DEBUG: %s()");', func_name)
		end

		if #args == 1 then
			return string.format('writeln("DEBUG: %s = " + (%s));', func_name, args[1])
		end

		local line = string.format('writeln("DEBUG: %s = "', func_name)
		for i, arg in ipairs(args) do
			if i > 1 then
				line = line .. ' + ", " + '
			end
			line = line .. "(" .. arg .. ")"
		end
		line = line .. ');'
		return line
	end

	for _, line in ipairs(lines) do
		local trimmed = line:gsub("^%s*", ""):gsub("%s*$", "")
		local stripped = trimmed:gsub("//.*$", ""):gsub("%s*$", "")
		local ends_with_semicolon = stripped:match(";%s*$")
		local unsafe_end = stripped:match("[{%(%[,]%s*$")
		local can_inject = ends_with_semicolon and not unsafe_end

		local local_match = stripped:match("^local%s+(%w+)%s*=%s*(.+)$")
		local var_match = stripped:match("^var%s+(%w+)%s*=%s*(.+)$")
		local assign_match = stripped:match("^(%w+)%s*=%s*(.+)$")
		local writeln_match = stripped:match("^writeln%s*%((.+)%)$")
		local if_match = stripped:match("^if%s*%((.+)%)%s*{?%s*$")
		local func_name, raw_args = stripped:match("^([%w_%.]+)%s*%((.*)%)%s*;%s*$")

		table.insert(debug_lines, line)

		if if_match then
			table.insert(debug_lines, string.format('writeln("DEBUG: if " + (%s));', if_match))
		elseif can_inject and local_match then
			local var_name = local_match
			table.insert(debug_lines, string.format('writeln("DEBUG: %s = " + %s);', var_name, var_name))
		elseif can_inject and var_match then
			local var_name = var_match
			table.insert(debug_lines, string.format('writeln("DEBUG: %s = " + %s);', var_name, var_name))
		elseif can_inject and assign_match and not trimmed:match("^function%s+") then
			local var_name = assign_match
			local expr = trimmed:match("^%w+%s*=%s*(.+)$")
			if expr then
				table.insert(debug_lines, string.format('writeln("DEBUG: %s = " + %s);', var_name, var_name))
			end
		elseif can_inject and func_name and not writeln_match and not stripped:match("^function%s+") and not stripped:find("=") then
			local args = split_args(raw_args or "")
			table.insert(debug_lines, build_function_debug_line(func_name, args))
		elseif writeln_match then
			-- Skip writeln lines to avoid duplicate output
		end
	end

	return debug_lines
end

local function create_temp_debug_cps(output_lines, output_path)
	local file = io.open(output_path, "w")
	if not file then
		vim.notify("Error: Cannot create temp debug file.", vim.log.levels.ERROR)
		return nil
	end

	for _, line in ipairs(output_lines) do
		file:write(line .. "\n")
	end

	file:close()
	return output_path
end

function M.debug_selected_lines(opts)
	local current_file = utils.get_current_cps_file()
	if not current_file then
		utils.notify_error("No valid post-processor (.cps) file is open.")
		return
	end

	local selected_lines, start_line, end_line = get_selected_lines()
	if not selected_lines then
		return
	end

	if #selected_lines == 0 then
		vim.notify("No lines selected.", vim.log.levels.WARN)
		return
	end

	local original_cps = io.open(current_file, "r")
	if not original_cps then
		vim.notify("Error: Cannot read original .cps file.", vim.log.levels.ERROR)
		return
	end

	local original_lines = {}
	for line in original_cps:lines() do
		table.insert(original_lines, line)
	end
	original_cps:close()

	local debug_injected_lines = parse_and_inject_debug(selected_lines)
	local output_lines = {}

	for i = 1, start_line - 1 do
		table.insert(output_lines, original_lines[i])
	end

	for _, line in ipairs({ 'writeln("")', 'writeln("DEBUG: Selected Lines Start")', 'writeln("")' }) do
		table.insert(output_lines, line)
	end

	for _, line in ipairs(debug_injected_lines) do
		table.insert(output_lines, line)
	end

	for _, line in ipairs({ 'writeln("")', 'writeln("DEBUG: Selected Lines End")', 'writeln("")' }) do
		table.insert(output_lines, line)
	end

	for i = end_line + 1, #original_lines do
		table.insert(output_lines, original_lines[i])
	end

	local temp_dir = os.getenv("TMPDIR") .. "fusion_nvim/"
	local ok = vim.loop.fs_mkdir(temp_dir, tonumber("755", 8))
	if not ok then
		-- Directory might already exist, that's ok
	end

	local temp_cps = temp_dir .. "debug_selected.cps"
	local result = create_temp_debug_cps(output_lines, temp_cps)
	if not result then
		return
	end

	log.log("Created temp debug file: " .. temp_cps)

	ui.select_file(opts.cnc_folder, function(selected_nc_file)
		if not selected_nc_file then
			vim.notify("No NC file selected.", vim.log.levels.WARN)
			vim.loop.fs_unlink(temp_cps)
			return
		end

		local core = require("fusion_post.core")
		core.run_post_processor(selected_nc_file, opts, false, temp_cps)
	end)
end

return M
