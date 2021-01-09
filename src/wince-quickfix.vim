" Wince Reference Definiton for Quickfix uberwin
let s:Log = jer_log#LogFunctions('wince-quickfix-uberwin')
let s:Win = jer_win#WinFunctions()

if !exists('g:wince_enable_quickfix') || !g:wince_enable_quickfix
    call s:Log.CFG('Quickfix uberwin disabled')
    finish
endif

" WinceToIdentifyQuickfix relies on getqflist with the winid key. So Vim-native winids
" are required. I see no other way to implement WinceToIdentifyQuickfix.
if s:Win.legacy
    call s:Log.ERR('The quickfix uberwin group is not supported with legacy winids')
    finish
endif

if !exists('g:wince_quickfix_top')
    let g:wince_quickfix_top = 0
endif

if !exists('g:wince_quickfix_height')
    let g:wince_quickfix_height = 10
endif

if !exists('g:wince_quickfix_statusline')
    let g:wince_quickfix_statusline = '%!WinceQuickfixStatusLine()'
endif

" Callback that opens the quickfix window
function! WinceToOpenQuickfix()
    call s:Log.INF('WinceToOpenQuickfix')
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
function! WinceToCloseQuickfix()
    call s:Log.INF('WinceToCloseQuickfix')
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
function! WinceToIdentifyQuickfix(winid)
    call s:Log.DBG('WinceToIdentifyQuickfix ', a:winid)
    let qfwinid = get(getqflist({'winid':0}), 'winid', -1)
    if a:winid ==# qfwinid
        return 'quickfix'
    endif
    return ''
endfunction

" Returns the statusline of the quickfix window
function! WinceQuickfixStatusLine()
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

" The quickfix window is an uberwin
call wince_user#AddUberwinGroupType('quickfix', ['quickfix'],
                             \[g:wince_quickfix_statusline],
                             \'Q', 'q', 2,
                             \50, [0],
                             \[-1], [g:wince_quickfix_height],
                             \function('WinceToOpenQuickfix'),
                             \function('WinceToCloseQuickfix'),
                             \function('WinceToIdentifyQuickfix'))

" Make sure the quickfix uberwin exists if and only if there is a quickfix
" list
function! UpdateQuickfixUberwin(hide)
    call s:Log.DBG('UpdateQuickfixUberwin ', a:hide)
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
function! UpdateQuickfixUberwinShow()
    call UpdateQuickfixUberwin(0)
endfunction
function! UpdateQuickfixUberwinHide()
    call UpdateQuickfixUberwin(1)
endfunction

" Update the quickfix uberwin after entering a tab
" If the uberwin needs to be added, make it hidden
call wince_user#AddTabEnterPreResolveCallback(function('UpdateQuickfixUberwinHide'))

" See comment on SessionLoadPost autocmd below
function! CloseDanglingQuickfixWindows()
    let qfwinid = get(getqflist({'winid':0}), 'winid', -1)
    while qfwinid
        call s:Log.INF('Closing dangling window ', qfwinid)
        cclose
        let qfwinid = get(getqflist({'winid':0}), 'winid', -1)
    endwhile
endfunction

augroup WinceQuickfix
    autocmd!

    " Update the quickfix uberwin whenever the quickfix list is changed
    " If the uberwin needs to be added don't hide it
    autocmd QuickFixCmdPost * call UpdateQuickfixUberwinShow()

    " If there are location windows when mksession is invoked, the location lists
    " they display do not persist. When the session is reloaded, the location
    " windows are opened without location lists. If there is no quickfix
    " window, Vim misidentifies the dangling location windows as quickfix
    " windows. This breaks the assumption that there is only ever one quickfix
    " window, which the Quickfix uberwin definition relies on. To be safe, invoke
    " cclose in every tab until there are no quickfix windows. 
    autocmd SessionLoadPost * call jer_util#TabDo('', 'call jer_chc#Register(function("CloseDanglingQuickfixWindows"), [], 1, -99, 0, 0, 0)')
augroup END

" Mappings
" No explicit mappings to add or remove. Those operations are done by
" UpdateQuickfixUberwin.
if exists('g:wince_disable_quickfix_mappings') && g:wince_disable_quickfix_mappings
    call s:Log.CFG('Quickfix uberwin mappings disabled')
else
    call wince_map#MapUserOp('<leader>qs', 'call wince_user#ShowUberwinGroup("quickfix", 1)')
    call wince_map#MapUserOp('<leader>qh', 'call wince_user#HideUberwinGroup("quickfix")')
    call wince_map#MapUserOp('<leader>qq', 'let g:wince_map_mode = wince_user#GotoUberwin("quickfix", "quickfix", g:wince_map_mode, 1)')
    call wince_map#MapUserOp('<leader>qc', 'call wince_user#RemoveUberwinGroup("quickfix") \| cexpr []')
endif
