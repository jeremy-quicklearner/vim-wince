" Wince dictates that some windows have non-default status lines. It defers to
" the default by returning an empty string that won't supersede the global
" default statusline
let s:Win = jer_win#WinFunctions()

" TODO: Someone may want different supwins to have different statuslines.
" Store supwin statuslines in the model and write a setter in the user
" operations
function! s:CorrectAllStatusLines()
    if s:Win.legacy
        noautocmd silent call jer_util#WinDo('',
       \    'let &l:statusline = wince_user#NonDefaultStatusLine()'
       \)
    else
        for winid in wince_state#GetWinidsByCurrentTab()
            call setwinvar(winid, '&statusline',
           \    wince_model#StatusLineByInfo(
           \        wince_model#InfoById(winid)
           \    )
           \)
        endfor
    endif
endfunction

" Register the above function as a one-time post-event callback
function! s:RegisterCorrectStatusLines()
    call jer_pec#Register(function('s:CorrectAllStatusLines'), [], 0, 1, 0, 0, 0)
endfunction

augroup WinceStatusLine
    autocmd!
    
    " Quickfix and Terminal windows have different statuslines that Vim sets
    " when they open or buffers enter them, so overwrite all non-default
    " statuslines after that happens
    autocmd BufWinEnter * call s:RegisterCorrectStatusLines()

    " Netrw windows also have local statuslines that get set by some autocmd
    " someplace in the Vim runtime. Overwrite them as well.
    autocmd FileType netrw call s:RegisterCorrectStatusLines()
augroup END
