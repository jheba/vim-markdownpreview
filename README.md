# vim-markdown-preview

A clean, zero-dependency Vim plugin to split the window and render/preview Markdown files using the terminal markdown renderer `glow`.

https://github.com/charmbracelet/glow

## Features

- **Split Window Preview**: Automatically splits your window (vertically on the right by default) and renders the Markdown file.
- **Terminal Rendering**: Uses Vim's built-in terminal feature to run `glow` interactively, meaning you can scroll, search, and exit it naturally.
- **Auto-Refresh**: Automatically refreshes the preview when the markdown file is saved.
- **Auto-Cleanup**: Automatically cleans up resources and links when the preview window or Vim is closed.
- **Security & Snap Support**: Uses a secure cache directory (`~/.markdown_preview_cache`) and supports `glow` installed via snap.

## Installation

### Using vim-plug
Add this to your `.vimrc`:
```vim
Plug 'yourusername/vim-markdown-preview'
```

### Manual Installation
Copy the files into your Vim directory:
```bash
cp plugin/* ~/.vim/plugin/
cp autoload/* ~/.vim/autoload/
cp doc/* ~/.vim/doc/
```

## Usage

Open a Markdown file (`.md` or `.markdown`) and run:
- `:MarkdownPreview` to open the preview.
- `:MarkdownPreviewRefresh` to manually refresh the preview.
- `:MarkdownPreviewToggle` to toggle (or map it to a key).

### Default Keymap
By default, `<Leader>mp` is mapped to toggle the preview window.

## Configuration

Add these to your `.vimrc` to customize behavior:

```vim
" Change the split command (default: 'vertical botright new')
let g:markdown_preview_split = 'botright new' " Horizontal bottom split

" Customize the glow command (default: ['glow', '-p'])
let g:markdown_preview_command = ['glow', '-s', 'dark', '-p']

" Disable auto refresh on save (default: 1)
let g:markdown_preview_auto_refresh = 0

" Disable default mappings (default: 0)
let g:markdown_preview_no_mappings = 1
```
