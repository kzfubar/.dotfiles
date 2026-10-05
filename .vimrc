syntax enable

set expandtab
set shiftwidth=2
set softtabstop=2

filetype plugin indent on

set cursorline

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
highlight TenLineNr ctermfg=yellow cterm=bold guifg=#e5c07b gui=bold
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
