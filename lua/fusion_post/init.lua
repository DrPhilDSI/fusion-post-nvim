local M = {}

-- Default settings
M.options = {
    post_exe_path = "",  -- User should define in LazyVim setup
    cnc_folder = "~/Fusion 360/NC Programs/", -- Default CNC folder
    password = "", -- Password for encrypting 
}

-- Function to update options with user-provided settings
function M.setup(opts)
    M.options = vim.tbl_extend("force", M.options, opts or {})

    -- Validate paths
    if vim.fn.filereadable(M.options.post_exe_path) ~= 1 then
        print("Warning: post.exe path is invalid. Set `post_exe_path` in your LazyVim config.")
    end

    if vim.fn.isdirectory(vim.fn.expand(M.options.cnc_folder)) ~= 1 then
        print("Warning: CNC folder path is invalid. Set `cnc_folder` in your LazyVim config.")
    end

    -- Register commands
    vim.api.nvim_create_user_command("FusionPost", function()
        local core = require("fusion_post.core")
        local ui = require("fusion_post.ui")
        ui.select_cnc_file(M.options.cnc_folder, function(selected_file)
            core.run_post_processor(selected_file, M.options)
        end)
    end, {})

    vim.api.nvim_create_user_command("FusionPostConfig", function(opts)
        if opts.args ~= "" then
            M.options.post_exe_path = opts.args
            print("Updated post.exe path: " .. M.options.post_exe_path)
        else
            print("Current post.exe path: " .. M.options.post_exe_path)
        end
    end, { nargs = "?" })
        vim.api.nvim_create_user_command("FusionEncrypt", function()
        local encrypt = require("fusion_post.encrypt")
        encrypt.encrypt_post(M.options)
    end, {})

    vim.api.nvim_create_user_command("FusionDecrypt", function()
        local decrypt = require("fusion_post.encrypt")
        decrypt.decrypt_post(M.options)
    end, {})
end

return M
