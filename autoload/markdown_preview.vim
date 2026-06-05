" Autoload functions for Vim Markdown Preview plugin
" Maintainer: Antigravity

if exists('g:loaded_markdown_preview_autoload')
  finish
endif
let g:loaded_markdown_preview_autoload = 1

" Default configurations
let s:default_command = ['glow', '-p']
let s:default_split = 'vertical botright new'
let s:default_auto_refresh = 1

function! s:GetConfig(name, default) abort
  return get(g:, a:name, a:default)
endfunction

function! s:GetCacheDir() abort
  let l:dir = expand('~/.markdown_preview_cache')
  if !isdirectory(l:dir)
    call mkdir(l:dir, 'p', 0700)
  endif
  return l:dir
endfunction

function! s:Log(msg) abort
  let l:log_file = s:GetCacheDir() . '/debug.log'
  call writefile([strftime('%Y-%m-%d %H:%M:%S') . ' ' . a:msg], l:log_file, 'a')
endfunction

function! s:GetSanitizedSplit() abort
  let l:split_cmd = s:GetConfig('markdown_preview_split', s:default_split)
  let l:allowed = ['vertical', 'botright', 'topleft', 'aboveleft', 'belowright', 'new', 'split', 'vnew', 'vsplit', ' ']
  let l:words = split(l:split_cmd)
  let l:sanitized = []
  for l:word in l:words
    if index(l:allowed, l:word) != -1
      call add(l:sanitized, l:word)
    endif
  endfor
  if empty(l:sanitized)
    return s:default_split
  endif
  return join(l:sanitized, ' ')
endfunction

function! s:GetCommandList(cache_file) abort
  let l:cmd = s:GetConfig('markdown_preview_command', s:default_command)
  
  if type(l:cmd) == v:t_string
    let l:cmd_list = split(l:cmd)
  elseif type(l:cmd) == v:t_list
    let l:cmd_list = copy(l:cmd)
  else
    return []
  endif

  if empty(l:cmd_list)
    return []
  endif

  " Fallback for snap-installed glow if not in PATH
  if l:cmd_list[0] ==# 'glow' && !executable('glow') && executable('/snap/bin/glow')
    let l:cmd_list[0] = '/snap/bin/glow'
  endif
  
  call add(l:cmd_list, a:cache_file)
  return l:cmd_list
endfunction

" Toggle preview window
function! markdown_preview#Toggle() abort
  call s:Log('Toggle called')
  if &filetype !=# 'markdown'
    echoerr 'MarkdownPreview: Not a markdown file'
    return
  endif

  let l:preview_buf = get(b:, 'markdown_preview_buf', 0)
  if l:preview_buf > 0 && bufexists(l:preview_buf)
    let l:win = bufwinnr(l:preview_buf)
    if l:win != -1
      " Preview is open, so close it
      execute l:win . 'wincmd c'
      return
    endif
  endif

  " Preview is not open, open it
  call markdown_preview#Open()
endfunction

" Open preview window
function! markdown_preview#Open() abort
  let l:src_buf = bufnr('%')
  call s:Log('Open called for src_buf=' . l:src_buf)
  if &filetype !=# 'markdown'
    echoerr 'MarkdownPreview: Not a markdown file'
    return
  endif

  let l:cache_file = s:GetCacheDir() . '/preview_' . l:src_buf . '.md'

  " Write current buffer contents to the cache file
  if writefile(getline(1, '$'), l:cache_file) != 0
    echoerr 'MarkdownPreview: Failed to write temporary cache file'
    return
  endif
  call s:Log('Open: Wrote cache file ' . l:cache_file)

  let l:cmd_list = s:GetCommandList(l:cache_file)
  if empty(l:cmd_list)
    call delete(l:cache_file)
    echoerr 'MarkdownPreview: g:markdown_preview_command must be a string or a list'
    return
  endif

  if !executable(l:cmd_list[0])
    call delete(l:cache_file)
    echoerr 'MarkdownPreview: Command not executable: ' . l:cmd_list[0]
    return
  endif

  let l:split_cmd = s:GetSanitizedSplit()
  execute l:split_cmd

  " Start terminal in current window
  let l:options = {}
  let l:options.curwin = 1
  let l:options.term_kill = 'kill'
  let l:options.term_name = '[Markdown Preview]'
  let l:options.exit_cb = function('s:OnPreviewExit', [l:src_buf])

  let l:preview_buf = term_start(l:cmd_list, l:options)
  if l:preview_buf == 0
    call delete(l:cache_file)
    echoerr 'MarkdownPreview: Failed to start terminal'
    return
  endif
  call s:Log('Open: Started terminal buffer=' . l:preview_buf)

  " Link the buffers and store cache path
  let b:markdown_source_buf = l:src_buf
  let b:markdown_preview_cache = l:cache_file
  call setbufvar(l:src_buf, 'markdown_preview_buf', l:preview_buf)

  augroup MarkdownPreviewTerm
    autocmd! * <buffer>
    autocmd BufWipeout <buffer> call s:OnPreviewBufWipeout()
  augroup END

  let l:src_win = bufwinnr(l:src_buf)
  if l:src_win != -1
    execute l:src_win . 'wincmd w'
  endif
endfunction

" Refresh preview window
function! markdown_preview#Refresh() abort
  let l:preview_buf = get(b:, 'markdown_preview_buf', 0)
  let l:src_buf = bufnr('%')
  call s:Log('Refresh called. src_buf=' . l:src_buf . ' preview_buf=' . l:preview_buf)
  if l:preview_buf <= 0 || !bufexists(l:preview_buf)
    call s:Log('Refresh: preview buf not valid, aborting')
    return
  endif

  let l:win = bufwinnr(l:preview_buf)
  if l:win == -1
    call s:Log('Refresh: preview window not visible, aborting')
    return
  endif

  let l:cache_file = s:GetCacheDir() . '/preview_' . l:src_buf . '.md'

  if writefile(getline(1, '$'), l:cache_file) != 0
    echoerr 'MarkdownPreview: Failed to update temporary cache file'
    return
  endif
  call s:Log('Refresh: Wrote cache file ' . l:cache_file)

  let l:src_win_id = win_getid()

  execute l:win . 'wincmd w'
  let l:old_win_id = win_getid()
  let l:old_buf = bufnr('%')
  call s:Log('Refresh: switched to preview window. old_buf=' . l:old_buf)

  let l:split_cmd = s:GetSanitizedSplit()
  let l:split_dir = (l:split_cmd =~? 'vertical' ? 'vertical' : '')
  
  execute l:split_dir . ' rightbelow split'
  call s:Log('Refresh: created temporary split')

  let l:cmd_list = s:GetCommandList(l:cache_file)
  if empty(l:cmd_list)
    call s:Log('Refresh: failed to get command list, closing split')
    close
    return
  endif

  let l:options = {}
  let l:options.curwin = 1
  let l:options.term_kill = 'kill'
  let l:options.term_name = '[Markdown Preview]'
  let l:options.exit_cb = function('s:OnPreviewExit', [l:src_buf])

  let l:new_buf = term_start(l:cmd_list, l:options)
  if l:new_buf > 0
    call s:Log('Refresh: started new terminal buffer=' . l:new_buf)
    let b:markdown_source_buf = l:src_buf
    let b:markdown_preview_cache = l:cache_file
    call setbufvar(l:src_buf, 'markdown_preview_buf', l:new_buf)
    
    augroup MarkdownPreviewTerm
      autocmd! * <buffer>
      autocmd BufWipeout <buffer> call s:OnPreviewBufWipeout()
    augroup END

    if win_gotoid(l:old_win_id)
      call s:Log('Refresh: closing old window for old_buf=' . l:old_buf)
      " We don't wipeout here to avoid triggering s:OnPreviewBufWipeout 
      " which would delete the cache file that our new term might still need.
      " The old buffer will be cleaned up when the user closes it or Vim exits.
      close
    endif
  else
    call s:Log('Refresh: failed to start new terminal, closing split')
    close
  endif

  call win_gotoid(l:src_win_id)
endfunction

" Clean up reference in source buffer and close window if successful
function! s:OnPreviewExit(src_buf, job, status) abort
  let l:buf = s:FindBufByJob(a:job)
  call s:Log('OnPreviewExit: src_buf=' . a:src_buf . ' job_status=' . a:status . ' job_buf=' . l:buf)

  if bufexists(a:src_buf)
    let l:active_preview = getbufvar(a:src_buf, 'markdown_preview_buf', 0)
    call s:Log('OnPreviewExit: active_preview=' . l:active_preview)
    if l:active_preview != l:buf
      call s:Log('OnPreviewExit: stale preview, ignoring exit')
      return
    endif
    call setbufvar(a:src_buf, 'markdown_preview_buf', 0)
  endif

  if l:buf > 0
    let l:cache_file = getbufvar(l:buf, 'markdown_preview_cache', '')
    if !empty(l:cache_file) && filereadable(l:cache_file)
      call s:Log('OnPreviewExit: deleting cache_file=' . l:cache_file)
      call delete(l:cache_file)
    endif

    if a:status == 0
      call s:Log('OnPreviewExit: closing window for buffer=' . l:buf)
      execute 'silent! bwipeout! ' . l:buf
    else
      echohl ErrorMsg
      echomsg 'MarkdownPreview: Process exited with error code ' . a:status
      echohl None
    endif
  endif
endfunction

" Clean up reference in source buffer if preview buffer is manually wiped out
function! s:OnPreviewBufWipeout() abort
  let l:src_buf = get(b:, 'markdown_source_buf', 0)
  let l:my_buf = bufnr('%')
  call s:Log('OnPreviewBufWipeout: current_buf=' . l:my_buf . ' src_buf=' . l:src_buf)
  if l:src_buf > 0 && bufexists(l:src_buf)
    let l:active_preview = getbufvar(l:src_buf, 'markdown_preview_buf', 0)
    call s:Log('OnPreviewBufWipeout: active_preview=' . l:active_preview)
    if l:active_preview == l:my_buf
      let l:cache_file = get(b:, 'markdown_preview_cache', '')
      if !empty(l:cache_file) && filereadable(l:cache_file)
        call s:Log('OnPreviewBufWipeout: deleting cache_file=' . l:cache_file)
        call delete(l:cache_file)
      endif
      call setbufvar(l:src_buf, 'markdown_preview_buf', 0)
    else
      call s:Log('OnPreviewBufWipeout: not active preview, skipping deletion')
    endif
  else
    let l:cache_file = get(b:, 'markdown_preview_cache', '')
    if !empty(l:cache_file) && filereadable(l:cache_file)
      call s:Log('OnPreviewBufWipeout: src_buf invalid, deleting cache_file=' . l:cache_file)
      call delete(l:cache_file)
    endif
  endif
endfunction

function! s:FindBufByJob(job) abort
  for l:buf in filter(range(1, bufnr('$')), 'bufexists(v:val)')
    if term_getjob(l:buf) == a:job
      return l:buf
    endif
  endfor
  return 0
endfunction
