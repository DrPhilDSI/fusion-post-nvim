local M = {}

function M.insert_boiler_plate(selected_file)
	local file = io.open(selected_file, "r")
	if file then
		local content = file:read("*a")
		file:close()

		local lines = {}
		for line in content:gmatch("[^\r\n]+") do
			table.insert(lines, line)
		end

		vim.api.nvim_put(lines, "l", true, true)
	end
end

return M
