
# sc-im.vim - Neovim Plugin for sc-im Integration

`sc-im.vim` is a Neovim plugin designed to seamlessly integrate `sc-im`, a terminal spreadsheet program to edit Markdown tables. It allows users to edit and insert `sc-im` tables directly within Neovim, enhancing the editing experience for Markdown files or other documents where `sc-im` tables are used.

## Features

- Open existing `sc-im` tables in a split window.
- Insert new `sc-im` tables at the current cursor position.
- Configurable to include `.sc` file links and customizable link text.

## Installation

First make sure that you have installed [sc-im](https://github.com/andmarti1424/sc-im) and it is available in your path.

You can install `sc-im.vim` using various plugin managers for Neovim. Below are examples for some common plugin managers:

### Using [vim-plug](https://github.com/junegunn/vim-plug)

Add the following line to your `init.vim`:

```vim
Plug 'DAmesberger/sc-im.vim'
```

Then run `:PlugInstall` in Neovim.

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

Add the following Lua code to your Neovim configuration:

```lua
use 'DAmesberger/sc-im.vim'
```

### Using [dein.vim](https://github.com/Shougo/dein.vim)

Add the following line to your `init.vim`:

```vim
call dein#add('DAmesberger/sc-im.vim')
```

### Using [Pathogen](https://github.com/tpope/vim-pathogen)

Clone the repository into your `~/.config/nvim/bundle` directory:

```sh
cd ~/.config/nvim/bundle
git clone https://github.com/DAmesberger/sc-im.vim.git
```

## Configuration

`sc-im.vim` can be configured in your `init.vim` or Lua configuration file. Here is an example:

```vim
lua << EOF
require'sc-im'.setup({
    include_sc_file = true,     -- Whether to include .sc file links
    link_text = "Open .sc file" -- Custom text for .sc file links
})
EOF
```

## Usage

### Opening an Existing Markdown Table

Navigate to a line in a markdown file with a Markdown table and use the configured key mapping or command:

```vim
nnoremap <leader>sc :lua require'sc-im'.open_in_scim()<CR>
```


### Overriding Configuration for a Single Use

To override the global configuration for a single use, pass a configuration table to `open_in_scim`:

```vim
:lua require'sc-im'.open_in_scim({include_sc_file = true, link_text = "sc file"})
```

## Examples

### Opening an Markdown Table

1. In a markdown file, move the cursor over a line containing an `Markdown` table.
2. Press the key mapping (e.g., `<leader>sc`) to open the table in `sc-im`.

### Inserting a New Table

1. Place the cursor at the desired location for a new table.
2. Press the key mapping for inserting a new table (e.g., `<leader>nc`).

## Contribution

Contributions to `sc-im.vim` are welcome. Open an issue or pull request on the repository for any bugs, suggestions, or improvements.
