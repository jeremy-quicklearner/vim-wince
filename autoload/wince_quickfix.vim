" Wince Reference Definition for Quickfix uberwin - autoloaded portion

" Avoid loading twice
if exists('s:loaded')
    finish
endif
let s:loaded = 0

let s:Log = jer_log#LogFunctions('wince-quickfix-uberwin')
let s:Win = jer_win#WinFunctions()

" WinceToIdentifyQuickfix relies on getqflist with the winid key. So Vim-native winids
" are required. I see no other way to implement WinceToIdentifyQuickfix.
if s:Win.legacy
    finish
endif

" Callback that opens the quickfix window
function! wince_quickfix#ToOpen()
    call s:Log.INF('wince_quickfix#ToOpen')
    " Fail if the quickfix window is already open
    let qfwinid = get(getqflist({'winid':0}), 'winid', -1)
    if qfwinid
        throw 'Quickfix window already exists with ID ' . qfwinid
    endif

    " This wonkiness with the heights avoids Vim equalizing other windows'
    " sizes
    if g:wince_quickfix_top
        execute 'noautocmd topleft copen ' . g:wince_quickfix_height
    else
        noautocmd botright copen 1
    endif

    execute 'noautocmd resize ' . g:wince_quickfix_height

    " Since we opened the quickfix window with noautocmd, &syntax was set but
    " the syntax wasn't loaded. Vim only loads syntax when the value
    " *changes*, so set it to nothing before *changing* it to qf
    noautocmd let &syntax = ''
    let &syntax = 'qf'

    " copen also moves the cursor to the quickfix window, so return the
    " current window ID
    return [s:Win.getid()]
endfunction

" Callback that closes the quickfix window
function! wince_quickfix#ToClose()
    call s:Log.INF('wince_quickfix#ToClose')
    " Fail if the quickfix window is already closed
    let qfwinid = get(getqflist({'winid':0}), 'winid', -1)
    if !qfwinid
        throw 'Quickfix window is already closed'
    endif

    " cclose fails if the quickfix window is the last window, so use :quit
    " instead
    if winnr('$') ==# 1 && tabpagenr('$') ==# 1
        quit
        return
    endif

    cclose
endfunction

" Callback that returns 'quickfix' if the supplied winid is for the quickfix
" window
function! wince_quickfix#ToIdentify(winid)
    call s:Log.DBG('wince_quickfix#ToIdentify ', a:winid)
    let qfwinid = get(getqflist({'winid':0}), 'winid', -1)
    if a:winid ==# qfwinid
        return 'quickfix'
    endif
    return ''
endfunction

" Returns the statusline of the quickfix window
function! wince_quickfix#StatusLine()
    call s:Log.DBG('QuickfixStatusLine')
    let qfdict = getqflist({
   \    'title': 1,
   \    'nr': 0
   \})

    let qfdict = map(qfdict, function('jer_util#SanitizeForStatusLine'))

    let statusline = ''

    " 'Quickfix' string
    let statusline .= '%2*[Quickfix]'

    " Start truncating
    let statusline .= '%<'

    " Quickfix list number
    let statusline .= '%1*[' . qfdict.nr . ']'

    " Quickfix list title (from the command that generated the list)
    let statusline .= '%1*[' . qfdict.title . ']'

    " Right-justify from now on
    let statusline .= '%=%<'

    " [Column][Current line/Total lines][% of buffer]
    let statusline .= '%2*[%c][%l/%L][%p%%]'

    return statusline
endfunction

" Make sure the quickfix uberwin exists if and only if there is a quickfix
" list
function! s:Update(hide)
    call s:Log.DBG('Update ', a:hide)
    let qfwinexists = wince_model#UberwinGroupExists('quickfix')
    let qflistexists = !empty(getqflist())
    
    if qfwinexists && !qflistexists
        call s:Log.INF('Remove quickfix uberwin because there is no quickfix list')
        call wince_user#RemoveUberwinGroup('quickfix')
        return
    endif

    if !qfwinexists && qflistexists
        call s:Log.INF('Add quickfix uberwin because there is a quickfix list')
        call wince_user#AddUberwinGroup('quickfix', a:hide, 0)
        return
    endif
endfunction
function! wince_quickfix#UpdateShow()
    call s:Update(0)
endfunction
function! wince_quickfix#UpdateHide()
    call s:Update(1)
endfunction

" See comment on SessionLoadPost autocmd below
function! wince_quickfix#CloseDangling()
    let qfwinid = get(getqflist({'winid':0}), 'winid', -1)
    while qfwinid
        call s:Log.INF('Closing dangling window ', qfwinid)
        cclose
        let qfwinid = get(getqflist({'winid':0}), 'winid', -1)
    endwhile
endfunction

