if vim.g.loaded_fusion_post then
    return
end
vim.g.loaded_fusion_post = true

require("fusion_post").setup()
