local M = {}

-- Utility function to format today's date as YYYY-MM-DD
local function get_current_date()
    return os.date("%Y-%m-%d")
end

-- Encrypt a post
function M.encrypt_post(opts)
    local post_exe_path = opts.post_exe_path
    local post_path = vim.fn.expand("%:p") -- Get currently open .cps file
    local password = opts.password

    if not post_path:match("%.cps$") then
        print("Error: No valid .cps file is open.")
        return
    end

    -- Define encrypted filename
    local encrypted_file = post_path:gsub("%.cps$", ".protected.cps")
    local final_name = post_path:gsub("%.cps$", " " .. get_current_date() .. ".cps")

    -- Construct encryption command
    local cmd = string.format('"%s" --encrypt "%s" "%s"', post_exe_path, password, post_path)
    print("Encrypting: " .. cmd)

    -- Run command
    local result = vim.fn.system(cmd)

    if vim.fn.filereadable(encrypted_file) == 1 then
        os.rename(encrypted_file, final_name) -- Rename file
        print("Encryption successful: " .. final_name)
    else
        print("Encryption failed.")
    end
end

-- Decrypt a post
function M.decrypt_post(opts)
    local post_exe_path = opts.post_exe_path
    local post_path = vim.fn.expand("%:p") -- Get currently open .cps file
    local password = opts.password

    if not post_path:match("%.cps$") then
        print("Error: No valid .cps file is open.")
        return
    end

    -- Construct decryption command
    local cmd = string.format('"%s" --decrypt "%s" "%s"', post_exe_path, password, post_path)
    print("Decrypting: " .. cmd)

    -- Run command
    local result = vim.fn.system(cmd)

    if result == 0 then
        print("Decryption successful: " .. post_path)
    else
        print("Decryption failed.")
    end
end

return M
