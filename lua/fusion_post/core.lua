local M = {}

local ui = require("fusion_post.ui")

function M.run_post_processor(selected_file,opts)
    local post_exe_path = opts.post_exe_path
    local cnc_folder = vim.fn.expand(opts.cnc_folder)

    if vim.fn.filereadable(post_exe_path) ~= 1 then
        print("Error: post.exe path is invalid. Set it in your LazyVim config.")
        return
    end

    local post_processor = vim.fn.expand("%:p")
    if not post_processor:match("%.cps$") then
        print("Error: No valid post-processor (.cps) file is open.")
        return
    end

    local output_file = selected_file:gsub("%.cnc$", ".nc")
    local log_file = selected_file:gsub("%.cnc$", ".log")

    local cmd = string.format('"%s" "%s" "%s" --property programName 1001', post_exe_path, post_processor, selected_file)
    print("Running command: " .. cmd)

    local result = vim.fn.system(cmd)
    local exit_code = vim.v.shell_error

    if vim.fn.filereadable(output_file) == 1 then
        ui.open_preview(output_file, "gcode")
    elseif (exit_code ~= 0 ) and vim.fn.filereadable(log_file) then
        ui.open_preview(log_file, "text")
        print(string.format("Post failed (exit code %d). Showing log.", exit_code))
    else
        print(string.format("Error: Post processing failed (exit code %d).", exit_code))
    end
end

return M
