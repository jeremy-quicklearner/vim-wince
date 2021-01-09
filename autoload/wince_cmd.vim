" Wince Commands - Autoloaded portion
" See wince.vim
let s:Log = jer_log#LogFunctions('wince-commands')

function! wince_cmd#SanitizeRange(cmdname, range, count, defaultcount)
    call s:Log.DBG('SanitizeRange ', a:cmdname, ', [', a:range, ',', a:count, ',', a:defaultcount, ']')
    if a:range ==# 0
        call s:Log.VRB('Using default count ', a:defaultcount)
        return a:defaultcount
    endif

    if a:range ==# 1
        call s:Log.VRB('Using given count ', a:count)
        return a:count
    endif
     
    if a:range ==# 2
        throw 'Range not allowed for ' . a:cmdname
    endif

    throw 'Invalid <range> ' . a:range
endfunction

function! wince_cmd#Run(cmdname, wincmd, range, count, startmode,
                       \ defaultcount,
                       \ preservecursor,
                       \ ifuberwindonothing,
                       \ ifsubwingotosupwin,
                       \ dowithoutuberwins,
                       \ dowithoutsubwins,
                       \ relyonresolver)
    call s:Log.INF('wince_cmd#Run ' . a:cmdname . ', ' . a:wincmd . ', [' . a:range . ',' . a:count . ',' . string(a:startmode) . ',' . a:defaultcount . ',' . a:preservecursor . ',' . a:ifuberwindonothing . ',' . a:ifsubwingotosupwin . ',' . a:dowithoutuberwins . ',' . a:dowithoutsubwins . ',' . a:relyonresolver . ']')
    try
        let opcount = wince_cmd#SanitizeRange(a:cmdname, a:range, a:count, a:defaultcount)
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

function! wince_cmd#RunSpecial(cmdname, range, count, startmode, handler)
    call s:Log.INF('wince_cmd#RunSpecial ', a:cmdname, ', [', a:range, ',', a:count, ',', a:startmode, '], ', a:handler)
    try
        let opcount = wince_cmd#SanitizeRange(a:cmdname, a:range, a:count, '')
        let Handler = function(a:handler)

        return Handler(opcount, a:startmode)
    catch /.*/
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
        return a:startmode
    endtry
endfunction

