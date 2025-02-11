local M = {}

function M.select_boiler_plate(template_folder, callback)
	local files = vim.fn.glob(template_folder .. "*", false, true)

	if #files == 0 then
		print("No Boiler plate files found in " .. template_folder)
		return nil
	end

	print("UI File Selection Started...") -- Debugging

	local filenames = {} -- Store short names
	local file_map = {} -- Map short names to full paths

	for _, file in ipairs(files) do
		local short_name = vim.fn.fnamemodify(file, ":t") -- Extract only the filename
		table.insert(filenames, short_name)
		file_map[short_name] = file -- Store full path for lookup
	end

	vim.ui.select(filenames, { prompt = "Select Boiler pLate File" }, function(choice)
		if choice then
			local full_path = file_map[choice] -- Retrieve full path
			print("User selected: " .. full_path) -- Debugging
			if type(callback) == "function" then
				callback(full_path) -- Pass full path to the callback
			else
				print("Error: No valid callback function provided!") -- Debugging
			end
		else
			print("User cancelled file selection") -- Debugging
		end
	end)
end

function M.select_cnc_file(cnc_folder, callback)
	local files = vim.fn.glob(cnc_folder .. "*.cnc", false, true)

	if #files == 0 then
		print("No .cnc files found in " .. cnc_folder)
		return nil
	end

	print("UI File Selection Started...") -- Debugging
	local filenames = {} -- Store short names
	local file_map = {} -- Map short names to full paths

	for _, file in ipairs(files) do
		local short_name = vim.fn.fnamemodify(file, ":t") -- Extract only the filename
		table.insert(filenames, short_name)
		file_map[short_name] = file -- Store full path for lookup
	end

	vim.ui.select(filenames, { prompt = "Select CNC File" }, function(choice)
		if choice then
			local full_path = file_map[choice] -- Retrieve full path
			print("User selected: " .. full_path) -- Debugging
			if type(callback) == "function" then
				callback(full_path) -- Pass full path to the callback
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
	vim.bo.buftype = "nofile"
	vim.bo.swapfile = false
	vim.bo.bufhidden = "wipe"
	vim.bo.readonly = true
end

return M
