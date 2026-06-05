" Vim Markdown Preview plugin
" Maintainer: Antigravity

if exists('g:loaded_markdown_preview')
  finish
endif
let g:loaded_markdown_preview = 1

" User commands
command! -nargs=0 MarkdownPreview call markdown_preview#Open()
command! -nargs=0 MarkdownPreviewRefresh call markdown_preview#Refresh()
command! -nargs=0 MarkdownPreviewToggle call markdown_preview#Toggle()

" Autocommands for auto-refresh
augroup MarkdownPreviewAutoRefresh
  autocmd!
  autocmd BufWritePost *.md,*.markdown if get(g:, 'markdown_preview_auto_refresh', 1) | call markdown_preview#Refresh() | endif
augroup END

" Default mappings (if not disabled by user)
if !get(g:, 'markdown_preview_no_mappings', 0)
  nnoremap <silent> <Plug>MarkdownPreviewToggle :MarkdownPreviewToggle<CR>
  
  " Bind to <Leader>mp by default if not mapped
  if !hasmapto('<Plug>MarkdownPreviewToggle', 'n') && maparg('<Leader>mp', 'n') ==# ''
    nmap <unique> <Leader>mp <Plug>MarkdownPreviewToggle
  endif
endif
