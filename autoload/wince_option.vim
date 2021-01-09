" Wince Reference Definition for Option uberwin - autoloaded portion
let s:Log = jer_log#LogFunctions('wince-option-uberwin')
let s:Win = jer_win#WinFunctions()

" Helper that silently jumps to t:prevwin and back
function! wince_option#GoPrev()
    let prev = wince_model#PreviousWinInfo()
    let previd = wince_model#IdByInfo(prev)
    call wince_state#MoveCursorToWinidSilently(previd)
    noautocmd silent wincmd p
endfunction

let s:sid = -1

" Callback that opens the option window
function! wince_option#ToOpen()
    call s:Log.INF('wince_option#ToOpen')
    if bufwinnr('option-window') >=# 0
        throw 'Option window already open'
    endif

    let prevwinid = s:Win.getid()

    " The option window always splits using the 'new' command with no
    " modifiers, so 'vertical options' won't work. Instead, create an
    " ephemeral window and open the option window from there.  This
    " wonkiness with the widths avoids Vim equalizing other windows'
    " sizes
    if g:wince_option_right
        noautocmd silent vertical botright 1split
    else
        execute 'noautocmd silent vertical topleft ' . g:wince_option_width . 'split'
    endif

    " Open the log buffer in the ephemeral window to ensure there are no issues
    " closing it later
    noautocmd silent buffer jersuite_buflog

    let &l:scrollbind = 0
    let &l:cursorbind = 0
    execute 'noautocmd vertical resize ' . g:wince_option_width
    noautocmd silent options
    noautocmd wincmd j
    quit
    options

    " After creating the option window, optwin.vim uses noremap with <SID> to
    " map <cr> and <space>:
    "     noremap <silent> <buffer> <CR> <C-\><C-N>:call <SID>CR()<CR>
    "     inoremap <silent> <buffer> <CR> <Esc>:call <SID>CR()<CR>
    "     noremap <silent> <buffer> <Space> :call <SID>Space()<CR>
    " These mappings then internally use 'wincmd p' to determine which window to
    " set local options for. This is undesirable because the resolver and user
    " operations are always moving the cursor all over the place, and the
    " previous window Vim stores for wincmd p isn't meaningful to the user.
    " Wince stores a more meaningful previous window in the model under
    " t:prevwin, but optwin.vim is part of Vim's runtime and therefore cannot
    " be changed to use t:prevwin instead of wincmd p.
    " A workaround is used - replace the mappings created in optwin.vim with new
    " mappings that silently move the cursor to t:prevwin and back, thus setting
    " wincmd p's 'previous window', right before doing what the original
    " mappings do.
    " Since <SID> evaluates to a script-unique value, that value must be
    " extracted from optwin.vim's mappings (which we can read using mapcheck())
    " and re-injected into the replacement mappings
    " The noremap commands in optwin.vim run every time the 'options' command is
    " invoked, so the new mappings need to be created on every
    " wince_option#ToOpen
    " call.
    if s:sid <# 0
        let crmap = mapcheck("<cr>")
        let snr = substitute(crmap, '<C-\\><C-N>:call <SNR>\(\d\+\)_CR()<CR>', '\1', '')
        let s:sid = '<SNR>_' . snr
    endif

    execute 'noremap <silent> <buffer> <CR> <C-\><C-N>:call wince_option#GoPrev()<CR>:call ' . s:sid . 'CR()<CR>'
    execute 'inoremap <silent> <buffer> <CR> <Esc>:call wince_option#GoPrev()<CR>:call ' . s:sid . 'CR()<CR>'
    execute 'noremap <silent> <buffer> <Space> :call wince_option#GoPrev()<CR>:call ' . s:sid . 'Space()<CR>'

    let winid = s:Win.getid()

    noautocmd call s:Win.gotoid(prevwinid)

    return [winid]
endfunction

" Callback that closes the option window
function! wince_option#ToClose()
    call s:Log.INF('wince_option#ToClose')
    let optionwinid = 0
    for winnr in range(1, winnr('$'))
        if wince_state#GetBufnrByWinidOrWinnr(winnr) ==# bufnr('option-window')
            let optionwinid = s:Win.getid(winnr)
        endif
    endfor

    if !optionwinid
        throw 'Option window is not open'
    endif

    call wince_state#MoveCursorToWinidSilently(optionwinid)
    quit
endfunction

" Callback that returns 'option' if the supplied winid is for the option
" window
function! wince_option#ToIdentify(winid)
    call s:Log.DBG('wince_option#ToIdentify ', a:winid)
    if wince_state#GetBufnrByWinidOrWinnr(a:winid) ==# bufnr('option-window')
        return 'option'
    endif
    return ''
endfunction

function! wince_option#StatusLine()
    call s:Log.DBG('OptionStatusLine')
    let statusline = ''

    " 'Option' string
    let statusline .= '%6*[Option]'

    " Start truncating
    let statusline .= '%<'

    " Buffer number
    let statusline .= '%1*[%n]'

    " Targetted window
    let target = wince_model#CurrentWinInfo()
    if target.category ==# 'uberwin' && target.grouptype ==# 'option'
        let target = wince_model#PreviousWinInfo()
    endif
    
    let targetstr = ''
    if target.category ==# 'uberwin'
        let targetstr = target.grouptype . ':' . target.typename
    elseif target.category ==# 'supwin'
        let targetstr = target.id
    elseif target.category == 'subwin'
        let targetstr = target.supwin . ':' . target.grouptype . ':' . target.typename
    else
        let targetstr = 'NULL'
    endif
    let statusline .= '[For window ' . targetstr . ']'

    " Right-justify from now on
    let statusline .= '%=%<'
   
    " [Column][Current line/Total lines][% of buffer]
    let statusline .= '%6*[%c][%l/%L][%p%%]'

    return statusline
endfunction

