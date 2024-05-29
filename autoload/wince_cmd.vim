" Wince Commands - Autoloaded portion
" See wince.vim

" Avoid loading twice
if exists('s:loaded')
    finish
endif
let s:loaded = 0

let s:Log = jer_log#LogFunctions('wince-commands')

" Using <range> is the natural way to check if a command's given Count is
" defaulted... but <range> is only supported as of Vim 8.0.1089. To support
" earlier versions, the magic number 1524607938 is used to pass the default.
" If anyone ever uses Wince at a large enough scale that this is the genuine
" count they wish to pass to a command, I'd be very surprised
function! wince_cmd#DefaultCount(cmdname, count)
    call s:Log.DBG('DefaultCount ', a:cmdname, ', ', a:count)
    if a:count ==# 1524607938
        call s:Log.VRB('Defaulting count to empty string')
        return ''
    endif

    call s:Log.VRB('Using given count ', a:count)
    return a:count
endfunction

function! wince_cmd#Run(cmdname, wincmd, count, startmode,
                       \ preservecursor,
                       \ ifuberwindonothing,
                       \ ifsubwingotosupwin,
                       \ dowithoutuberwins,
                       \ dowithoutsubwins,
                       \ relyonresolver)
    call s:Log.INF('wince_cmd#Run ' . a:cmdname . ', ' . a:wincmd . ', [' . a:count . ',' . string(a:startmode) . ',' . a:preservecursor . ',' . a:ifuberwindonothing . ',' . a:ifsubwingotosupwin . ',' . a:dowithoutuberwins . ',' . a:dowithoutsubwins . ',' . a:relyonresolver . ']')
    try
        let opcount = wince_cmd#DefaultCount(a:cmdname, a:count)
    catch /.*/
        call s:Log.ERR(v:exception)
        return a:startmode
    endtry

    return wince_user#DoCmdWithFlags(a:wincmd, opcount, a:startmode,
                                    \ a:preservecursor,
                                    \ a:ifuberwindonothing,
                                    \ a:ifsubwingotosupwin,
                                    \ a:dowithoutuberwins,
                                    \ a:dowithoutsubwins,
                                    \ a:relyonresolver)
endfunction

function! wince_cmd#RunSpecial(cmdname, count, startmode, handler)
    call s:Log.INF('wince_cmd#RunSpecial ', a:cmdname, ', [', a:count, ',', a:startmode, '], ', a:handler)
    try
        let opcount = wince_cmd#DefaultCount(a:cmdname, a:count)
        let Handler = function(a:handler)

        return Handler(opcount, a:startmode)
    catch /.*/
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
        return a:startmode
    endtry
endfunction

