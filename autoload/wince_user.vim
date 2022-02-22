" Wince User Operations

" Avoid loading twice
if exists('s:loaded')
    finish
endif
let s:loaded = 0

" See wince.vim
let s:Log = jer_log#LogFunctions('wince-user')
let s:t = jer_util#Types()

" Resolver callback registration

" Register a callback to run at the beginning of the resolver, when the
" resolver runs for the first time after entering a tab
function! wince_user#AddTabEnterPreResolveCallback(callback)
    call wince_model#AddTabEnterPreResolveCallback(a:callback)
    call s:Log.CFG('TabEnter pre-resolve callback: ', a:callback)
endfunction

" Register a callback to run after any successful user operation that changes
" the state or model and leaves them consistent
function! wince_user#AddPostUserOperationCallback(callback)
    call wince_model#AddPostUserOperationCallback(a:callback)
    call s:Log.CFG('Post-user operation callback: ', a:callback)
endfunction

function! s:RunPostUserOpCallbacks()
    call s:Log.DBG('Running post-user-operation callbacks')
    for PostUserOpCallback in wince_model#PostUserOperationCallbacks()
        call s:Log.VRB('Running post-user-operation callback ', PostUserOpCallback)
        call PostUserOpCallback()
    endfor
endfunction

" Group Types

" Add an uberwin group type. One uberwin group type represents one or more uberwins
" which are opened together
" one window
" name:           The name of the uberwin group type
" typenames:      The names of the uberwin types in the group
" statuslines:    The statusline strings of the uberwin types in the group
" flag:           Flag to insert into the tabline when the uberwins are shown
" hidflag:        Flag to insert into the tabline when the uberwins are hidden
" flagcol:        Number between 1 and 9 representing which User highlight group
"                 to use for the tabline flag
" priority:       uberwin groups will be opened in order of ascending priority
" canHaveLoclist: Flag (one for each uberwin type in the group) signifying
"                 whether uberwins of that type are allowed to have location lists
" widths:         Widths of uberwins. -1 means variable width.
" heights:        Heights of uberwins. -1 means variable height.
" toOpen:         Function that opens uberwins of this group type and returns their
"                 window IDs. This function is required not to move the cursor
"                 between windows before opening the uberwins
" toClose:        Function that closes the uberwins of this group type.
" toIdentify:     Function that, when called in an uberwin of a type from this group
"                 type, returns the type name. Returns an empty string if called from
"                 any other window
function! wince_user#AddUberwinGroupType(name, typenames, statuslines,
                                \flag, hidflag, flagcol,
                                \priority, canHaveLoclist,
                                \widths, heights, toOpen, toClose,
                                \toIdentify)
    call wince_model#AddUberwinGroupType(a:name, a:typenames, a:statuslines,
                                    \a:flag, a:hidflag, a:flagcol,
                                    \a:priority, a:canHaveLoclist,
                                    \a:widths, a:heights,
                                    \a:toOpen, a:toClose, a:toIdentify)
    call s:Log.CFG('Uberwin group type: ', a:name)
endfunction

" Add a subwin group type. One subwin group type represents the types of one or more
" subwins which are opened together
" one window
" name:                The name of the subwin group type
" typenames:           The names of the subwin types in the group
" statuslines:         The statusline strings of the subwin types in the group
" flag:                Flag to insert into the statusline of the supwin of subwins of
"                      types in this group type when the subwins are shown
" hidflag:             Flag to insert into the statusline of the supwin of subwins of
"                      types in this group type when the subwins are hidden
" flagcol:             Number between 1 and 9 representing which User highlight group
"                      to use for the statusline flag
" priority:            Subwins for a supwin will be opened in order of ascending
"                      priority
" afterimaging:        List of flags for each subwin type in the group. If true,
"                      afterimage
"                      subwins of that type when they and their supwin lose focus
" canHaveLoclist:      Flag (one for each subwin type in the group) signifying
"                      whether subwins of that type are allowed to have location lists
" stompWithBelowRight: Value to use for the the 'splitbelow' and 'splitright'
"                      options when bypassing ToClose and closing windows of
"                      this group type directly. Set this to 0 if your subwin
"                      group opens above or to the left of the supwin, and to 1
"                      otherwise.
" widths:              Widths of subwins. -1 means variable width.
" heights:             Heights of subwins. -1 means variable height.
" toOpen:              Function that, when called from the supwin, opens subwins of these
"                      types and returns their window IDs.
" toClose:             Function that, when called from a supwin, closes the the subwins of
"                      this group type for the supwin.
" toIdentify:          Function that, when called in a subwin of a type from this group
"                      type, returns a dict with the type name and supwin ID (with keys
"                      'typename' and 'supwin' repspectively). Returns an enpty dict if
"                      called from any other window
function! wince_user#AddSubwinGroupType(name, typenames, statuslines,
                               \flag, hidflag, flagcol,
                               \priority, afterimaging, canHaveLoclist, stompWithBelowRight,
                               \widths, heights,
                               \toOpen, toClose, toIdentify)
    call wince_model#AddSubwinGroupType(a:name, a:typenames, a:statuslines,
                                   \a:flag, a:hidflag, a:flagcol,
                                   \a:priority, a:afterimaging, a:canHaveLoclist, a:stompWithBelowRight,
                                   \a:widths, a:heights,
                                   \a:toOpen, a:toClose, a:toIdentify)
    call s:Log.CFG('Subwin group type: ', a:name)
endfunction

" Uberwins

" For tabline generation
function! wince_user#UberwinFlagsStr()
    " Due to a bug in Vim, this function sometimes throws E315 in terminal
    " windows
    try
        call s:Log.DBG('Retrieving Uberwin flags string')
        return wince_model#UberwinFlagsStr()
    catch /.*/
        call s:Log.DBG('Failed to retrieve Uberwin flags: ')
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
        return ''
    endtry
endfunction

function! s:AddUberwinGroupGivenNoSubwins(grouptypename, suppresserror)
    call s:Log.DBG('AddUberwinGroupGivenNoSubwins ', a:grouptypename, ' ', a:suppresserror)
    " Each uberwin must be, at the time it is opened, the one with the
    " highest priority. So close all uberwins with higher priority.
    let highertypes = wince_common#CloseUberwinsWithHigherPriorityThan(a:grouptypename)
    call s:Log.VRB('Closed higher-priority uberwin groups ', highertypes)
    try
        try
            let winids = wince_common#OpenUberwins(a:grouptypename)
            call s:Log.VRB('Opened uberwin group ', a:grouptypename, ' in state with winids ', winids)
            " Initially add to model with dummy dimensions since reopening
            " higher-priority uberwins may change nr anyway. Dimensions
            " will be properly recorded by wince_common#RecordAllDimensions
            call wince_model#AddUberwins(a:grouptypename, winids, [])
            call s:Log.VRB('Added uberwin group ', a:grouptypename, ' to model')
        catch /.*/
            if !a:suppresserror
                call s:Log.WRN('wince_user#AddUberwinGroup failed to open ', a:grouptypename, ' uberwin group:')
                call s:Log.DBG(v:throwpoint)
                call s:Log.WRN(v:exception)
            endif

            " Failed to add as shown, so add as hidden
            call wince_model#AddUberwins(a:grouptypename, [], [])

            return
        endtry

    " Reopen the uberwins we closed
    finally
        call wince_common#ReopenUberwins(highertypes)
        call s:Log.VRB('Reopened higher-priority uberwins groups')
    endtry
endfunction
function! wince_user#AddUberwinGroup(grouptypename, hidden, suppresserror)
    try
        call wince_model#AssertUberwinGroupDoesntExist(a:grouptypename)
    catch /.*/
        if a:suppresserror
            return
        endif
        call s:Log.DBG('wince_user#AddUberwinGroup cannot add uberwin group ', a:grouptypename, ': ')
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
        return
    endtry

    " If we're adding the uberwin group as hidden, add it only to the model
    if a:hidden
        call s:Log.INF('wince_user#AddUberwinGroup hidden ', a:grouptypename)
        call wince_model#AddUberwins(a:grouptypename, [], [])
        call s:RunPostUserOpCallbacks()
        return
    endif
    
    call s:Log.INF('wince_user#AddUberwinGroup shown ', a:grouptypename)

    let info = wince_common#GetCursorPosition()
    call s:Log.VRB('Preserved cursor position ', info)
    try
        call wince_common#DoWithoutSubwins(info.win, function('s:AddUberwinGroupGivenNoSubwins'), [a:grouptypename, a:suppresserror], 0)
        call wince_common#RecordAllDimensions()
    finally
        call wince_common#RestoreCursorPosition(info)
        call s:Log.VRB('Restored cursor position')
        call s:RunPostUserOpCallbacks()
    endtry
endfunction

function! wince_user#RemoveUberwinGroup(grouptypename)
    try
        call wince_model#AssertUberwinGroupExists(a:grouptypename)
    catch /.*/
        call s:Log.DBG('wince_user#RemoveUberwinGroup cannot remove uberwin group ', a:grouptypename, ':')
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
        return
    endtry

    call s:Log.INF('wince_user#RemoveUberwinGroup ', a:grouptypename)

    let info = wince_common#GetCursorPosition()
    call s:Log.VRB('Preserved cursor position ', info)
    try
        if !wince_model#UberwinGroupIsHidden(a:grouptypename)
            call wince_common#DoWithoutSubwins(info.win, function('wince_common#CloseUberwinsByGroupTypeName'), [a:grouptypename], 0)
            call s:Log.VRB('Closed uberwin group ', a:grouptypename, ' in state')
        endif

        call wince_model#RemoveUberwins(a:grouptypename)
        call s:Log.VRB('Removed uberwin group ', a:grouptypename, ' from model')
        call wince_common#RecordAllDimensions()

    finally
        call wince_common#RestoreCursorPosition(info)
        call s:Log.VRB('Restored cursor position')
        call s:RunPostUserOpCallbacks()
    endtry
endfunction

function! wince_user#HideUberwinGroup(grouptypename)
    try
        call wince_model#AssertUberwinGroupIsNotHidden(a:grouptypename)
    catch /.*/
        call s:Log.DBG('wince_user#HideUberwinGroup cannot hide uberwin group ', a:grouptypename, ': ')
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
        return
    endtry

    call s:Log.INF('wince_user#HideUberwinGroup ', a:grouptypename)

    let info = wince_common#GetCursorPosition()
    call s:Log.VRB('Preserved cursor position ', info)
    try
        call wince_common#DoWithoutSubwins(info.win, function('wince_common#CloseUberwinsByGroupTypeName'), [a:grouptypename], 0)
        call s:Log.VRB('Closed uberwin group ', a:grouptypename, ' in state')
        call wince_model#HideUberwins(a:grouptypename)
        call s:Log.VRB('Hid uberwin group ', a:grouptypename, ' in model')
        call wince_common#RecordAllDimensions()

    finally
        call wince_common#RestoreCursorPosition(info)
        call s:Log.VRB('Restored cursor position')
        call s:RunPostUserOpCallbacks()
    endtry
endfunction

function! s:ShowUberwinGroupGivenNoSubwins(grouptypename, suppresserror)
    call s:Log.DBG('ShowUberwinGroupGivenNoSubwins ', a:grouptypename, ' ', a:suppresserror)
    " Each uberwin must be, at the time it is opened, the one with the
    " highest priority. So close all uberwins with higher priority.
    let highertypes = wince_common#CloseUberwinsWithHigherPriorityThan(a:grouptypename)
    call s:Log.VRB('Closed higher-priority uberwin groups ', highertypes)
    try
        try
            let winids = wince_common#OpenUberwins(a:grouptypename)
            call s:Log.VRB('Opened uberwin group ', a:grouptypename, ' in state with winids ', winids)
            " Initially add to model with dummy dimensions since reopening
            " higher-priority uberwins may change nr anyway. Dimensions
            " will be properly recorded by wince_common#RecordAllDimensions
            call wince_model#ShowUberwins(a:grouptypename, winids, [])
            call s:Log.VRB('Showed uberwin group ', a:grouptypename, ' in model')

        catch /.*/
            if a:suppresserror
                return
            endif
            call s:Log.WRN('wince_user#ShowUberwinGroup failed to open ', a:grouptypename, ' uberwin group:')
            call s:Log.DBG(v:throwpoint)
            call s:Log.WRN(v:exception)
            return
        endtry
    " Reopen the uberwins we closed
    finally
        call wince_common#ReopenUberwins(highertypes)
        call s:Log.VRB('Reopened higher-priority uberwins groups')
    endtry
endfunction
function! wince_user#ShowUberwinGroup(grouptypename, suppresserror)
    try
        call wince_model#AssertUberwinGroupIsHidden(a:grouptypename)
    catch /.*/
        if a:suppresserror
            return
        endif
        call s:Log.DBG('wince_user#ShowUberwinGroup cannot show uberwin group ', a:grouptypename, ': ')
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
        return
    endtry

    call s:Log.INF('wince_user#ShowUberwinGroup ', a:grouptypename)

    let info = wince_common#GetCursorPosition()
    call s:Log.VRB('Preserved cursor position ', info)
    try
        call wince_common#DoWithoutSubwins(info.win, function('s:ShowUberwinGroupGivenNoSubwins'), [a:grouptypename, a:suppresserror], 0)
        call wince_common#RecordAllDimensions()
    finally
        call wince_common#RestoreCursorPosition(info)
        call s:Log.VRB('Restored cursor position')
        call s:RunPostUserOpCallbacks()
    endtry
endfunction

" Subwins

" For supwins' statusline generation
function! wince_user#SubwinFlagsForGlobalStatusline()
    let flagsstr = ''

    " Due to a bug in Vim, these functions sometimes throw E315 in terminal
    " windows
    try
        call s:Log.DBG('Retrieving subwin flags string for current supwin')
        for grouptypename in wince_model#SubwinGroupTypeNames()
            call s:Log.VRB('Retrieving subwin flags string for subwin ', grouptypename, ' of current supwin')
            let flagsstr .= wince_common#SubwinFlagStrByGroup(grouptypename)
        endfor
    catch /.*/
        call s:Log.DBG('Failed to retrieve Subwin flags: ')
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
        return ''
    endtry

    call s:Log.VRB('Subwin flags string for current supwin: ', flagsstr)
    return flagsstr
endfunction

function! wince_user#AddSubwinGroup(winid, grouptypename, hidden, suppresserror)
    if !a:winid
        let winid = wince_state#GetCursorWinId()
    else
        let winid = a:winid
    endif
    try
        let supwinid = wince_model#SupwinIdBySupwinOrSubwinId(winid)
        call wince_model#AssertSubwinGroupDoesntExist(supwinid, a:grouptypename)
    catch /.*/
        if a:suppresserror
            return
        endif
        call s:Log.DBG('wince_user#AddSubwinGroup cannot add subwin group ', supwinid, ':', a:grouptypename, ': ')
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
        return
    endtry

    " If we're adding the subwin group as hidden, add it only to the model
    if a:hidden
        call s:Log.INF('wince_user#AddSubwinGroup hidden ', supwinid, ':', a:grouptypename)
        call wince_model#AddSubwins(supwinid, a:grouptypename, [], [])
        call s:RunPostUserOpCallbacks()
        return
    endif

    call s:Log.INF('wince_user#AddSubwinGroup shown ', supwinid, ':', a:grouptypename)
    let info = wince_common#GetCursorPosition()
    call s:Log.VRB('Preserved cursor position ', info)
    try
        " Each subwin must be, at the time it is opened, the one with the
        " highest priority for its supwin. So close all supwins with higher priority.
        let highertypes = wince_common#CloseSubwinsWithHigherPriorityThan(supwinid, a:grouptypename)
        call s:Log.VRB('Closed higher-priority subwin groups for supwin ', supwinid, ': ', highertypes)
        let opened = -1
        try
            try
                let winids = wince_common#OpenSubwins(supwinid, a:grouptypename)
                call s:Log.VRB('Opened subwin group ', supwinid, ':', a:grouptypename, ' in state with winids ', winids)
                " Initially add to model with dummy dimensions since reopening
                " higher-priority subwins may change relnr anyway. Dimensions
                " will be properly recorded by wince_common#RecordAllDimensions
                call wince_model#AddSubwins(supwinid, a:grouptypename, winids, [])
                call s:Log.VRB('Added subwin group ', supwinid, ':', a:grouptypename, ' to model')
                let opened = 1
            catch /.*/
                if !a:suppresserror
                    call s:Log.WRN('wince_user#AddSubwinGroup failed to open ', a:grouptypename, ' subwin group for supwin ', supwinid, ':')
                    call s:Log.DBG(v:throwpoint)
                    call s:Log.WRN(v:exception)
                endif
                call wince_model#AddSubwins(supwinid, a:grouptypename, [], [])
                let opened = 0
            endtry

        " Reopen the subwins we closed
        finally
            call wince_common#ReopenSubwins(supwinid, highertypes)
            call s:Log.VRB('Reopened higher-priority subwin groups')
            if opened
                call wince_common#RecordAllDimensions()
            endif
        endtry

    finally
        call wince_common#RestoreCursorPosition(info)
        call s:Log.VRB('Restored cursor position')
        call s:RunPostUserOpCallbacks()
    endtry
endfunction

function! wince_user#RemoveSubwinGroup(winid, grouptypename)
    if !a:winid
        let winid = wince_state#GetCursorWinId()
    else
        let winid = a:winid
    endif
    try
        let supwinid = wince_model#SupwinIdBySupwinOrSubwinId(winid)
        call wince_model#AssertSubwinGroupExists(supwinid, a:grouptypename)
    catch /.*/
        call s:Log.DBG('wince_user#RemoveSubwinGroup cannot remove subwin group ', supwinid, ':', a:grouptypename, ': ')
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
        return
    endtry

    call s:Log.INF('wince_user#RemoveSubwinGroup ', supwinid, ':', a:grouptypename)
    let info = wince_common#GetCursorPosition()
    call s:Log.VRB('Preserved cursor position ', info)
    try

        let closed = 0
        if !wince_model#SubwinGroupIsHidden(supwinid, a:grouptypename)
            call wince_common#CloseSubwins(supwinid, a:grouptypename)
            call s:Log.VRB('Closed subwin group ', supwinid, ':', a:grouptypename, ' in state')
            let closed = 1
        endif

        call wince_model#RemoveSubwins(supwinid, a:grouptypename)
        call s:Log.VRB('Removed subwin group ', supwinid, ':', a:grouptypename, ' from model')

        if closed
            call wince_common#CloseAndReopenSubwinsWithHigherPriorityBySupwin(
           \    supwinid,
           \    a:grouptypename
           \)
            call s:Log.VRB('Closed and reopened all shown subwins of supwin ', supwinid, ' with priority higher than ', a:grouptypename)
        endif

    finally
        call wince_common#RecordAllDimensions()
        call wince_common#RestoreCursorPosition(info)
        call s:Log.VRB('Restored cursor position')
        call s:RunPostUserOpCallbacks()
    endtry
endfunction

function! wince_user#HideSubwinGroup(winid, grouptypename)
    if !a:winid
        let winid = wince_state#GetCursorWinId()
    else
        let winid = a:winid
    endif
    try
        let supwinid = wince_model#SupwinIdBySupwinOrSubwinId(winid)
        call wince_model#AssertSubwinGroupIsNotHidden(supwinid, a:grouptypename)
    catch /.*/
        call s:Log.DBG('wince_user#HideSubwinGroup cannot hide subwin group ', winid, ':', a:grouptypename, ': ')
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
        return
    endtry

    call s:Log.INF('wince_user#HideSubwinGroup ', a:grouptypename)
    let info = wince_common#GetCursorPosition()
    call s:Log.VRB('Preserved cursor position ', info)
    try
        call wince_common#CloseSubwins(supwinid, a:grouptypename)
        call s:Log.VRB('Closed subwin group ', supwinid, ':', a:grouptypename, ' in state')
        call wince_model#HideSubwins(supwinid, a:grouptypename)
        call s:Log.VRB('Hid subwin group ', supwinid, ':', a:grouptypename, ' in model')
        call wince_common#CloseAndReopenSubwinsWithHigherPriorityBySupwin(
       \    supwinid,
       \    a:grouptypename
       \)
        call s:Log.VRB('Closed and reopened all shown subwins of supwin ', supwinid, ' with priority higher than ', a:grouptypename)

    finally
        call wince_common#RecordAllDimensions()
        call wince_common#RestoreCursorPosition(info)
        call s:Log.VRB('Restored cursor position')
        call s:RunPostUserOpCallbacks()
    endtry
endfunction

function! wince_user#ShowSubwinGroup(srcid, grouptypename, suppresserror)
    if !a:srcid
        let srcid = wince_state#GetCursorWinId()
    else
        let srcid = a:srcid
    endif
    try
        let supwinid = wince_model#SupwinIdBySupwinOrSubwinId(srcid)
        call wince_model#AssertSubwinGroupIsHidden(supwinid, a:grouptypename)
    catch /.*/
        if a:suppresserror
            return
        endif
        call s:Log.DBG('wince_user#ShowSubwinGroup cannot show subwin group ', srcid, ':', a:grouptypename, ': ')
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
        return
    endtry

    call s:Log.INF('wince_user#ShowSubwinGroup ', supwinid, ':', a:grouptypename)
    let info = wince_common#GetCursorPosition()
    call s:Log.VRB('Preserved cursor position ', info)
    try
        " Each subwin must be, at the time it is opened, the one with the
        " highest priority for its supwin. So close all supwins with higher priority.
        let highertypes = wince_common#CloseSubwinsWithHigherPriorityThan(supwinid, a:grouptypename)
        call s:Log.VRB('Closed higher-priority subwin groups for supwin ', supwinid, ': ', highertypes)
        let opened = -1
        try
            try
                let winids = wince_common#OpenSubwins(supwinid, a:grouptypename)
                call s:Log.VRB('Opened subwin group ', supwinid, ':', a:grouptypename, ' in state with winids ', winids)
                " Initially add to model with dummy dimensions since reopening
                " higher-priority subwins may change relnr anyway. Dimensions
                " will be properly recorded by wince_common#RecordAllDimensions
                call wince_model#ShowSubwins(supwinid, a:grouptypename, winids, [])
                call s:Log.VRB('Showed subwin group ', supwinid, ':', a:grouptypename, ' in model')
                let opened = 1
            catch /.*/
                if a:suppresserror
                    return
                endif
                call s:Log.WRN('wince_user#ShowSubwinGroup failed to open ', a:grouptypename, ' subwin group for supwin ', supwinid, ':')
                call s:Log.DBG(v:throwpoint)
                call s:Log.WRN(v:exception)
                let opened = 0
            endtry

        " Reopen the subwins we closed
        finally
            call wince_common#ReopenSubwins(supwinid, highertypes)
            call s:Log.VRB('Reopened higher-priority subwin groups')
            if opened
                call wince_common#RecordAllDimensions()
            endif
        endtry

    finally
        call wince_common#RestoreCursorPosition(info)
        call s:Log.VRB('Restored cursor position')
        call s:RunPostUserOpCallbacks()
    endtry
endfunction

" Retrieve subwins and supwins' statuslines from the model
function! wince_user#NonDefaultStatusLine()
    call s:Log.DBG('Retrieving non-default statusline for current window')
    let info = wince_common#GetCursorPosition().win
    return wince_model#StatusLineByInfo(info)
endfunction

" Execute a Ctrl-W command under various conditions specified by flags
" WARNING! This particular user operation is not guaranteed to leave the state
" and model consistent. It is designed to be used only by the Commands and
" Mappings, which ensure consistency by passing carefully-chosen flags.
" In particular, the 'relyonresolver' flag causes the resolver to be invoked
" at the end of the operation
function! wince_user#DoCmdWithFlags(cmd,
                            \ count,
                            \ startmode,
                            \ preservecursor,
                            \ ifuberwindonothing, ifsubwingotosupwin,
                            \ dowithoutuberwins, dowithoutsubwins,
                            \ relyonresolver)
    call s:Log.INF('wince_user#DoCmdWithFlags ' . a:cmd . ' ' . a:count . ' ' . string(a:startmode) . ' [' . a:preservecursor . ',' . a:ifuberwindonothing . ',' . a:ifsubwingotosupwin . ',' . a:dowithoutuberwins . ',' . a:dowithoutsubwins . ',' . ',' . a:relyonresolver . ']')
    let info = wince_common#GetCursorPosition()
    call s:Log.VRB('Preserved cursor position ', info)

    if a:ifuberwindonothing && info.win.category ==# 'uberwin'
        call s:Log.WRN('Cannot run wincmd ', a:cmd, ' in uberwin')
        return a:startmode
    endif

    let endmode = a:startmode
    if a:ifsubwingotosupwin && info.win.category ==# 'subwin'
        call s:Log.DBG('Going from subwin to supwin')
        " Drop the mode. It'll be restored from a:startmode if we restore the
        " cursor position
        let endmode = wince_user#GotoSupwin(info.win.supwin, 0)
    endif

    let cmdinfo = wince_common#GetCursorPosition()
    call s:Log.VRB('Running command from window ', cmdinfo)

    let reselect = !a:relyonresolver

    try
        if a:dowithoutuberwins && a:dowithoutsubwins
            call s:Log.DBG('Running command without uberwins or subwins')
            let endmode = wince_common#DoWithoutUberwinsOrSubwins(cmdinfo.win, function('wince_state#Wincmd'), [a:count, a:cmd, endmode], reselect)
        elseif a:dowithoutuberwins
            call s:Log.DBG('Running command without uberwins')
            let endmode = wince_common#DoWithoutUberwins(cmdinfo.win, function('wince_state#Wincmd'), [a:count, a:cmd, endmode], reselect)
        elseif a:dowithoutsubwins
            call s:Log.DBG('Running command without subwins')
            let endmode = wince_common#DoWithoutSubwins(cmdinfo.win, function('wince_state#Wincmd'), [a:count, a:cmd, endmode], reselect)
        else
            call s:Log.DBG('Running command')
            let endmode = wince_state#Wincmd(a:count, a:cmd, endmode)
        endif
    catch /.*/
        call s:Log.DBG('wince_user#DoCmdWithFlags failed: ')
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
        return endmode
    finally
        if a:relyonresolver
            " This call to the resolver from the user operations is
            " an unfortunate architectural violation, but it doesn't
            " introduce any dependency issues. The user operations
            " just depend on the resolver.
            call wince_resolve#Resolve()
            let endmode = {'mode':'n'}
        else
            call wince_common#RecordAllDimensions()
        endif
        let endinfo = wince_common#GetCursorPosition()
        if a:preservecursor
            call wince_common#RestoreCursorPosition(info)
            let endmode = a:startmode
            call s:Log.VRB('Restored cursor position')
        elseif !a:relyonresolver && wince_model#IdByInfo(info.win) !=# wince_model#IdByInfo(endinfo.win)
            call wince_model#SetPreviousWinInfo(info.win)
            call wince_model#SetCurrentWinInfo(endinfo.win)
        endif
        call s:RunPostUserOpCallbacks()
    endtry
    return endmode
endfunction

" Navigation

" Movement between different categories of windows is restricted and sometimes
" requires afterimaging and deafterimaging
function! s:GoUberwinToUberwin(dstgrouptypename, dsttypename, startmode, suppresserror)
    try
        call wince_model#AssertUberwinTypeExists(a:dstgrouptypename, a:dsttypename)
    catch /.*/
        if a:suppresserror
            return
        endif
        call s:Log.DBG('GoUberwinToUberwin failed: ')
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
        return
    endtry

    call s:Log.DBG('GoUberwinToUberwin ', a:dstgrouptypename, ':', a:dsttypename)
    if wince_model#UberwinGroupIsHidden(a:dstgrouptypename)
        call wince_user#ShowUberwinGroup(a:dstgrouptypename, a:suppresserror)
        call s:Log.INF('Showing uberwin group ', a:dstgrouptypename, ' so that the cursor can be moved to its uberwin ', a:dsttypename)
    endif
    let winid = wince_model#IdByInfo({
   \    'category': 'uberwin',
   \    'grouptype': a:dstgrouptypename,
   \    'typename': a:dsttypename
   \})
    call s:Log.VRB('Destination winid is ', winid)
    return wince_state#MoveCursorToWinidAndUpdateMode(winid, a:startmode)
endfunction

function! s:GoUberwinToSupwin(dstsupwinid, startmode)
    call s:Log.DBG('GoUberwinToSupwin ', a:dstsupwinid, ' ', a:startmode)
    let endmode = wince_state#MoveCursorToWinidAndUpdateMode(a:dstsupwinid, a:startmode)
    let cur = wince_common#GetCursorPosition()
    call s:Log.VRB('Preserved cursor position ', cur)
    call s:Log.VRB('Deafterimaging subwins of destination supwin ', a:dstsupwinid)
    call wince_common#DeafterimageSubwinsBySupwin(a:dstsupwinid)
    call wince_common#RestoreCursorPosition(cur)
    call s:Log.VRB('Restored cursor position')
    return endmode
endfunction

function! s:GoSupwinToUberwin(srcsupwinid, dstgrouptypename, dsttypename, startmode, suppresserror)
    try
        call wince_model#AssertUberwinTypeExists(a:dstgrouptypename, a:dsttypename)
    catch /.*/
        if a:suppresserror
            return
        endif
        call s:Log.DBG('GoSupwinToUberwin failed: ')
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
        return
    endtry

    call s:Log.DBG('GoSupwinToUberwin ', a:srcsupwinid, ', ', a:dstgrouptypename, ':', a:dsttypename)
    if wince_model#UberwinGroupIsHidden(a:dstgrouptypename)
        call s:Log.INF('Showing uberwin group ', a:dstgrouptypename, ' so that the cursor can be moved to its uberwin ', a:dsttypename)
        call wince_user#ShowUberwinGroup(a:dstgrouptypename, a:suppresserror)
    endif
    call s:Log.VRB('Afterimaging subwins of source supwin ', a:srcsupwinid)
    call wince_common#AfterimageSubwinsBySupwin(a:srcsupwinid)
    let winid = wince_model#IdByInfo({
   \    'category': 'uberwin',
   \    'grouptype': a:dstgrouptypename,
   \    'typename': a:dsttypename
   \})
    call s:Log.VRB('Destination winid is ', winid)
    " This is done so that wince_state#MoveCursorToWinidAndUpdateMode can start
    " in (and therefore restore the mode to) the correct window
    call wince_state#MoveCursorToWinidSilently(a:srcsupwinid)
    return wince_state#MoveCursorToWinidAndUpdateMode(winid, a:startmode)
endfunction

function! s:GoSupwinToSupwin(srcsupwinid, dstsupwinid, startmode)
    call s:Log.DBG('GoSupwinToSupwin ', a:srcsupwinid, ', ', a:dstsupwinid)
    call s:Log.VRB('Afterimaging subwins of soruce supwin ',a:srcsupwinid)
    call wince_common#AfterimageSubwinsBySupwin(a:srcsupwinid)
    " This is done so that wince_state#MoveCursorToWinidAndUpdateMode can start
    " in (and therefore restore the mode to) the correct window
    call wince_state#MoveCursorToWinidSilently(a:srcsupwinid)
    let endmode = wince_state#MoveCursorToWinidAndUpdateMode(a:dstsupwinid, a:startmode)
    let cur = wince_common#GetCursorPosition()
    call s:Log.VRB('Preserved cursor position ', cur)
    call s:Log.VRB('Deafterimaging subwins of destination supwin ', a:dstsupwinid)
    " Don't update the mode here
    call wince_common#DeafterimageSubwinsBySupwin(a:dstsupwinid)
    call wince_common#RestoreCursorPosition(cur)
    call s:Log.VRB('Restored cursor position')
    return endmode
endfunction

function! s:GoSupwinToSubwin(srcsupwinid, dstgrouptypename, dsttypename, startmode, suppresserror)
    try
        call wince_model#AssertSubwinTypeExists(a:dstgrouptypename, a:dsttypename)
    catch /.*/
        if a:suppresserror
            return
        endif
        call s:Log.DBG('GoSupwinToSubwin failed: ')
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
        return
    endtry

    call s:Log.DBG('GoSupwinToSupwin ', a:srcsupwinid, ':', a:dstgrouptypename, ':', a:dsttypename)

    if wince_model#SubwinGroupIsHidden(a:srcsupwinid, a:dstgrouptypename)
        call s:Log.INF('Showing subwin group ', a:srcsupwinid, ':', a:dstgrouptypename, ' so that the cursor can be moved to its subwin ', a:dsttypename)
        call wince_user#ShowSubwinGroup(a:srcsupwinid, a:dstgrouptypename, a:suppresserror)
    endif
    call s:Log.VRB('Afterimaging subwins of source supwin ', a:srcsupwinid, ' except destination subwin group ', a:dstgrouptypename)
    call wince_common#AfterimageSubwinsBySupwinExceptOne(a:srcsupwinid, a:dstgrouptypename)
    let winid = wince_model#IdByInfo({
   \    'category': 'subwin',
   \    'supwin': a:srcsupwinid,
   \    'grouptype': a:dstgrouptypename,
   \    'typename': a:dsttypename
   \})
    call s:Log.VRB('Destination winid is ', winid)
    " This is done so that wince_state#MoveCursorToWinidAndUpdateMode can start
    " in (and therefore restore the mode to) the correct window
    call wince_state#MoveCursorToWinidSilently(a:srcsupwinid)
    return wince_state#MoveCursorToWinidAndUpdateMode(winid, a:startmode)
endfunction

function! s:GoSubwinToSupwin(srcsupwinid, startmode)
    call s:Log.DBG('GoSubwinToSupwin ', a:srcsupwinid)
    let endmode = wince_state#MoveCursorToWinidAndUpdateMode(a:srcsupwinid, a:startmode)
    let cur = wince_common#GetCursorPosition()
    call s:Log.VRB('Preserved cursor position ', cur)
    call s:Log.VRB('Deafterimaging subwins of source supwin ', a:srcsupwinid)
    call wince_common#DeafterimageSubwinsBySupwin(a:srcsupwinid)
    call wince_common#RestoreCursorPosition(cur)
    call s:Log.VRB('Restored cursor position')
    return endmode
endfunction
function! s:GoSubwinToSubwin(srcsupwinid, srcgrouptypename, dsttypename, startmode, suppresserror)
    call s:Log.DBG('GoSubwinToSubwin ', a:srcsupwinid, ':', a:srcgrouptypename, ':', a:dsttypename)
    let winid = wince_model#IdByInfo({
   \    'category': 'subwin',
   \    'supwin': a:srcsupwinid,
   \    'grouptype': a:srcgrouptypename,
   \    'typename': a:dsttypename
   \})
    call s:Log.VRB('Destination winid is ', winid)
    return wince_state#MoveCursorToWinidAndUpdateMode(winid, a:startmode)
endfunction

" Move the cursor to a given uberwin
function! wince_user#GotoUberwin(dstgrouptype, dsttypename, startmode, suppresserror)
    try
        call wince_model#AssertUberwinTypeExists(a:dstgrouptype, a:dsttypename)
        call wince_model#AssertUberwinGroupExists(a:dstgrouptype)
    catch /.*/
        if a:suppresserror
            return a:startmode
        endif
        call s:Log.WRN('Cannot go to uberwin ', a:dstgrouptype, ':', a:dsttypename, ':')
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
        return a:startmode
    endtry

    call s:Log.INF('wince_user#GotoUberwin ', a:dstgrouptype, ':', a:dsttypename, ' ', a:startmode)

    if wince_model#UberwinGroupIsHidden(a:dstgrouptype)
        call s:Log.INF('Showing uberwin group ', a:dstgrouptype, ' so that the cursor can be moved to its uberwin ', a:dsttypename)
        call wince_user#ShowUberwinGroup(a:dstgrouptype, a:suppresserror)
    endif

    let cur = wince_common#GetCursorPosition()
    if wince_model#IdByInfo({
   \    'category': 'uberwin',
   \    'grouptype': a:dstgrouptype,
   \    'typename': a:dsttypename
   \}) == wince_state#GetCursorWinId()
        call s:RunPostUserOpCallbacks()
        return a:startmode
    endif

    call wince_model#SetPreviousWinInfo(cur.win)
    call s:Log.VRB('Previous window set to ', cur.win)
    let endmode = a:startmode
    
    " Moving from subwin to uberwin must be done via supwin
    if cur.win.category ==# 'subwin'
        call s:Log.DBG('Moving to supwin first')
        let endmode = s:GoSubwinToSupwin(cur.win.supwin, endmode)
        let cur = wince_common#GetCursorPosition()
    endif

    if cur.win.category ==# 'supwin'
       let endmode = s:GoSupwinToUberwin(cur.win.id, a:dstgrouptype, a:dsttypename, endmode, a:suppresserror)
        call wince_model#SetCurrentWinInfo(wince_common#GetCursorPosition().win)
        call s:RunPostUserOpCallbacks()
        return endmode
    endif

    if cur.win.category ==# 'uberwin'
        let endmode = s:GoUberwinToUberwin(a:dstgrouptype, a:dsttypename, endmode, a:suppresserror)
        call wince_model#SetCurrentWinInfo(wince_common#GetCursorPosition().win)
        call s:RunPostUserOpCallbacks()
        return endmode
    endif

    throw 'Cursor window is neither subwin nor supwin nor uberwin'
endfunction

" Move the cursor to a given supwin
function! wince_user#GotoSupwin(dstwinid, startmode)
    try
        let dstsupwinid = wince_model#SupwinIdBySupwinOrSubwinId(a:dstwinid)
    catch /.*/
        call s:Log.WRN('Cannot go to supwin ', a:dstwinid, ':')
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
        return a:startmode
    endtry

    call s:Log.INF('wince_user#GotoSupwin ', a:dstwinid, ' ', a:startmode)

    let cur = wince_common#GetCursorPosition()
    if wince_model#IdByInfo({
   \    'category': 'supwin',
   \    'id': a:dstwinid
   \}) == wince_state#GetCursorWinId()
        call s:RunPostUserOpCallbacks()
        return a:startmode
    endif

    call s:Log.VRB('Previous window set to ', cur.win)
    call wince_model#SetPreviousWinInfo(cur.win)

    let endmode = a:startmode

    if cur.win.category ==# 'subwin'
        call s:Log.DBG('Moving to supwin first')
        let endmode = s:GoSubwinToSupwin(cur.win.supwin, endmode)
        let cur = wince_common#GetCursorPosition()
    endif

    if cur.win.category ==# 'uberwin'
        let endmode = s:GoUberwinToSupwin(dstsupwinid, endmode)
        call wince_model#SetCurrentWinInfo(wince_common#GetCursorPosition().win)
        call s:RunPostUserOpCallbacks()
        return endmode
    endif

    if cur.win.category ==# 'supwin'
        let endmode = a:startmode
        if cur.win.id != dstsupwinid
            let endmode = s:GoSupwinToSupwin(cur.win.id, dstsupwinid, endmode)
        endif
        call wince_model#SetCurrentWinInfo(wince_common#GetCursorPosition().win)
        call s:RunPostUserOpCallbacks()
        return endmode
    endif

    return endmode
endfunction

" Move the cursor to a given subwin
function! wince_user#GotoSubwin(dstwinid, dstgrouptypename, dsttypename, startmode, suppresserror)
    if !a:dstwinid
        let dstwinid = wince_state#GetCursorWinId()
    else
        let dstwinid = a:dstwinid
    endif
    try
        let dstsupwinid = wince_model#SupwinIdBySupwinOrSubwinId(dstwinid)
        call wince_model#AssertSubwinGroupExists(dstsupwinid, a:dstgrouptypename)
    catch /.*/
        if a:suppresserror
            return a:startmode
        endif
        call s:Log.WRN('Cannot go to subwin ', a:dstgrouptypename, ':', a:dsttypename, ' of supwin ', dstwinid, ':')
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
        return a:startmode
    endtry
    
    call s:Log.INF('wince_user#GotoSubwin ', dstwinid, ':', a:dstgrouptypename, ':', a:dsttypename, ' ', a:startmode)

    if wince_model#SubwinGroupIsHidden(dstsupwinid, a:dstgrouptypename)
        call s:Log.INF('Showing subwin group ', dstsupwinid, ':', a:dstgrouptypename, ' so that the cursor can be moved to its subwin ', a:dsttypename)
        call wince_user#ShowSubwinGroup(dstsupwinid, a:dstgrouptypename, a:suppresserror)
    endif

    let cur = wince_common#GetCursorPosition()
    if wince_model#IdByInfo({
   \    'category': 'subwin',
   \    'supwin': dstsupwinid,
   \    'grouptype': a:dstgrouptypename,
   \    'typename': a:dsttypename
   \}) == wince_state#GetCursorWinId()
        call s:RunPostUserOpCallbacks()
        return a:startmode
    endif

    call wince_model#SetPreviousWinInfo(cur.win)
    call s:Log.VRB('Previous window set to ', cur.win)

    let endmode = a:startmode

    if cur.win.category ==# 'subwin'
        if cur.win.supwin ==# dstsupwinid && cur.win.grouptype ==# a:dstgrouptypename
            let endmode =  s:GoSubwinToSubwin(cur.win.supwin, cur.win.grouptype, a:dsttypename, endmode, a:suppresserror)
            call wince_model#SetCurrentWinInfo(wince_common#GetCursorPosition().win)
            call s:RunPostUserOpCallbacks()
            return endmode
        endif

        call s:Log.DBG('Moving to supwin first')
        let endmode = s:GoSubwinToSupwin(cur.win.supwin, endmode)
        let cur = wince_common#GetCursorPosition()
    endif

    if cur.win.category ==# 'uberwin'
        let endmode = s:GoUberwinToSupwin(dstsupwinid, endmode)
        let cur = wince_common#GetCursorPosition()
    endif

    if cur.win.category !=# 'supwin'
        throw 'Cursor should be in a supwin now'
    endif

    if cur.win.id !=# dstsupwinid
        let endmode = s:GoSupwinToSupwin(cur.win.id, dstsupwinid, endmode)
        let cur = wince_common#GetCursorPosition()
    endif

    let endmode = s:GoSupwinToSubwin(cur.win.id, a:dstgrouptypename, a:dsttypename, endmode, a:suppresserror)
    call wince_model#SetCurrentWinInfo(wince_common#GetCursorPosition().win)
    call s:RunPostUserOpCallbacks()

    return endmode
endfunction

function! wince_user#AddOrShowUberwinGroup(grouptypename)
    call s:Log.INF('WinAddOrShowUberwinGroup ', a:grouptypename)
    if !wince_model#UberwinGroupExists(a:grouptypename)
        call wince_user#AddUberwinGroup(a:grouptypename, 0, 1)
    else
        call wince_user#ShowUberwinGroup(a:grouptypename, 1)
    endif
endfunction

function! wince_user#AddOrShowSubwinGroup(supwinid, grouptypename)
    call s:Log.INF('WinAddOrShowSubwinGroup ', a:supwinid, ':', a:grouptypename)
    if !wince_model#SubwinGroupExists(a:supwinid, a:grouptypename)
        call wince_user#AddSubwinGroup(a:supwinid, a:grouptypename, 0, 1)
    else
        call wince_user#ShowSubwinGroup(a:supwinid, a:grouptypename, 1)
    endif
endfunction

function! wince_user#AddOrGotoUberwin(grouptypename, typename, startmode)
    call s:Log.INF('wince_user#AddOrGotoUberwin ', a:grouptypename, ':', a:typename, ' ', a:startmode)
    if !wince_model#UberwinGroupExists(a:grouptypename)
        call wince_user#AddUberwinGroup(a:grouptypename, 0, 1)
    endif
    return wince_user#GotoUberwin(a:grouptypename, a:typename, a:startmode, 1)
endfunction

function! wince_user#AddOrGotoSubwin(supwinid, grouptypename, typename, startmode)
    call s:Log.INF('wince_user#AddOrGotoSubwin ', a:supwinid, ':', a:grouptypename, ':', a:typename, ' ', a:startmode)
    if !wince_model#SubwinGroupExists(a:supwinid, a:grouptypename)
        call wince_user#AddSubwinGroup(a:supwinid, a:grouptypename, 0, 1)
    endif
    call wince_user#GotoSubwin(a:supwinid, a:grouptypename, a:typename, a:startmode, 1)
endfunction

function! s:GotoByInfo(info, startmode)
    call s:Log.DBG('GotoByInfo ', a:info)
    if a:info.category ==# 'uberwin'
        return wince_user#GotoUberwin(a:info.grouptype, a:info.typename, a:startmode, 0)
    endif
    if a:info.category ==# 'supwin'
        return wince_user#GotoSupwin(a:info.id, a:startmode)
    endif
    if a:info.category ==# 'subwin'
        return wince_user#GotoSubwin(a:info.supwin, a:info.grouptype, a:info.typename, a:startmode, 0)
    endif
    throw 'Cannot go to window with category ' . a:info.category
endfunction

function! wince_user#GotoPrevious(count, startmode)
    call s:Log.INF('wince_user#GotoPrevious ', a:count, ' ', a:startmode)
    if a:count !=# 0 && a:count % 2 ==# 0
        call s:Log.DBG('Count is even. Doing nothing')
        return
    endif
    let dst = wince_model#PreviousWinInfo()
    if !wince_model#IdByInfo(dst)
        call s:Log.DBG('Previous window does not exist in model. Doing nothing.')
        return
    endif
    
    let src = wince_common#GetCursorPosition().win

    call wince_model#SetPreviousWinInfo(src)
    let endmode = s:GotoByInfo(dst, a:startmode)
    call wince_model#SetCurrentWinInfo(dst)

    call s:Log.VRB('Previous window set to ', src)
    call s:RunPostUserOpCallbacks()
    return endmode
endfunction

function! s:GoInDirection(count, direction, startmode)
    call s:Log.DBG('GoInDirection ', a:count, ', ', a:direction, ' ', a:startmode)
    if type(a:count) ==# s:t.string && empty(a:count)
        call s:Log.DBG('Defaulting count to 1')
        let thecount = 1
    else
        let thecount = a:count
    endif
    let endmode = a:startmode
    let mainsrcwininfo = wince_model#InfoById(wince_state#GetCursorWinId())
    for iter in range(thecount)
        call s:Log.DBG('Iteration ', iter)
        let srcwinid = wince_state#GetCursorWinId()
        let srcinfo = wince_model#InfoById(srcwinid)
        call s:Log.DBG('Source window is ', srcinfo)
        let srcsupwin = -1
        if srcinfo.category ==# 'subwin'
            let srcsupwin = srcinfo.supwin
        endif
        
        let curwinid = srcwinid
        let prvwinid = 0
        let dstwinid = 0
        while 1
            let prvwinid = curwinid
            call s:Log.VRB('Silently moving cursor in direction ', a:direction)
            call wince_state#SilentWincmd(1, a:direction, 0)

            let curwinid = wince_state#GetCursorWinId()
            let curwininfo = wince_model#InfoById(curwinid)
            call s:Log.VRB('Landed in ', curwininfo)
 
            if curwininfo.category ==# 'supwin'
                call s:Log.DBG('Found supwin ', curwinid)
                let dstwinid = curwinid
                break
            endif
            if curwininfo.category ==# 'subwin' && curwininfo.supwin !=# srcwinid &&
           \   curwininfo.supwin !=# srcsupwin
                call s:Log.DBG('Found supwin ', curwininfo.supwin, ' by its subwin ', curwininfo.grouptype, ':', curwininfo.typename)
                let dstwinid = curwininfo.supwin
                break
            endif
            if curwinid == prvwinid
                call s:Log.VRB('Did not move from last step')
                break
            endif
        endwhile

        call s:Log.VRB('Selected destination supwin ', dstwinid, '. Silently returning to source window')
        call wince_state#MoveCursorToWinidSilently(srcwinid)
        if dstwinid
            call s:Log.VRB('Moving to destination supwin ', dstwinid)
            let endmode = wince_user#GotoSupwin(dstwinid, endmode)
        endif
    endfor
    call wince_model#SetPreviousWinInfo(mainsrcwininfo)
    return endmode
endfunction

" Move the cursor to the supwin on the left
function! wince_user#GoLeft(count, startmode)
    call s:Log.INF('wince_user#GoLeft ', a:count, ' ', a:startmode)
    return s:GoInDirection(a:count, 'h', a:startmode)
endfunction

" Move the cursor to the supwin below
function! wince_user#GoDown(count, startmode)
    call s:Log.INF('wince_user#GoDown ', a:count, ' ', a:startmode)
    return s:GoInDirection(a:count, 'j', a:startmode)
endfunction

" Move the cursor to the supwin above
function! wince_user#GoUp(count, startmode)
    call s:Log.INF('wince_user#GoUp ', a:count, ' ', a:startmode)
    return s:GoInDirection(a:count, 'k', a:startmode)
endfunction

" Move the cursor to the supwin to the right
function! wince_user#GoRight(count, startmode)
    call s:Log.INF('wince_user#GoRight ', a:count, ' ', a:startmode)
    return s:GoInDirection(a:count, 'l', a:startmode)
endfunction

" Close all windows except for either a given supwin, or the supwin of a given
" subwin
" WARNING! This particular user operation is not guaranteed to leave the state
" and model consistent. It is designed to rely on the resolver.
function! wince_user#Only(count, startmode)
    call s:Log.INF('wince_user#Only ', a:count, ' ', a:startmode)
    if type(a:count) ==# s:t.string && empty(a:count)
        let winid = wince_state#GetCursorWinId()
    else
        let thecount = a:count
        let winid = wince_state#GetWinidByWinnr(thecount)
    endif

    let info = wince_model#InfoById(winid)

    if info.category ==# 'uberwin'
        throw 'Cannot invoke WinceOnly from uberwin'
        return a:startmode
    endif
    if info.category ==# 'subwin'
        call s:Log.DBG('shifting target to supwin')
        let winid = info.supwin
    endif

    " Afterimaged subwins contain modified buffers which <c-w>o refuses to
    " close if the global 'hidden' option is false, so we need to close those
    " subwins. While we're here, we may as well close *all* subwins since
    " <c-w>o will close them anyway and it would be better to use the toClose
    " callbacks than stomp them with <c-w>o. Same goes for uberwins.
    for supwinid in wince_model#SupwinIds()
       call wince_common#CloseSubwinsWithHigherPriorityThan(supwinid, '')
    endfor
    call wince_common#CloseUberwinsWithHigherPriorityThan('')

    call s:Log.VRB('target supwin ', winid)

    let endmode = wince_state#MoveCursorToWinidAndUpdateMode(winid, a:startmode)
    let endmode = wince_state#Wincmd('', 'o', endmode)

    " This call to the resolver from the user operations is
    " an unfortunate architectural violation, but it doesn't
    " introduce any dependency issues. The user operations
    " just depend on the resolver.
    call wince_resolve#Resolve()

    call s:RunPostUserOpCallbacks()
    return endmode
endfunction

" Exchange the current supwin (or current subwin's supwin) with a different
" supwin
function! wince_user#Exchange(count, startmode)
    call s:Log.INF('wince_user#Exchange ', a:count, ' ', a:startmode)
    let info = wince_common#GetCursorPosition()

    if info.win.category ==# 'uberwin'
        throw 'Cannot invoke WinceExchange from uberwin'
        return
    endif

    call s:Log.INF('wince_user#Exchange ', a:count)

    if info.win.category ==# 'subwin'
        call s:Log.DBG('Moving to supwin first')
        " Don't change the mode. It'll be dropped later anyway
        call wince_user#GotoSupwin(info.win.supwin, 0)
    endif

    let cmdinfo = wince_common#GetCursorPosition()
    call s:Log.VRB('Running command from window ', cmdinfo)

    let endmode = a:startmode
    try
        let endmode = wince_common#DoWithoutUberwinsOrSubwins(cmdinfo.win, function('wince_state#Wincmd'), [a:count, 'x', a:startmode], 0)
    catch /.*/
        call s:Log.DBG('wince_user#Exchange failed: ')
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
    finally
        if info.win.category ==# 'subwin'
            call s:Log.VRB('Returning to subwin ', info.win)
            " Drop the mode
            let endmode = {'mode':'n'}
            call wince_user#GotoSubwin(0, info.win.grouptype, info.win.typename, 0, 1)
        endif
        call wince_common#RecordAllDimensions()
        call s:RunPostUserOpCallbacks()
        return endmode
    endtry
endfunction

function! s:ResizeGivenNoSubwins(width, height, preclosedim)
    call s:Log.DBG('ResizeGivenNoSubwins ', ', [', a:width, ',', a:height, '], ', a:preclosedim)

    let winid = wince_model#IdByInfo(wince_common#GetCursorPosition().win)

    let precloseuberdim = wince_state#GetAllWinDimensionsByCurrentTab()

    call s:Log.DBG('Closing all uberwins')
    let closeduberwingroups = wince_common#CloseUberwinsWithHigherPriorityThan('')
    try
        call wince_state#MoveCursorToWinid(winid)

        " Counts inputted by the user wouldn't account for uberwins and
        " subwins being closed at the time the state command is invoked, so
        " increase the counts by the same amount that the target window grows
        " by
        let postcloseuberdim = wince_state#GetAllWinDimensionsByCurrentTab()

        " Uberwin delta - how much bigger the target window got when we closed
        " uberwins
        let uberdeltaw = postcloseuberdim[winid].w - precloseuberdim[winid].w
        let uberdeltah = postcloseuberdim[winid].h - precloseuberdim[winid].h

        " Subwin delta - how much bigger the target window got when we closed
        " subwins. The proclosedim parameter was created further up the stack
        " in wince_user#ResizeCurrentSupwin, before subwins were closed
        let subdeltaw = precloseuberdim[winid].w - a:preclosedim.w
        let subdeltah = precloseuberdim[winid].h - a:preclosedim.h

        " Both deltas matter
        let finalw = a:width + uberdeltaw + subdeltaw
        let finalh = a:height + uberdeltah + subdeltah

        let dow = 1
        let doh = 1
        call s:Log.DBG('Deltas: dw=', uberdeltaw, ' dh=', uberdeltah)

        if a:width ==# ''
            let finalw = ''
        endif
        if a:height ==# ''
            let finalh = ''
        endif
        if type(a:width) ==# s:t.number && a:width <# 0
            let dow = 0
        endif
        if type(a:height) ==# s:t.number && a:height <# 0
            let doh = 0
        endif

        if dow
            call s:Log.DBG('Resizing to width ', finalw)
            call wince_state#Wincmd(finalw, '|', 0)
        endif
        if doh
            call s:Log.DBG('Resizing to height ', finalh)
            call wince_state#Wincmd(finalh, '_', 0)
        endif

        let postresizedim = wince_state#GetAllWinDimensionsByCurrentTab()
        for otherwinid in keys(postcloseuberdim)
            if postresizedim[otherwinid].w !=# postcloseuberdim[otherwinid].w ||
           \   postresizedim[otherwinid].h !=# postcloseuberdim[otherwinid].h
               call remove(precloseuberdim, otherwinid)
            endif
        endfor
    finally
        call s:Log.DBG('Reopening all uberwins')
        call wince_common#ReopenUberwins(closeduberwingroups)
        call wince_common#RestoreDimensions(precloseuberdim)
    endtry
endfunction

function! wince_user#ResizeCurrentSupwin(width, height, startmode)
    let info = wince_common#GetCursorPosition()

    if info.win.category ==# 'uberwin'
        throw 'Cannot resize an uberwin'
        return a:startmode
    endif

    call s:Log.INF('wince_user#ResizeCurrentSupwin ', a:width, ' ', a:height)

    if info.win.category ==# 'subwin'
        call s:Log.DBG('Moving to supwin first')
        " Don't change the mode
        call wince_user#GotoSupwin(info.win.supwin, 0)
    endif

    let cmdinfo = wince_common#GetCursorPosition()
    call s:Log.VRB('Running command from window ', cmdinfo)

    let preclosedim = wince_state#GetWinDimensions(cmdinfo.win.id)

    try
        call wince_common#DoWithoutSubwins(cmdinfo.win, function('s:ResizeGivenNoSubwins'), [a:width, a:height, preclosedim], 1)
    finally
        call wince_common#RestoreCursorPosition(info)
    endtry

    call wince_common#RecordAllDimensions()
    call s:RunPostUserOpCallbacks()
    return a:startmode
endfunction

function! wince_user#ResizeVertical(count, startmode)
    call s:Log.INF('wince_user#ResizeVertical ' . a:count)
    return wince_user#ResizeCurrentSupwin(a:count, -1, a:startmode)
endfunction
function! wince_user#ResizeHorizontal(count, startmode)
    call s:Log.INF('wince_user#ResizeHorizontal ' . a:count)
    return wince_user#ResizeCurrentSupwin(-1, a:count, a:startmode)
endfunction
function! wince_user#ResizeHorizontalDefaultNop(count, startmode)
    call s:Log.INF('wince_user#ResizeHorizontalDefaultNop ' . a:count)
    if a:count ==# ''
        return a:startmode
    endif
    return wince_user#ResizeCurrentSupwin(-1, a:count, a:startmode)
endfunction

" Run a command in every supwin
" WARNING! This particular user operation is not guaranteed to leave the state
" and model consistent. Avoid passing commands that change the window state.
function! SupwinDo(command, range)
    call s:Log.INF('SupwinDo <', a:command, '>, ', a:range)
    let info = wince_common#GetCursorPosition()
    call s:Log.VRB('Preserved cursor position ', info)
    try
        for supwinid in wince_model#SupwinIds()
            " Don't change the mode
            call wince_user#GotoSupwin(supwinid, 0)
            call s:Log.VRB('running command <', a:range, a:command, '>')
            execute a:range . a:command
        endfor
    finally
        call wince_common#RestoreCursorPosition(info)
        call s:Log.VRB('Restored cursor position')
    endtry
endfunction
