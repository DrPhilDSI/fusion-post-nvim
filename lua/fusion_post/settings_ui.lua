local M = {}

local settings_storage = require("fusion_post.settings_storage")
local utils = require("fusion_post.utils")

-- UI state
local ui_state = {
	bufnr = nil,
	win_id = nil,
	settings = {},
	current_field = 1, -- 1 = program_name, 2 = shorten_output, 3 = line_limit
	on_close = nil, -- Callback when UI closes
}

local FIELD_NAMES = {
	"Program Name",
	"Shorten Output",
	"Line Limit",
}

local FIELD_KEYS = {
	"program_name",
	"shorten_output",
	"line_limit",
}

-- Update display
local function update_display()
	if not ui_state.bufnr or not vim.api.nvim_buf_is_valid(ui_state.bufnr) then
		return
	end

	local lines = {}
	table.insert(lines, "Fusion Post Settings")
	table.insert(lines, "===================")
	table.insert(lines, "")

	for i, field_name in ipairs(FIELD_NAMES) do
		local key = FIELD_KEYS[i]
		local value = ui_state.settings[key]
		
		if key == "shorten_output" then
			value = tostring(value)
		elseif key == "line_limit" then
			value = tostring(value)
		end
		
		local line = string.format("  %s: %s", field_name, value)
		table.insert(lines, line)
	end

	table.insert(lines, "")
	table.insert(lines, "Press Enter to edit, q to quit")

	vim.api.nvim_buf_set_lines(ui_state.bufnr, 0, -1, false, lines)

	-- Set up highlights
	local ns = vim.api.nvim_create_namespace("fusion_post_settings")
	vim.api.nvim_buf_clear_namespace(ui_state.bufnr, ns, 0, -1)

	-- Highlight current line
	if ui_state.current_field > 0 and ui_state.current_field <= #FIELD_NAMES then
		local current_line = 3 + ui_state.current_field -- 3 header lines + current field
		vim.api.nvim_buf_add_highlight(
			ui_state.bufnr,
			ns,
			"CursorLine",
			current_line - 1,
			0,
			-1
		)
		-- Set cursor position
		if ui_state.win_id and vim.api.nvim_win_is_valid(ui_state.win_id) then
			vim.api.nvim_win_set_cursor(ui_state.win_id, { current_line, 0 })
		end
	end
end

-- Edit current field
local function edit_current_field()
	local key = FIELD_KEYS[ui_state.current_field]
	local current_value = ui_state.settings[key]
	
	if key == "shorten_output" then
		-- Toggle boolean
		ui_state.settings[key] = not current_value
		settings_storage.set_setting(key, ui_state.settings[key])
		update_display()
		vim.notify(string.format("%s set to %s", FIELD_NAMES[ui_state.current_field], tostring(ui_state.settings[key])), vim.log.levels.INFO)
	else
		-- Prompt for input
		local prompt = string.format("Enter %s (current: %s): ", FIELD_NAMES[ui_state.current_field], tostring(current_value))
		vim.ui.input({ prompt = prompt, default = tostring(current_value) }, function(input)
			if input then
				if key == "line_limit" then
					local num = tonumber(input)
					if num and num > 0 then
						ui_state.settings[key] = num
						settings_storage.set_setting(key, num)
						update_display()
						vim.notify(string.format("%s set to %d", FIELD_NAMES[ui_state.current_field], num), vim.log.levels.INFO)
					else
						vim.notify("Invalid number. Must be greater than 0.", vim.log.levels.ERROR)
					end
				else -- program_name
					if input ~= "" then
						ui_state.settings[key] = input
						settings_storage.set_setting(key, input)
						update_display()
						vim.notify(string.format("%s set to %s", FIELD_NAMES[ui_state.current_field], input), vim.log.levels.INFO)
					else
						vim.notify("Program name cannot be empty.", vim.log.levels.ERROR)
					end
				end
			end
		end)
	end
end

-- Setup keybindings
local function setup_keybindings()
	local function close_ui()
		if ui_state.win_id and vim.api.nvim_win_is_valid(ui_state.win_id) then
			vim.api.nvim_win_close(ui_state.win_id, true)
		end
		ui_state.win_id = nil
		ui_state.bufnr = nil
		-- Call callback if provided
		if ui_state.on_close then
			ui_state.on_close()
			ui_state.on_close = nil
		end
	end

	vim.keymap.set("n", "<CR>", edit_current_field, { buffer = ui_state.bufnr })
	vim.keymap.set("n", "q", close_ui, { buffer = ui_state.bufnr })
	vim.keymap.set("n", "<Esc>", close_ui, { buffer = ui_state.bufnr })
	vim.keymap.set("n", "j", function()
		if ui_state.current_field < #FIELD_NAMES then
			ui_state.current_field = ui_state.current_field + 1
			update_display()
		end
	end, { buffer = ui_state.bufnr })
	vim.keymap.set("n", "k", function()
		if ui_state.current_field > 1 then
			ui_state.current_field = ui_state.current_field - 1
			update_display()
		end
	end, { buffer = ui_state.bufnr })
end

-- Open settings UI
function M.open_settings_ui(on_close_callback)
	-- Load current settings
	ui_state.settings = settings_storage.get_all_settings()
	ui_state.on_close = on_close_callback

	-- Close existing window if open
	if ui_state.win_id and vim.api.nvim_win_is_valid(ui_state.win_id) then
		vim.api.nvim_win_close(ui_state.win_id, true)
	end

	-- Create buffer
	ui_state.bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(ui_state.bufnr, "FusionPost Settings")
	vim.bo[ui_state.bufnr].buftype = "nofile"
	vim.bo[ui_state.bufnr].swapfile = false
	vim.bo[ui_state.bufnr].bufhidden = "wipe"
	vim.bo[ui_state.bufnr].filetype = "markdown"

	-- Create floating window
	local width = 50
	local height = 12
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
	ui_state.current_field = 1

	-- Set up keybindings
	setup_keybindings()

	-- Update display
	update_display()

	vim.notify("Settings UI opened. Use j/k to navigate, Enter to edit, q to quit", vim.log.levels.INFO)
end

return M
