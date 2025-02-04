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
        require("fusion_post.core").run_post_processor(M.options)
    end, {})

    vim.api.nvim_create_user_command("FusionPostConfig", function(opts)
        if opts.args ~= "" then
            M.options.post_exe_path = opts.args
            print("Updated post.exe path: " .. M.options.post_exe_path)
        else
            print("Current post.exe path: " .. M.options.post_exe_path)
        end
    end, { nargs = "?" })
end

return M
