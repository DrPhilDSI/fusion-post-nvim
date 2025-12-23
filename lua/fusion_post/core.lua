local M = {}

local ui = require("fusion_post.ui")
local hint = require("fusion_post.hint")
local previous_cnc_file = ""

local function get_plugin_root()
	local str = debug.getinfo(1, "S").source:sub(2)
	return str:match("(.*/)")
end

local plugin_root = get_plugin_root()
local dumper_path = plugin_root .. "dump/dump.cps"

function M.run_post_processor(selected_file, opts, useDumper)
	local post_exe_path = opts.post_exe_path

	if selected_file == "saved" then
		if previous_cnc_file == "" then
			print("Error: No previous output")
			return
		else
			selected_file = previous_cnc_file
			print("%s re-called", selected_file)
		end
	end

	previous_cnc_file = selected_file

	if vim.fn.filereadable(post_exe_path) ~= 1 then
		print("Error: post.exe path is invalid. Set it in your LazyVim config.")
		return
	end

	local post_processor = vim.fn.expand("%:p")
	if useDumper then
		post_processor = dumper_path
	end

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

	-- Two output files: one clean (for preview), one debug (for hints)
	local output_file = sub_dir .. "post.nc"
	local debug_output_file = sub_dir .. "post-debug.nc"
	local log_file = output_file:gsub("%.nc", ".log")

	-- vim.notify("Running post processor...", vim.log.levels.INFO)

	-- First pass: Run WITHOUT --debugall to get clean output
	local cmd_args_clean = {
		post_exe_path,
		post_processor,
		selected_file,
		output_file,
		"--property",
		"programName",
		"1001",
	}

	vim.system(cmd_args_clean, { text = true }, function(res)
		if res.code == 0 and vim.fn.filereadable(output_file) == 1 then
			-- Open preview immediately with clean output
			vim.schedule(function()
				local preview_bufnr = ui.open_preview(output_file, "gcode")

				-- If not using dumper, run second pass with debug for hints
				if not useDumper then
					-- Second pass: Run WITH --debugall to get debug output for hints
					local cmd_args_debug = {
						post_exe_path,
						post_processor,
						selected_file,
						debug_output_file,
						"--property",
						"programName",
						"1001",
						"--debugall",
					}

					vim.system(cmd_args_debug, { text = true }, function(debug_res)
						if debug_res.code == 0 and vim.fn.filereadable(debug_output_file) == 1 then
							-- Apply hints to the preview buffer
							vim.schedule(function()
								hint.add_function_hints(post_processor, output_file, debug_output_file, preview_bufnr)
							end)
						else
							vim.notify("Debug post run failed (exit code " .. debug_res.code .. "). Hints unavailable.", vim.log.levels.WARN)
						end
					end)
				end
			end)
		elseif vim.fn.filereadable(log_file) == 1 then
			vim.schedule(function()
				ui.open_preview(log_file, "text")
			end)
			vim.notify("Post failed (exit code " .. res.code .. "). Showing log.", vim.log.levels.WARN)
		else
			vim.notify("Post failed (exit code " .. res.code .. ")", vim.log.levels.ERROR)
		end
	end)
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
