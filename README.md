# fusion-post-nvim

A NeoVim plugin for developing and testing Fusion post-processors.

## Installation

### LazyVim

Add to your `~/.config/nvim/lua/plugins/fusion-post.lua`:

```lua
return {
  {
    "DrPhilDSI/fusion-post-nvim",
	dependencies = { "wilberter/gcode.vim" },

	opts = {
      post_exe_path = "C:/Program Files/Autodesk/Fusion 360/post.exe", -- Windows
      -- post_exe_path = "/Applications/Autodesk Fusion 360.app/Contents/Libraries/post.exe", -- macOS
      cnc_folder = "~/Fusion 360/NC Programs/",
      password = "", -- For encryption/decryption
      boiler_plate_folder = "", -- For :FusionInsert
      shorten_output = false,
      line_limit = 20,
      call_stack_key = "gK",
      show_inline_hints = true,
      inline_hints_filter = {
        writeBlock = true,
        writeLn = true,
        writeComment = true,
        onLinear = true,
        onLinear5D = true,
        onRapid = true,
        onRapid5D = true,
        onCircular = true,
      },
      call_stack_filter = {},
    },
  },
}
```

### Manual Installation

Clone the repo and add to your `init.lua`:

```bash
git clone https://github.com/DrPhilDSI/fusion-post-nvim.git ~/.config/nvim/lua/fusion-post-nvim
```

```lua
require("fusion-post-nvim").setup({
  post_exe_path = "C:/Program Files/Autodesk/Fusion 360/post.exe",
})
```

## Configuration

The only required option is `post_exe_path` - point it to your Fusion `post.exe`:

- `cnc_folder` - Where your test `.cnc` files live (default: `"~/Fusion 360/NC Programs/"`)
- `password` - For encrypting/decrypting post-processors
- `boiler_plate_folder` - Template files for `:FusionInsert`
- `shorten_output` - Show fewer lines in preview (default: `false`)
- `line_limit` - How many lines when shortened (default: `20`)
- `call_stack_key` - Keybinding to show call stack popup (default: `"gK"`)
- `show_inline_hints` - Show inline hints in NC preview (default: `true`)
- `inline_hints_filter` - Functions to exclude from inline hints (table, default: see below)
- `call_stack_filter` - Functions to exclude from call stack popup (table, default: `{}`)

### Default Filters

By default, inline hints exclude these common functions:

```lua
inline_hints_filter = {
  writeBlock = true,
  writeLn = true,
  writeComment = true,
  onLinear = true,
  onLinear5D = true,
  onRapid = true,
  onRapid5D = true,
  onCircular = true,
}
```

The call stack popup shows all functions by default (empty filter).

### Customizing Filters

```lua
-- Disable inline hints completely
require("fusion_post").setup({
  show_inline_hints = false,
})

-- Custom inline hints filter
require("fusion_post").setup({
  inline_hints_filter = { onLinear = true, onRapid = true, writeBlock = true },
})

-- Filter functions from the call stack popup
require("fusion_post").setup({
  call_stack_filter = { onLinear = true, writeBlock = true },
})
```

## Commands

### `:FusionPost` / `:FusionDump`

Run the post-processor on a selected `.cnc` file. Opens a picker to choose your test file, then processes it and shows the output in a preview window. `:FusionDump` uses a special debug post-processor that shows everything.

Once you've selected a file, it's remembered. Save your `.cps` file and it'll automatically run with that test file.

### `:FusionProperties`

Opens an interactive UI to manage post-processor properties. Changes persist for the current session and are used when running the post-processor.

### `:FusionInsert`

Inserts boilerplate code from a template file. Configure `boiler_plate_folder` to use this.

### `:FusionDeploy`

Creates a date-stamped copy of your post-processor (e.g., `my_post 2024-01-15.cps`). Handy for versioning.

### `:FusionEncrypt` / `:FusionDecrypt`

Encrypt or decrypt your post-processor. Requires `password` to be set in config.

### `:FusionAutoComplete`

Adds a TypeScript reference for Fusion 360 globals at the top of your file. Only adds it if it's not already there.

### `:FusionDebugSelectedLines`

Debug selected lines in your post-processor. Select lines in visual mode, then run this command. The plugin will:
1. Create a temporary .cps file that adds `writeln()` statements after each selected line
2. Open the file picker to select a test .cnc file
3. Run the temp post-processor with debug output
4. Show the results in a preview window
5. Delete the temp file after execution

The debug output will show variable values for lines like:
- `local x = 10;` → outputs `DEBUG: x = 10`
- `var y = x * 2;` → outputs `DEBUG: y = 20`
- `writeBlock("G1 X" + x);` → outputs `DEBUG: writeBlock: G1 X10`

This command works best with visual line selection (`V`).

### `:FusionPostConfig [path]`

Check or update your `post.exe` path. Run without arguments to see current path, or with a path to update it.

### `:FusionLog`

View the plugin's activity log. Useful for debugging.

### `:FusionSettings`

Change plugin settings like `Program name` `shorten_output` and `line_limit` on the fly.

## Usage

Open a `.cps` file, run `:FusionPost` to pick a test file, then just edit and save. The post-processor runs automatically on each save. Use `:FusionProperties` to tweak properties, `:FusionDeploy` to create versioned copies, and `:FusionEncrypt` if you need to protect your code.

### Call Stack Navigation

When viewing the NC output preview, you can press the `call_stack_key` (default: `gK`) on any line with a hint to see the full call stack. A popup menu will show all the functions in the call stack (from top-level to the immediate caller). Select any function to jump directly to that line in your `.cps` file.

This helps you understand the execution flow and quickly navigate to the relevant code when debugging your post-processor.

## Troubleshooting

**"post.exe path is invalid"** - Make sure you're using the full absolute path to `post.exe`.

**"No files found"** - Check that your `cnc_folder` path is correct and contains `.cnc` or `.js` files.

**Auto-run not working** - Make sure you've run `:FusionPost` at least once to select a test file. Check `:FusionLog` for errors.

**Preview not opening** - Check `:FusionLog` to see if the post-processor ran successfully.

**Nothing happens on save** - Ensure you're editing a `.cps` file and that you have added `.cps` to your filetype settings if needed.
```lua
    vim.filetype.add({
        extension = {
            cps = "javascript",
        },
    })
```

## Keybindings

- Some sample keybindings to run commands

```lua
		vim.keymap.set("n", "<leader>df", ":FusionPost<CR>", { desc = "Debug Fusion Post" })

        vim.keymap.set("n", "<leader>pf", ":FusionProperties<CR>", { desc = "Change post properties for debug" })

		-- Debug selected lines (visual mode)
		vim.keymap.set("v", "<leader>d", ":FusionDebugSelectedLines<CR>", { desc = "Debug selected lines" })
```
