" Wince Reference Definition for Loclist subwin
let s:Log = jer_log#LogFunctions('wince-loclist-subwin')
let s:Win = jer_win#WinFunctions()
" TODO: Figure out why sometimes the syntax highlighting doesn't get applied

if !exists('g:wince_enable_loclist') || !g:wince_enable_loclist
    call s:Log.CFG('Loclist subwin disabled')
    finish
endif

" wince_loclist#ToIdentify relies on getwininfo, and also on getloclist with the
" winid key. So Vim-native winids are required. I see no other way to implement
" wince_loclist#ToIdentify.
if s:Win.legacy
    call s:Log.ERR('The loclist subwin group is not supported with legacy winids')
    finish
endif

if !exists('g:wince_loclist_top')
    let g:wince_loclist_top = 0
endif

if !exists('g:wince_loclist_height')
    let g:wince_loclist_height = 10
endif

if !exists('g:wince_loclist_statusline')
    let g:wince_loclist_statusline = '%!wince_loclist#StatusLine()'
endif

" The location window is a subwin
call wince_user#AddSubwinGroupType('loclist', ['loclist'],
                          \[g:wince_loclist_statusline],
                          \'L', 'l', 2,
                          \50, [0], [1], !g:wince_loclist_top,
                          \[-1], [g:wince_loclist_height],
                          \function('wince_loclist#ToOpen'),
                          \function('wince_loclist#ToClose'),
                          \function('wince_loclist#ToIdentify'))

" Update the loclist subwins after each resolver run, when the state and
" model are certain to be consistent
if !exists('g:wince_loclist_chc')
    let g:wince_loclist_chc = 1
    call jer_chc#Register(function('wince_loclist#Update'), [], 1, 20, 1, 0, 1)
    call wince_user#AddPostUserOperationCallback(function('wince_loclist#Update'))
endif

" Mappings
" No explicit mappings to add or remove. Those operations are done by
" wince_loclist#Update.
if exists('g:wince_disable_loclist_mappings') && g:wince_disable_loclist_mappings
    call s:Log.CFG('Loclist uberwin mappings disabled')
else
    call wince_map#MapUserOp('<leader>ls', 'call wince_user#ShowSubwinGroup(win_getid(), "loclist", 1)')
    call wince_map#MapUserOp('<leader>lh', 'call wince_user#HideSubwinGroup(win_getid(), "loclist")')
    call wince_map#MapUserOp('<leader>ll', 'let g:wince_map_mode = wince_user#GotoSubwin(win_getid(), "loclist", "loclist", g:wince_map_mode, 1)')
    call wince_map#MapUserOp('<leader>lc', 'lexpr [] \| call wince_loclist#Update()')
endif
