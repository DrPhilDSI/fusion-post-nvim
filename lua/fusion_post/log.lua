local M = {}

M._log = M._log or {}

function M.log(msg)
	M._log[#M._log + 1] = string.format("[%s] %s", os.date("%H:%M:%S"), msg)
end

vim.api.nvim_create_user_command("FusionLog", function()
	-- dump to a scratch buffer
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, M._log)
	vim.api.nvim_set_current_buf(buf)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "log"
end, {})

return M
