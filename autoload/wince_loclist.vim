" Wince Reference Definition for Loclist subwin

" Avoid loading twice
if exists('s:loaded')
    finish
endif
let s:loaded = 0

let s:Log = jer_log#LogFunctions('wince-loclist-subwin')
let s:Win = jer_win#WinFunctions()

if s:Win.legacy
    finish
endif

" This helper is used here and also in the help uberwin
function! wince_loclist#FieldForStatusLine(fieldname)
    call s:Log.DBG('wince_loclist#FieldForStatusLine')
    return jer_util#SanitizeForStatusLine('', getloclist(win_getid(),{a:fieldname:0})[a:fieldname])
endfunction

" Callback that opens the location window for the current window
function! wince_loclist#ToOpen()
    call s:Log.INF('wince_loclist#ToOpen')
    let supwinid = win_getid()

    " Fail if the location window is already open
    let locwinid = get(getloclist(supwinid, {'winid':0}), 'winid', -1)
    if locwinid
        throw 'Window ' . supwinid . ' already has location window ' . locwinid
    endif

    " Before opening the location window, make sure there's enough room. We
    " need at least H + 2 rows - H for the loclist content, one for the supwin
    " statusline, and one for the supwin content
    if winheight(0) <# g:wince_loclist_height + 2
        throw 'Not enough room'
    endif

    " Open the location window
    if g:wince_loclist_top
        execute 'noautocmd aboveleft lopen ' . g:wince_loclist_height
    else
        execute 'noautocmd belowright lopen ' . g:wince_loclist_height
    endif

    " Since we opened the location window with noautocmd, &syntax was set
    " but the syntax wasn't loaded. Vim only loads syntax when the value
    " *changes*, so set it to nothing before *changing* it to qf
    noautocmd let &syntax = ''
    let &syntax = 'qf'

    " lopen also moves the cursor to the location window, so return the
    " current window ID
    let locwinid = win_getid()

    " Go back to the supwin
    noautocmd call win_gotoid(supwinid)

    return [locwinid]
endfunction

" Callback that closes the location list for the current window
function! wince_loclist#ToClose()
    call s:Log.INF('wince_loclist#ToClose')
    let supwinid = win_getid()

    " Fail if the location window is already closed
    let locwinid = get(getloclist(supwinid, {'winid':0}), 'winid', -1)
    if !locwinid
        throw 'Location window for window ' . supwinid . ' does not exist'
    endif

    " lclose fails if the location window is the last window, so use :quit
    " instead
    if winnr('$') ==# 1 && tabpagenr('$') ==# 1
        quit
        return
    endif

    " When closing the location list, we want its supwin to fill the
    " space left. If there is also a supwin on the other side of the loclist
    " window, Vim may choose to fill the space with that one instead. Setting
    " splitbelow causes Vim to always pick the supwin above via some undocumented
    " behaviour. Conversely, resetting splitbelow causes Vim to always pick
    " the supwin below.
    let oldsb = &splitbelow
    if g:wince_loclist_top
        let &splitbelow = 0
    else
        let &splitbelow = 1
    endif

    " Close the location window
    lclose

    " Restore splitbelow
    let &splitbelow = oldsb
endfunction

" Callback that returns {'typename':'loclist','supwin':<id>} if the supplied
" winid is for a location window that is not the location window of a help
" window
function! wince_loclist#ToIdentify(winid)
    call s:Log.DBG('wince_loclist#ToIdentify ', a:winid)
    let locwinnr = win_id2win(a:winid)
    if getwininfo(a:winid)[0]['loclist']
        for winnr in range(1,winnr('$'))
            if winnr != locwinnr &&
           \   get(getloclist(winnr, {'winid':0}), 'winid', -1) == a:winid &&
           \   getwinvar(winnr, '&ft', '') !=? 'help'
                return {'typename':'loclist','supwin':win_getid(winnr)}
            endif
        endfor
        return {'typename':'loclist','supwin':-1}
    endif
    return {}
endfunction

" Returns the statusline of the location window
function! wince_loclist#StatusLine()
    call s:Log.DBG('LoclistStatusLine')
    let statusline = ''

    " 'Loclist' string
    let statusline .= '%2*[Loclist]'

    " Start truncating
    let statusline .= '%<'

    " Location list number
    let statusline .= '%1*[%{wince_loclist#FieldForStatusLine("title")}]'

    " Location list title (from the command that generated the list)
    let statusline .= '%1*[%{wince_loclist#FieldForStatusLine("nr")}]'

    " Right-justify from now on
    let statusline .= '%=%<'

    " [Column][Current line/Total lines][% of buffer]
    let statusline .= '%2*[%c][%l/%L][%p%%]'

    return statusline
endfunction

" For each supwin, make sure the loclist subwin exists if and only if that
" supwin has a location list
function! wince_loclist#Update()
    call s:Log.DBG('wince_loclist#Update')
    for supwinid in wince_model#SupwinIds()
        let locwinexists = wince_model#SubwinGroupExists(supwinid, 'loclist')
        let loclistexists = !empty(getloclist(supwinid))

        if locwinexists && !loclistexists
            call s:Log.INF('Remove loclist subwin from supwin ', supwinid, ' because it has no location list')
            call wince_user#RemoveSubwinGroup(supwinid, 'loclist')
            continue
        endif

        if !locwinexists && loclistexists
            call s:Log.INF('Add loclist subwin to supwin ', supwinid, ' because it has a location list')
            call wince_user#AddSubwinGroup(supwinid, 'loclist', 0, 0)
            continue
        endif
    endfor
endfunction

