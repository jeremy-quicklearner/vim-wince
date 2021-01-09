" Wince dictates that some windows have non-default status lines. It defers to
" the default by returning an empty string that won't supersede the global
" default statusline

" TODO: Someone may want different supwins to have different statuslines.
" Store supwin statuslines in the model and write a setter in the user
" operations
function! s:SetSpecificStatusLine()
    execute 
endfunction

function! s:CorrectAllStatusLines()
    noautocmd silent call jer_util#WinDo('',
   \    'let &l:statusline = wince_user#NonDefaultStatusLine()'
   \)
endfunction

" Register the above function to be called on the next CursorHold event
function! s:RegisterCorrectStatusLines()
    call jer_chc#Register(function('s:CorrectAllStatusLines'), [], 0, 1, 0, 0, 0)
endfunction

augroup WinceStatusLine
    autocmd!
    
    " Quickfix and Terminal windows have different statuslines that Vim sets
    " when they open or buffers enter them, so overwrite all non-default
    " statuslines after that happens
    autocmd BufWinEnter,TerminalOpen * call s:RegisterCorrectStatusLines()

    " Netrw windows also have local statuslines that get set by some autocmd
    " someplace in the Vim runtime. Overwrite them as well.
    autocmd FileType netrw call s:RegisterCorrectStatusLines()
augroup END
