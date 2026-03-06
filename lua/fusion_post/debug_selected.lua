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
	local if_depth = 0
	local collecting_if = false
	local collecting_if_type = nil
	local if_paren_depth = 0
	local if_condition_parts = {}
	local if_lines = {}
	local if_quote = nil
	local if_escape = false

	local function reset_if_state()
		collecting_if = false
		collecting_if_type = nil
		if_paren_depth = 0
		if_condition_parts = {}
		if_lines = {}
		if_quote = nil
		if_escape = false
	end

	local function process_if_text(text)
		for i = 1, #text do
			local ch = text:sub(i, i)

			if if_escape then
				table.insert(if_condition_parts, ch)
				if_escape = false
			elseif ch == "\\" and if_quote then
				if_escape = true
				table.insert(if_condition_parts, ch)
			elseif if_quote then
				if ch == if_quote then
					if_quote = nil
				end
				table.insert(if_condition_parts, ch)
			elseif ch == "\"" or ch == "'" then
				if_quote = ch
				table.insert(if_condition_parts, ch)
			elseif ch == "(" then
				if_paren_depth = if_paren_depth + 1
				table.insert(if_condition_parts, ch)
			elseif ch == ")" then
				if_paren_depth = if_paren_depth - 1
				if if_paren_depth == 0 then
					return true
				end
				table.insert(if_condition_parts, ch)
			else
				table.insert(if_condition_parts, ch)
			end
		end

		return false
	end
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
			return string.format('writeln("     DEBUG: %s()");', func_name)
		end

		if #args == 1 then
			return string.format('writeln("     DEBUG: %s = " + (%s));', func_name, args[1])
		end

		local line = string.format('writeln("     DEBUG: %s = " + ', func_name)
		for i, arg in ipairs(args) do
			if i > 1 then
				line = line .. ' + ", " + '
			end
			line = line .. "(" .. arg .. ")"
		end
		line = line .. ');'
		return line
	end

	local function split_condition_args(condition)
		local parts = {}
		local current = {}
		local depth = 0
		local quote = nil
		local escape = false
		local i = 1

		while i <= #condition do
			local ch = condition:sub(i, i)

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
			elseif ch == "(" then
				depth = depth + 1
				table.insert(current, ch)
			elseif ch == ")" then
				depth = math.max(depth - 1, 0)
				table.insert(current, ch)
			elseif depth == 0 and (condition:sub(i, i + 1) == "&&" or condition:sub(i, i + 1) == "||") then
				local part = table.concat(current):gsub("^%s*", ""):gsub("%s*$", "")
				if part ~= "" then
					table.insert(parts, part)
				end
				current = {}
				i = i + 2
				goto continue
			else
				table.insert(current, ch)
			end

			i = i + 1
			::continue::
		end

		local part = table.concat(current):gsub("^%s*", ""):gsub("%s*$", "")
		if part ~= "" then
			table.insert(parts, part)
		end

		return parts
	end

	local function emit_if_debug_lines(condition)
		local function escape_single_quotes(text)
			return text:gsub("'", "\\'")
		end

		local parts = split_condition_args(condition)
		table.insert(debug_lines, "writeln('     DEBUG: ----- IF ARFGS -----');")
		for _, part in ipairs(parts) do
			local label = escape_single_quotes(part)
			table.insert(debug_lines, string.format("writeln('     DEBUG: %s = ' + (%s));", label, part))
		end
		table.insert(debug_lines, "writeln('');")
		table.insert(debug_lines, string.format('writeln("     DEBUG: if " + (%s) + " then");', condition))
	end

	local function emit_else_if_debug_lines(condition)
		local function escape_single_quotes(text)
			return text:gsub("'", "\\'")
		end

		local parts = split_condition_args(condition)
		table.insert(debug_lines, "writeln('     DEBUG: ----- ELSE IF ARGS -----');")
		for _, part in ipairs(parts) do
			local label = escape_single_quotes(part)
			table.insert(debug_lines, string.format("writeln('     DEBUG: %s = ' + (%s));", label, part))
		end
		table.insert(debug_lines, "writeln('');")
		table.insert(debug_lines, string.format('writeln("     DEBUG: else if " + (%s) + " then");', condition))
	end

	for _, line in ipairs(lines) do
		local trimmed = line:gsub("^%s*", ""):gsub("%s*$", "")
		local stripped = trimmed:gsub("//.*$", ""):gsub("%s*$", "")
		local ends_with_semicolon = stripped:match(";%s*$")
		local unsafe_end = stripped:match("[{%(%[,]%s*$")
		local can_inject = ends_with_semicolon and not unsafe_end
		local starts_else_if = stripped:match("^else%s+if%s*%(") ~= nil
		local starts_if = stripped:match("^if%s*%(") ~= nil
		local starts_else = stripped:match("^else%s*{?%s*$") ~= nil

		local local_match = stripped:match("^local%s+(%w+)%s*=%s*(.+)$")
		local var_match = stripped:match("^var%s+(%w+)%s*=%s*(.+)$")
		local assign_match = stripped:match("^(%w+)%s*=%s*(.+)$")
		local writeln_match = stripped:match("^writeln%s*%((.+)%)$")
		local func_name, raw_args = stripped:match("^([%w_%.]+)%s*%((.*)%)%s*;%s*$")

		if collecting_if then
			table.insert(if_lines, line)
			local complete = process_if_text(stripped)
			if complete then
				local condition = table.concat(if_condition_parts):gsub("^%s*", ""):gsub("%s*$", "")
				if collecting_if_type == "else_if" then
					emit_else_if_debug_lines(condition)
				else
					emit_if_debug_lines(condition)
				end
				if_depth = if_depth + 1
				for _, buffered_line in ipairs(if_lines) do
					table.insert(debug_lines, buffered_line)
				end
				reset_if_state()
			end
			goto continue
		end

		if starts_else_if then
			local paren_index = stripped:find("%(")
			if paren_index then
				reset_if_state()
				collecting_if = true
				collecting_if_type = "else_if"
				if_paren_depth = 1
				table.insert(if_lines, line)
				local remaining = stripped:sub(paren_index + 1)
				local complete = process_if_text(remaining)
				if complete then
					local condition = table.concat(if_condition_parts):gsub("^%s*", ""):gsub("%s*$", "")
					emit_else_if_debug_lines(condition)
					if_depth = if_depth + 1
					for _, buffered_line in ipairs(if_lines) do
						table.insert(debug_lines, buffered_line)
					end
					reset_if_state()
				end
				goto continue
			end
		end

		if starts_if then
			local paren_index = stripped:find("%(")
			if paren_index then
				reset_if_state()
				collecting_if = true
				collecting_if_type = "if"
				if_paren_depth = 1
				table.insert(if_lines, line)
				local remaining = stripped:sub(paren_index + 1)
				local complete = process_if_text(remaining)
				if complete then
					local condition = table.concat(if_condition_parts):gsub("^%s*", ""):gsub("%s*$", "")
					emit_if_debug_lines(condition)
					if_depth = if_depth + 1
					for _, buffered_line in ipairs(if_lines) do
						table.insert(debug_lines, buffered_line)
					end
					reset_if_state()
				end
				goto continue
			end
		end

		if starts_else and not starts_else_if then
			table.insert(debug_lines, 'writeln("     DEBUG: else");')
			table.insert(debug_lines, "writeln('');")
		end

		table.insert(debug_lines, line)

		if can_inject and local_match then
			local var_name = local_match
			table.insert(debug_lines, string.format('writeln("     DEBUG: %s = " + %s);', var_name, var_name))
		elseif can_inject and var_match then
			local var_name = var_match
			table.insert(debug_lines, string.format('writeln("     DEBUG: %s = " + %s);', var_name, var_name))
		elseif can_inject and assign_match and not trimmed:match("^function%s+") then
			local var_name = assign_match
			local expr = trimmed:match("^%w+%s*=%s*(.+)$")
			if expr then
				table.insert(debug_lines, string.format('writeln("     DEBUG: %s = " + %s);', var_name, var_name))
			end
		elseif can_inject and func_name and not writeln_match and not stripped:match("^function%s+") and not stripped:find("=") then
			local args = split_args(raw_args or "")
			table.insert(debug_lines, build_function_debug_line(func_name, args))
		elseif writeln_match then
			-- Skip writeln lines to avoid duplicate output
		end

		if stripped:match("^}%s*") and if_depth > 0 then
			table.insert(debug_lines, 'writeln("     DEBUG: end");')
			if_depth = if_depth - 1
		end

		::continue::
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

local function get_machine_state_debug_lines()
	return {
		'writeln("")',
		'writeln("     DEBUG: ----- MACHINE STATE -----")',
		'if (typeof machineState !== "undefined") {',
		'  for (var key in machineState) {',
		'    if (typeof machineState[key] != "function") {',
		'      writeln("     DEBUG: machineState." + key + " = " + machineState[key]);',
		'    }',
		'  }',
		'} else if (typeof state !== "undefined") {',
		'  for (var key in state) {',
		'    if (typeof state[key] != "function") {',
		'      writeln("     DEBUG: state." + key + " = " + state[key]);',
		'    }',
		'  }',
		'} else {',
		'  writeln("     DEBUG: no machineState/state found");',
		'}',
		'writeln("")',
	}
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

	vim.ui.select({ "Yes", "No" }, {
		prompt = "Debug selected lines: check machine state?",
	}, function(choice)
		if not choice then
			return
		end

		local include_machine_state = choice == "Yes"
		local output_lines = {}

		for i = 1, start_line - 1 do
			table.insert(output_lines, original_lines[i])
		end

		if include_machine_state then
			for _, line in ipairs(get_machine_state_debug_lines()) do
				table.insert(output_lines, line)
			end
		end

		for _, line in ipairs({ 'writeln("")', 'writeln("     DEBUG: Selected Lines Start")', 'writeln("")' }) do
			table.insert(output_lines, line)
		end

		for _, line in ipairs(debug_injected_lines) do
			table.insert(output_lines, line)
		end

		for _, line in ipairs({ 'writeln("")', 'writeln("     DEBUG: Selected Lines End")', 'writeln("")' }) do
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
			local run_opts = vim.tbl_extend("force", {}, opts, { show_inline_hints = false })
			core.run_post_processor(selected_nc_file, run_opts, false, temp_cps)
		end)
	end)
end

return M
