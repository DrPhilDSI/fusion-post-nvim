local M = {}


function M.select_cnc_file(cnc_folder, callback)
    local files = vim.fn.glob(cnc_folder .. "*.cnc", false, true)

    if #files == 0 then
        print("No .cnc files found in " .. cnc_folder)
        return nil
    end

    print("UI File Selection Started...")  -- Debugging

    vim.ui.select(files, { prompt = "Select CNC File" }, function(choice)
        if choice then
            print("User selected: " .. choice)  -- Debugging
            if type(callback) == "function" then
                callback(choice)  -- **Only call if callback is valid**
            else
                print("Error: No valid callback function provided!")  -- Debugging
            end
        else
            print("User cancelled file selection")  -- Debugging
        end
    end)
end

function M.open_preview(file, filetype)
    local preview_win = nil
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].buftype == "nofile" and vim.bo[buf].readonly then
            preview_win = win
            break
        end
    end
    if preview_win then
        vim.api.nvim_win_close(preview_win, true)
    end

    vim.cmd("vsplit " .. file)
    vim.cmd("wincmd L")
    vim.bo.buftype = "nofile"
    vim.bo.swapfile = false
    vim.bo.bufhidden = "wipe"
    vim.bo.readonly = true
    vim.cmd("set filetype=" .. filetype)
end

return M
