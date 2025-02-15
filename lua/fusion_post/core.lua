local M = {}

local ui = require("fusion_post.ui")
local hint = require("fusion_post.hint")
local last_selected = ""

function M.run_post_processor(selected_file, opts)
	local post_exe_path = opts.post_exe_path

	if selected_file == "saved" then
		if last_selected == "" then
			return
		else
			selected_file = last_selected
		end
	end

	last_selected = selected_file

	if vim.fn.filereadable(post_exe_path) ~= 1 then
		print("Error: post.exe path is invalid. Set it in your LazyVim config.")
		return
	end

	local post_processor = vim.fn.expand("%:p")
	if not post_processor:match("%.cps$") then
		print("Error: No valid post-processor (.cps) file is open.")
		return
	end
	local temp_dir = os.getenv("TMPDIR")
	local sub_dir = temp_dir .. "fusion_nvim/"

	local success, err = vim.loop.fs_mkdir(sub_dir, 448) -- 448 = 0o700 permission
	if not success and err ~= "EEXIST" then
		print("Failed to create directory: " .. err)
	end

	local output_file = sub_dir .. "debug_post.nc"
	local log_file = output_file:gsub("%.nc", ".log")
	local cleaned_output_file = output_file:gsub("%.nc", "-cleaned.nc")

	local cmd = string.format(
		'"%s" "%s" "%s" "%s" --property programName 1001 --debugall',
		post_exe_path,
		post_processor,
		selected_file,
		output_file
	)
	print("Running command: " .. cmd)

	local result = vim.fn.system(cmd)
	local exit_code = vim.v.shell_error

	if vim.fn.filereadable(output_file) == 1 then
		M.clean_debug_output(output_file, cleaned_output_file)
		ui.open_preview(cleaned_output_file, "gcode")
		hint.add_function_hints(post_processor, cleaned_output_file, output_file)
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
