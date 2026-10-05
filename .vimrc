syntax enable

set expandtab
set shiftwidth=2
set softtabstop=2

filetype plugin indent on

set cursorline
set mouse=a

set guifont=Menlo:h14
set autoindent
set tabstop=4
syntax on

set number

imap jj <Esc>

set incsearch
set hlsearch
nnoremap ,<space> :nohlsearch<CR>

" Highlight the line number every 10 lines above and below the cursor
highlight TenLineNr ctermfg=green cterm=bold guifg=#98c379 gui=bold
set signcolumn=number
call sign_define('TenMark', {'numhl': 'TenLineNr'})
function! s:MarkTens() abort
  call sign_unplace('tens', {'buffer': bufnr()})
  let cur = line('.')
  for lnum in range(cur - 100, cur + 100, 10)
    if lnum != cur && lnum >= 1 && lnum <= line('$')
      call sign_place(0, 'tens', 'TenMark', bufnr(), {'lnum': lnum})
    endif
  endfor
endfunction
augroup tens
  autocmd!
  autocmd CursorMoved,BufEnter * call s:MarkTens()
augroup END

" :Ask <task> asks Claude for a Vim command and puts it on the command line
" without running it. Works on a visual selection too (:'<,'>Ask ...).
let s:ask_prompt = join([
      \ 'You suggest Vim 9 commands. The user describes an editing task.',
      \ 'Reply with exactly two lines and nothing else, no markdown or backticks.',
      \ "Line 1: the command. Prefer one Ex command starting with ':'.",
      \ 'If lines are selected, an Ex command must start with the given range.',
      \ "If Normal-mode keys fit better, give the keys with no leading ':'.",
      \ 'Line 2: a short explanation of how the command works.'])
function! s:Ask(task, range, line1, line2) abort
  let context = 'Filetype: ' . (empty(&filetype) ? 'none' : &filetype) . "\n"
  if a:range > 0
    let visual = a:line1 == line("'<") && a:line2 == line("'>")
    let range = visual ? "'<,'>" : a:line1 . ',' . a:line2
    let context .= 'Range :' . range . ". The user has these lines selected:\n"
          \ . join(getline(a:line1, a:line2), "\n")
  else
    let context .= "No selection. Current line:\n" . getline('.')
  endif
  echo 'Asking Claude...'
  redraw
  let out = systemlist('claude -p --model sonnet --tools "" --setting-sources ""'
        \ . ' --no-session-persistence --system-prompt ' . shellescape(s:ask_prompt),
        \ context . "\n\nTask: " . a:task)
  " Drop keys and mouse events typed while waiting
  while getchar(0) | endwhile
  if v:shell_error || empty(out)
    echohl ErrorMsg | echomsg 'Ask failed: ' . join(out, ' ') | echohl None
    return
  endif
  let cmd = out[0]
  let explanation = join(out[1:], ' ')
  call popup_notification([cmd, explanation], {'time': 10000, 'pos': 'topright', 'line': 1, 'col': &columns})
  if cmd =~# '^:'
    call feedkeys(cmd, 'n')
  endif
endfunction
command! -range -nargs=+ Ask call s:Ask(<q-args>, <range>, <line1>, <line2>)
nnoremap ,a :Ask<Space>
xnoremap ,a :Ask<Space>
