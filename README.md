
# sc-im.nvim - Edit Markdown tables in sc-im

`sc-im.nvim` is a Neovim plugin written in Lua designed to seamlessly integrate with [sc-im](https://github.com/andmarti1424/sc-im), a terminal spreadsheet calculator, to edit Markdown tables. 
Its core feature is that it can generate and link the native sc-im file to the Markdown table. That allows to retain formatting and formulas upon reopening (see Options). The plugin also propagates simple changes to the Markdown table back to the sc-im table without overwriting formulas.


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
when true, a link to the sc file (sc-ims native file format) is automatically added to retain formatting and formulas upon reopening. The format of the link is controlled with `link_fmt`. The link name is the table sheet that the Markdown table is referring to.
When this option is enabled the plugin will generate a file with a random file name in the same file location as your markdown file you are editing in nvim and links it to your document. You can use the rename() function to change the name.

### `update_sc_from_md`
if set to true, when opening the table in sc-im, changes in the Markdown table are propagated to the sc-im table. Changes are applied sequentially via an sc-im script, so the changes can be undone with the sc-im undo command. Formulas are not touched, so changes to cells in Markdown that are formulas in sc-im are ignored

### `link_fmt`

1 - Adds the table link as comment. Not visible when rendering. (default)
2 - Adds the table link as Markdown link. Shows in the rendered Markdown file but enables link detection and updates in external tools

### `split`

Defines the split direction when opening `sc-im`. Default is `floating`. Can be `floating`, `horizontal` or `vertical`
### Vimscript Configuration
```vim
lua << EOF
require'sc-im'.setup({
    ft = 'scim',
    include_sc_file = true,
    update_sc_from_md = true,
    link_fmt = 1,
    split = "floating",
    float_config = {
        height = 0.9,
        width = 0.9,
        style = 'minimal',
        border = 'single',
        hl = 'Normal',
        blend = 0
    }
})
EOF
```
### Lua Configuration

```lua
require('sc-im').setup({
    ft = 'scim',
    include_sc_file = true,
    update_sc_from_md = true,
    link_fmt = 1,
    split = "floating",
    float_config = {
        height = 0.9,
        width = 0.9,
        style = 'minimal',
        border = 'single',
        hl = 'Normal',
        blend = 0
    }
})
```


## Functions 

- `open_in_scim(add_link)` - Opens the table under the cursor in sc-im. Creates a new table when the cursor is not in a markdown table. The optional add_link can override the default setting `include_sc_file`. If `add_link` is false, the sc file is not linked to the table resulting in a plain Markdown table. If `add_link` is true, the sc file is linked to the table.

- `rename(new_name)` - Renames the attached sc file if present. If new_name is not given, prompts for a new name.

- `toggle()` - Toggle the sc link format between sc link comment (`<!--[table link](file.sc)-->`) and markdown link (`[table link](file.sc)`)

- `update(save_sc)` - Updates the Markdown table by passing changes into sc-im, recalculating and generating the Markdown table, replacing the old one. If `save_sc` is true, the sc file is updated also. Beware, that upon saving changes to the sc file, you cannot undo changes. If you just open the Markdown table using `open_in_scim`, and `update_sc_from_md` is true, you can still undo the changes while editing using the undo function of sc-im.

- `close()` - Closes sc-im without saving. When using a keymap, the keymap needs to be set for terminal `t` mode. See `Keybindings` below

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
            l = { ":lua require('sc-im').open_in_scim(true)<cr>", "Open table in sc-im" },
            p = { ":lua require('sc-im').open_in_scim(false)<cr>", "Open plain table in sc-im" },
            t = { ":lua require('sc-im').toggle(true)<cr>", "Toggle sc-im link format" },
            r = { ":lua require('sc-im').rename()<cr>", "Rename linked sc-im file" },
            u = { ":lua require('sc-im').update()<cr>", "Recalculate Markdown table" },
            U = { ":lua require('sc-im').update(true)<cr>", "Update sc file and Markdown table" },
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
