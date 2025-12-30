local M = {}

-- Utility function to format today's date as YYYY-MM-DD
local function get_current_date()
	return os.date("%Y-%m-%d")
end

function M.deploy_post(opts)
	local post_path = vim.fn.expand("%:p") -- Get currently open .cps file
	local final_path = post_path:gsub("%.cps$", " " .. get_current_date() .. ".cps")

	-- Lua doesn't have a built-in file copy function, so we read and write the file manually
	local source_file, err_read = io.open(post_path, "r")
	if not source_file then
		print("Error opening source file: " .. err_read)
	else
		local content = source_file:read("*a") -- "*a" reads the entire file
		source_file:close() -- Close the source file

		local dest_file, err_write = io.open(final_path, "w")
		if not dest_file then
			print("Error creating destination file: " .. err_write)
		else
			dest_file:write(content)
			dest_file:close() -- Close the destination file
			print("File copied successfully to " .. final_path .. ".")
		end
	end
end

return M
