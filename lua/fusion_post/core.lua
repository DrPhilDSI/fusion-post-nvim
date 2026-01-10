local M = {}

local ui = require("fusion_post.ui")
local hint = require("fusion_post.hint")
local log = require("fusion_post.log")
local properties = require("fusion_post.properties")
local utils = require("fusion_post.utils")
local previous_cnc_file = ""

local plugin_root = utils.get_plugin_root()
local dumper_path = plugin_root .. "dump/dump.cps"

function M.run_post_processor(selected_file, opts, useDumper, post_processor)
	local post_exe_path = opts.post_exe_path

	if selected_file == "saved" then
		if previous_cnc_file == "" then
			utils.notify_error("No previous output")
			return
		else
			selected_file = previous_cnc_file
			log.log(string.format("%s re-called", selected_file))
		end
	end

	previous_cnc_file = selected_file

	if vim.fn.filereadable(post_exe_path) ~= 1 then
		utils.notify_error("post.exe path is invalid. Set it in your LazyVim config.")
		return
	end

	-- Use provided post_processor or get from current buffer
	if not post_processor then
		post_processor = utils.get_current_cps_file()
	end
	
	if useDumper then
		post_processor = dumper_path
	end

	if not post_processor or not post_processor:match(utils.FILE_EXTENSIONS.cps) then
		utils.notify_error("No valid post-processor (.cps) file is open.")
		return
	end

	local temp_dir = os.getenv("TMPDIR")
	local sub_dir = temp_dir .. "fusion_nvim/"

	local ok, err, err_name = vim.loop.fs_mkdir(sub_dir, utils.TEMP_DIR_PERMISSIONS)
	if not ok and err_name ~= "EEXIST" then
		utils.notify_error("Failed to create directory: " .. err)
	end

	local output_file = sub_dir .. "debug_post.nc"
	local log_file = output_file:gsub("%.nc", ".log")
	local cleaned_output_file = output_file:gsub("%.nc", "-cleaned.nc")
	local post_options = {
		post_exe_path,
		post_processor,
		selected_file,
		output_file,
		"--property",
		"programName",
		opts.program_name or utils.DEFAULT_PROGRAM_NAME,
	}
	if opts.shorten_output then
		table.insert(post_options, "--shorten")
		table.insert(post_options, opts.line_limit)
	end

	-- Get modified properties for this post processor
	local modified_props = properties.get_modified_properties(post_processor)

	for name, value in pairs(modified_props) do
		table.insert(post_options, "--property")
		table.insert(post_options, name)
		local value_str = tostring(value)
		if type(value) == "string" then
			value_str = "'" .. value_str .. "'"
		end
		table.insert(post_options, value_str)
	end
	table.insert(post_options, "--debugall")

	vim.system(post_options, { text = true }, function(res)
		if res.code == 0 and vim.fn.filereadable(output_file) == 1 then
			M.clean_debug_output(output_file, cleaned_output_file)
			vim.schedule(function()
				ui.open_preview(cleaned_output_file, "gcode")
				if not useDumper then
					hint.add_function_hints(post_processor, cleaned_output_file, output_file)
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
		utils.notify_error("Cannot open NC file for cleaning.")
		return
	end

	local outfile = io.open(output_file, "w")
	if not outfile then
		utils.notify_error("Cannot create cleaned NC file.")
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

	log.log("Cleaned NC file created: " .. output_file)
end

return M
