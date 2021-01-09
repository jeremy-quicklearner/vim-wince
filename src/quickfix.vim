" Wince Reference Definiton for Quickfix uberwin
let s:Log = jer_log#LogFunctions('wince-quickfix-uberwin')
let s:Win = jer_win#WinFunctions()

if !exists('g:wince_enable_quickfix') || !g:wince_enable_quickfix
    call s:Log.CFG('Quickfix uberwin disabled')
    finish
endif

" wince_quickfix#ToIdentify relies on getqflist with the winid key. So Vim-native winids
" are required. I see no other way to implement wince_quickfix#ToIdentify.
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
    let g:wince_quickfix_statusline = '%!wince_quickfix#StatusLine()'
endif

" The quickfix window is an uberwin
call wince_user#AddUberwinGroupType('quickfix', ['quickfix'],
                             \[g:wince_quickfix_statusline],
                             \'Q', 'q', 2,
                             \50, [0],
                             \[-1], [g:wince_quickfix_height],
                             \function('wince_quickfix#ToOpen'),
                             \function('wince_quickfix#ToClose'),
                             \function('wince_quickfix#ToIdentify'))

" Update the quickfix uberwin after entering a tab
" If the uberwin needs to be added, make it hidden
call wince_user#AddTabEnterPreResolveCallback(function('wince_quickfix#UpdateHide'))

augroup WinceQuickfix
    autocmd!

    " Update the quickfix uberwin whenever the quickfix list is changed
    " If the uberwin needs to be added don't hide it
    autocmd QuickFixCmdPost * call wince_quickfix#UpdateShow()

    " If there are location windows when mksession is invoked, the location lists
    " they display do not persist. When the session is reloaded, the location
    " windows are opened without location lists. If there is no quickfix
    " window, Vim misidentifies the dangling location windows as quickfix
    " windows. This breaks the assumption that there is only ever one quickfix
    " window, which the Quickfix uberwin definition relies on. To be safe, invoke
    " cclose in every tab until there are no quickfix windows. 
    autocmd SessionLoadPost * call jer_util#TabDo('', 'call jer_chc#Register(function("wince_quickfix#CloseDangling"), [], 1, -99, 0, 0, 0)')
augroup END

" Mappings
" No explicit mappings to add or remove. Those operations are done by
" wince_quickfix.vim's s:Update().
if exists('g:wince_disable_quickfix_mappings') && g:wince_disable_quickfix_mappings
    call s:Log.CFG('Quickfix uberwin mappings disabled')
else
    call wince_map#MapUserOp('<leader>qs', 'call wince_user#ShowUberwinGroup("quickfix", 1)')
    call wince_map#MapUserOp('<leader>qh', 'call wince_user#HideUberwinGroup("quickfix")')
    call wince_map#MapUserOp('<leader>qq', 'let g:wince_map_mode = wince_user#GotoUberwin("quickfix", "quickfix", g:wince_map_mode, 1)')
    call wince_map#MapUserOp('<leader>qc', 'call wince_user#RemoveUberwinGroup("quickfix") \| cexpr []')
endif
