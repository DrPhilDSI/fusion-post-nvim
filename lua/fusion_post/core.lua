local M = {}

local ui = require("fusion_post.ui")
local hint = require("fusion_post.hint")

function M.run_post_processor(selected_file, opts)
	local post_exe_path = opts.post_exe_path
	local cnc_folder = vim.fn.expand(opts.cnc_folder)

	if vim.fn.filereadable(post_exe_path) ~= 1 then
		print("Error: post.exe path is invalid. Set it in your LazyVim config.")
		return
	end

	local post_processor = vim.fn.expand("%:p")
	if not post_processor:match("%.cps$") then
		print("Error: No valid post-processor (.cps) file is open.")
		return
	end

	local output_file = selected_file:gsub("%.cnc$", ".nc")
	local log_file = selected_file:gsub("%.cnc$", ".log")
	local cleaned_output_file = selected_file:gsub("%.cnc$", "-cleaned.nc")

	local cmd = string.format(
		'"%s" "%s" "%s" --property programName 1001 --debugall',
		post_exe_path,
		post_processor,
		selected_file
	)
	print("Running command: " .. cmd)

	local result = vim.fn.system(cmd)
	local exit_code = vim.v.shell_error

	if vim.fn.filereadable(output_file) == 1 then
		M.clean_debug_output(output_file, cleaned_output_file)
		ui.open_preview(cleaned_output_file, "gcode")
		hint.add_function_hints(post_processor, output_file)
	elseif (exit_code ~= 0) and vim.fn.filereadable(log_file) then
		ui.open_preview(log_file, "text")
		print(string.format("Post failed (exit code %d). Showing log.", exit_code))
	else
		print(string.format("Error: Post processing failed (exit code %d).", exit_code))
	end
end

function M.clean_debug_output(input_file, output_file)
	local infile = io.open(input_file, "r")
	if not infile then
		print("Error: Cannot open NC file for cleaning.")
		return
	end

	local outfile = io.open(output_file, "w")
	if not outfile then
		print("Error: Cannot create cleaned NC file.")
		infile:close()
		return
	end

	for line in infile:lines() do
		if not line:match("!DEBUG") then
			outfile:write(line .. "\n")
		end
	end

	infile:close()
	outfile:close()

	print("Cleaned NC file created: " .. output_file)
end

return M
