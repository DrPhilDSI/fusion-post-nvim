local M = {}

local utils = require("fusion_post.utils")
local log = require("fusion_post.log")

-- Encrypt a post
function M.encrypt_post(opts)
	local post_exe_path = opts.post_exe_path
	local post_path = utils.get_current_cps_file()
	local password = opts.password

	if not post_path then
		utils.notify_error("No valid .cps file is open.")
		return
	end

	-- Define encrypted filename
	local encrypted_file = post_path:gsub(utils.FILE_EXTENSIONS.cps, ".protected.cps")
	local final_name = post_path:gsub(utils.FILE_EXTENSIONS.cps, " " .. utils.get_current_date() .. ".cps")

	-- Construct encryption command
	local cmd = string.format('"%s" --encrypt "%s" "%s"', post_exe_path, password, post_path)
	log.log("Encrypting: " .. cmd)

	-- Run command
	local result = vim.fn.system(cmd)

	if vim.fn.filereadable(encrypted_file) == 1 then
		os.rename(encrypted_file, final_name)
		vim.notify("Encryption successful: " .. final_name, vim.log.levels.INFO)
	else
		utils.notify_error("Encryption failed.")
	end
end

-- Decrypt a post
function M.decrypt_post(opts)
	local post_exe_path = opts.post_exe_path
	local post_path = utils.get_current_cps_file()
	local password = opts.password

	if not post_path then
		utils.notify_error("No valid .cps file is open.")
		return
	end

	-- Construct decryption command
	local cmd = string.format('"%s" --decrypt "%s" "%s"', post_exe_path, password, post_path)
	log.log("Decrypting: " .. cmd)

	-- Run command
	local result = vim.fn.system(cmd)
	local exit_code = vim.v.shell_error

	if exit_code ~= 0 then
		utils.notify_error("Decryption failed.")
	else
		vim.notify("Decryption successful: " .. post_path, vim.log.levels.INFO)
	end
end

return M
