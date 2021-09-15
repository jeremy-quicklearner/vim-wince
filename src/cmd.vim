" Wince Commands
" See wince.vim
let s:Log = jer_log#LogFunctions('wince-commands')

" See comments in autoload/wince_cmd.vim for notes on the 1524607938 magic
" number
function! s:Define(cmdname, wincmd,
                 \ preservecursor,
                 \ ifuberwindonothing, ifsubwingotosupwin,
                 \ dowithoutuberwins, dowithoutsubwins,
                 \ relyonresolver)
    call s:Log.DBG('Command: ', a:cmdname)
    execute 'command! -nargs=? -count=1524607938 ' .
   \        a:cmdname .
   \        ' call jer_mode#Detect("<args>") | '
   \        'call jer_mode#ForcePreserve(wince_cmd#Run(' .
   \        '"' . a:cmdname . '",' .
   \        '"' . a:wincmd . '",' .
   \        '<count>,' .
   \        'jer_mode#Retrieve(),' .
   \        a:preservecursor . ',' .
   \        a:ifuberwindonothing . ',' .
   \        a:ifsubwingotosupwin . ',' .
   \        a:dowithoutuberwins . ',' .
   \        a:dowithoutsubwins . ',' .
   \        a:relyonresolver . ')) | ' .
   \        'call jer_mode#Restore()'
endfunction

function! s:DefineSpecial(cmdname, handler)
    call s:Log.DBG('Special command: ', a:cmdname)
    execute 'command! -nargs=? -count=1524607938 ' .
   \        a:cmdname .
   \        ' call jer_mode#Detect("<args>") | ' .
   \        'call jer_mode#ForcePreserve(wince_cmd#RunSpecial(' .
   \        '"' . a:cmdname . '",' .
   \        '<count>,' .
   \        'jer_mode#Retrieve(),' .
   \        '"' . a:handler . '")) | ' .
   \        'call jer_mode#Restore()'
endfunction

" Exchanging supwins is special because if the operation is invoked from a
" subwin, the cursor should be restored to the corresponding subwin of the
" exchanged window
call s:DefineSpecial('WinceExchange','wince_user#Exchange')

" Going to the previous window requires special accounting in the user
" operations because wince is always moving the cursor all over the place
" and Vim's internal 'previous window' means nothing to the user
call s:DefineSpecial('WinceGotoPrevious','wince_user#GotoPrevious')

" WinceOnly is special because if it isn't, its counted version can land in a
" subwin and close all other windows (including the subwin's supwin) leaving
" the subwin dangling, which will cause the resolver to exit the tab.
" We can't just close subwins and uberwins during execution without
" normalizing the count to account for their absence
call s:DefineSpecial('WinceOnly', 'wince_user#Only')

" If WinceResizeHorizontal and WinceResizeVertical ran run wincmd _ and wincmd | with
" uberwins open, they could change the uberwins' sizes and cause the resolver to
" later close and reopen the uberwins. RestoreMaxDimensionsByWinid
" would then mess up all the supwins' sizes, so the user's intent would be
" lost. So WinceResizeHorizontal and WinceResizeVertical must run without
" uberwins.
" The user invokes WinceResizeHorizontal and WinceResizeVertical while looking at
" a layout with uberwins, and supplies counts accordingly. However, when
" wincmd _ and wincmd | run, the closed uberwins may have given their screen
" space to the supwin being resized. So the counts need to be normalized by
" the supwin's change in dimension across the uberwins closing.
" WinCommonDoWithout* shouldn't have to do the normalizing because these are
" the only two commands that require it. So they have a custom implementation.
call s:DefineSpecial('WinceResizeVertical',             'wince_user#ResizeVertical')
call s:DefineSpecial('WinceResizeHorizontal',           'wince_user#ResizeHorizontal')
" This command exists because the default behaviour of z<cr> (a nop) is
" different from the default behaviour of <c-w>_
call s:DefineSpecial('WinceResizeHorizontalDefaultNop', 'wince_user#ResizeHorizontalDefaultNop')

" Movement commands are special because if the starting point is an uberwin,
" using DoWithoutUberwins would change the starting point to be the first
" supwin. But DoWithoutUberwins would be necessary because we don't want to
" move to Uberwins. So use custom logic.
call s:DefineSpecial('WinceGoLeft',  'wince_user#GoLeft' )
call s:DefineSpecial('WinceGoDown',  'wince_user#GoDown' )
call s:DefineSpecial('WinceGoUp',    'wince_user#GoUp'   )
call s:DefineSpecial('WinceGoRight', 'wince_user#GoRight')

let s:allNonSpecialCmds = {
\   'WinceDecreaseHeight':   '-',
\   'WinceDecreaseWidth':    '<',
\   'WinceEqualize':         '=',
\   'WinceGoFirst':          't',
\   'WinceGoLast':           'b',
\   'WinceGoNext':           'w',
\   'WinceIncreaseHeight':   '+',
\   'WinceIncreaseWidth':    '>',
\   'WinceMoveToBottomEdge': 'J',
\   'WinceMoveToLeftEdge':   'H',
\   'WinceMoveToNewTab':     'T',
\   'WinceMoveToRightEdge':  'L',
\   'WinceMoveToTopEdge':    'K',
\   'WinceReverseGoNext':    'W',
\   'WinceReverseRotate':    'R',
\   'WinceRotate':           'r',
\   'WinceSplitHorizontal':  's',
\   'WinceSplitVertical':    'v',
\   'WinceSplitNew':         'n',
\   'WinceSplitAlternate':   '^',
\   'WinceQuit':             'q',
\   'WinceClose':            'c',
\   'WinceGotoPreview':      'P',
\   'WinceSplitTag':         ']',
\   'WinceSplitTagSelect':   'g]',
\   'WinceSplitTagJump':     'g<c-]>',
\   'WinceSplitFilename':    'f',
\   'WinceSplitFilenameLine':'F',
\   'WincePreviewClose':     'z',
\   'WincePreviewTag':       '}',
\   'WincePreviewTagJump':   'g}',
\   'WinceSplitSearchWord':  'i',
\   'WinceSplitSearchMacro': 'd'
\} 
let s:cmdsThatPreserveCursorPos = [
\   'WinceDecreaseHeight',
\   'WinceDecreaseWidth',
\   'WinceEqualize',
\   'WinceIncreaseHeight',
\   'WinceIncreaseWidth',
\   'WinceMoveToBottomEdge',
\   'WinceMoveToLeftEdge',
\   'WinceMoveToRightEdge',
\   'WinceMoveToTopEdge',
\   'WinceReverseRotate',
\   'WinceRotate',
\   'WincePreviewClose'
\]
let s:cmdsWithUberwinNop = [
\   'WinceDecreaseHeight',
\   'WinceDecreaseWidth',
\   'WinceGoLast',
\   'WinceGoNext',
\   'WinceIncreaseHeight',
\   'WinceIncreaseWidth',
\   'WinceMoveToBottomEdge',
\   'WinceMoveToLeftEdge',
\   'WinceMoveToNewTab',
\   'WinceMoveToRightEdge',
\   'WinceMoveToTopEdge',
\   'WinceReverseGoNext',
\   'WinceReverseRotate',
\   'WinceRotate',
\   'WinceSplitHorizontal',
\   'WinceSplitVertical',
\   'WinceSplitNew',
\   'WinceSplitAlternate',
\   'WinceSplitTag',
\   'WinceSplitTagSelect',
\   'WinceSplitTagJump',
\   'WinceSplitFilename',
\   'WinceSplitFilenameLine',
\   'WinceSplitSearchWord',
\   'WinceSplitSearchMacro'
\]
let s:cmdsWithSubwinToSupwin = [
\   'WinceDecreaseHeight',
\   'WinceDecreaseWidth',
\   'WinceGoFirst',
\   'WinceGoLast',
\   'WinceGoNext',
\   'WinceIncreaseHeight',
\   'WinceIncreaseWidth',
\   'WinceMoveToBottomEdge',
\   'WinceMoveToLeftEdge',
\   'WinceMoveToNewTab',
\   'WinceMoveToRightEdge',
\   'WinceMoveToTopEdge',
\   'WinceReverseGoNext',
\   'WinceReverseRotate',
\   'WinceRotate',
\   'WinceSplitHorizontal',
\   'WinceSplitVertical',
\   'WinceSplitNew',
\   'WinceSplitAlternate',
\   'WinceSplitTag',
\   'WinceSplitTagSelect',
\   'WinceSplitTagJump',
\   'WinceSplitFilename',
\   'WinceSplitFilenameLine',
\   'WinceSplitSearchWord',
\   'WinceSplitSearchMacro'
\]
let s:cmdsWithoutUberwins = [
\   'WinceDecreaseHeight',
\   'WinceDecreaseWidth',
\   'WinceGoFirst',
\   'WinceGoLast',
\   'WinceGoNext',
\   'WinceIncreaseHeight',
\   'WinceIncreaseWidth',
\   'WinceMoveToBottomEdge',
\   'WinceMoveToLeftEdge',
\   'WinceMoveToRightEdge',
\   'WinceMoveToTopEdge',
\   'WinceMoveToNewTab',
\   'WinceReverseGoNext',
\   'WinceReverseRotate',
\   'WinceRotate'
\]
let s:cmdsWithoutSubwins = [
\   'WinceDecreaseHeight',
\   'WinceDecreaseWidth',
\   'WinceEqualize',
\   'WinceGoFirst',
\   'WinceGoLast',
\   'WinceGoNext',
\   'WinceIncreaseHeight',
\   'WinceIncreaseWidth',
\   'WinceMoveToBottomEdge',
\   'WinceMoveToLeftEdge',
\   'WinceMoveToNewTab',
\   'WinceMoveToRightEdge',
\   'WinceMoveToTopEdge',
\   'WinceReverseGoNext',
\   'WinceReverseRotate',
\   'WinceRotate',
\   'WinceSplitHorizontal',
\   'WinceSplitVertical',
\   'WinceSplitNew',
\   'WinceSplitAlternate',
\   'WinceSplitTag',
\   'WinceSplitTagSelect',
\   'WinceSplitTagJump',
\   'WinceSplitFilename',
\   'WinceSplitFilenameLine',
\   'WinceSplitSearchWord',
\   'WinceSplitSearchMacro'
\]

" Commands in this list are the ones that wince_user#DoCmdWithFlags isn't
" smart enough to handle, but the resolver is smart enough for
let s:cmdsThatRelyOnResolver = [
\   'WinceMoveToNewTab',
\   'WinceSplitHorizontal',
\   'WinceSplitVertical',
\   'WinceSplitNew',
\   'WinceSplitAlternate',
\   'WinceQuit',
\   'WinceClose',
\   'WinceGotoPreview',
\   'WinceSplitTag',
\   'WinceSplitTagSelect',
\   'WinceSplitTagJump',
\   'WinceSplitFilename',
\   'WinceSplitFilenameLine',
\   'WincePreviewClose',
\   'WincePreviewTag',
\   'WincePreviewTagJump',
\   'WinceSplitSearchWord',
\   'WinceSplitSearchMacro'
\]

for cmdname in keys(s:allNonSpecialCmds)
    call s:Define(
   \    cmdname, s:allNonSpecialCmds[cmdname],
   \    index(s:cmdsThatPreserveCursorPos,  cmdname) >= 0,
   \    index(s:cmdsWithUberwinNop,         cmdname) >= 0,
   \    index(s:cmdsWithSubwinToSupwin,     cmdname) >= 0,
   \    index(s:cmdsWithoutUberwins,        cmdname) >= 0,
   \    index(s:cmdsWithoutSubwins,         cmdname) >= 0,
   \    index(s:cmdsThatRelyOnResolver,     cmdname) >= 0
   \)
endfor
