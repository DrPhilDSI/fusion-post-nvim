local M = {}

local log = require("fusion_post.log")

-- Constants
M.FILE_EXTENSIONS = {
	cps = "%.cps$",
	js = "%.js$",
	cnc = "%.cnc$",
}

M.TEMP_DIR_PERMISSIONS = 448 -- 0o700
M.DEFAULT_PROGRAM_NAME = "1001"
M.SUPPORTED_CNC_EXTS = { "js", "cnc" }

-- Get plugin root directory
function M.get_plugin_root()
	local str = debug.getinfo(1, "S").source:sub(2)
	return str:match("(.*/)")
end

-- Get current date in YYYY-MM-DD format
function M.get_current_date()
	return os.date("%Y-%m-%d")
end

-- Get and validate current .cps file path
-- Returns the absolute path if valid, nil otherwise
function M.get_current_cps_file()
	local file_path = vim.fn.expand("%:p")
	if file_path and file_path ~= "" and file_path:match(M.FILE_EXTENSIONS.cps) then
		return file_path
	end
	return nil
end

-- Error handling helpers
function M.notify_error(msg)
	vim.notify(msg, vim.log.levels.ERROR)
end

function M.notify_warning(msg)
	vim.notify(msg, vim.log.levels.WARN)
end

function M.log_and_notify(msg, level)
	log.log(msg)
	if level == vim.log.levels.ERROR then
		M.notify_error(msg)
	elseif level == vim.log.levels.WARN then
		M.notify_warning(msg)
	else
		vim.notify(msg, level or vim.log.levels.INFO)
	end
end

return M
