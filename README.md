# fusion-post-nvim

A NeoVim plugin for developing and testing Fusion post-processors.

## Installation

### LazyVim

Add to your `~/.config/nvim/lua/plugins/fusion-post.lua`:

```lua
return {
  {
    "DrPhilDSI/fusion-post-nvim",
	dependencies = { "wilriker/gcode.vim" },

opts = {
      post_exe_path = "C:/Program Files/Autodesk/Fusion 360/post.exe", -- Windows
      -- post_exe_path = "/Applications/Autodesk Fusion 360.app/Contents/Libraries/post.exe", -- macOS
      cnc_folder = "~/Fusion 360/NC Programs/",
      password = "", -- For encryption/decryption
      boiler_plate_folder = "", -- For :FusionInsert
      shorten_output = false,
      line_limit = 20,
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

### `:FusionPostConfig [path]`

Check or update your `post.exe` path. Run without arguments to see current path, or with a path to update it.

### `:FusionLog`

View the plugin's activity log. Useful for debugging.

### `:FusionSettings`

Change plugin settings like `Program name` `shorten_output` and `line_limit` on the fly.

## Usage

Open a `.cps` file, run `:FusionPost` to pick a test file, then just edit and save. The post-processor runs automatically on each save. Use `:FusionProperties` to tweak properties, `:FusionDeploy` to create versioned copies, and `:FusionEncrypt` if you need to protect your code.

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
```
