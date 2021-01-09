" Wince code common to resolver and user operations
" See wince.vim
let s:Log = jer_log#LogFunctions('wince-common')

" Returns a data structure that encodes information about the window that the
" cursor is in
function! wince_common#GetCursorPosition()
    call s:Log.DBG('wince_common#GetCursorPosition')
    return {
   \    'win':wince_model#InfoById(wince_state#GetCursorWinId()),
   \    'cur':wince_state#GetCursorPosition()
   \}
endfunction

" Returns true if winids listed in in the model for an uberwin group exist in
" the state
function! wince_common#UberwinGroupExistsInState(grouptypename)
    call s:Log.DBG('wince_common#UberwinGroupExistsInState ', a:grouptypename)
    return wince_state#WinExists(wince_model#SomeUberwinIdByGroupTypeName(a:grouptypename))
endfunction

" Returns true if winids listed in the model for a subwin group exist in the
" state
function! wince_common#SubwinGroupExistsInState(supwinid, grouptypename)
    call s:Log.DBG('wince_common#SubwinGroupExistsInState ', a:supwinid, ':', a:grouptypename)
    return wince_state#WinExists(wince_model#SomeSubwinIdByGroupTypeName(a:supwinid, a:grouptypename))
endfunction

" Returns false if the dimensions in the model of any uberwin in a shown group of
" a given type are dummies or inconsistent with the state. True otherwise.
function! wince_common#UberwinGroupDimensionsMatch(grouptypename)
    call s:Log.DBG('wince_common#UberwinGroupDimensionsMatch ', a:grouptypename)
    for [typename, mdims] in items(wince_model#UberwinDimensionsByGroupTypeName(a:grouptypename))
        call s:Log.VRB('Check uberwin ', a:grouptypename, ':', typename)
        if mdims.nr ==# -1 || mdims.w ==# -1 || mdims.h ==# -1
            call s:Log.DBG('Uberwin ', a:grouptypename, ':', typename, ' has dummy dimensions')
            return 0
        endif
        let sdims = wince_state#GetWinDimensions(mdims.id)
        if sdims.nr !=# mdims.nr || sdims.w !=# mdims.w || sdims.h !=# mdims.h
            call s:Log.DBG('Uberwin ', a:grouptypename, ':', typename, ' has inconsistent non-dummy dimensions')
            return 0
        endif
    endfor
    call s:Log.DBG('No dimensional inconsistency found for uberwin group ', a:grouptypename)
    return 1
endfunction

" Returns false if the dimensions in the model of a given supwin are dummies
" or inconsistent with the state. True otherwise.
function! wince_common#SupwinDimensionsMatch(supwinid)
    call s:Log.DBG('wince_common#SupwinDimensionsMatch ', a:supwinid)
    let mdims = wince_model#SupwinDimensions(a:supwinid)
    if mdims.nr ==# -1 || mdims.w ==# -1 || mdims.h ==# -1
        call s:Log.DBG('Supwin ', a:supwinid, ' has dummy dimensions')
        return 0
    endif
    let sdims = wince_state#GetWinDimensions(a:supwinid)
    if sdims.nr !=# mdims.nr || sdims.w !=# mdims.w || sdims.h !=# mdims.h
        call s:Log.DBG('Supwin ', a:supwinid, ' has inconsistent non-dummy dimensions')
        return 0
    endif
    call s:Log.DBG('No dimensional inconsistency found for supwin ', a:supwinid)
    return 1
endfunction

" Returns false if the dimensions in the model of any subwin in a shown group of
" a given type for a given supwin are dummies or inconsistent with the state.
" True otherwise.
function! wince_common#SubwinGroupDimensionsMatch(supwinid, grouptypename)
    call s:Log.DBG('wince_common#SubwinGroupDimensionsMatch ', a:supwinid, ':', a:grouptypename)
    for [winid, mdims] in items(wince_model#SubwinDimensionsByGroupTypeName(a:supwinid, a:grouptypename))
        call s:Log.VRB('Check subwin ', winid)
        if mdims.relnr ==# 0 || mdims.w ==# -1 || mdims.h ==# -1
            call s:Log.DBG('Subwin ', winid, ' has dummy dimensions')
            return 0
        endif
        let sdims = wince_state#GetWinDimensions(winid)
        let snr = wince_state#GetWinnrByWinid(a:supwinid)
        if sdims.nr !=# snr + mdims.relnr || sdims.w !=# mdims.w || sdims.h !=# mdims.h
            call s:Log.DBG('Subwin ', winid, ' has inconsistent non-dummy dimensions')
            return 0
        endif
    endfor
    call s:Log.DBG('No dimensional inconsistency found for subwin group ', a:supwinid, ':', a:grouptypename)
    return 1
endfunction

" Get the window ID of the topmost leftmost supwin
function! wince_common#FirstSupwinId()
    call s:Log.DBG('wince_common#FirstSupwinId')
    let minsupwinnr = 0
    let minsupwinid = 0
    for supwinid in wince_model#SupwinIds()
        if !wince_state#WinExists(supwinid)
            call s:Log.VRB('Skipping non-state-present supwin ', supwinid)
            continue
        endif
        call s:Log.VRB('Check supwin ', supwinid)
        let winnr = wince_state#GetWinnrByWinid(supwinid)
        if minsupwinnr ==# 0 || minsupwinnr > winnr
            call s:Log.VRB('Supwin ', supwinid, ' has lowest winnr so far: ', winnr)
            let minsupwinnr = winnr
            let minsupwinid = supwinid
        endif
    endfor
    call s:Log.DBG('Supwin with lowest winnr is ', minsupwinid)
    return minsupwinid
endfunction

" Get the window ID of the first uberwin in the lowest-priority shown uberwin
" group
function! wince_common#FirstUberwinInfo()
    call s:Log.DBG('wince_common#FirstUberwinInfo')
    let grouptypenames = wince_model#ShownUberwinGroupTypeNames()
    if empty(grouptypenames)
        call s:Log.DBG('No uberwins are open')
        return {'category':'none','id':0}
    endif
    let grouptypename = grouptypenames[0]
    let typename = g:wince_uberwingrouptype[grouptypename].typenames[0]
    call s:Log.DBG('Selected uberwin ', grouptypename, ':', typename, ' as first uberwin')
    return {
   \    'category':'uberwin',
   \    'grouptype':grouptypename,
   \    'typename':typename
   \}
endfunction

" Given a cursor position remembered with wince_common#GetCursorPosition, return
" either the same position or an updated one if it doesn't exist anymore
let s:cases = {'none':0,'uberwin':1,'supwin':2,'subwin':3}
function! wince_common#ReselectCursorWindow(oldpos)
    call s:Log.DBG('wince_common#ReselectCursorWindow ', a:oldpos)
    let pos = a:oldpos

    " If the cursor is in a nonexistent or hidden subwin, try to select its supwin
    if pos.category ==# 'subwin' && !wince_model#ShownSubwinGroupExists(pos.supwin, pos.grouptype)
        call s:Log.DBG('Cursor is in nonexistent or hidden subwin. Attempt to select its supwin: ', pos.supwin)
        let pos = {'category':'supwin','id':pos.supwin}
    endif

    " If all we have is a window ID, try looking it up
    if pos.category ==# 'none' || pos.category ==# 'supwin'
        call s:Log.DBG('Validate winid ', pos.id, ' by model lookup')
        let pos = wince_model#InfoById(pos.id)
    endif

    " If we still have just a window ID, or if the cursor is in a nonexistent
    " supwin, nonexistent uberwin, or hidden uberwin, try to select the first supwin
    let catn = get(s:cases, pos.category, -1)
    if catn ==# 0 ||
   \   (catn ==# 2 && !wince_model#SupwinExists(pos.id)) ||
   \   (catn ==# 1 && (!wince_model#ShownUberwinGroupExists(pos.grouptype)))
        call s:Log.DBG('Cursor position fallback to first supwin')
        let firstsupwinid = wince_common#FirstSupwinId()
        if firstsupwinid
            call s:Log.DBG('First supwin is ', firstsupwinid)
            let pos = {'category':'supwin','id':firstsupwinid}
        endif
    endif

    " If we still have just a window ID, there are no supwins and therefore
    " also no subwins. Try to select the first uberwin.
    if pos.category ==# 'none' ||
   \   (pos.category ==# 'supwin' && !wince_model#SupwinExists(pos.id))
        call s:Log.DBG('Cursor position fallback to first uberwin')
        let pos = wince_common#FirstUberwinInfo()
    endif

    " If we still have no window ID, then there are no windows in the model
    " and an informed decision can't be made.
    if pos.category ==# 'none'
        return a:oldpos
    endif

    " At this point, a window has been chosen based only on the model. But if
    " the model and state are inconsistent, the window may not be open in the
    " state.
    call s:Log.DBG('Cursor position selected based on model: ', pos)
    let winexistsinstate = wince_state#WinExists(wince_model#IdByInfo(pos))

    " If a non-open subwin was selected, select its supwin
    if !winexistsinstate && pos.category ==# 'subwin'
        call s:Log.DBG('Cursor position is a state-closed subwin. Attempt to select its supwin: ', pos.supwin)
        let pos = {'category':'supwin','id':pos.supwin}
        let winexistsinstate = wince_state#WinExists(wince_model#IdByInfo(pos))
    endif

    " If a non-open supwin was selected. select the first supwin
    if !winexistsinstate && pos.category ==# 'supwin'
        call s:Log.DBG('Cursor position is a state-closed supwin. Fallback to first supwin')
        let firstsupwinid = wince_common#FirstSupwinId()
        if firstsupwinid
            call s:Log.DBG('First supwin is ', firstsupwinid)
            let pos = {'category':'supwin','id':firstsupwinid}
        endif
        let winexistsinstate = wince_state#WinExists(wince_model#IdByInfo(pos))
    endif

    " If we still haven't selected an open supwin, there are no open supwins.
    " Select the first uberwin.
    if !winexistsinstate 
        call s:Log.DBG('Cursor position fallback to first uberwin')
        let pos = wince_common#FirstUberwinInfo()
        let winexistsinstate = wince_state#WinExists(wince_model#IdByInfo(pos))
    endif

    " If we still have no window ID, then we're out of ideas
    if !winexistsinstate
        throw "No windows from the model are open in the state. Cannot select a window for the cursor."
    endif

    call s:Log.VRB('Reselected cursor position ', pos)
    return pos
endfunction

" Preserve the view (scroll and cursor position) in all windows except for
" some exceptions
function! wince_common#ShieldAllWindows(excludedwinids)
    call s:Log.DBG('wince_common#ShieldAllWindows')
    let preshield = {}

    for winid in wince_state#GetWinidsByCurrentTab()
        if index(a:excludedwinids, str2nr(winid)) >=# 0
            continue
        endif
        call s:Log.VRB('Shield ', winid)
        let preshield[winid] = wince_state#ShieldWindow(winid)
    endfor

    call s:Log.VRB('Shielded: ', preshield)
    return preshield
endfunction

" Restore views from wince_common#ShieldAllWindows()
function! wince_common#UnshieldWindows(preshield)
    call s:Log.DBG('wince_common#UnshieldWindows')
    for winid in keys(a:preshield)
        if wince_state#WinExists(winid)
            call s:Log.VRB('Unshield ', winid, ':', a:preshield[winid])
            call wince_state#UnshieldWindow(winid, a:preshield[winid])
        else
            call s:Log.VRB('Window ', winid, ' does not exist in state and so cannot be unshielded')
        endif
    endfor
endfunction

" Moves the cursor to a window remembered with wince_common#GetCursorPosition. If
" the window no longer exists, go to the next best window as selected by
" wince_common#ReselectCursorWindow
function! wince_common#RestoreCursorPosition(info)
    call s:Log.DBG('wince_common#RestoreCursorPosition ', a:info)
    let newpos = wince_common#ReselectCursorWindow(a:info.win)
    call s:Log.DBG('Reselected cursor position: ', newpos)
    " If we failed to reselect, we fail to restore
    if newpos.category ==# 'none'
        return newpos
    endif
    let winid = wince_model#IdByInfo(newpos)
    call wince_state#MoveCursorToWinid(winid)
    if wince_model#IdByInfo(a:info.win) ==# winid
        call wince_state#RestoreCursorPosition(a:info.cur)
    endif
    return newpos
endfunction

" When windows are closed, Vim needs to choose which other windows to
" expand to fill the free space and how to change those windows' scroll
" positions. Sometimes Vim makes choices I don't like, such as scrolling
" down in the windows it expands. So before closing the uberwin, Remember the
" scroll and cursor position scroll position of every window except the ones
" being closed. This is a wrapper that does just that. It also ensures that
" ToClose is closing the right windows.
function! wince_common#CloseUberwinsByGroupTypeName(grouptypename)
    call s:Log.DBG('wince_common#CloseUberwinsByGroupTypeName ', a:grouptypename)
    let uberwinids = wince_model#UberwinIdsByGroupTypeName(a:grouptypename)

    let preshield = wince_common#ShieldAllWindows(uberwinids)

    try
        let grouptype = g:wince_uberwingrouptype[a:grouptypename]
        let preclosewinids = wince_state#GetWinidsDictByCurrentTab()
        for winid in uberwinids
            if !has_key(preclosewinids, winid)
                throw 'Model uberwin ID ' . winid . ' from group ' . a:grouptypename . ' not present in state'
            endif
        endfor
        call s:Log.DBG('State-closing uberwin group ', a:grouptypename)
        call wince_state#CloseUberwinsByGroupType(grouptype)
        let postclosewinids = wince_state#GetWinidsDictByCurrentTab()
        for winid in keys(preclosewinids)
            " TODO? All these linear searches add up. Maybe use dicts with
            "       has_key() instead, but not worth it unless there's a group
            "       type with lots and lots of types in it
            let isuberwinid = (index(uberwinids, str2nr(winid)) >= 0)
            let ispresent = has_key(postclosewinids, winid)
            if !isuberwinid && !ispresent
                throw 'toClose callback of uberwin group type ' . a:grouptypename . ' closed window ' . winid . ' which was not a member of uberwin group ' . a:grouptypename
            endif
            if isuberwinid && ispresent
                throw 'toClose callback of uberwin group type ' . a:grouptypename . ' did not close uberwin ' . winid
            endif
        endfor
    finally
        call wince_common#UnshieldWindows(preshield)
    endtry
endfunction

function! s:CompareWinidsByWinnr(winid1, winid2)
    let winnr1 = wince_state#GetWinnrByWinid(a:winid1)
    let winnr2 = wince_state#GetWinnrByWinid(a:winid2)
    return winnr1 == winnr2 ? 0 : winnr1 > winnr2 ? 1 : -1
endfunction
function! s:RestoreDimensionsByWinid(winid, olddims, issupwinid, indirectresize)
    call s:Log.VRB('RestoreDimensionsByWinid ', a:winid, ' ', a:olddims, a:issupwinid, ' ', ' ', a:indirectresize)
    let newdims = wince_state#GetWinDimensions(a:winid)
    " This function gets called only when there are no subwins, so any
    " non-supwin must be an uberwin.
    let isuberwin = !a:issupwinid
    let fixed = wince_state#FixednessByWinid(a:winid)
    if (a:olddims.w <# newdims.w) || (isuberwin && fixed.w && a:olddims.w ># newdims.w)
        call s:Log.DBG('Set width for window ', a:winid, ' to ', a:olddims.w)
        call wince_state#ResizeHorizontal(a:winid, a:olddims.w, a:indirectresize)
    endif
    if (a:olddims.h <# newdims.h) || (isuberwin && fixed.h && a:olddims.h ># newdims.h)
        call s:Log.DBG('Set height for window ', a:winid, ' to ', a:olddims.h)
        call wince_state#ResizeVertical(a:winid, a:olddims.h, a:indirectresize)
    endif
endfunction
" Restore dimensions remembered with wince_state#GetAllWinDimensionsByCurrentTab
function! wince_common#RestoreDimensions(windims)
    call s:Log.DBG('wince_common#RestoreDimensions ')
    let sorted = copy(keys(a:windims))
    call filter(sorted, {idx, val -> wince_state#WinExists(val)})
    call sort(sorted, function('s:CompareWinidsByWinnr'))
    let supwinids = wince_model#SupwinIds()
    let supwinidsdict = {}
    for supwinid in supwinids
        let supwinidsdict[supwinid] = 1
    endfor
    for winid in sorted
        call s:RestoreDimensionsByWinid(winid, a:windims[winid], has_key(supwinidsdict, winid), 0)
    endfor
    call reverse(sorted)
    for winid in sorted
        call s:RestoreDimensionsByWinid(winid, a:windims[winid], has_key(supwinidsdict, winid), 1)
    endfor
endfunction

" Record the dimensions of all windows in the model
function! wince_common#RecordAllDimensions()
    call s:Log.DBG('wince_common#RecordAllDimensions')
    " Record all uberwin dimensions in the model
    for grouptypename in wince_model#ShownUberwinGroupTypeNames()
        try
            let winids = wince_model#UberwinIdsByGroupTypeName(grouptypename)
            let dims = wince_state#GetWinDimensionsList(winids)
            call s:Log.DBG('Write state dimensions of uberwin group ', grouptypename, ' to model: ', dims)
            call wince_model#ChangeUberwinGroupDimensions(grouptypename, dims)
        catch /.*/
            call s:Log.WRN('wince_common#RecordAllDimensions found uberwin group ', grouptypename, ' inconsistent:')
            call s:Log.DBG(v:throwpoint)
            call s:Log.WRN(v:exception)
        endtry
    endfor

    " Record all supwin dimensions in the model
    for supwinid in wince_model#SupwinIds()
        try
            let dim = wince_state#GetWinDimensions(supwinid)
            call s:Log.DBG('Write state dimensions of supwin ', supwinid, ' to model: ', dim)
            call wince_model#ChangeSupwinDimensions(supwinid, dim.nr, dim.w, dim.h)
        catch
            call s:Log.WRN('wince_common#RecordAllDimensions found supwin ', supwinid, ' inconsistent:')
            call s:Log.DBG(v:throwpoint)
            call s:Log.WRN(v:exception)
        endtry

    " Record all subwin dimensions in the model
        let supwinnr = wince_state#GetWinnrByWinid(supwinid)
        for grouptypename in wince_model#ShownSubwinGroupTypeNamesBySupwinId(supwinid)
            try
                let winids = wince_model#SubwinIdsByGroupTypeName(supwinid, grouptypename)
                let dims = wince_state#GetWinRelativeDimensionsList(winids, supwinnr)
                call s:Log.DBG('Write state dimensions of subwin group ', supwinid, ':', grouptypename, ' to model: ', dims)
                call wince_model#ChangeSubwinGroupDimensions(supwinid, grouptypename, dims)
            catch /.*/
                call s:Log.WRN('wince_common#RecordAllDimensions found subwin group ', grouptypename, ' for supwin ', supwinid, ' inconsistent:')
                call s:Log.DBG(v:throwpoint)
                call s:Log.WRN(v:exception)
            endtry
        endfor
    endfor
endfunction

" Wrapper for wince_state#OpenUberwinsByGroupType that freezes scroll positions
" and corrects dimensions for existing windows
function! wince_common#OpenUberwins(grouptypename)
    call s:Log.DBG('wince_common#OpenUberwins ', a:grouptypename)
    let preshield = wince_common#ShieldAllWindows([])
    try
        " When windows are opened, Vim needs to choose which other windows to shrink
        " to make room. Sometimes Vim makes choices I don't like, such as equalizing
        " windows along the way. This function can be called before opening a window,
        " to remember the dimensions of all the windows that are already open. The
        " remembered dimensions can then be somewhat restored using
        " wince_common#RestoreDimensions
        let windims = wince_state#GetAllWinDimensionsByCurrentTab()
        try
            let grouptype = g:wince_uberwingrouptype[a:grouptypename]
            let winids = wince_state#OpenUberwinsByGroupType(grouptype)

        finally
            call wince_common#RestoreDimensions(windims)
        endtry

    finally
        call wince_common#UnshieldWindows(preshield)
    endtry
    call s:Log.VRB('Opened uberwin group ', a:grouptypename, ' with winids ', winids)
    return winids
endfunction

" Closes all uberwins with priority higher than a given, and returns a list of
" group types closed. The model is unchanged.
function! wince_common#CloseUberwinsWithHigherPriorityThan(grouptypename)
    call s:Log.DBG('wince_common#CloseUberwinsWithHigherPriorityThan ', a:grouptypename)
    let grouptypenames = wince_model#ShownUberwinGroupTypeNamesWithHigherPriorityThan(a:grouptypename)
    let preserved = []

    " grouptypenames is reversed so that we close uberwins in descending
    " priority order. See comments in wince_common#CloseSubwinsWithHigherPriorityThan
    call reverse(grouptypenames)

    " Apply PreCloseAndReopenUberwins to all uberwins first, then close them
    " all. This is done because sometimes closing an uberwin will cause other
    " lower-priority uberwins' dimensions to change, and we don't want to
    " preserve those changes
    for grouptypename in grouptypenames
        call s:Log.VRB('Uberwin group ', grouptypename, ' has higher priority')
        let pre = wince_common#PreCloseAndReopenUberwins(grouptypename)
        call insert(preserved, {'grouptypename':grouptypename,'pre':pre})
    endfor
    for grouptypename in grouptypenames
        call wince_common#CloseUberwinsByGroupTypeName(grouptypename)
    endfor
    return preserved
endfunction

" Reopens uberwins that were closed by wince_common#CloseUberwinsWithHigherPriorityThan
" and updates the model with the new winids
function! wince_common#ReopenUberwins(preserved)
    call s:Log.DBG('wince_common#ReopenUberwins')
    " Open all uberwins first, then apply PostCloseAndReopenUberwins to them
    " all. This is done because sometimes opening an uberwin will cause other
    " lower-priority uberwins' dimensions to change, and we don't want that to
    " happen after they've been restored
    let winids = {}
    for grouptype in a:preserved
        call s:Log.DBG('Reopening preserved uberwin group ', grouptype.grouptypename)
        try
            let winids[grouptype.grouptypename] = wince_common#OpenUberwins(grouptype.grouptypename)
            call s:Log.VRB('Reopened uberwin group ', grouptype.grouptypename, ' with winids ', winids)
        catch /.*/
             call s:Log.WRN('wince_common#ReopenUberwins failed to open ', grouptype.grouptypename, ' uberwin group:')
             call s:Log.DBG(v:throwpoint)
             call s:Log.WRN(v:exception)
             call wince_model#HideUberwins(grouptype.grouptypename)
        endtry
    endfor
    for grouptype in a:preserved
        if !has_key(winids, grouptype.grouptypename)
            continue
        endif
        call wince_model#ChangeUberwinIds(grouptype.grouptypename, winids[grouptype.grouptypename])
        call wince_common#PostCloseAndReopenUberwins(
       \    grouptype.grouptypename,
       \    grouptype.pre
       \)

        let dims = wince_state#GetWinDimensionsList(winids[grouptype.grouptypename])
        call wince_model#ChangeUberwinGroupDimensions(grouptype.grouptypename, dims)
    endfor
endfunction

" Wrapper for wince_state#CloseSubwinsByGroupType that falls back to
" wince_state#CloseWindow if any subwins in the group are afterimaged
function! wince_common#CloseSubwins(supwinid, grouptypename)
    call s:Log.DBG('wince_common#CloseSubwins ', a:supwinid, ':', a:grouptypename)
    let preunfix = wince_state#UnfixDimensions(a:supwinid)
    try
        if wince_model#SubwinGroupIsAfterimaged(a:supwinid, a:grouptypename)
            call s:Log.DBG('Subwin group ', a:supwinid, ':', a:grouptypename, ' is afterimaged. Stomping subwins individually.')
            for subwinid in wince_model#SubwinIdsByGroupTypeName(
           \    a:supwinid,
           \    a:grouptypename
           \)
                call s:Log.VRB('Stomp subwin ', subwinid)
                call wince_state#CloseWindow(subwinid, g:wince_subwingrouptype[a:grouptypename].stompWithBelowRight)
            endfor

            " Here, afterimaged subwins are removed from the state but not from
            " the model. If they are opened again, they will not be afterimaged in
            " the state. So deafterimage them in the model.
            call wince_model#DeafterimageSubwinsByGroup(a:supwinid, a:grouptypename)
        else
            let grouptype = g:wince_subwingrouptype[a:grouptypename]
            let preclosewinids = wince_state#GetWinidsDictByCurrentTab()
            let subwinids = wince_model#SubwinIdsByGroupTypeName(a:supwinid, a:grouptypename)
            for winid in subwinids
                " TODO? All these linear searches add up. Maybe use dicts with
                "       has_key() instead, but not worth it unless there's a group
                "       type with lots and lots of types in it
                if !has_key(preclosewinids, winid)
                    throw 'Model subwin ID ' . winid . ' from group ' . a:supwinid . ':' . a:grouptypename . ' not present in state'
                endif
            endfor
            call s:Log.DBG('Subwin group ', a:supwinid, ':', a:grouptypename, ' is not afterimaged. Closing via toClose')
            call wince_state#CloseSubwinsByGroupType(a:supwinid, grouptype)
            let postclosewinids = wince_state#GetWinidsDictByCurrentTab()
            for winid in keys(preclosewinids)
                let issubwinid = (index(subwinids, str2nr(winid)) >= 0)
                let ispresent = has_key(postclosewinids, winid)
                if !issubwinid && !ispresent
                    throw 'toClose callback of subwin group type ' . a:grouptypename . ' closed window ' . winid . ' which was not a member of subwin group ' . a:supwinid . ':' . a:grouptypename
                endif
                if issubwinid && ispresent
                    throw 'toClose callback of subwin group type ' . a:grouptypename . ' did not close subwin ' . a:winid . ' of supwin ' . a:supwinid
                endif
            endfor
        endif
    catch /.*/
        call s:Log.WRN('wince_common#CloseSubwins failed on ', a:supwinid, ':', a:grouptypename, ':')
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
        call wince_model#HideSubwins(a:supwinid, grouptype.grouptypename)
    finally
        call wince_state#RefixDimensions(a:supwinid, preunfix)
    endtry
endfunction

" Wrapper for wince_state#OpenSubwinsByGroupType that uses a group type from the
" model
function! wince_common#OpenSubwins(supwinid, grouptypename)
    call s:Log.DBG('wince_common#OpenSubwins ', a:supwinid, ':', a:grouptypename)
    if wince_state#WinIsTerminal(a:supwinid)
        throw 'Supwin ' . a:supwinid . ' is a terminal window'
    endif
    let preunfix = wince_state#UnfixDimensions(a:supwinid)
    try
        let grouptype = g:wince_subwingrouptype[a:grouptypename]
        let winids = wince_state#OpenSubwinsByGroupType(a:supwinid, grouptype)
        call s:Log.VRB('Opened subwin group ', a:supwinid, ':', a:grouptypename, ' with winids ', winids)
    finally
        call wince_state#RefixDimensions(a:supwinid, preunfix)
    endtry
    return winids
endfunction

" Closes all subwins for a given supwin with priority higher than a given, and
" returns a list of group types closed. The model is unchanged.
function! wince_common#CloseSubwinsWithHigherPriorityThan(supwinid, grouptypename)
    call s:Log.DBG('wince_common#CloseSubwinsWithHigherPriorityThan ', a:supwinid, ':', a:grouptypename)
    let grouptypenames = wince_model#ShownSubwinGroupTypeNamesWithHigherPriorityThan(
   \    a:supwinid,
   \    a:grouptypename
   \)
    let preserved = []

    " grouptypenames is reversed because Vim sometimes makes strange decisions
    " when deciding which windows will fill the space left behind by a window
    " that closes. Assuming that subwins in ascending priority open from the
    " outside in (which is the intent underpinning the notion of subwin
    " priorities), closing them in descending priority order means closing
    " them from the inside out. This means that a subwin will never have to
    " stretch to fill the space left behind - only the supwin will stretch.
    " I don't fully understand why, but relaxing that constraint and allowing
    " subwins to stretch causes strange behaviour with other supwins filling
    " the space left by subwins closing after they have stretched.
    call reverse(grouptypenames)

    for grouptypename in grouptypenames
        call s:Log.VRB('Subwin group ', grouptypename, ' has higher priority')
        let pre = wince_common#PreCloseAndReopenSubwins(a:supwinid, grouptypename)
        call insert(preserved, {'grouptypename':grouptypename,'pre':pre})
        call wince_common#CloseSubwins(a:supwinid, grouptypename)
    endfor
    return preserved
endfunction

" Reopens subwins that were closed by wince_common#CloseSubwinsWithHigherPriorityThan
" and updates the model with the new winids
function! wince_common#ReopenSubwins(supwinid, preserved)
    call s:Log.DBG('wince_common#ReopenSubwins ', a:supwinid)
    for grouptype in a:preserved
        call s:Log.DBG('Reopening preserved supwin group ', a:supwinid, ':', grouptype.grouptypename)
        try
            let winids = wince_common#OpenSubwins(
           \    a:supwinid,
           \    grouptype.grouptypename
           \)
            call s:Log.VRB('Reopened subwin group ', a:supwinid, ':', grouptype.grouptypename, ' with winids ', winids)
            call wince_model#ChangeSubwinIds(a:supwinid, grouptype.grouptypename, winids)
            call wince_common#PostCloseAndReopenSubwins(
           \    a:supwinid,
           \    grouptype.grouptypename,
           \    grouptype.pre
           \)
            call wince_model#DeafterimageSubwinsByGroup(
           \    a:supwinid,
           \    grouptype.grouptypename
           \)

        catch /.*/
            call s:Log.WRN('wince_common#ReopenSubwins failed to open ', grouptype.grouptypename, ' subwin group for supwin ', a:supwinid, ':')
            call s:Log.DBG(v:throwpoint)
            call s:Log.WRN(v:exception)
            call wince_model#HideSubwins(a:supwinid, grouptype.grouptypename)
        endtry
    endfor
endfunction

function! wince_common#PreCloseAndReopenUberwins(grouptypename)
    call s:Log.DBG('wince_common#PreCloseAndReopenUberwins ', a:grouptypename)
    call wince_model#AssertUberwinGroupExists(a:grouptypename)
    let preserved = {}
    for typename in g:wince_uberwingrouptype[a:grouptypename].typenames
        let winid = wince_model#IdByInfo({
       \    'category': 'uberwin',
       \    'grouptype': a:grouptypename,
       \    'typename': typename
       \})
        let preserved[typename] = wince_state#PreCloseAndReopen(winid)
        call s:Log.VRB('Preserved uberwin ', a:grouptypename, ':', typename, ' with winid ', winid, ': ', preserved[typename])
    endfor
    return preserved
endfunction

function! wince_common#PostCloseAndReopenUberwins(grouptypename, preserved)
    call s:Log.DBG('wince_common#PostCloseAndReopenUberwins ', a:grouptypename)
    call wince_model#AssertUberwinGroupExists(a:grouptypename)
    for typename in keys(a:preserved)
        let winid = wince_model#IdByInfo({
       \    'category': 'uberwin',
       \    'grouptype': a:grouptypename,
       \    'typename': typename
       \})
        call s:Log.VRB('Restore uberwin ', a:grouptypename, ':', typename, ' with winid ', winid, ': ', a:preserved[typename])
        call wince_state#PostCloseAndReopen(winid, a:preserved[typename])
    endfor
endfunction

function! wince_common#PreCloseAndReopenSubwins(supwinid, grouptypename)
    call s:Log.DBG('wince_common#PreCloseAndReopenSubwins ', a:supwinid, ':', a:grouptypename)
    call wince_model#AssertSubwinGroupExists(a:supwinid, a:grouptypename)
    let preserved = {}
    for typename in g:wince_subwingrouptype[a:grouptypename].typenames
        let winid = wince_model#IdByInfo({
       \    'category': 'subwin',
       \    'supwin': a:supwinid,
       \    'grouptype': a:grouptypename,
       \    'typename': typename
       \})
        let preserved[typename] = wince_state#PreCloseAndReopen(winid)
        call s:Log.VRB('Preserved subwin ', a:supwinid, ':', a:grouptypename, ':', typename, ' with winid ', winid, ': ', preserved[typename])
    endfor
    return preserved
endfunction

function! wince_common#PostCloseAndReopenSubwins(supwinid, grouptypename, preserved)
    call s:Log.DBG('wince_common#PostCloseAndReopenSubwins ', a:supwinid, ':', a:grouptypename)
    call wince_model#AssertSubwinGroupExists(a:supwinid, a:grouptypename)
    for typename in keys(a:preserved)
        let winid = wince_model#IdByInfo({
       \    'category': 'subwin',
       \    'supwin': a:supwinid,
       \    'grouptype': a:grouptypename,
       \    'typename': typename
       \})
        call s:Log.VRB('Restore subwin ', a:supwinid, ':', a:grouptypename, ':', typename, ' with winid ', winid, ': ', a:preserved[typename])
        call wince_state#PostCloseAndReopen(winid, a:preserved[typename])
    endfor
endfunction

" Closes and reopens all shown subwins of a given supwin with priority higher
" than a given
function! wince_common#CloseAndReopenSubwinsWithHigherPriorityBySupwin(supwinid, grouptypename)
    call s:Log.DBG('wince_common#CloseAndReopenSubwinsWithHigherPriorityBySupwin ', a:supwinid, ':', a:grouptypename)
    let preserved = wince_common#CloseSubwinsWithHigherPriorityThan(a:supwinid, a:grouptypename)
    call s:Log.VRB('Preserved subwins across close-and-reopen: ', preserved)
    call wince_common#ReopenSubwins(a:supwinid, preserved)

    let dims = wince_state#GetWinDimensions(a:supwinid)
    call s:Log.VRB('New dimensions of closed-and-reopened subwins: ', dims)
    call wince_model#ChangeSupwinDimensions(a:supwinid, dims.nr, dims.w, dims.h)
endfunction

" Afterimages all afterimaging non-afterimaged subwins of a non-hidden subwin group
function! wince_common#AfterimageSubwinsByInfo(supwinid, grouptypename)
    call s:Log.DBG('wince_common#AfterimageSubwinsByInfo ', a:supwinid, ':', a:grouptypename)
    " Don't bother doing anything if the group is already afterimaged or has
    " no afterimaging types
    if empty(g:wince_subwingrouptype[a:grouptypename].afterimaging) ||
   \   wince_model#SubwinGroupIsAfterimaged(a:supwinid, a:grouptypename)
        call s:Log.DBG('Subwin group ', a:supwinid, ':', a:grouptypename, ' requires no aftermimaging')
        return
    endif

    " To make sure the subwins are in a good state, start from their supwin
    call wince_state#MoveCursorToWinid(a:supwinid)

    " Afterimage each afterimaging subwin in the group
    let aibufs = {}
    let afterimaging = g:wince_subwingrouptype[a:grouptypename].afterimaging
    for typename in keys(afterimaging)
        " Get the subwin ID
        let subwinid = wince_model#IdByInfo({
       \    'category': 'subwin',
       \    'supwin': a:supwinid,
       \    'grouptype': a:grouptypename,
       \    'typename': typename
       \})

        call s:Log.DBG('Afterimaging subwin ', a:supwinid, ':', a:grouptypename, ':', typename, ' with winid ', subwinid)

        " Afterimage the subwin in the state
        let aibufs[typename] = wince_state#AfterimageWindow(subwinid)
    endfor

    " Afterimage the subwin group in the model
    call wince_model#AfterimageSubwinsByGroup(a:supwinid, a:grouptypename, aibufs)
endfunction

" Afterimages all afterimaging non-afterimaged shown subwins of a supwin
function! wince_common#AfterimageSubwinsBySupwin(supwinid)
    call s:Log.DBG('wince_common#AfterimageSubwinsBySupwin ', a:supwinid)
    for grouptypename in wince_model#ShownSubwinGroupTypeNamesBySupwinId(a:supwinid)
        call wince_common#AfterimageSubwinsByInfo(a:supwinid, grouptypename)
    endfor
endfunction

" Afterimages all afterimaging non-afterimaged shown subwins of a supwin
" unless they belong to a given group
function! wince_common#AfterimageSubwinsBySupwinExceptOne(supwinid, excludedgrouptypename)
    call s:Log.DBG('wince_common#AfterimageSubwinsBySupwinExceptOne ', a:supwinid, ':', a:excludedgrouptypename)
    for grouptypename in wince_model#ShownSubwinGroupTypeNamesBySupwinId(a:supwinid)
        if grouptypename !=# a:excludedgrouptypename
            call wince_common#AfterimageSubwinsByInfo(a:supwinid, grouptypename)
        endif
    endfor
endfunction

" Closes all afterimaged subwin groups of a supwin (as well as any other
" groups with higher priority) and reopend them as non-afterimaged
function! wince_common#DeafterimageSubwinsBySupwin(supwinid)
    call s:Log.DBG('wince_common#DeafterimageSubwinsBySupwin ', a:supwinid)
    let prevgrouptypename = ''
    for grouptypename in wince_model#ShownSubwinGroupTypeNamesBySupwinId(a:supwinid)
        call s:Log.VRB('Subwin group ', a:supwinid, ':', grouptypename)
        if wince_model#SubwinGroupIsAfterimaged(a:supwinid, grouptypename)
            call s:Log.DBG(' Closing-and-reopening subwin groups of supwin ', a:supwinid, ' starting with partially afterimaged group ', grouptypename)
            let priority = g:wince_subwingrouptype[grouptypename].priority
            call wince_common#CloseAndReopenSubwinsWithHigherPriorityBySupwin(
           \    a:supwinid,
           \    prevgrouptypename
           \)
            return
        endif
        let prevgrouptypename = grouptypename
    endfor
endfunction

function! wince_common#UpdateAfterimagingByCursorWindow(curwin)
    call s:Log.DBG('wince_common#UpdateAfterimagingByCursorWindow ', a:curwin)
    " If the given cursor is in a window that doesn't exist, place it in a
    " window that does exist
    let catn = s:cases[a:curwin.category]

    " If the cursor's position is in an uberwin (or in a window that doesn't exist),
    " afterimage all shown afterimaging subwins of all supwins
    if catn ==# 1 || catn ==# 0
        call s:Log.DBG('Cursor position is uberwin. Afterimaging all subwins of all supwins.')
        for supwinid in wince_model#SupwinIds()
            call wince_common#AfterimageSubwinsBySupwin(supwinid)
        endfor

    " If the cursor's position is in a supwin, afterimage all
    " shown afterimaging subwins of all supwins except the one with
    " the cursor. Deafterimage all shown afterimaging subwins of the
    " supwin with the cursor.
    elseif catn ==# 2
        call s:Log.DBG('Cursor position is supwin ', a:curwin.id, '. Afterimaging all subwins of all other supwins')
        for supwinid in wince_model#SupwinIds()
            if supwinid !=# a:curwin.id
                call wince_common#AfterimageSubwinsBySupwin(supwinid)
            endif
        endfor
        call s:Log.DBG('Cursor position is supwin ', a:curwin.id, '. Deafterimaging all its subwins. ')
        call wince_common#DeafterimageSubwinsBySupwin(a:curwin.id)

    " If the cursor's position is in a subwin, afterimage all
    " shown afterimaging subwins of all supwins except the one with
    " the subwin with the cursor. Also afterimage all shown
    " afterimaging subwins of the supwin with the subwin with the
    " cursor except for the ones in the group with the subwin with
    " the cursor. If the cursor is in a group with an afterimaging
    " subwin, Deafterimage that group. I had fun writing this
    " comment.
    elseif catn ==# 3
        call s:Log.DBG('Cursor position is subwin ', a:curwin.supwin, ':', a:curwin.grouptype, ':', a:curwin.typename, '. Afterimaging all subwins of all other supwins.')
        for supwinid in wince_model#SupwinIds()
            if supwinid !=# a:curwin.supwin
                call wince_common#AfterimageSubwinsBySupwin(supwinid)
            endif
        endfor
        call s:Log.DBG('Cursor position is subwin ', a:curwin.supwin, ':', a:curwin.grouptype, ':', a:curwin.typename, '. Afterimaging all subwins of supwin ', a:curwin.supwin, ' except those in group ', a:curwin.supwin, ':', a:curwin.grouptype)
        call wince_common#DeafterimageSubwinsBySupwin(a:curwin.supwin)
        call wince_common#AfterimageSubwinsBySupwinExceptOne(
                    \    a:curwin.supwin,
                    \    a:curwin.grouptype
                    \)

    else
       throw 'Cursor final position ' . string(a:curwin) . ' is neither uberwin nor supwin nor subwin'
    endif
endfunction

" Sorry
function! s:DoWithout(curwin, callback, args, nouberwins, nosubwins, reselect)
    call s:Log.DBG('DoWithout ', a:curwin, ', ', a:callback, ', ', a:args, ', [', a:nouberwins, ',', a:nosubwins, ',', a:reselect, ']')
    let supwinids = wince_model#SupwinIds()
    let closedsubwingroupsbysupwin = {}
    for supwinid in supwinids
        let closedsubwingroupsbysupwin[supwinid] = []
    endfor

    let info = wince_common#GetCursorPosition()
    call s:Log.DBG('Cursor position before removals is ', info)
    
    if a:nosubwins && !empty(supwinids)
        let startwith = supwinids[0]
        let catn = s:cases[a:curwin.category]

        " If the cursor is in a supwin, start with it
        if catn ==# 2
            call s:Log.VRB('Cursor is in supwin ', a:curwin.id, '. Its subwins will be closed first')
            let startwith = str2nr(a:curwin.id)

        " If the cursor is in a subwin, start with its supwin
        elseif catn ==# 3
            call s:Log.VRB('Cursor is in subwin ', a:curwin.supwin, ':', a:curwin.grouptype, ':', a:curwin.typename, '. Subwins of supwin ', a:curwin.supwin, ' will be closed first')
            let startwith = str2nr(a:curwin.supwin)
        endif

        call remove(supwinids, index(supwinids, startwith))
        call insert(supwinids, startwith)

        call s:Log.DBG('Closing all subwins')
        for supwinid in supwinids
             let closedsubwingroupsbysupwin[supwinid] = 
            \    wince_common#CloseSubwinsWithHigherPriorityThan(supwinid, '')
        endfor
    endif

    let pretabnr = wince_state#GetTabnr()
    let posttabnr = pretabnr
    try
        let closeduberwingroups = []
        if a:nouberwins
            call s:Log.DBG('Closing all uberwins')
            let closeduberwingroups = wince_common#CloseUberwinsWithHigherPriorityThan('')
        endif
        try
            if type(a:curwin) ==# v:t_dict
                let winid = wince_model#IdByInfo(a:curwin)
                if wince_state#WinExists(winid)
                    call s:Log.DBG('Cursor window still exists. Moving to it.')
                    call wince_state#MoveCursorToWinid(winid)
                endif
            endif
            call s:Log.VRB('Invoking callback ', a:callback, ' with args ', a:args)
            let retval = call(a:callback, a:args)
            call s:Log.VRB('Callback gave return value ', retval)
            let info = wince_common#GetCursorPosition()
            call s:Log.DBG('New cursor position after callback is ', info)
            let posttabnr = wince_state#GetTabnr()
            call s:Log.DBG('New tab after callback is ', posttabnr)

        finally
            if pretabnr !=# posttabnr
                call s:Log.DBG('Callback changed tab from ', pretabnr, ' to ', posttabnr, '. Returning before reopening.')
                call wince_state#GotoTab(pretabnr)
            endif
            call s:Log.DBG('Reopening all uberwins')
            call wince_common#ReopenUberwins(closeduberwingroups)
        endtry

    finally
        call s:Log.DBG('Reopening all subwins')
        for supwinid in supwinids
            let newsupwinid = supwinid
            let gotopretabnr = 0
            if !wince_state#WinExists(supwinid)
                if pretabnr !=# posttabnr
                    " There is only one command that removes a window and ends
                    " in a different tab: WinceMoveToNewTab. So if the control
                    " reaches here, the command is WinceMoveToNewTab. We need to
                    " move the model's record of the supwin to the new tab's
                    " model, and also restore the state subwins in the new
                    " tab.
                    let supwindata = wince_model#RemoveSupwin(supwinid)
                    call wince_state#GotoTab(posttabnr)
                    call wince_model#RestoreSupwin(supwindata)
                    " This command changes the winid of the window being
                    " moved (even with legacy winids, because it wipes out
                    " window-local variables). So after moving the supwin
                    " record to the new tab's model, change its winid.
                    " Immediately after wincmd T, the only window in the tab
                    " is the one that was moved and so the cursor is in it
                    let newsupwinid = wince_state#GetCursorWinId()
                    call wince_model#ReplaceWinid(supwinid, newsupwinid)
                    let gotopretabnr = 1
                    call s:Log.DBG('Supwin ', supwinid, ' has moved to tab ', posttabnr, ' and changed winid to ', newsupwinid, '. Restoring subwins there.')
                else
                    call s:Log.DBG('Supwin ', supwinid, ' has vanished from state. Not restoring its subwins.')
                    continue
                endif
            endif
            call s:Log.VRB('Reopening all subwins of supwin ', newsupwinid)
            call wince_common#ReopenSubwins(newsupwinid, closedsubwingroupsbysupwin[supwinid])
            let dims = wince_state#GetWinDimensions(newsupwinid)
            call s:Log.VRB('Supwin dimensions after reopening its subwins: ', dims)
            " Afterimage everything after finishing with each supwin to avoid collisions
            call s:Log.VRB('Afterimaging all reopened subwins of supwin ', newsupwinid, ' to avoid collisions with the next supwin')
            call wince_common#AfterimageSubwinsBySupwin(newsupwinid)
            call wince_model#ChangeSupwinDimensions(newsupwinid, dims.nr, dims.w, dims.h)
            if gotopretabnr
                call s:Log.DBG('Finished restoring subwins of supwin ', newsupwinid, ' in tab ', posttabnr, '. Returning to tab ', pretabnr)
                call wince_state#GotoTab(pretabnr)
            endif
        endfor
        if pretabnr !=# posttabnr
            call s:Log.DBG('Finished reopening. All afterimaging subwins afterimaged. Moving back to post-callback tab ', posttabnr)
            call wince_state#GotoTab(posttabnr)
        endif
        if a:reselect
            let newpos = wince_common#RestoreCursorPosition(info)
            call wince_common#UpdateAfterimagingByCursorWindow(newpos)
        else
            let infowin = info.win
            if has_key(infowin, 'id')
                call wince_state#MoveCursorToWinid(infowin.id)
            else
                call wince_state#MoveCursorToWinid(wince_model#IdByInfo(infowin))
            endif
        endif
    endtry
    return retval
endfunction
function! wince_common#DoWithoutUberwins(curwin, callback, args, reselect)
    call s:Log.DBG('wince_common#DoWithoutUberwins ', a:curwin, ', ', a:callback, ', ', a:args, ', ', a:reselect)
    return s:DoWithout(a:curwin, a:callback, a:args, 1, 0, a:reselect)
endfunction

function! wince_common#DoWithoutSubwins(curwin, callback, args, reselect)
    call s:Log.DBG('wince_common#DoWithoutSubwins ', a:curwin, ', ', a:callback, ', ', a:args, ', ', a:reselect)
    return s:DoWithout(a:curwin, a:callback, a:args, 0, 1, a:reselect)
endfunction

function! wince_common#DoWithoutUberwinsOrSubwins(curwin, callback, args, reselect)
    call s:Log.DBG('wince_common#DoWithoutUberwinsOrSubwins ', a:curwin, ', ', a:callback, ', ', a:args, ', ', a:reselect, )
    return s:DoWithout(a:curwin, a:callback, a:args, 1, 1, a:reselect)
endfunction

function! s:Nop()
    call s:Log.DBG('Nop')
endfunction

" Closes and reopens all shown subwins in the current tab, afterimaging the
" afterimaging ones that need it
function! wince_common#CloseAndReopenAllShownSubwins(curwin)
    call s:Log.DBG('wince_common#CloseAndReopenAllShownSubwins ', a:curwin)
     call wince_common#DoWithoutSubwins(a:curwin, function('s:Nop'), [], 1)
endfunction

" Returns a statusline-friendly string that will evaluate to the correct
" colour and flag for the given subwin group
" The way that Vim's statusline option works is very restrictive:
" 1. %!<expr> results in a Vimscript expression, which is evaluated in the
"    context of the current window to give a statusline string
" 2. The statusline string is expanded once for each window in the context
"    of that window, resulting in each window having its own statusline
" This is problematic because there is only one expansion step that can be done
" in a window-specific way. Therefore the string that gets expanded by that
" step needs to be the same for all windows, and evaluate to something
" different in every window. Each colour change needs to be its own expansion
" item, so there can't just be a function that returns all the flags - Vim
" wouldn't recurse expansion on the colour changes between the flags.
" Wince's approach is to use the wince_user#SubwinFlagsForGlobalStatusline user
" operation to craft a long string containing statusline items for all the
" subwin groups, one after another. Unfortunately this means that every window
" has to evaluate items for every subwin group, every time.
" The only other way would be to set a different statusline option value for
" each supwin, from the resolver. This would mean the user needs to configure
" some sort of statusline template (with only one expansion item - the subwin
" flags) which the resolver would then apply supwin-specific flags to. I deem
" this solution too complicated, as it would surely cause trouble with statusline
" plugins. The current solution using wince_user#SubwinFlagsForGlobalStatusline has
" only one downside - performance. If the user has trouble with statusline
" evaluation taking too long, they are free to remove the subwin flags from
" their statusline.
function! wince_common#SubwinFlagByGroup(grouptypename)
    return wince_model#SubwinFlagByGroup(wince_state#GetCursorWinId(), a:grouptypename)
endfunction
function! wince_common#SubwinFlagStrByGroup(grouptypename)
    call s:Log.DBG('wince_common#SubwinFlagStrByGroup ', a:grouptypename)
    let flagcol = wince_model#SubwinFlagCol(a:grouptypename)
    let flagexpr = 'wince_common#SubwinFlagByGroup("' . a:grouptypename . '")'
    return '%' . flagcol . '*%{' . flagexpr . '}'
endfunction
