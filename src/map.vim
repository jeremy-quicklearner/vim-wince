" Wince Mappings
" See wince.vim
" This file remaps every Vim Ctrl-W command that doesn't play well with the
" window engine to one of the custom commands from wince-commands.vim.
" I did my best to cover all of them. If any slipped through, please let me
" know!
" TODO: Use <cmd> to avoid messing around with modes
let s:Log = jer_log#LogFunctions('wince-mappings')

if exists('g:wince_disable_all_mappings') && g:wince_disable_all_mappings
    call s:Log.CFG('Mappings disabled')
    finish
endif

if !exists('g:wince_disabled_mappings')
    let g:wince_disabled_mappings = {}
endif

" Map a command of the form <c-w><cmd> to run an Ex command with a count
function! s:DefineMappings(cmd, exCmd, allow0, mapinnormalmode, mapinvisualmode, mapinselectmode, mapinterminalmode)
    call s:Log.DBG('DefineMappings ', a:cmd, ', ', a:exCmd, ', [', a:allow0, ',', a:mapinnormalmode, ',', a:mapinvisualmode, ',', a:mapinselectmode, ',', a:mapinterminalmode, ']')
    if a:mapinnormalmode
        execute 'nnoremap <silent> ' . a:cmd .
       \    ' :<c-u>execute wince_map#ProcessCounts(' .
       \        a:allow0 .
       \    ') . "' . a:exCmd . ' n"<cr>'
    endif
    if a:mapinvisualmode
        execute 'xnoremap <silent> ' . a:cmd .
       \    ' :<c-u>execute wince_map#ProcessCounts(' .
       \        a:allow0 .
       \    ') . "' . a:exCmd . ' v"<cr>'
    endif
    if a:mapinselectmode
        execute 'snoremap <silent> ' . a:cmd .
       \    ' :<c-u>execute wince_map#ProcessCounts(' .
       \        a:allow0 .
       \    ') . "' . a:exCmd . ' s"<cr>'
    endif
    if a:mapinterminalmode && exists(':tnoremap')
         execute 'tnoremap <silent> ' . a:cmd .
        \    ' <c-w>:<c-u>execute wince_map#ProcessCounts(' .
        \        a:allow0 .
        \    ') . "' . a:exCmd . ' t"<cr>'
    endif
endfunction

" Create an Ex command and mappings that run a Ctrl-W command with flags
function! s:MapCmd(cmds, exCmdName, allow0,
                 \ mapinselectmode, mapinterminalmode)
    call s:Log.DBG('Map ', a:cmds, ' to ', a:exCmdName)
    for cmd in a:cmds
        if has_key(g:wince_disabled_mappings, cmd)
            continue
        endif
        call s:DefineMappings(cmd, a:exCmdName, a:allow0, 1, 1, a:mapinselectmode, a:mapinterminalmode)
    endfor
endfunction

" This tower of hacks maps <c-w>{nr}{cmd} to {nr}<c-w>{cmd} and z{nr}<cr>
" to {nr}z<cr>. This can't be done with v:count because {nr} doesn't come first.
" We must parse the characters ourselves.
" Technically some of the functions here could be autoloaded to reduce Vim's
" startup time, but it's hard enough to understand without jumping across
" multiple files

" These top-level mappings are just on the first character and first digit of
" {nr}. 0 Is ommitted because Vim's default behaviour on <c-w>0 and z0 is
" already a nop
" When we start reading characters, we preserve/retrieve the current mode.
for idx in range(1,9)
    " There is no snoremap for <c-w> because no <c-w> commands can be run from
    " select mode
    for [mapchr, lhs, modechr, whichscan] in [
   \    ['n', '<c-w>', 'n', 'W'],
   \    ['x', '<c-w>', 'v', 'W'],
   \    ['n', 'z',     'n', 'Z'],
   \    ['x', 'z',     'v', 'Z'],
   \    ['s', 'z',     's', 'Z']
   \]
        execute mapchr . 'noremap <silent> ' . lhs . idx . ' ' .
       \    ':<c-u>call jer_mode#Detect("' . modechr . '")<cr>' .
       \    ':<c-u>let g:wince_map_mode=jer_mode#Retrieve()<cr>' .
       \    ':<c-u>call WinceMapScan' . whichscan .'(' . idx . ')<cr>'
    endfor
endfor

" Tracks the characters typed so far
let s:sofar = ''

" These functions call WinceMapScan() which will read more characters.
function! WinceMapScanW(firstdigit)
    call s:Log.DBG('WinceMapcanW ', a:firstdigit)
    let s:sofar = "\<c-w>" . a:firstdigit
    call WinceMapScan()
endfunction
function! WinceMapScanZ(firstdigit)
    call s:Log.DBG('WinceMapScanZ ', a:firstdigit)
    let s:sofar = "z" . a:firstdigit
    call WinceMapScan()
endfunction

" These two mappings contain <plug>, so the user will never invoke them.
" They both start with <plug>WinceMapParse, so they are ambiguous.
" WinceMapScan exploits Vim's behaviour with ambiguous mappings - more on
" this below
map <silent> <plug>WinceMapParse :call WinceMapScan()<cr>
map <silent> <plug>WinceMapParse<plug> <nop>

" This function scans for (and records) new characters typed by the user
" and checks if the user is partway through typing one of
" <c-w>{nr}{cmd} or z{nr}<cr>.
"
" If the user is partway through typing such a command, it uses feedkeys() to
" setup an invocation of the first of the ambiguous mappings above. Vim will
" wait a while due to the ambiguity (during which characters can be typed by
" the user) and then run the mapping which calls this function again. So the
" function runs over and over reading one character at a time.
" The mode that was preserve/retrieved by the top-level mappings is restored
" each time.
" If the user is not partway through typing such a command (either because
" they've finished typing it or because they typed a character that isn't in
" the command), stop feedkeys'ing the ambiguous mapping and pass the
" characters typed so far to s:RunInfixCmd.
function! WinceMapScan()
    " If no characters at all have been typed, something is wrong.
    if empty(s:sofar)
        throw 'WinceMapScan() on empty s:sofar'
    endif

    " If no characters are available now, setup another call.
    if !getchar(1)
        call s:Log.VRB('WinceMapScan sees no new characters')
        call jer_mode#ForcePreserve(g:wince_map_mode)
        call jer_mode#Restore()
        call feedkeys("\<plug>WinceMapParse")
        return
    endif

    " A character is available. Read it.
    let s:sofar .= nr2char(getchar())
    call s:Log.DBG('WinceMapScan captured ', s:sofar)
    " If it was a number, setup another call because there may be more
    " characters
    if s:sofar[1:] =~# '^\d*$'
        call s:Log.DBG('Not finished scanning yet')
        call jer_mode#ForcePreserve(g:wince_map_mode)
        call jer_mode#Restore()
        call feedkeys("\<plug>WinceMapParse")
        return
    endif

    " It wasn't a number. We're done.
    call s:RunInfixCmd(s:sofar)

    " Clear the read characters for next time
    let s:sofar = ''
endfunction

" Given a command with an infixed count, use feedkeys to run it but with the
" count prefixed instead of infixed. If there is a non-hacky mapping that uses
" v:count, it will be triggered.
" Also restore the mode that was preserve/retrieved by the top-level mappings,
" so that the non-hacky mapping runs in the same mode that we started in
function! s:RunInfixCmd(cmd)
    if index(["\<c-w>", 'z'], a:cmd[0]) <# 0
        throw 's:RunInfixCmd on invalid command ' . a:cmd
    endif
    call s:Log.INF('RunInfixCmd ', a:cmd, ' -> ', a:cmd[1:-2], a:cmd[0], a:cmd[-1:-1])
    call jer_mode#ForcePreserve(g:wince_map_mode)
    call jer_mode#Restore()
    call feedkeys(a:cmd[1:-2] . a:cmd[0] . a:cmd[-1:-1])
endfunction

" The tower of hacks ends here

" Command mappings
call s:MapCmd(['<c-w>o','<c-w><c-o>'    ], 'WinceOnly',                 0, 0, 1)
call s:MapCmd(['<c-w>-'                 ], 'WinceDecreaseHeight',       0, 0, 1)
call s:MapCmd(['<c-w><'                 ], 'WinceDecreaseWidth',        0, 0, 1)
call s:MapCmd(['<c-w>='                 ], 'WinceEqualize',             0, 0, 1)
call s:MapCmd(['<c-w>x','<c-w><c-x>'    ], 'WinceExchange',             1, 0, 1)
call s:MapCmd(['<c-w>j','<c-w><down>'   ], 'WinceGoDown',               0, 0, 1)
call s:MapCmd(['<c-w>t','<c-w><c-t>'    ], 'WinceGoFirst',              0, 0, 1)
call s:MapCmd(['<c-w>b','<c-w><c-b>'    ], 'WinceGoLast',               0, 0, 1)
call s:MapCmd(['<c-w>h','<c-w><left>'   ], 'WinceGoLeft',               0, 0, 1)
call s:MapCmd(['<c-w>w','<c-w><c-w>'    ], 'WinceGoNext',               0, 0, 1)
call s:MapCmd(['<c-w>l','<c-w><right>'  ], 'WinceGoRight',              0, 0, 1)
call s:MapCmd(['<c-w>k','<c-w><up>'     ], 'WinceGoUp',                 0, 0, 1)
call s:MapCmd(['<c-w>p','<c-w><c-p>'    ], 'WinceGotoPrevious',         1, 0, 1)
call s:MapCmd(['<c-w>+'                 ], 'WinceIncreaseHeight',       0, 0, 1)
call s:MapCmd(['<c-w>>'                 ], 'WinceIncreaseWidth',        0, 0, 1)
call s:MapCmd(['<c-w>J'                 ], 'WinceMoveToBottomEdge',     0, 0, 1)
call s:MapCmd(['<c-w>H'                 ], 'WinceMoveToLeftEdge',       0, 0, 1)
call s:MapCmd(['<c-w>T'                 ], 'WinceMoveToNewTab',         0, 0, 1)
call s:MapCmd(['<c-w>L'                 ], 'WinceMoveToRightEdge',      0, 0, 1)
call s:MapCmd(['<c-w>K'                 ], 'WinceMoveToTopEdge',        0, 0, 1)
call s:MapCmd(['<c-w>_','<c-w><c-_>'    ], 'WinceResizeHorizontal',     1, 0, 1)
call s:MapCmd(['z<cr>'            ], 'WinceResizeHorizontalDefaultNop', 1, 1, 1)
call s:MapCmd(['<c-w>\|'                ], 'WinceResizeVertical',       1, 0, 1)
call s:MapCmd(['<c-w>W'                 ], 'WinceReverseGoNext',        0, 0, 1)
call s:MapCmd(['<c-w>R'                 ], 'WinceReverseRotate',        0, 0, 1)
call s:MapCmd(['<c-w>r','<c-w><c-r>'    ], 'WinceRotate',               0, 0, 1)
call s:MapCmd(['<c-w>s','<c-w>S','<c-s>'], 'WinceSplitHorizontal',      0, 0, 1)
call s:MapCmd(['<c-w>v','<c-w><c-v>'    ], 'WinceSplitVertical',        0, 0, 1)
call s:MapCmd(['<c-w>n','<c-w><c-n>'    ], 'WinceSplitNew',             0, 0, 1)
call s:MapCmd(['<c-w>^','<c-w><c-^>'    ], 'WinceSplitAlternate',       0, 0, 1)
call s:MapCmd(['<c-w>q','<c-w><c-q>'    ], 'WinceQuit',                 0, 0, 1)
call s:MapCmd(['<c-w>c'                 ], 'WinceClose',                0, 0, 1)
call s:MapCmd(['<c-w>P'                 ], 'WinceGotoPreview',          0, 0, 1)
call s:MapCmd(['<c-w>]','<c-w><c-]>'    ], 'WinceSplitTag',             0, 0, 1)
call s:MapCmd(['<c-w>g]',               ], 'WinceSplitTagSelect',       0, 0, 1)
call s:MapCmd(['<c-w>g<c-]>',           ], 'WinceSplitTagJump',         0, 0, 1)
call s:MapCmd(['<c-w>f','<c-w><c-f>'    ], 'WinceSplitFilename',        0, 0, 1)
call s:MapCmd(['<c-w>F',                ], 'WinceSplitFilenameLine',    0, 0, 1)
call s:MapCmd(['<c-w>z','<c-w><c-z>'    ], 'WincePreviewClose',         0, 0, 1)
call s:MapCmd(['<c-w>}'                 ], 'WincePreviewTag',           0, 0, 1)
call s:MapCmd(['<c-w>g}'                ], 'WincePreviewTagJump',       0, 0, 1)
call s:MapCmd(['<c-w>i','<c-w><c-i>'    ], 'WinceSplitSearchWord',      0, 0, 1)
call s:MapCmd(['<c-w>d','<c-w><c-d>'    ], 'WinceSplitSearchMacro',     0, 0, 1)
call s:MapCmd(['<bs>'                   ], 'WinceGoLeft',               0, 1, 0)
