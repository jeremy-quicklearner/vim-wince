" Wince Mappings - Autoloaded portion

" Avoid loading twice
if exists('s:loaded')
    finish
endif
let s:loaded = 0

" See wince.vim
let s:Log = jer_log#LogFunctions('wince-mappings')

" This function is a helper for group definitions which want to define
" mappings for adding, removing, showing, hiding, and jumping to their groups
function! wince_map#MapUserOp(lhs, rhs)
    call s:Log.CFG('Map ', a:lhs, ' to ', a:rhs)
    for [mapchr, modechr] in [['n', 'n'], ['x', 'v'], ['s', 's'], ['t', 't']]
        let mapcmd = mapchr .  'noremap <silent> ' .  a:lhs . ' ' .
       \    '<c-w>:<c-u>call jer_mode#Detect("' . modechr .'")<cr>' .
       \    '<c-w>:<c-u>let g:wince_map_mode=jer_mode#Retrieve()<cr>' .
       \    '<c-w>:<c-u>' . a:rhs . '<cr>' .
       \    '<c-w>:<c-u>call jer_mode#ForcePreserve(g:wince_map_mode)<cr>' .
       \    '<c-w>:<c-u>call jer_mode#Restore()<cr>'
        execute mapcmd
    endfor
endfunction

" Process v:count and v:count1 into a single count
function! wince_map#ProcessCounts(allow0)
    call s:Log.DBG('wince_map#ProcessCounts ' , a:allow0)
    " v:count and v:count1 default to different values when no count is
    " provided
    if v:count !=# v:count1
        call s:Log.DBG('Count not set')
        return ''
    endif

    if !a:allow0 && v:count <= 0
        call s:Log.DBG('Count 0 not allowed. Substituting 1.')
        return 1
    endif

    return v:count
endfunction

