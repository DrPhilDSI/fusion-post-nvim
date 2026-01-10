local M = {}

M.options = {
	post_exe_path = "", -- User should define in LazyVim setup
	cnc_folder = "~/Fusion 360/NC Programs/", -- Default CNC folder
	password = "", -- Password for encrypting
	boiler_plate_folder = "",
	shorten_output = false,
	line_limit = 20,
	program_name = "1001",
}

local log = require("fusion_post.log")
local cnc_storage = require("fusion_post.cnc_storage")
local utils = require("fusion_post.utils")
local settings_storage = require("fusion_post.settings_storage")

local plugin_root = utils.get_plugin_root()
local globals_path = plugin_root .. "types/globals.d.ts"

-- Register post processing commands
local function register_post_commands()
	vim.api.nvim_create_user_command("FusionPost", function()
		local core = require("fusion_post.core")
		local ui = require("fusion_post.ui")
		ui.select_file(M.options.cnc_folder, function(selected_file)
			core.run_post_processor(selected_file, M.options, false)
		end)
	end, {})

	vim.api.nvim_create_user_command("FusionDump", function()
		local core = require("fusion_post.core")
		local ui = require("fusion_post.ui")
		ui.select_file(M.options.cnc_folder, function(selected_file)
			core.run_post_processor(selected_file, M.options, true)
		end)
	end, {})
end

-- Register utility commands
local function register_utility_commands()
	vim.api.nvim_create_user_command("FusionInsert", function()
		local insert_boiler = require("fusion_post.insert_boiler")
		local ui = require("fusion_post.ui")
		ui.select_file(M.options.boiler_plate_folder, function(selected_file)
			insert_boiler.insert_boiler_plate(selected_file)
		end)
	end, {})

	vim.api.nvim_create_user_command("FusionPostConfig", function(opts)
		if opts.args ~= "" then
			M.options.post_exe_path = opts.args
			vim.notify("Updated post.exe path: " .. M.options.post_exe_path, vim.log.levels.INFO)
		else
			vim.notify("Current post.exe path: " .. M.options.post_exe_path, vim.log.levels.INFO)
		end
	end, { nargs = "?" })

	vim.api.nvim_create_user_command("FusionDeploy", function()
		local deploy = require("fusion_post.deploy")
		deploy.deploy_post(M.options)
	end, {})

	vim.api.nvim_create_user_command("FusionEncrypt", function()
		local encrypt = require("fusion_post.encrypt")
		encrypt.encrypt_post(M.options)
	end, {})

	vim.api.nvim_create_user_command("FusionDecrypt", function()
		local decrypt = require("fusion_post.encrypt")
		decrypt.decrypt_post(M.options)
	end, {})

	vim.api.nvim_create_user_command("FusionAutoComplete", function()
		local line = '/// <reference path="' .. globals_path .. '" />'

		local first_line = vim.fn.getline(1)
		if first_line:find("globals%.d%.ts") then
			vim.notify("Reference already exists.", vim.log.levels.INFO)
			return
		end

		vim.api.nvim_buf_set_lines(0, 0, 0, false, { line, "" })
		vim.notify("Fusion 360 globals reference added.", vim.log.levels.INFO)
	end, {})

	vim.api.nvim_create_user_command("FusionProperties", function()
		local current_file = utils.get_current_cps_file()
		if not current_file then
			utils.notify_error("No valid post-processor (.cps) file is open.")
			return
		end

		local properties_ui = require("fusion_post.properties_ui")
		properties_ui.open_properties_ui(current_file)
	end, {})

	vim.api.nvim_create_user_command("FusionSettings", function()
		local settings_ui = require("fusion_post.settings_ui")
		settings_ui.open_settings_ui(function()
			-- Callback when UI closes - reload settings into options
			local saved_settings = settings_storage.get_all_settings()
			M.options.program_name = saved_settings.program_name
			M.options.shorten_output = saved_settings.shorten_output
			M.options.line_limit = saved_settings.line_limit
		end)
	end, {})
end

-- Register autocmds
local function register_autocmds()
	vim.api.nvim_create_autocmd("BufWritePost", {
		pattern = "*.cps",
		callback = function(args)
			-- Get the file path from the buffer that was saved
			local post_processor = vim.api.nvim_buf_get_name(args.buf)
			if not post_processor or post_processor == "" or not post_processor:match(utils.FILE_EXTENSIONS.cps) then
				return
			end

			-- Normalize the path to absolute
			post_processor = vim.fn.fnamemodify(post_processor, ":p")
			local saved_buf = args.buf

			-- Get buffered .cnc file from storage
			local buffered_file = cnc_storage.get_for_file(post_processor)
			if buffered_file then
				vim.defer_fn(function()
					-- Ensure we're in the correct buffer context
					local current_buf = vim.api.nvim_get_current_buf()
					if current_buf ~= saved_buf then
						vim.api.nvim_set_current_buf(saved_buf)
					end
					local core = require("fusion_post.core")
					-- Pass post_processor explicitly to avoid buffer context issues
					core.run_post_processor(buffered_file, M.options, false, post_processor)
				end, 100)
			else
				log.log("No buffered .cnc file found for " .. post_processor)
			end
		end,
	})

	-- Clear property storage when .cps buffer is closed
	vim.api.nvim_create_autocmd("BufUnload", {
		pattern = "*.cps",
		callback = function(args)
			local properties = require("fusion_post.properties")
			local file_path = args.file
			if file_path and file_path ~= "" then
				properties.clear_storage(file_path)
			end
		end,
	})

	-- Clear all .cnc file storage when session ends
	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			cnc_storage.clear_all()
		end,
	})
end

-- Function to update options with user-provided settings
function M.setup(opts)
	-- Load saved settings first
	local saved_settings = settings_storage.get_all_settings()
	
	-- Merge: defaults -> saved settings -> user opts (user opts take precedence)
	M.options = vim.tbl_extend("force", M.options, saved_settings)
	M.options = vim.tbl_extend("force", M.options, opts or {})

	-- Validate paths
	if vim.fn.filereadable(M.options.post_exe_path) ~= 1 then
		utils.notify_warning("post.exe path is invalid. Set `post_exe_path` in your LazyVim config.")
	end

	if vim.fn.isdirectory(vim.fn.expand(M.options.cnc_folder)) ~= 1 then
		utils.notify_warning("CNC folder path is invalid. Set `cnc_folder` in your LazyVim config.")
	end

	-- Register commands and autocmds
	register_post_commands()
	register_utility_commands()
	register_autocmds()
end

return M
