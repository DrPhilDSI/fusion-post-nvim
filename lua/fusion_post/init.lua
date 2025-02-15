local M = {}
-- Function to get the plugin directory dynamically
local function get_plugin_root()
	local str = debug.getinfo(1, "S").source:sub(2)
	return str:match("(.*/)")
end

local plugin_root = get_plugin_root()
local globals_path = plugin_root .. "lsp/globals.d.ts"

M.options = {
	post_exe_path = "", -- User should define in LazyVim setup
	cnc_folder = "~/Fusion 360/NC Programs/", -- Default CNC folder
	password = "", -- Password for encrypting
	boiler_plate_folder = "",
	shorten_output = true,
	line_limit = 20,
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

	vim.api.nvim_create_autocmd("BufWritePost", {
		pattern = "*.cps",
		callback = function()
			local post_processor = vim.fn.expand("%:p")
			if not post_processor:match("%.cps$") then
				return
			end
			local core = require("fusion_post.core")
			core.run_post_processor("saved", M.options)
		end,
	})

	vim.api.nvim_create_user_command("FusionInsert", function()
		local insert_boiler = require("fusion_post.insert_boiler")
		local ui = require("fusion_post.ui")
		ui.select_boiler_plate(M.options.boiler_plate_folder, function(selected_file)
			insert_boiler.insert_boiler_plate(selected_file)
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

	-- Register TypeScript LSP (ts_ls) for Fusion 360 Post Processors
	local lspconfig = require("lspconfig")

	lspconfig.ts_ls.setup({
		root_dir = function(fname)
			return require("lspconfig.util").find_git_ancestor(fname) or vim.fn.getcwd() -- Ensures LSP loads in the correct workspace
		end,
		settings = {
			javascript = {
				suggest = {
					completeFunctionCalls = true,
				},
				implicitProjectConfig = {
					checkJs = true,
				},
			},
		},
		init_options = {
			preferences = {
				includeCompletionsForImportStatements = true,
			},
		},
	})

	-- Auto-load globals.d.ts for Fusion 360
	vim.api.nvim_create_autocmd("BufRead", {
		pattern = "*.cps",
		callback = function()
			local ts_settings = vim.lsp.get_active_clients({ name = "ts_ls" })[1]
			if ts_settings then
				ts_settings.config.settings.typescript = ts_settings.config.settings.typescript or {}
				ts_settings.config.settings.typescript.types = { globals_path }
				vim.lsp.buf_notify(0, "workspace/didChangeConfiguration", { settings = ts_settings.config.settings })
			end
		end,
	})
end

return M
