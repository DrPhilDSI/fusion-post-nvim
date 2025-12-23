local M = {}

function M.select_file(folder, callback)
	local exts = { "js", "cnc" }
	local all_files = {}

	for _, ext in ipairs(exts) do
		local pattern = folder .. "*." .. ext
		local files = vim.fn.glob(pattern, false, true)
		vim.list_extend(all_files, files)
	end

	if #all_files == 0 then
		print("No files found in " .. folder)
		return nil
	end

	-- Create display list and map
	local items = {}
	local lookup = {}

	for _, full_path in ipairs(all_files) do
		local name = vim.fn.fnamemodify(full_path, ":t") -- just the file name
		table.insert(items, name)
		lookup[name] = full_path
	end

	vim.ui.select(items, { prompt = "Select File" }, function(choice)
		if choice then
			local full_path = lookup[choice]
			print("User selected: " .. full_path)
			if type(callback) == "function" then
				callback(full_path)
			else
				print("Error: No valid callback function provided!") -- Debugging
			end
		else
			print("User cancelled file selection") -- Debugging
		end
	end)
end

function M.open_preview(file, filetype)
	local preview_win = nil
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].buftype == "nofile" and vim.bo[buf].readonly then
			preview_win = win
			break
		end
	end
	if preview_win then
		vim.api.nvim_win_close(preview_win, true)
	end

	vim.cmd("vsplit " .. file)
	vim.cmd("wincmd L")
	local bufnr = vim.api.nvim_get_current_buf()
	vim.bo.buftype = "nofile"
	vim.bo.swapfile = false
	vim.bo.bufhidden = "wipe"
	vim.bo.readonly = true
	return bufnr
end

return M
