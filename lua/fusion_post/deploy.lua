local M = {}

local utils = require("fusion_post.utils")

function M.deploy_post(opts)
	local post_path = utils.get_current_cps_file()
	if not post_path then
		utils.notify_error("No valid .cps file is open.")
		return
	end

	local final_path = post_path:gsub(utils.FILE_EXTENSIONS.cps, " " .. utils.get_current_date() .. ".cps")

	-- Lua doesn't have a built-in file copy function, so we read and write the file manually
	local source_file, err_read = io.open(post_path, "r")
	if not source_file then
		utils.notify_error("Error opening source file: " .. err_read)
		return
	end

	local content = source_file:read("*a")
	source_file:close()

	local dest_file, err_write = io.open(final_path, "w")
	if not dest_file then
		utils.notify_error("Error creating destination file: " .. err_write)
		return
	end

	dest_file:write(content)
	dest_file:close()
	vim.notify("File copied successfully to " .. final_path, vim.log.levels.INFO)
end

return M
