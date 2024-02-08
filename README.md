
# sc-im.nvim - Edit Markdown tables in sc-im

`sc-im.nvim` is a Neovim plugin written in Lua designed to seamlessly integrate with [sc-im](https://github.com/andmarti1424/sc-im), a terminal spreadsheet calculator, to edit Markdown tables. 
Its core feature is that it can generate and link the native sc file to the Markdown table. That allows to retain formatting and formulas upon reopening (see Options).


![table editing](./table.svg)
## Features

- Create or open markdown tables in `sc-im` using a split terminal buffer (can be configured to open in a vertical or horizontal split).
- Optionally generates and links the `.sc` file (native sc-im file format) so that formatting and formulas are retained below the table in the markdown file.


## Installation

First make sure that you have installed [sc-im](https://github.com/andmarti1424/sc-im) and it is available in your path.

You can install `sc-im.nvim` using various plugin managers for Neovim. Below are examples for some common plugin managers:

### Using [vim-plug](https://github.com/junegunn/vim-plug)

Add the following line to your `init.vim`:

```vim
Plug 'DAmesberger/sc-im.nvim'
```

Then run `:PlugInstall` in Neovim.

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

Add the following Lua code to your Neovim configuration:

```lua
use 'DAmesberger/sc-im.nvim'
```

### Using [dein.vim](https://github.com/Shougo/dein.vim)

Add the following line to your `init.vim`:

```vim
call dein#add('DAmesberger/sc-im.nvim')
```

### Using [Pathogen](https://github.com/tpope/vim-pathogen)

Clone the repository into your `~/.config/nvim/bundle` directory:

```sh
cd ~/.config/nvim/bundle
git clone https://github.com/DAmesberger/sc-im.nvim.git
```

## Configuration

`sc-im.nvim` can be configured in your `init.vim` or Lua configuration file. Here is an example:

## Options
### `include_sc_file` 
can be set to true to automatically add a link to the sc file (sc-ims native file format) to retain formatting and formulas upon reopening.
When this option is enabled the plugin will generate a file with a random file name in the same file location as your markdown file you are editing in nvim and links it to your document. You can use the rename() function to change the name.

### `link_name`

Link text used when `include_sc_file` is enabled. Defaults to `table link`

### `link_fmt`

1 - Adds the table link as comment. Not visible when rendering. (default)
2 - Adds the table link as Markdown link. Shows in the rendered Markdown file but enables link detection and updates in external tools

### `split`

Defines the split direction when opening `sc-im`. Default is `floating`. Can be `floating`, `horizontal` or `vertical`
### Vimscript Configuration
```vim
lua << EOF
require'sc-im'.setup({
    include_sc_file = true,     -- Whether to include .sc file links, default is false
    link_name = "table link",
    link_fmt = 1,
    split = "floating",
    float_config = {
        width = 0.8,
        height = 0.8,
        style = 'minimal',
        border = 'single',
    }
})
EOF
```
### Lua Configuration

```lua
require('sc-im').setup({
    include_sc_file = true,     -- Whether to include .sc file links, default is false
    link_name = "table link",
    link_fmt = 1,
    split = "floating",
    float_config = {
        width = 0.8,
        height = 0.8,
        style = 'minimal',
        border = 'single',
    }
})
```


## Functions 

- `open_in_scim(add_link)` - Opens the table under the cursor in sc-im. Creates a new table when the cursor is not in a markdown table. The optional add_link can override the default setting `include_sc_file`. If `add_link` is false, the sc file is not linked to the table resulting in a plain Markdown table. If `add_link` is true, the sc file is linked to the table.

- `rename(new_name)` - Renames the attached sc file if present. If new_name is not given, prompts for a new name.

- `toggle()` - Toggle the sc link format between sc link comment (`<!--[table link](file.sc)-->`) and markdown link (`[table link](file.sc)`)

### Keybindings

Example keybindings, <leader>sc to open a table in sc-im, <leader>x to close sc-im without saving

### Vimscript
```vim
nnoremap <leader>sc :lua require'sc-im'.open_in_scim()<CR>
tnoremap <leader>x <C-\><C-n>:lua require('sc-im').close()<CR>
```
### Lua

``` lua
vim.api.nvim_set_keymap('n', '<leader>sc', ":lua require'sc-im'.open_in_scim()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap('t', '<leader>x', [[<C-\><C-n>:lua require('sc-im').close()<CR>]], { noremap = true, silent = true })
```

### [which-key](https://github.com/folke/which-key.nvim)
``` lua
require("which-key").register({
    s = {  
        name = "sc-im",
        c = { ":lua require('sc-im').open_in_scim()<cr>", "Open table in sc-im" },
        p = { ":lua require('sc-im').open_in_scim(false)<cr>", "Open plain table in sc-im" },
        t = { ":lua require('sc-im').toggle(true)<cr>", "Toggle sc-im link format" },
        r = { ":lua require('sc-im').rename()<cr>", "Rename linked sc-im file" },
    }
}, { prefix = "<leader>" })

vim.api.nvim_set_keymap('t', '<leader>x', [[<C-\><C-n>:lua require('sc-im').close()<CR>]],
    { noremap = true, silent = true })
```

## Examples

### Opening an Markdown Table

1. In a markdown file, move the cursor over a line containing an `Markdown` table.
2. Press the key mapping (e.g., `<leader>sc`) or enter the command directly (`:lua require'sc-im'.open_in_scim()`) to open the table in `sc-im`.

### Inserting a New Table

1. Place the cursor at the desired location for a new table.
2. Press the key mapping for inserting a new table (e.g., `<leader>nc`).

### Using include_sc_file with Joplin Notes
If you use Neovim as your external editor, there is currently no way of letting Joplin automatically know that you created a link as far as I know. So in order to have the .sc file in your notes, you have to attach the file manually to the Joplin note. This creates a link. Replace the link created by sc-im.nvim with the new one, and remove the file of the old link.
You only have to do this once per table, after that the sc file will be synced and you can edit the table normally as expected.


## Contribution

Contributions to `sc-im.nvim` are welcome. Open an issue or pull request on the repository for any bugs, suggestions, or improvements.
