" Wince Mappings
" See wince.vim
" This file remaps every Vim Ctrl-W command that doesn't play well with the
" window engine to one of the custom commands from wince-commands.vim.
" I did my best to cover all of them. If any slipped through, please let me
" know!
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
    for [domap, mapchr, modechr] in [
   \    [a:mapinnormalmode,   'n', 'n'],
   \    [a:mapinvisualmode,   'x', 'v'],
   \    [a:mapinselectmode,   's', 's'],
   \    [a:mapinterminalmode, 't', 't']
   \]
        if domap
            let mapcmd =  mapchr . 'noremap <silent> ' . a:cmd . ' ' .
           \    '<c-w>:<c-u>execute wince_map#ProcessCounts(' .
           \        a:allow0 .
           \    ') . "' . a:exCmd . ' ' . modechr . '"<cr>'
            execute mapcmd
        endif
    endfor
endfunction

" Create an Ex command and mappings that run a Ctrl-W command with flags
function! s:MapCmd(cmds, exCmdName, allow0,
                 \ mapinnormalmode, mapinvisualmode,
                 \ mapinselectmode, mapinterminalmode)
    call s:Log.DBG('Map ', a:cmds, ' to ', a:exCmdName)
    for cmd in a:cmds
        if has_key(g:wince_disabled_mappings, cmd)
            continue
        endif
        call s:DefineMappings(cmd, a:exCmdName, a:allow0, a:mapinnormalmode, a:mapinvisualmode, a:mapinselectmode, a:mapinterminalmode)
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
        let mapcmd = mapchr . 'noremap <silent> ' . lhs . idx . ' ' .
       \    '<c-w>:<c-u>call jer_mode#Detect("' . modechr . '")<cr>' .
       \    '<c-w>:<c-u>let g:wince_map_mode=jer_mode#Retrieve()<cr>' .
       \    '<c-w>:<c-u>call WinceMapScan' . whichscan .'(' . idx . ')<cr>'
        execute mapcmd
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
let s:allCmds = {
\   'WinceOnly':                      ['<c-w>o','<c-w><c-o>'    ],
\   'WinceDecreaseHeight':            ['<c-w>-'                 ],
\   'WinceDecreaseWidth':             ['<c-w><'                 ],
\   'WinceEqualize':                  ['<c-w>='                 ],
\   'WinceExchange':                  ['<c-w>x','<c-w><c-x>'    ],
\   'WinceGoDown':                    ['<c-w>j','<c-w><down>'   ],
\   'WinceGoFirst':                   ['<c-w>t','<c-w><c-t>'    ],
\   'WinceGoLast':                    ['<c-w>b','<c-w><c-b>'    ],
\   'WinceGoLeft':                    ['<c-w>h','<c-w><left>'   ],
\   'WinceGoNext':                    ['<c-w>w','<c-w><c-w>'    ],
\   'WinceGoRight':                   ['<c-w>l','<c-w><right>'  ],
\   'WinceGoUp':                      ['<c-w>k','<c-w><up>'     ],
\   'WinceGotoPrevious':              ['<c-w>p','<c-w><c-p>'    ],
\   'WinceIncreaseHeight':            ['<c-w>+'                 ],
\   'WinceIncreaseWidth':             ['<c-w>>'                 ],
\   'WinceMoveToBottomEdge':          ['<c-w>J'                 ],
\   'WinceMoveToLeftEdge':            ['<c-w>H'                 ],
\   'WinceMoveToNewTab':              ['<c-w>T'                 ],
\   'WinceMoveToRightEdge':           ['<c-w>L'                 ],
\   'WinceMoveToTopEdge':             ['<c-w>K'                 ],
\   'WinceResizeHorizontal':          ['<c-w>_','<c-w><c-_>'    ],
\   'WinceResizeHorizontalDefaultNop':['z<cr>'                  ],
\   'WinceResizeVertical':            ['<c-w>\|'                ],
\   'WinceReverseGoNext':             ['<c-w>W'                 ],
\   'WinceReverseRotate':             ['<c-w>R'                 ],
\   'WinceRotate':                    ['<c-w>r','<c-w><c-r>'    ],
\   'WinceSplitHorizontal':           ['<c-w>s','<c-w>S','<c-s>'],
\   'WinceSplitVertical':             ['<c-w>v','<c-w><c-v>'    ],
\   'WinceSplitNew':                  ['<c-w>n','<c-w><c-n>'    ],
\   'WinceSplitAlternate':            ['<c-w>^','<c-w><c-^>'    ],
\   'WinceQuit':                      ['<c-w>q','<c-w><c-q>'    ],
\   'WinceClose':                     ['<c-w>c'                 ],
\   'WinceGotoPreview':               ['<c-w>P'                 ],
\   'WinceSplitTag':                  ['<c-w>]','<c-w><c-]>'    ],
\   'WinceSplitTagSelect':            ['<c-w>g]',               ],
\   'WinceSplitTagJump':              ['<c-w>g<c-]>',           ],
\   'WinceSplitFilename':             ['<c-w>f','<c-w><c-f>'    ],
\   'WinceSplitFilenameLine':         ['<c-w>F',                ],
\   'WincePreviewClose':              ['<c-w>z','<c-w><c-z>'    ],
\   'WincePreviewTag':                ['<c-w>}'                 ],
\   'WincePreviewTagJump':            ['<c-w>g}'                ],
\   'WinceSplitSearchWord':           ['<c-w>i','<c-w><c-i>'    ],
\   'WinceSplitSearchMacro':          ['<c-w>d','<c-w><c-d>'    ]
\}

let s:cmdsWithAllow0 = [
\   'WinceExchange',
\   'WinceGotoPrevious',
\   'WinceResizeHorizontal',
\   'WinceResizeVertical'
\]


let s:cmdsWithNormalModeMapping = keys(s:allCmds)
let s:cmdsWithVisualModeMapping = keys(s:allCmds)
" This matches Vim's native behaviour. Sticks out like a sore thumb, dooesn't
" it?
let s:cmdsWithSelectModeMapping = ['WinceResizeHorizontalDefuaultNop']
let s:cmdsWithTerminalModeMapping = keys(s:allCmds)

for cmdname in keys(s:allCmds)
    call s:MapCmd(
   \    s:allCmds[cmdname], cmdname,
   \    index(s:cmdsWithAllow0,              cmdname) >=# 0,
   \    index(s:cmdsWithNormalModeMapping,   cmdname) >=# 0,
   \    index(s:cmdsWithVisualModeMapping,   cmdname) >=# 0,
   \    index(s:cmdsWithSelectModeMapping,   cmdname) >=# 0,
   \    index(s:cmdsWithTerminalModeMapping, cmdname) >=# 0
   \)
endfor

" Special case: WinceGoLeft needs to be mapped to <bs>, but not in terminal mode
call s:MapCmd(['<bs>'], 'WinceGoLeft', 0, 1, 1, 1, 0)

