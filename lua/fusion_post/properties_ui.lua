local M = {}

local properties = require("fusion_post.properties")

-- UI state
local ui_state = {
	bufnr = nil,
	win_id = nil,
	file_path = nil,
	props = {},
	prop_list = {}, -- Flat list of {name, group} for navigation
	current_index = 1,
	line_to_prop_index = {}, -- Map line number to property index
}

-- Format value for display
local function format_value(value, prop_type)
	if value == nil then
		return "nil"
	end
	if prop_type == "boolean" then
		return tostring(value)
	elseif prop_type == "enum" then
		return '"' .. tostring(value) .. '"'
	elseif prop_type == "integer" then
		return tostring(value)
	else
		return tostring(value)
	end
end

-- Check if property is modified
local function is_modified(file_path, name)
	local modified = properties.get_modified_properties(file_path)
	return modified[name] ~= nil
end

-- Build display lines
local function build_display_lines()
	local lines = {}
	table.insert(lines, "Properties Editor")
	table.insert(lines, "================")
	table.insert(lines, "")

	-- Group properties by group
	local grouped = {}
	for _, item in ipairs(ui_state.prop_list) do
		local prop = ui_state.props[item.name]
		if prop then
			local group = prop.group or "other"
			if not grouped[group] then
				grouped[group] = {}
			end
			table.insert(grouped[group], item.name)
		end
	end

	-- Sort groups for consistent display
	local sorted_groups = {}
	for group, _ in pairs(grouped) do
		table.insert(sorted_groups, group)
	end
	table.sort(sorted_groups)

	-- Display by group
	local line_map = {} -- Map line number to property name
	local name_to_line = {} -- Map property name to line number
	-- Clear the line mapping
	ui_state.line_to_prop_index = {}

	for _, group in ipairs(sorted_groups) do
		local prop_names = grouped[group]
		table.insert(lines, "[Group: " .. group .. "]")

		for _, name in ipairs(prop_names) do
			local prop = ui_state.props[name]
			if prop then
				-- Find the property index in prop_list
				local prop_index = nil
				for i, item in ipairs(ui_state.prop_list) do
					if item.name == name then
						prop_index = i
						break
					end
				end

				local current_value = properties.get_property_value(ui_state.file_path, name)
				local value_str = format_value(current_value, prop.type)
				local modified_str = is_modified(ui_state.file_path, name) and " [MODIFIED]" or ""
				local line = string.format("  %s: %s [%s]%s", name, value_str, prop.type, modified_str)
				table.insert(lines, line)
				-- Buffer lines are 1-indexed, and #lines gives us the current line number
				local buffer_line = #lines
				line_map[buffer_line] = name
				name_to_line[name] = buffer_line
				if prop_index then
					ui_state.line_to_prop_index[buffer_line] = prop_index
				end
			end
		end

		table.insert(lines, "")
	end

	table.insert(lines, "")
	table.insert(lines, "Press Enter to edit, r to reset, q to quit")

	return lines, line_map, name_to_line
end

-- Update the buffer content
local function update_display()
	if not ui_state.bufnr or not vim.api.nvim_buf_is_valid(ui_state.bufnr) then
		return
	end

	local lines, line_map, name_to_line = build_display_lines()
	vim.api.nvim_buf_set_lines(ui_state.bufnr, 0, -1, false, lines)

	-- Set up highlights for modified properties
	local ns = vim.api.nvim_create_namespace("fusion_post_properties")
	vim.api.nvim_buf_clear_namespace(ui_state.bufnr, ns, 0, -1)

	for line_num, prop_name in pairs(line_map) do
		if is_modified(ui_state.file_path, prop_name) then
			vim.api.nvim_buf_add_highlight(
				ui_state.bufnr,
				ns,
				"DiffAdd",
				line_num - 1,
				0,
				-1
			)
		end
	end

	-- Highlight current line
	if ui_state.current_index > 0 and ui_state.current_index <= #ui_state.prop_list then
		local current_name = ui_state.prop_list[ui_state.current_index].name
		local current_line = name_to_line[current_name]
		if current_line then
			vim.api.nvim_buf_add_highlight(
				ui_state.bufnr,
				ns,
				"CursorLine",
				current_line - 1,
				0,
				-1
			)
			-- Also set cursor position
			vim.api.nvim_win_set_cursor(ui_state.win_id, { current_line, 0 })
		end
	end
end

-- Edit current property
local function edit_current_property()
	-- Get the actual cursor line to determine which property to edit
	local cursor_pos = vim.api.nvim_win_get_cursor(ui_state.win_id)
	local cursor_line = cursor_pos[1] -- 1-indexed

	-- Find the property at this line
	local prop_index = ui_state.line_to_prop_index[cursor_line]
	if not prop_index or prop_index < 1 or prop_index > #ui_state.prop_list then
		-- Fall back to current_index if line doesn't map to a property
		prop_index = ui_state.current_index
	end

	-- Update current_index to match
	ui_state.current_index = prop_index

	local prop_name = ui_state.prop_list[prop_index].name
	local prop = ui_state.props[prop_name]
	if not prop then
		return
	end

	local current_value = properties.get_property_value(ui_state.file_path, prop_name)

	if prop.type == "boolean" then
		-- Toggle boolean
		local new_value = not current_value
		properties.set_property(ui_state.file_path, prop_name, new_value)
		update_display()
	elseif prop.type == "enum" and prop.values then
		-- Show enum selection
		local items = {}
		for _, val in ipairs(prop.values) do
			table.insert(items, val.title .. " (" .. val.id .. ")")
		end

		vim.ui.select(items, { prompt = "Select value for " .. prop_name }, function(choice)
			if choice then
				-- Extract id from choice
				local id = choice:match("%((.+)%)$")
				if id then
					properties.set_property(ui_state.file_path, prop_name, id)
					update_display()
				end
			end
		end)
	elseif prop.type == "integer" then
		-- Input integer
		vim.ui.input({ prompt = "Enter value for " .. prop_name .. ": ", default = tostring(current_value) }, function(input)
			if input then
				local num = tonumber(input)
				if num then
					properties.set_property(ui_state.file_path, prop_name, num)
					update_display()
				else
					vim.notify("Invalid number", vim.log.levels.ERROR)
				end
			end
		end)
	else
		-- Generic input
		vim.ui.input({ prompt = "Enter value for " .. prop_name .. ": ", default = tostring(current_value) }, function(input)
			if input then
				properties.set_property(ui_state.file_path, prop_name, input)
				update_display()
			end
		end)
	end
end

-- Navigate up
local function navigate_up()
	if ui_state.current_index > 1 then
		ui_state.current_index = ui_state.current_index - 1
		update_display()
	else
		-- Try to find property at cursor line - 1
		local cursor_pos = vim.api.nvim_win_get_cursor(ui_state.win_id)
		local prev_line = cursor_pos[1] - 1
		local prev_prop_index = ui_state.line_to_prop_index[prev_line]
		if prev_prop_index then
			ui_state.current_index = prev_prop_index
			update_display()
		end
	end
end

-- Navigate down
local function navigate_down()
	if ui_state.current_index < #ui_state.prop_list then
		ui_state.current_index = ui_state.current_index + 1
		update_display()
	else
		-- Try to find property at cursor line + 1
		local cursor_pos = vim.api.nvim_win_get_cursor(ui_state.win_id)
		local next_line = cursor_pos[1] + 1
		local next_prop_index = ui_state.line_to_prop_index[next_line]
		if next_prop_index then
			ui_state.current_index = next_prop_index
			update_display()
		end
	end
end

-- Reset all changes
local function reset_all()
	properties.reset_properties(ui_state.file_path)
	update_display()
	vim.notify("All property changes reset", vim.log.levels.INFO)
end

-- Close the UI
local function close_ui()
	if ui_state.win_id and vim.api.nvim_win_is_valid(ui_state.win_id) then
		vim.api.nvim_win_close(ui_state.win_id, true)
	end
	ui_state.bufnr = nil
	ui_state.win_id = nil
	ui_state.file_path = nil
	ui_state.props = {}
	ui_state.prop_list = {}
	ui_state.current_index = 1
	ui_state.line_to_prop_index = {}
end

-- Update current_index based on cursor position
local function sync_cursor_to_index()
	local cursor_pos = vim.api.nvim_win_get_cursor(ui_state.win_id)
	local cursor_line = cursor_pos[1]
	local prop_index = ui_state.line_to_prop_index[cursor_line]
	if prop_index then
		ui_state.current_index = prop_index
	end
end

-- Set up keybindings
local function setup_keybindings()
	if not ui_state.bufnr then
		return
	end

	local opts = { noremap = true, silent = true }

	vim.api.nvim_buf_set_keymap(ui_state.bufnr, "n", "<Enter>", "", {
		callback = edit_current_property,
		noremap = true,
		silent = true,
	})

	vim.api.nvim_buf_set_keymap(ui_state.bufnr, "n", "k", "", {
		callback = navigate_up,
		noremap = true,
		silent = true,
	})

	vim.api.nvim_buf_set_keymap(ui_state.bufnr, "n", "j", "", {
		callback = navigate_down,
		noremap = true,
		silent = true,
	})

	vim.api.nvim_buf_set_keymap(ui_state.bufnr, "n", "r", "", {
		callback = reset_all,
		noremap = true,
		silent = true,
	})

	vim.api.nvim_buf_set_keymap(ui_state.bufnr, "n", "q", "", {
		callback = close_ui,
		noremap = true,
		silent = true,
	})

	vim.api.nvim_buf_set_keymap(ui_state.bufnr, "n", "<Esc>", "", {
		callback = close_ui,
		noremap = true,
		silent = true,
	})

	-- Sync cursor position to current_index when cursor moves
	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = ui_state.bufnr,
		callback = sync_cursor_to_index,
	})
end

-- Open properties UI
function M.open_properties_ui(file_path)
	-- Parse properties
	local props = properties.parse_properties(file_path)
	if not props or vim.tbl_isempty(props) then
		vim.notify("No properties found in file", vim.log.levels.WARN)
		return
	end

	-- Build flat list for navigation
	local prop_list = {}
	for name, prop in pairs(props) do
		table.insert(prop_list, { name = name, group = prop.group or "other" })
	end

	-- Sort by group, then by name
	table.sort(prop_list, function(a, b)
		if a.group ~= b.group then
			return a.group < b.group
		end
		return a.name < b.name
	end)

	-- Update state
	ui_state.file_path = file_path
	ui_state.props = props
	ui_state.prop_list = prop_list
	ui_state.current_index = 1
	ui_state.line_to_prop_index = {}

	-- Close existing window if open
	if ui_state.win_id and vim.api.nvim_win_is_valid(ui_state.win_id) then
		vim.api.nvim_win_close(ui_state.win_id, true)
	end

	-- Create buffer
	ui_state.bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(ui_state.bufnr, "FusionPost Properties")
	vim.bo[ui_state.bufnr].buftype = "nofile"
	vim.bo[ui_state.bufnr].swapfile = false
	vim.bo[ui_state.bufnr].bufhidden = "wipe"
	vim.bo[ui_state.bufnr].filetype = "markdown"

	-- Create floating window
	local width = math.min(80, vim.o.columns - 4)
	local height = math.min(30, vim.o.lines - 4)
	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	local opts = {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = "single",
	}

	ui_state.win_id = vim.api.nvim_open_win(ui_state.bufnr, true, opts)

	-- Set up keybindings
	setup_keybindings()

	-- Update display
	update_display()

	vim.notify("Properties UI opened. Use Enter to edit, r to reset, q to quit", vim.log.levels.INFO)
end

return M

