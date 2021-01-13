" Wince Reference Definition for Help uberwin
" Warning: This is the most complicated of all the reference definitions.
" If you're trying to learn how to write uberwin group types, don't start
" here.
let s:Log = jer_log#LogFunctions('wince-help-uberwin')
let s:Win = jer_win#WinFunctions()

if !exists('g:wince_enable_help') || !g:wince_enable_help
    call s:Log.CFG('Help uberwin disabled')
    finish
endif

" wince_help#ToIdentifyLocHelp relies on getwininfo, and also on getloclist with the
" winid key. So Vim-native winids are required. I see no other way to
" implement wince_help#ToIdentifyLocHelp.
if s:Win.legacy
    call s:Log.CFG('No Lochelp uberwin group with legacy winids')
endif

if !exists('g:wince_help_left')
    let g:wince_help_left = 0
endif

if !exists('g:wince_help_statusline')
    let g:wince_help_statusline = '%!wince_help#HelpStatusLine()'
endif

if !exists('g:wince_helploc_statusline')
    let g:wince_helploc_statusline = '%!wince_help#HelpLocStatusLine()'
endif

if !exists('g:wince_help_width')
    let g:wince_help_width = 89
endif

" There are two uberwin groups. One for the help window, and a second one for
" the help window and its location list
call wince_user#AddUberwinGroupType('help', ['help'],
                           \[g:wince_help_statusline],
                           \'H', 'h', 4,
                           \40, [0],
                           \[g:wince_help_width], [-1],
                           \function('wince_help#ToOpenHelp'),
                           \function('wince_help#ToCloseHelp'),
                           \function('wince_help#ToIdentifyHelp'))

augroup WinceHelp
    autocmd!
    autocmd VimEnter, TabNew * let t:j_help = {}
augroup END

if !s:Win.legacy
    " The lochelp uberwin has a lower priority value than the help uberwin
    " because we want the Resolver to call its ToIdentify callback first
    call wince_user#AddUberwinGroupType('lochelp', ['help', 'loclist'],
                               \[g:wince_help_statusline, g:wince_helploc_statusline],
                               \'HL', 'hl', 4,
                               \39, [1, 1],
                               \[g:wince_help_width, g:wince_help_width], [-1, 10],
                               \function('wince_help#ToOpenLocHelp'),
                               \function('wince_help#ToCloseLocHelp'),
                               \function('wince_help#ToIdentifyLocHelp'))

    call jer_pec#Register(function('wince_help#UpdatePreResolve'), [], 0, -50, 1, 0, 1)
    call jer_pec#Register(function('wince_help#UpdatePostResolve'), [], 0, 30, 1, 0, 1)

    if exists('g:wince_disable_help_mappings') && g:wince_disable_help_mappings
        call s:Log.CFG('Help uberwin mappings disabled')
    else
        call wince_map#MapUserOp('<leader>hs', 'call wince_help#AddOrShow()')
        call wince_map#MapUserOp('<leader>hc', 'call wince_help#Hide()')
        call wince_map#MapUserOp('<leader>hh', 'let g:wince_map_mode = wince_help#AddOrGotoHelp(g:wince_map_mode)')
        call wince_map#MapUserOp('<leader>hl', 'let g:wince_map_mode = wince_help#AddOrGotoLoc(g:wince_map_mode)')
    endif

else
    if exists('g:wince_disable_help_mappings') && g:wince_disable_help_mappings
        call s:Log.CFG('Help uberwin mappings disabled')
    else
        call wince_map#MapUserOp('<leader>hs', 'call wince_user#AddOrShowUberwinGroup("help")')
        call wince_map#MapUserOp('<leader>hc', 'call wince_user#HideUberwinGroup("help")')
        call wince_map#MapUserOp('<leader>hh', 'let g:wince_map_mode = wince_user#AddOrGotoUberwin("help","help",g:wince_map_mode)')
    endif
endif

