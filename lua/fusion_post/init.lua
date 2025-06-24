local M = {}

M.options = {
	post_exe_path = "", -- User should define in LazyVim setup
	cnc_folder = "~/Fusion 360/NC Programs/", -- Default CNC folder
	password = "", -- Password for encrypting
	boiler_plate_folder = "",
	shorten_output = true,
	line_limit = 20,
}

-- Function to get the plugin directory dynamically
local function get_plugin_root()
	local str = debug.getinfo(1, "S").source:sub(2)
	return str:match("(.*/)")
end

local plugin_root = get_plugin_root()
local globals_path = plugin_root .. "types/globals.d.ts"

-- Function to update options with user-provided settings
function M.setup(opts)
	M.options = vim.tbl_extend("force", M.options, opts or {})

	-- Validate paths
	if vim.fn.filereadable(M.options.post_exe_path) ~= 1 then
		print("Warning: post.exe path is invalid. Set `post_exe_path` in your LazyVim config.")
	end

	if vim.fn.isdirectory(vim.fn.expand(M.options.cnc_folder)) ~= 1 then
		print("Warning: CNC folder path is invalid. Set `cnc_folder` in your LazyVim config.")
	end

	-- Register commands
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

	vim.api.nvim_create_autocmd("BufWritePost", {
		pattern = "*.cps",
		callback = function(args)
			local post_processor = vim.fn.expand("%:p")
			if not post_processor:match("%.cps$") then
				return
			end
			local current_file = args.file
			if vim.api.nvim_buf_get_name(0) == current_file then
				vim.defer_fn(function()
					local core = require("fusion_post.core")
					core.run_post_processor("saved", M.options, false)
				end, 100)
			end
		end,
	})

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
			print("Updated post.exe path: " .. M.options.post_exe_path)
		else
			print("Current post.exe path: " .. M.options.post_exe_path)
		end
	end, { nargs = "?" })

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
			print("Reference already exists.")
			return
		end

		vim.api.nvim_buf_set_lines(0, 0, 0, false, { line, "" })
		print("Fusion 360 globals reference added.")
	end, {})
end

return M
