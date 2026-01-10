local M = {}

-- Storage for buffered .cnc file paths
-- Structure: { global = path, per_file = { [cps_path] = cnc_path } }
local storage = {
	global = nil,
	per_file = {},
}

-- Store global .cnc file path
function M.set_global(path)
	storage.global = path
end

-- Store .cnc path for specific .cps file
function M.set_for_file(cps_path, cnc_path)
	if cps_path and cps_path ~= "" then
		storage.per_file[cps_path] = cnc_path
	end
end

-- Get .cnc path for a .cps file (checks per-file first, then global)
function M.get_for_file(cps_path)
	if cps_path and cps_path ~= "" then
		-- Check per-file storage first
		if storage.per_file[cps_path] then
			return storage.per_file[cps_path]
		end
	end
	-- Fall back to global storage
	return storage.global
end

-- Clear all storage
function M.clear_all()
	storage.global = nil
	storage.per_file = {}
end

-- Clear storage for specific .cps file
function M.clear_for_file(cps_path)
	if cps_path and storage.per_file[cps_path] then
		storage.per_file[cps_path] = nil
	end
end

return M
