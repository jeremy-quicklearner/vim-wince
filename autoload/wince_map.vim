" Wince Mappings - Autoloaded portion

" Avoid loading twice
if exists('s:loaded')
    finish
endif
let s:loaded = 0

" See wince.vim
let s:Log = jer_log#LogFunctions('wince-mappings')

function! wince_map#DoAndRestoreMode(rhs, modechr)
    call jer_mode#Detect(a:modechr)
    let g:wince_map_mode = jer_mode#Retrieve()
    execute a:rhs
    call jer_mode#ForcePreserve(g:wince_map_mode)
    call jer_mode#Restore()
endfunction

" This function is a helper for group definitions which want to define
" mappings for adding, removing, showing, hiding, and jumping to their groups
function! wince_map#MapUserOp(lhs, rhs)
    call s:Log.CFG('Map ', a:lhs, ' to ', a:rhs)
    let mapmodes = [['n', 'n'], ['x', 'v'], ['s', 's']]
    for [mapchr, modechr] in mapmodes
        let mapcmd = mapchr .  'noremap <silent> ' . a:lhs . ' ' .
       \    ':<c-u>call wince_map#DoAndRestoreMode(''' .
       \        a:rhs .
       \    ''', ''' .
       \        modechr .
       \    ''')<cr>'
        execute mapcmd
    endfor

    if exists(':tnoremap')
        execute 'tnoremap <silent> ' . a:lhs . ' ' .
       \    '<c-w>:<c-u>call wince_map#DoAndRestoreMode(''' .
       \        a:rhs .
       \    ''', ''t'')<cr>'
    endif
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

