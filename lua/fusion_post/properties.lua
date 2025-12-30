local M = {}

-- Storage for property values per file
local property_storage = {}

-- Helper function to parse JavaScript-like values
local function parse_value(str)
	str = str:match("^%s*(.-)%s*$") -- trim whitespace
	if str == "true" then
		return true
	elseif str == "false" then
		return false
	elseif str:match("^%d+$") then
		return tonumber(str)
	elseif str:match('^".-"$') or str:match("^'.-'$") then
		-- Remove quotes
		return str:sub(2, -2)
	else
		return str
	end
end

-- Helper function to parse array values (for enum)
local function parse_array(str)
	local values = {}
	-- Match array items: {title:"Yes", id:"true"} or {title:'Yes', id:'true'}
	-- Handle nested braces by tracking depth
	local depth = 0
	local current_item = ""

	for i = 1, #str do
		local char = str:sub(i, i)
		if char == "{" then
			if depth == 0 then
				current_item = ""
			end
			depth = depth + 1
			current_item = current_item .. char
		elseif char == "}" then
			current_item = current_item .. char
			depth = depth - 1
			if depth == 0 then
				-- Parse the complete item
				local title_match = current_item:match('title%s*:%s*"([^"]+)"')
				if not title_match then
					title_match = current_item:match("title%s*:%s*'([^']+)'")
				end
				local id_match = current_item:match('id%s*:%s*"([^"]+)"')
				if not id_match then
					id_match = current_item:match("id%s*:%s*'([^']+)'")
				end
				if title_match and id_match then
					table.insert(values, { title = title_match, id = id_match })
				end
				current_item = ""
			end
		elseif depth > 0 then
			current_item = current_item .. char
		end
	end
	return values
end

-- Parse a single property object
local function parse_property_object(content, start_line, end_line)
	local prop = {}
	local lines = {}
	for i = start_line, end_line do
		table.insert(lines, content[i])
	end
	local full_text = table.concat(lines, "\n")

	-- Extract title (handle multi-line with potential escaped quotes)
	local title_match = full_text:match('title%s*:%s*"([^"]+)"')
	if not title_match then
		-- Try with single quotes
		title_match = full_text:match("title%s*:%s*'([^']+)'")
	end
	if title_match then
		prop.title = title_match
	end

	-- Extract description (handle multi-line)
	local desc_match = full_text:match('description%s*:%s*"([^"]+)"')
	if not desc_match then
		desc_match = full_text:match("description%s*:%s*'([^']+)'")
	end
	if desc_match then
		prop.description = desc_match
	end

	-- Extract group
	local group_match = full_text:match('group%s*:%s*"([^"]+)"')
	if not group_match then
		group_match = full_text:match("group%s*:%s*'([^']+)'")
	end
	if group_match then
		prop.group = group_match
	else
		prop.group = "other"
	end

	-- Extract type
	local type_match = full_text:match('type%s*:%s*"([^"]+)"')
	if not type_match then
		type_match = full_text:match("type%s*:%s*'([^']+)'")
	end
	if type_match then
		prop.type = type_match
	end

	-- Extract value (more flexible pattern - handle quoted strings and unquoted values)
	-- Search line by line for the value field
	local value_match = nil
	local is_quoted = false

	for line in full_text:gmatch("[^\n]+") do
		-- Trim the line
		local trimmed = line:match("^%s*(.-)%s*$")

		-- Check if line starts with "value:" (after trimming) but not "values:"
		-- This is the key: we check the START of the trimmed line
		local starts_with_value = trimmed:match("^value%s*:")
		local starts_with_values = trimmed:match("^values%s*:")

		if starts_with_value and not starts_with_values then
			-- Try quoted double string
			value_match = trimmed:match('value%s*:%s*"([^"]+)"')
			if value_match then
				is_quoted = true
			else
				-- Try quoted single string
				value_match = trimmed:match("value%s*:%s*'([^']+)'")
				if value_match then
					is_quoted = true
				else
					-- Try unquoted value - match everything after "value:" until comma, semicolon, or end
					local after_colon = trimmed:match("value%s*:%s*(.+)")
					if after_colon then
						-- Remove trailing comma/semicolon and trim
						value_match = after_colon:match("^%s*(.-)%s*[,;]?%s*$")
						if value_match then
							value_match = value_match:match("^%s*(.-)%s*$")
						end
					end
				end
			end

			if value_match then
				break
			end
		end
	end

	-- Store the value
	if value_match then
		-- For quoted strings, preserve the string value as-is (don't convert "true"/"false" to booleans)
		-- This is important for enum values which are strings like "true", "G28", etc.
		if is_quoted then
			prop.value = value_match -- Keep as string
		else
			prop.value = parse_value(value_match) -- Parse for booleans/numbers
		end
	end

	-- Extract values array (for enums) - handle multi-line arrays
	local values_start = full_text:find("values%s*:%s*%[")
	if values_start then
		local array_text = ""
		local brace_count = 0
		local in_array = false
		for i = values_start, #full_text do
			local char = full_text:sub(i, i)
			if char == "[" then
				in_array = true
				brace_count = brace_count + 1
			elseif char == "]" then
				brace_count = brace_count - 1
				if brace_count == 0 then
					array_text = array_text .. char
					break
				end
			end
			if in_array then
				array_text = array_text .. char
			end
		end
		if array_text ~= "" then
			local values_match = array_text:match("%[(.+)%]")
			if values_match then
				prop.values = parse_array(values_match)
			end
		end
	end

	return prop
end

-- Parse properties from file content
function M.parse_properties(file_path)
	local content = {}
	local file = io.open(file_path, "r")
	if not file then
		return {}
	end

	for line in file:lines() do
		table.insert(content, line)
	end
	file:close()

	local properties = {}

	-- First, look for properties = { ... } format
	local in_properties_object = false
	local brace_count = 0
	local prop_start_line = 0
	local current_prop_name = nil
	local prop_brace_count = 0

	for i, line in ipairs(content) do
		-- Skip comments
		if line:match("^%s*//") then
			goto continue
		end

		-- Check for properties = { start
		if line:match("^%s*properties%s*=%s*{") then
			in_properties_object = true
			brace_count = 1
		elseif in_properties_object then
			-- Check for property name: { pattern (start of a property) FIRST
			-- This must happen before we count braces, so we can start tracking the property
			local prop_name_match = line:match("^%s*([%w_]+)%s*:%s*{")
			local is_new_property = false
			if prop_name_match and not current_prop_name then
				current_prop_name = prop_name_match
				prop_start_line = i
				prop_brace_count = 0 -- Will be set to 1 after counting
				is_new_property = true
			end

			-- Count braces for the main properties object
			for char in line:gmatch(".") do
				if char == "{" then
					brace_count = brace_count + 1
				elseif char == "}" then
					brace_count = brace_count - 1
				end
			end

			-- If we're inside a property, count its braces separately
			if current_prop_name then
				-- Count braces for this specific property
				-- We need to count all braces on this line to track nested objects
				for char in line:gmatch(".") do
					if char == "{" then
						prop_brace_count = prop_brace_count + 1
					elseif char == "}" then
						prop_brace_count = prop_brace_count - 1
					end
				end

				-- Check if we've closed the current property object
				-- We check AFTER counting braces on this line, so we include the closing brace line
				if prop_brace_count == 0 then
					local prop = parse_property_object(content, prop_start_line, i)
					prop.name = current_prop_name
					properties[current_prop_name] = prop
					current_prop_name = nil
				end
			end

			-- Check if we've closed the properties object
			if brace_count == 0 then
				in_properties_object = false
			end
		end

		::continue::
	end

	-- Second, look for properties.propertyName = { ... } format
	for i, line in ipairs(content) do
		-- Skip comments
		if line:match("^%s*//") then
			goto continue2
		end

		local prop_match = line:match("^%s*properties%.([%w_]+)%s*=%s*{")
		if prop_match then
			-- Find the closing brace
			local brace_count = 1
			local start_line = i
			local end_line = i
			for j = i + 1, #content do
				local l = content[j]
				for char in l:gmatch(".") do
					if char == "{" then
						brace_count = brace_count + 1
					elseif char == "}" then
						brace_count = brace_count - 1
					end
				end
				if brace_count == 0 then
					end_line = j
					break
				end
			end

			local prop = parse_property_object(content, start_line, end_line)
			prop.name = prop_match
			properties[prop_match] = prop
		end

		::continue2::
	end

	-- Store original values
	if not property_storage[file_path] then
		property_storage[file_path] = {
			original = {},
			modified = {},
		}
	end

	for name, prop in pairs(properties) do
		if prop.value ~= nil then
			property_storage[file_path].original[name] = prop.value
		end
	end

	return properties
end

-- Get modified properties for a file
function M.get_modified_properties(file_path)
	if not property_storage[file_path] then
		return {}
	end

	local modified = {}
	for name, value in pairs(property_storage[file_path].modified) do
		modified[name] = value
	end
	return modified
end

-- Set a property value
function M.set_property(file_path, name, value)
	if not property_storage[file_path] then
		property_storage[file_path] = {
			original = {},
			modified = {},
		}
	end

	-- Only store if different from original
	local original = property_storage[file_path].original[name]
	if original ~= value then
		property_storage[file_path].modified[name] = value
	else
		-- If same as original, remove from modified
		property_storage[file_path].modified[name] = nil
	end
end

-- Reset all properties for a file
function M.reset_properties(file_path)
	if property_storage[file_path] then
		property_storage[file_path].modified = {}
	end
end

-- Get current value (modified if exists, otherwise original)
function M.get_property_value(file_path, name)
	if not property_storage[file_path] then
		return nil
	end

	if property_storage[file_path].modified[name] ~= nil then
		return property_storage[file_path].modified[name]
	end
	return property_storage[file_path].original[name]
end

-- Clear storage for a file
function M.clear_storage(file_path)
	property_storage[file_path] = nil
end

return M
