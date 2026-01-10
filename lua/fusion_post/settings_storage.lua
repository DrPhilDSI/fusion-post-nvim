local M = {}

local utils = require("fusion_post.utils")

-- Default settings
local DEFAULT_SETTINGS = {
	program_name = "1001",
	shorten_output = false,
	line_limit = 20,
}

-- Get settings file path
local function get_settings_path()
	local data_dir = vim.fn.stdpath("data")
	return data_dir .. "/fusion-post-settings.json"
end

-- Load settings from file
function M.load_settings()
	local settings_path = get_settings_path()
	local file = io.open(settings_path, "r")
	if not file then
		-- Return defaults if file doesn't exist
		return vim.deepcopy(DEFAULT_SETTINGS)
	end

	local content = file:read("*a")
	file:close()

	-- Parse JSON
	local ok, settings = pcall(vim.json.decode, content)
	if not ok or not settings then
		return vim.deepcopy(DEFAULT_SETTINGS)
	end

	-- Merge with defaults to ensure all keys exist
	local merged = vim.deepcopy(DEFAULT_SETTINGS)
	for key, value in pairs(settings) do
		if DEFAULT_SETTINGS[key] ~= nil then
			merged[key] = value
		end
	end

	return merged
end

-- Save settings to file
function M.save_settings(settings)
	local settings_path = get_settings_path()
	local dir = vim.fn.fnamemodify(settings_path, ":h")

	-- Create directory if it doesn't exist
	if vim.fn.isdirectory(dir) ~= 1 then
		vim.fn.mkdir(dir, "p")
	end

	local json_content = vim.json.encode(settings)
	local file = io.open(settings_path, "w")
	if not file then
		return false, "Failed to open settings file for writing"
	end

	file:write(json_content)
	file:close()
	return true
end

-- Get a specific setting value
function M.get_setting(key)
	local settings = M.load_settings()
	return settings[key] or DEFAULT_SETTINGS[key]
end

-- Update a setting and save
function M.set_setting(key, value)
	local settings = M.load_settings()
	if DEFAULT_SETTINGS[key] == nil then
		return false, "Invalid setting key: " .. key
	end

	settings[key] = value
	local ok, err = M.save_settings(settings)
	if not ok then
		return false, err
	end

	return true
end

-- Get all settings
function M.get_all_settings()
	return M.load_settings()
end

-- Update multiple settings at once
function M.update_settings(new_settings)
	local settings = M.load_settings()
	for key, value in pairs(new_settings) do
		if DEFAULT_SETTINGS[key] ~= nil then
			settings[key] = value
		end
	end

	local ok, err = M.save_settings(settings)
	if not ok then
		return false, err
	end

	return true
end

return M
