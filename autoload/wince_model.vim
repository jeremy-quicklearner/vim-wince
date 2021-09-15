" Wince Model

" Avoid loading twice
if exists('s:loaded')
    finish
endif
let s:loaded = 0

" See wince.vim
let s:Log = jer_log#LogFunctions('wince-model')
let s:t = jer_util#Types()

" g:wince_tabenterpreresolvecallbacks = [
"     <funcref>
"     ...
" ]
" g:wince_postuseropcallbacks = [
"     <funcref>
"     ...
" ]
" g:wince_uberwingrouptype = {
"     <grouptypename>: {
"         typenames: [<typename>, ...]
"         statuslines: [<statusline>, ...]
"         flag: <flag>
"         hidflag: <flag>
"         flagcol: <1-9>
"         priority: <num>
"         orderidx: <num>
"         canHaveLoclist: [<0|1>, ...]
"         widths: <num>
"         heights: <num>
"         toOpen: <funcref>
"         toClose: <funcref>
"         toIdentify: <funcref>
"     }
"     ...
" }
" g:wince_ordered_uberwingrouptype = [
"     <grouptypename>
"     ...
" ]
" g:wince_subwingrouptype = {
"     <grouptypename>: {
"         typenames: [<typename>, ...]
"         statuslines: [<statusline>, ...]
"         flag: <flag>
"         hidflag: <flag>
"         flagcol: <1-9>
"         priority: <num>
"         orderidx: <num>
"         afterimaging: {
"             <typename>: 1
"             ...
"         }
"         canHaveLoclist: [<0|1>, ...]
"         closeWithBelowRight: <0|1>
"         widths: <num>
"         heights: <num>
"         toOpen: <funcref>
"         toClose: <funcref>
"         toIdentify: <funcref>
"     }
"     ...
" }
" g:wince_ordered_subwingrouptype = [
"     <grouptypename>
"     ...
" ]
" t:prevwin = {
"     category: <'uberwin'|'supwin'|'subwin'|'none'>
"     grouptypename: <grouptypename>
"     grouptype: <grouptype>
"     supwin: <winid>
"     id: <winid>
" }
" t:curwin = {
"     category: <'uberwin'|'supwin'|'subwin'|'none'>
"     grouptypename: <grouptypename>
"     grouptype: <grouptype>
"     supwin: <winid>
"     id: <winid>
" }
" t:wince_uberwin = {
"     <grouptypename>: {
"         hidden: <0|1>
"         uberwin: {
"             <typename>: {
"                 id: <uberwinid>
"                 nr: <winnr>
"                 w: <width>
"                 h: <height>
"             }
"             ...
"         }
"     }
"     ...
" }
" t:wince_supwin = {
"     <supwinid>: {
"         nr: <winnr>
"         w: <width>
"         h: <height>
"         subwin: {
"             <grouptypename>: {
"                 hidden: <0|1>
"                 afterimaged: <0|1>
"                 subwin: {
"                     <typename>: {
"                         id: <subwinid>
"                     }
"                     ...
"                 }
"             }
"             ...
"         }
"     }
"     ...
" }
" t:wince_subwin = {
"     <subwinid>: {
"         supwin: <supwinid>
"         grouptypename: <grouptypename>
"         typename: <typename>
"         aibuf: <bufnr>
"         relnr: <relnr>
"         w: <width>
"         h: <height>
"     }
"     ...
" }
" t:wince_all = {
"     <winid>: 1
"     ...
" }

" Resolver and post-user-operation callbacks and group types are global
if !exists('g:wince_uberwingrouptype')
    call s:Log.INF('Initializing global model')
    let g:wince_tabenterpreresolvecallbacks = []
    let g:wince_postuseropcallbacks = []
    let g:wince_uberwingrouptype = {}
    let g:wince_subwingrouptype = {}
    let g:wince_ordered_uberwingrouptype = []
    let g:wince_ordered_subwingrouptype = []
endif

" The rest of the model is tab-specific
function! s:EnsureModelExists()
    call s:Log.DBG('EnsureModelExists')
    if exists('t:wince_uberwin')
        return
    endif
    let t:prevwin = {'category':'none','id':0}
    let t:curwin = {'category':'none','id':0}
    let t:wince_uberwin = {}
    let t:wince_supwin = {}
    let t:wince_subwin = {}
    let t:wince_all = {}
endfunction

" Callback manipulation
function! s:AddTypedCallback(type, callback)
    call s:Log.DBG('Callback: ', a:type, ', ', a:callback)
    if type(a:callback) != s:t.func
        throw 'Callback is not a function'
    endif
    if !exists('g:wince_' . a:type . 'callbacks')
        throw 'Callback type ' . a:type . ' does not exist')
    endif
    if eval('index(g:wince_' . a:type . 'callbacks, a:callback)') >= 0
        throw 'Callback is already registered'
    endif

    execute 'call add(g:wince_' . a:type . 'callbacks, a:callback)'
endfunction
function! wince_model#AddTabEnterPreResolveCallback(callback)
    call s:Log.DBG('TabEnter PreResolve Callback: ', a:callback)
    call s:AddTypedCallback('tabenterpreresolve', a:callback)
endfunction
function! wince_model#AddPostUserOperationCallback(callback)
    call s:Log.DBG('Post-User Operation Callback: ', a:callback)
    call s:AddTypedCallback('postuserop', a:callback)
endfunction
function! wince_model#TabEnterPreResolveCallbacks()
    call s:Log.DBG('wince_model#TabEnterPreResolveCallbacks')
    return g:wince_tabenterpreresolvecallbacks
endfunction
function! wince_model#PostUserOperationCallbacks()
    call s:Log.DBG('wince_model#PostUserOperationCallbacks')
    return g:wince_postuseropcallbacks
endfunction

" Uberwin group type manipulation
function! wince_model#AssertUberwinGroupTypeExists(grouptypename)
    call s:Log.DBG('wince_model#AssertUberwinGroupTypeExists ', a:grouptypename)
    let item = get(g:wince_uberwingrouptype, a:grouptypename)
    if type(item) !=# s:t.dict
        throw 'nonexistent uberwin group type ' . a:grouptypename
    endif
    return item
endfunction
function! wince_model#AssertUberwinTypeExists(grouptypename, typename)
    call s:Log.DBG('wince_model#AssertUberwinTypeExists ', a:grouptypename)
    let grouptype = wince_model#AssertUberwinGroupTypeExists(a:grouptypename)
    let idx = index(grouptype.typenames, a:typename)
    if idx < 0
        throw 'uberwin group type ' . a:grouptypename . ' has no uberwin type ' . a:typename
    endif
    return [grouptype, idx]
endfunction
function! wince_model#AddUberwinGroupType(name, typenames, statuslines,
                                       \flag, hidflag, flagcol,
                                       \priority, canHaveLoclist,
                                       \widths, heights, toOpen, toClose,
                                       \toIdentify)
    " All parameters must be of the correct type
    if type(a:name) != s:t.string
        throw 'name must be a string'
    endif
    if type(a:typenames) != s:t.list
        throw 'typenames must be a list'
    endif
    for elem in a:typenames
        if type(elem) != s:t.string
            throw 'typenames must be a list of strings'
        endif
    endfor
    if type(a:statuslines) != s:t.list
        throw 'statuslines must be a list'
    endif
    for elem in a:statuslines
        if type(elem) != s:t.string
            throw 'statuslines must be a list of strings'
        endif
    endfor
    if type(a:flag) != s:t.string
        throw 'flag must be a string'
    endif
    if type(a:hidflag) != s:t.string
        throw 'hidflag must be a string'
    endif
    if type(a:flagcol) != s:t.number ||  a:flagcol > 9 || a:flagcol < 1
       throw 'flagcol must be a number between 1-9 inclusive'
    endif
    if type(a:priority) != s:t.number || a:priority <=# 0
        throw 'priority must be a positive number'
    endif
    if type(a:canHaveLoclist) != s:t.list
        throw 'canHaveLoclist must be a list'
    endif
    for elem in a:canHaveLoclist
        if type(elem) != s:t.number || elem < 0 || elem > 1
            throw 'canHaveLoclist must be a list of 0s and 1s'
        endif
    endfor
    if type(a:widths) != s:t.list
        throw 'widths must be a list'
    endif
    for elem in a:widths
        if type(elem) != s:t.number || elem < -1
            throw 'widths must be a list of numbers greater than -2'
        endif
    endfor
    if type(a:heights) != s:t.list
        throw 'heights must be a list'
    endif
    for elem in a:heights
        if type(elem) != s:t.number || elem < -1
            throw 'heights must be a list of numbers greater than -2'
        endif
    endfor
    if type(a:toOpen) != s:t.func
        throw 'toOpen must be a function'
    endif
    if type(a:toClose) != s:t.func
        throw 'toClose must be a function'
    endif
    if type(a:toIdentify) != s:t.func
        throw 'toIdentify must be a function'
    endif

    " All the lists must be the same length
    let numtypes = len(a:typenames)
    if len(a:widths) != numtypes
        throw len(a:widths) . ' widths provided for ' . numtypes . ' uberwin types'
    endif
    if len(a:heights) != numtypes
        throw len(a:heights) . ' heights provided for ' . numtypes . ' uberwin types'
    endif

    call s:Log.DBG('Uberwin Group Type: ', a:name)

    " Add the uberwin type group
    let grouptype = {
    \    'name': a:name,
    \    'typenames': a:typenames,
    \    'statuslines': a:statuslines,
    \    'flag': a:flag,
    \    'hidflag': a:hidflag,
    \    'flagcol': a:flagcol,
    \    'priority': a:priority,
    \    'canHaveLoclist': a:canHaveLoclist,
    \    'widths': a:widths,
    \    'heights': a:heights,
    \    'toOpen': a:toOpen,
    \    'toClose': a:toClose,
    \    'toIdentify': a:toIdentify
    \}
    let g:wince_uberwingrouptype[a:name] = grouptype

    let added = 0
    let oldlen = len(g:wince_ordered_uberwingrouptype)
    for idx in range(oldlen + 1)
        if !added
            if idx ==# oldlen
                call add(g:wince_ordered_uberwingrouptype, a:name)
                let grouptype.orderidx = idx
                " No need to update 'added' since we're at the end
            elseif a:priority < g:wince_uberwingrouptype[g:wince_ordered_uberwingrouptype[idx]].priority
                call insert(g:wince_ordered_uberwingrouptype, a:name, idx)
                let grouptype.orderidx = idx
                let added = 1
            endif
        else
            let g:wince_uberwingrouptype[g:wince_ordered_uberwingrouptype[idx]].orderidx = idx
        endif
    endfor
endfunction

" Subwin group type manipulation
function! wince_model#AssertSubwinGroupTypeExists(grouptypename)
    call s:Log.DBG('wince_model#AssertSubwinGroupTypeExists ', a:grouptypename)
    let item = get(g:wince_subwingrouptype, a:grouptypename)
    if type(item) !=# s:t.dict
        throw 'nonexistent subwin group type ' . a:grouptypename
    endif
    return item
endfunction
function! wince_model#AssertSubwinTypeExists(grouptypename, typename)
    call s:Log.DBG('wince_model#AssertSubwinTypeExists ', a:grouptypename, ':', a:typename)
    let grouptype =  wince_model#AssertSubwinGroupTypeExists(a:grouptypename)
    let typeidx = index(grouptype.typenames, a:typename)
    if typeidx < 0
        throw 'subwin group type ' . a:grouptypename . ' has no subwin type ' . a:typename
    endif
    return [grouptype, typeidx]
endfunction
function! wince_model#SubwinGroupTypeHasAfterimagingSubwin(grouptypename)
    call s:Log.DBG('wince_model#SubwinGroupTypeHasAfterimagingSubwin ', a:grouptypename)
    return !empty(wince_model#AssertSubwinGroupTypeExists(a:grouptypename).afterimaging)
endfunction
function! wince_model#AddSubwinGroupType(name, typenames, statuslines,
                                      \flag, hidflag, flagcol,
                                      \priority, afterimaging,
                                      \canHaveLoclist, stompWithBelowRight,
                                      \widths, heights,
                                      \toOpen, toClose, toIdentify)
    " All parameters must be of the correct type
    if type(a:name) != s:t.string
        throw 'name must be a string'
    endif
    if type(a:typenames) != s:t.list
        throw 'typenames must be a list'
    endif
    if type(a:statuslines) != s:t.list
        throw 'statuslines must be a list'
    endif
    for elem in a:statuslines
        if type(elem) != s:t.string
            throw 'statuslines must be a list of strings'
        endif
    endfor
    for elem in a:typenames
        if type(elem) != s:t.string
            throw 'typenames must be a list of strings'
        endif
    endfor
    if type(a:flag) != s:t.string
        throw 'flag must be a string'
    endif
    if type(a:hidflag) != s:t.string
        throw 'hidflag must be a string'
    endif
    if type(a:flagcol) != s:t.number ||  a:flagcol > 9 || a:flagcol < 1
       throw 'flagcol must be a number between 1-9 inclusive'
    endif
    if type(a:priority) != s:t.number || a:priority <= 0
        throw 'priority must be a positive number'
    endif
    if type(a:afterimaging) != s:t.list
        throw 'afterimaging must be a list'
    endif
    for elem in a:afterimaging
        if type(elem) != s:t.number || elem < 0 || elem > 1
            throw 'afterimaging must be a list of 1s or 0s'
        endif
    endfor
    if type(a:canHaveLoclist) != s:t.list
        throw 'canHaveLoclist must be a list'
    endif
    for elem in a:canHaveLoclist
        if type(elem) != s:t.number || elem < 0 || elem > 1
            throw 'canHaveLoclist must be a list of 0s and 1s'
        endif
    endfor
    if type(a:stompWithBelowRight) != s:t.number || elem < 0 || elem > 1
        throw 'stompWithBelowRight must be a 0 or 1'
    endif
    if type(a:widths) != s:t.list
        throw 'widths must be a list'
    endif
    for elem in a:widths
        if type(elem) != s:t.number || elem < -1
            throw 'widths must be a list of numbers greater than -2'
        endif
    endfor
    if type(a:heights) != s:t.list
        throw 'heights must be a list'
    endif
    for elem in a:heights
        if type(elem) != s:t.number || elem < -1
            throw 'heights must be a list of numbers greater than -2'
        endif
    endfor
    if type(a:toOpen) != s:t.func
        throw 'toOpen must be a function'
    endif
    if type(a:toClose) != s:t.func
        throw 'toClose must be a function'
    endif
    if type(a:toIdentify) != s:t.func
        throw 'toIdentify must be a function'
    endif

    " All the lists must be the same length
    let numtypes = len(a:typenames)
    if len(a:widths) != numtypes
        throw len(a:widths) . ' widths provided for ' . numtypes . ' subwin types'
    endif
    if len(a:heights) != numtypes
        throw len(a:heights) . ' heights provided for ' . numtypes . ' subwin types'
    endif
    if len(a:afterimaging) != numtypes
        throw len(a:afterimaging) . ' afterimaging flags provided for ' . numtypes . ' subwin types'
    endif

    let afterimagingdict = {}
    for idx in range(numtypes)
        if a:afterimaging[idx]
            let afterimagingdict[a:typenames[idx]] = 1
        endif
    endfor

    call s:Log.DBG('Subwin Group Type: ', a:name)

    " Add the subwin type group
    let grouptype = {
   \    'name': a:name,
   \    'typenames': a:typenames,
   \    'statuslines': a:statuslines,
   \    'flag': a:flag,
   \    'hidflag': a:hidflag,
   \    'flagcol': a:flagcol,
   \    'priority': a:priority,
   \    'afterimaging': afterimagingdict,
   \    'canHaveLoclist': a:canHaveLoclist,
   \    'stompWithBelowRight': a:stompWithBelowRight,
   \    'widths': a:widths,
   \    'heights': a:heights,
   \    'toOpen': a:toOpen,
   \    'toClose': a:toClose,
   \    'toIdentify': a:toIdentify
   \}
    let g:wince_subwingrouptype[a:name] = grouptype

    let added = 0
    let oldlen = len(g:wince_ordered_subwingrouptype)
    for idx in range(oldlen + 1)
        if !added
            if idx ==# oldlen
                call add(g:wince_ordered_subwingrouptype, a:name)
                let grouptype.orderidx = idx
                " No need to update 'added' since we're at the end
            elseif a:priority < g:wince_subwingrouptype[g:wince_ordered_subwingrouptype[idx]].priority
                call insert(g:wince_ordered_subwingrouptype, a:name, idx)
                let grouptype.orderidx = idx
                let added = 1
            endif
        else
            let g:wince_subwingrouptype[g:wince_ordered_subwingrouptype[idx]].orderidx = idx
        endif
    endfor
endfunction

" Previous window info manipulation
function! wince_model#PreviousWinInfo()
    call s:Log.DBG('wince_model#PreviousWinInfo')
    call s:EnsureModelExists()
    call s:Log.DBG('Previous window: ', t:prevwin)
    return t:prevwin
endfunction

function! wince_model#SetPreviousWinInfo(info)
    call s:Log.INF('wince_model#SetPreviousWinInfo ', a:info)
    if !wince_model#IdByInfo(a:info)
        call s:Log.INF("Attempted to set previous window to one that doesn't exist in model: ", a:info, '. Default to current window')
        let t:prevwin = t:curwin
        return
    endif
    let t:prevwin = a:info
endfunction

" Current window info manipulation
function! wince_model#CurrentWinInfo()
    call s:Log.DBG('wince_model#CurrentWinInfo')
    call s:EnsureModelExists()
    call s:Log.DBG('Current window: ', t:curwin)
    return t:curwin
endfunction

function! wince_model#SetCurrentWinInfo(info)
    call s:Log.INF('wince_model#SetCurrentWinInfo ', a:info)
    if !wince_model#IdByInfo(a:info)
        throw "Attempted to set current window to one that doesn't exist in model: " . string(a:info)
    endif
    let t:curwin = a:info
endfunction

" General Getters

" Returns the names of all uberwin groups in the current tab, shown or not
function! wince_model#UberwinGroups()
    call s:Log.DBG('wince_model#UberwinGroups')
    call s:EnsureModelExists()
    let groups = keys(t:wince_uberwin)
    call s:Log.DBG('Uberwin groups: ', groups)
    return groups
endfunction

" Returns a list containing the IDs of all uberwins in an uberwin group
function! wince_model#UberwinIdsByGroupTypeName(grouptypename)
    call s:Log.DBG('wince_model#UberwinIdsByGroupTypeName ', a:grouptypename)
    call wince_model#AssertUberwinGroupTypeExists(a:grouptypename)
    let uberwinids = []
    if !wince_model#ShownUberwinGroupExists(a:grouptypename)
        call s:Log.DBG('No shown uberwin group ', a:grouptypename)
        return []
    endif
    let uberwins = t:wince_uberwin[a:grouptypename].uberwin
    for typename in wince_model#UberwinTypeNamesByGroupTypeName(a:grouptypename)
        let winid = uberwins[typename].id
        call s:Log.VRB('Uberwin ', a:grouptypename, ':', typename, ' has ID ', winid)
        call add(uberwinids, winid)
    endfor
    call s:Log.DBG('Uberwin IDs for group ', a:grouptypename, ': ', uberwinids)
    return uberwinids
endfunction

function! wince_model#SomeUberwinIdByGroupTypeName(grouptypename)
    call s:Log.DBG('wince_model#SomeUberwinIdByGroupTypeName ', a:grouptypename)
    if !wince_model#ShownUberwinGroupExists(a:grouptypename)
        call s:Log.DBG('No shown uberwin group ', a:grouptypename)
        return 0
    endif
    for uberwin in values(t:wince_uberwin[a:grouptypename].uberwin)
        return uberwin.id
    endfor
endfunction

" Returns a list containing all uberwin IDs
function! wince_model#UberwinIds()
    call s:Log.DBG('wince_model#UberwinIds')
    call s:EnsureModelExists()
    let uberwinids = []
    for [grouptypename, group] in items(t:wince_uberwin)
        if group.hidden
            call s:Log.VRB('Skipping hidden uberwin group ', grouptypename)
            continue
        endif
        let uberwins = group.uberwin
        for [typename, uberwin] in items(uberwins)
            let winid = uberwin.id
            call s:Log.VRB('Uberwin ', grouptypename, ':', typename, ' has ID ', winid)
            call add(uberwinids, winid)
        endfor
    endfor
    call s:Log.DBG('Uberwin IDs: ', uberwinids)
    return uberwinids
endfunction

" Returns a string with uberwin flags to be included in the tabline, and its
" length (not counting colour-changing escape sequences)
function! wince_model#UberwinFlagsStr()
    call s:Log.DBG('wince_model#UberwinFlagsStr')
    call s:EnsureModelExists()

    let flagsstr = ''
    let flagslen = 0

    for [grouptypename, group] in items(t:wince_uberwin)
        let grouptype = g:wince_uberwingrouptype[grouptypename]
        if group.hidden
            call s:Log.VRB('Hidden uberwin group ', grouptypename, ' contributes ', grouptype.hidflag)
            let flag = grouptype.hidflag
        else
            call s:Log.VRB('Shown uberwin group ', grouptypename, ' contributes ', grouptype.flag)
            let flag = grouptype.flag
        endif
        let flagsstr .= '%' . grouptype.flagcol . '*[' . flag . ']'
        let flagslen += len(flag) + 2
    endfor

    call s:Log.DBG('Uberwin flags: ', flagsstr)
    return [flagsstr, flagslen]
endfunction

" Returns a list containing all supwin IDs
function! wince_model#SupwinIds()
    call s:Log.DBG('wince_model#SupwinIds')
    call s:EnsureModelExists()
    " Can't use map(t:wince_supwin) because it would change t_supwin's
    " contents
    let winids = map(keys(t:wince_supwin), 'str2nr(v:val)')
    call s:Log.DBG('Supwin IDs: ', winids)
    return winids
endfunction

" Returns a list containing the IDs of all subwins in a subwin group
function! wince_model#SubwinIdsByGroupTypeName(supwinid, grouptypename)
    call s:Log.DBG('wince_model#SubwinIdsByGroupTypeName ', a:supwinid, ':', a:grouptypename)
    if !wince_model#ShownSubwinGroupExists(a:supwinid, a:grouptypename)
        call s:Log.DBG('No shown subwin group ', a:supwinid, ':', a:grouptypename)
        return []
    endif
    let subwinids = []
    let subwins = t:wince_supwin[a:supwinid].subwin[a:grouptypename].subwin
    for [typename, subwin] in items(subwins)
        let subwinid = subwin.id
        call s:Log.VRB('Subwin ', a:supwinid, ':', a:grouptypename, ':', typename, ' has ID ', subwinid)
        call add(subwinids, subwinid)
    endfor
    call s:Log.DBG('Subwin IDs for group ', a:supwinid, ':', a:grouptypename, ': ', subwinids)
    return subwinids
endfunction

function! wince_model#SomeSubwinIdByGroupTypeName(supwinid, grouptypename)
    call s:Log.DBG('wince_model#SomeSubwinIdByGroupTypeName ', a:supwinid, ':', a:grouptypename)
    if !wince_model#ShownSubwinGroupExists(a:supwinid, a:grouptypename)
        call s:Log.DBG('No shown subwin group ', a:supwinid, ':', a:grouptypename)
        return 0
    endif
    for subwin in values(t:wince_supwin[a:supwinid].subwin[a:grouptypename].subwin)
        return subwin.id
    endfor
endfunction

" Returns which flag to show for a given supwin due to a given subwin group
" type's existence, hiddenness, etc.
function! wince_model#SubwinFlagByGroup(supwinid, grouptypename)
    call s:Log.DBG('wince_model#SubwinFlagByGroup ', a:supwinid, ':', a:grouptypename)
    call s:EnsureModelExists()
    let supwin = get(t:wince_supwin, a:supwinid, 0)
    if empty(supwin)
        call s:Log.DBG('No supwin ', a:supwinid, '. Returning empty string.')
        return ''
    endif
    let group = get(supwin.subwin, a:grouptypename, 0)
    if empty(group)
        call s:Log.DBG('No subwin group ', a:supwinid, ':', a:grouptypename, '. Returning empty string.')
        return ''
    endif

    let grouptype = g:wince_subwingrouptype[a:grouptypename]
    if group.hidden
        call s:Log.DBG('Hidden subwin group ', a:supwinid, ':', a:grouptypename, ' gives ', grouptype.hidflag)
        let flag = grouptype.hidflag
    else
        call s:Log.DBG('Shown subwin group ', a:supwinid, ':', a:grouptypename, ' gives ', grouptype.flag)
        let flag = grouptype.flag
    endif

    return '[' . flag . ']'
endfunction

function! wince_model#SubwinFlagCol(grouptypename)
    call s:Log.DBG('wince_model#SubwinFlagCol ', a:grouptypename)
    let flagcol = wince_model#AssertSubwinGroupTypeExists(a:grouptypename).flagcol
    call s:Log.DBG('Flag colour is ', flagcol)
    return flagcol
endfunction

" Returns a list containing all subwin IDs
function! wince_model#SubwinIds()
    call s:Log.DBG('wince_model#SubwinIds')
    call s:EnsureModelExists()
    let winids = map(keys(t:wince_subwin), 'str2nr(v:val)')
    call s:Log.DBG('Subwin IDs: ', winids)
    return winids
endfunction

" Returns 1 if a winid is represented in the model. 0 otherwise.
function! wince_model#WinExists(winid)
    call s:Log.DBG('wince_model#WinExists ', a:winid)
    return has_key(t:wince_all, a:winid)
endfunction

" Given a window ID, return a dict that identifies it within the model
function! wince_model#InfoById(winid)
    call s:Log.DBG('wince_model#InfoById ', a:winid)
    call s:Log.VRB('Check for ID', a:winid, ' in supwin list')
    call s:EnsureModelExists()
    let supwin = get(t:wince_supwin, a:winid, 0)
    if !empty(supwin)
        call s:Log.DBG('ID ', a:winid, ' found in supwin list with dimensions [', supwin.nr, ',', supwin.w, ',', supwin.h, ']')
        return {
       \    'category': 'supwin',
       \    'id': a:winid,
       \    'nr': supwin.nr,
       \    'w': supwin.w,
       \    'h': supwin.h
       \}
    endif

    call s:Log.VRB('Check for ID ', a:winid, ' in subwin list')
    let subwin = get(t:wince_subwin, a:winid, 0)
    if !empty(subwin)
        call s:Log.DBG('ID ', a:winid, ' found in subwin listas ', subwin.supwin, ':', subwin.typename, ' with dimensions [', subwin.relnr, ',', subwin.w, ',', subwin.h, ']')
        return {
       \    'category': 'subwin',
       \    'supwin': subwin.supwin,
       \    'grouptype': subwin.grouptypename,
       \    'typename': subwin.typename,
       \    'relnr': subwin.relnr,
       \    'w': subwin.w,
       \    'h': subwin.h
       \}
    endif

    call s:Log.VRB('Check for ID ', a:winid, ' in All list')
    if !has_key(t:wince_all, a:winid)
        call s:Log.DBG('ID ', a:winid, ' not found in model')
        return {'category': 'none', 'id': a:winid}
    endif

    for [grouptypename, group] in items(t:wince_uberwin)
        for [typename, uberwin] in items(group.uberwin)
            call s:Log.VRB('Check for ID ', a:winid, ' in uberwin ', grouptypename, ':', typename)
            if uberwin.id == a:winid
                call s:Log.DBG('ID ', a:winid, ' found in uberwin record with dimensions [', uberwin.nr, ',', uberwin.w, ',', uberwin.h, ']')
                return {
               \    'category': 'uberwin',
               \    'grouptype': grouptypename,
               \    'typename': typename,
               \    'nr': uberwin.nr,
               \    'w': uberwin.w,
               \    'h': uberwin.h
               \}
            endif
        endfor
    endfor

    throw 'Control reached the end of wince_model#InfoById for winid ' . a:winid
endfunction

" Given a supwin id, returns it. Given a subwin ID, returns the ID of the
" supwin of the subwin. Given anything else, fails
let s:cases = {'none':0,'uberwin':1,'supwin':2,'subwin':3}
function! wince_model#SupwinIdBySupwinOrSubwinId(winid)
    call s:Log.DBG('wince_model#SupwinIdBySupwinOrSubwinId ', a:winid)
    let info = wince_model#InfoById(a:winid)
    let category = get(s:cases, info.category, -1)
    if category ==# 0
        throw 'Window with id ' . a:winid . ' is uncategorized'
    elseif category ==# 1
        throw 'Window with id ' . a:winid . ' is an uberwin'
    elseif category ==# 2
        call s:Log.DBG('ID ', a:winid, ' found in supwin list')
        return a:winid
    elseif category ==# 3
        call s:Log.DBG('ID ', a:winid, ' found in subwin list with supwin ', info.supwin)
        return info.supwin
    else
        throw 'Control should never reach here'
    endif
endfunction

" Given window info, return a statusline for that window. Returns an empty
" string if the window should have the default statusline
function! wince_model#StatusLineByInfo(info)
    call s:Log.DBG('wince_model#StatusLineByInfo ', a:info)
    let category = get(s:cases, a:info.category, -1)
    if !exists('t:wince_uberwin') || category ==# 2 || category ==# 0
        call s:Log.DBG('Supwin or uncategorized window carries default statusline')
        return ''
    elseif category ==# 1
        let [grouptype, typeidx] = wince_model#AssertUberwinTypeExists(a:info.grouptype, a:info.typename)
        call s:Log.DBG('Uberwin type ', a:info.grouptype, ':', a:info.typename, ' specifies statusline')
    elseif category ==# 3
        let [grouptype, typeidx] = wince_model#AssertSubwinTypeExists(a:info.grouptype, a:info.typename)
        call s:Log.DBG('Subwin type ', a:info.grouptype, ':', a:info.typename, ' specifies statusline')
    endif

    let statusline = grouptype.statuslines[typeidx]
    call s:Log.DBG('Statusline: ', statusline)
    return statusline
endfunction

" Given an info dict from wince_model#InfoById, return the window ID
function! wince_model#IdByInfo(info)
    call s:Log.DBG('wince_model#IdByInfo ', a:info)
    let category = get(s:cases, a:info.category, -1)
    if category ==# 2 || category ==# 0
        let id = a:info.id
        if wince_model#SupwinExists(id)
            call s:Log.DBG('Supwin with ID ', id, ' found')
            return id
        endif
        call s:Log.DBG('Supwin with ID ', a:info.id, ' not found')
    elseif category ==# 1
        let grouptype = a:info.grouptype
        if wince_model#ShownUberwinGroupExists(grouptype)
            let typename = a:info.typename
            let id = t:wince_uberwin[grouptype].uberwin[typename].id
            call s:Log.DBG('Uberwin ', grouptype, ':', typename, ' has ID ', id)
            return id
        endif
        call s:Log.DBG('Uberwin group ', grouptype, ' not shown')
    elseif category ==# 3
        let supwin = a:info.supwin
        let grouptype = a:info.grouptype
        if wince_model#ShownSubwinGroupExists(supwin, grouptype)
            let typename = a:info.typename
            let id = t:wince_supwin[supwin].subwin[grouptype].subwin[typename].id
            call s:Log.DBG('Subwin ', supwin, ':', grouptype, ':', typename, ' has ID ', id)
            return id
        endif
        call s:Log.DBG('Subwin group ', supwin, ':', grouptype, ' not shown')
    endif
    return 0
endfunction

" Return a list of names of group types of all non-hidden uberwin groups with
" priorities higher than a given, sorted in ascending order of priority
function! wince_model#ShownUberwinGroupTypeNamesWithHigherPriorityThan(grouptypename)
    call s:Log.DBG('wince_model#ShownUberwinGroupTypeNamesWithHigherPriorityThan ', a:grouptypename)
    call s:EnsureModelExists()
    if !empty(a:grouptypename)
        if !has_key(g:wince_uberwingrouptype, a:grouptypename)
            throw 'uberwin group type ' . a:grouptypename . ' does not exist'
        endif
        let idx = get(g:wince_uberwingrouptype, a:grouptypename).orderidx
    else
        let idx = -1
    endif

    let grouptypenames = g:wince_ordered_uberwingrouptype[(idx + 1):]

    call filter(grouptypenames, 'wince_model#ShownUberwinGroupExists(v:val)')

    return grouptypenames
endfunction
" Return a list of names of all uberwin group types sorted in ascending order
" of priority
function! wince_model#AllUberwinGroupTypeNamesByPriority()
    call s:Log.DBG('wince_model#AllUberwinGroupTypeNamesByPriority')
    return g:wince_ordered_uberwingrouptype
endfunction

" Return a list of names of group types of all non-hidden subwin groups with
" priority higher than a given, for a given supwin, sorted in ascending order
" of priority
function! wince_model#ShownSubwinGroupTypeNamesWithHigherPriorityThan(supwinid, grouptypename)
    call s:Log.DBG('wince_model#ShownSubwinGroupTypeNamesWithHigherPriorityThan ', a:supwinid, ':', a:grouptypename)
    call s:EnsureModelExists()
    if !empty(a:grouptypename)
        if !has_key(g:wince_subwingrouptype, a:grouptypename)
            throw 'subwin group type ' . a:grouptypename . ' does not exist'
        endif
        let idx = get(g:wince_subwingrouptype, a:grouptypename).orderidx
    else
        let idx = -1
    endif

    let grouptypenames = g:wince_ordered_subwingrouptype[(idx + 1):]
    call filter(grouptypenames, 'wince_model#ShownSubwinGroupExists(' . a:supwinid . ', v:val)')

    return grouptypenames
endfunction
" Return a list of names of all subwin group types sorted in ascending order
" of priority
function! wince_model#AllSubwinGroupTypeNamesByPriority()
    call s:Log.DBG('wince_model#AllSubwinGroupTypeNamesByPriority')
    return g:wince_ordered_subwingrouptype
endfunction

" Validate a list of winids to be added to the model someplace
function! s:ValidateNewWinids(winids, explen)
    call s:Log.DBG('ValidateNewWinids ', a:winids, ' ', a:explen)
    " Validate that winids is a list
    if type(a:winids) != s:t.list
        throw 'expected list of winids but got param of type ' . type(a:winids)
    endif

    " Validate the number of winids
    if a:explen > -1
        if len(a:winids) != a:explen
            throw 'expected ' . a:explen . ' winids but ' . len(a:winids) . ' provided'
        endif
    endif

    " All winids must be numbers that aren't already in the model
    " somewhere
    for winid in a:winids
        if type(winid) != s:t.number
            throw 'winid ' . winid . ' is not a number'
        endif
        if has_key(t:wince_all, winid)
            throw 'winid ' . winid . ' is already in the model'
        endif
    endfor

    " No duplicate winids are allowed
    let found = {}
    for winid in a:winids
        if has_key(found, winid)
            throw 'duplicate winid ' . winid
        endif
        let found[winid] = 1
    endfor
endfunction

" Validate dimensions of an uberwin or supwin to be added to the model
" someplace
function! s:ValidateNewDimensions(nr, w, h)
    call s:Log.DBG('ValidateNewDimensions ', ' [', a:nr, ',', a:w, ',', a:h, ']')
    if type(a:nr) !=# s:t.number || (a:nr !=# -1 && a:nr <=# 0)
        throw "nr must be a positive number or -1"
    endif
    if type(a:w) !=# s:t.number || a:w <# -1
        throw "w must be at least -1"
    endif
    if type(a:h) !=# s:t.number || a:h <# -1
        throw "h must be at least -1"
    endif
endfunction
function! s:ValidateNewUberwinDimensions(grouptypename, typename, nr, w, h)
    call s:Log.DBG('ValidateNewUberwinDimensions ', a:grouptypename, ':', a:typename, ' [', a:nr, ',', a:w, ',', a:h, ']')

    call s:ValidateNewDimensions(a:nr, a:w, a:h)
    let [grouptype, typeidx] = wince_model#AssertUberwinTypeExists(a:grouptypename, a:typename)
    let expw = grouptype.widths[typeidx]
    let exph = grouptype.heights[typeidx]
    " The group type's prescribed width and height are maximums because if
    " Vim is resized into a small terminal, they need to shrink
    if expw !=# -1 && a:w !=# -1 && expw < a:w
        throw 'width ' . a:w . ' invalid for ' . a:grouptypename . ':' . a:typename
    endif
    " The group type's prescribed width and height are maximums because if
    " Vim is resized into a small terminal, they need to shrink
    if exph !=# -1 && a:h !=# -1 && exph < a:h
        throw 'height ' . a:h . ' invalid for ' . a:grouptypename . ':' . a:typename
    endif
endfunction

" Validate a list of dimensions of uberwins or supwins to be added to the
" model someplace
let s:defaultdims = {'nr': -1, 'w': -1, 'h': -1}
let s:dimkeys = keys(s:defaultdims)
function! s:ValidateNewUberwinDimensionsList(grouptypename, dims)
    call s:Log.DBG('ValidateNewUberwinDimensionsList ', a:grouptypename, ' ', a:dims)
    if type(a:dims) !=# s:t.list
        throw 'given dimensions list is not a list'
    endif
    
    let typenames = g:wince_uberwingrouptype[a:grouptypename].typenames
    let numtypenames = len(typenames)
    let rangenumtypenames = range(numtypenames)
    if empty(a:dims)
        let retlist = []
        for i in rangenumtypenames
            call add(retlist, copy(s:defaultdims))
        endfor
        call s:Log.DBG('Populated dummy dimensions: ', retlist)
        return retlist
    endif
    if len(a:dims) !=# numtypenames
        throw len(a:dims) . ' is the wrong number of dimensions for ' . a:grouptypename
    endif

    for typeidx in rangenumtypenames
        let dim = a:dims[typeidx]
        call s:Log.VRB('Validate dimensions ', dim)
        " TODO? Fill in missing dicts with -1,-1,-1
        " - This will only be required if there's ever a case where multiple
        "   windows are added to the model at the same time, but only some of
        "   them have non-dummy dimensions. At the moment, I see no reason why
        "   that would happen
        let typename = typenames[typeidx]
        if type(dim) !=# s:t.dict
            throw 'given dimensions are not a dict'
        endif
        for key in s:dimkeys
            if !has_key(dim, key)
                throw 'dimensions must have keys nr, w, and h'
            endif
        endfor
        call s:ValidateNewUberwinDimensions(a:grouptypename, typename, dim.nr, dim.w, dim.h)
    endfor
    return a:dims
endfunction

" Validate dimensions of a subwin to be added to the model someplace
function! s:ValidateNewSubwinDimensions(grouptypename, typename, relnr, w, h)
    call s:Log.DBG('ValidateNewSubwinDimensions ', a:grouptypename, ':', a:typename, ' [', a:relnr, ',', a:w, ',', a:h, ']')
    if type(a:relnr) !=# s:t.number
        throw "relnr must be a number"
    endif
    if type(a:w) !=# s:t.number || a:w <# -1
        throw "w must be at least -1"
    endif
    if type(a:h) !=# s:t.number || a:h <# -1
        throw "h must be at least -1"
    endif
    let [grouptype, typeidx] =  wince_model#AssertSubwinTypeExists(a:grouptypename, a:typename)
    let expw = grouptype.widths[typeidx]
    let exph = grouptype.heights[typeidx]
    " The group type's prescribed width and height are maximums because if
    " Vim is resized into a small terminal, they need to shrink
    if expw !=# -1 && a:w !=# -1 && expw < a:w
        throw 'width ' . a:w . ' invalid for ' . a:grouptypename . ':' . a:typename
    endif
    " The group type's prescribed width and height are maximums because if
    " Vim is resized into a small terminal, they need to shrink
    if exph !=# -1 && a:h !=# -1 && exph < a:h
        throw 'height ' . a:h . ' invalid for ' . a:grouptypename . ':' . a:typename
    endif
endfunction

" Validate a list of dimensions of subwins to be added to the model someplace
let s:defaultreldims = {'relnr': 0, 'w': -1, 'h': -1}
let s:reldimkeys = keys(s:defaultreldims)
function! s:ValidateNewSubwinDimensionsList(grouptypename, dims)
    call s:Log.DBG('ValidateNewSubwinDimensionsList ', a:grouptypename, ' ', a:dims)
    if type(a:dims) !=# s:t.list
        throw 'given subwin dimensions list is not a list'
    endif
    let typenames = g:wince_subwingrouptype[a:grouptypename].typenames
    let numtypenames = len(typenames)
    let rangenumtypenames = range(numtypenames)
    if empty(a:dims)
        let retlist = []
        for i in rangenumtypenames
            call add(retlist, copy(s:defaultreldims))
        endfor
        call s:Log.DBG('Populated dummy dimensions: ', retlist)
        return retlist
    endif
    if len(a:dims) !=# numtypenames
        throw len(dims) . ' is the wrong number of dimensions for ' . a:grouptypename
    endif

    for typeidx in rangenumtypenames
        let dim = a:dims[typeidx]
        call s:Log.VRB('Validate dimensions ', dim)
        " TODO? Fill in missing dicts with 0,-1,-1
        " - This will only be required if there's ever a case where multiple
        "   windows are added to the model at the same time, but only some of
        "   them have non-dummy dimensions. At the moment, I see no reason why
        "   that would happen
        let typename = typenames[typeidx]
        if type(dim) !=# s:t.dict
            throw 'given subwin dimensions are not a dict'
        endif
        for key in s:reldimkeys
            if !has_key(dim, key)
                throw 'subwin dimensions must have keys relnr, w, and h'
            endif
        endfor
        call s:ValidateNewSubwinDimensions(
       \    a:grouptypename,
       \    typename,
       \    dim.relnr,
       \    dim.w,
       \    dim.h
       \)
    endfor
    return a:dims
endfunction

" Get a dict of all uberwins' toIdentify functions keyed by their group type
function! wince_model#ToIdentifyUberwins()
    call s:Log.DBG('wince_model#ToIdentifyUberwins')
    let retdict = {}
    for [grouptypename, grouptype] in items(g:wince_uberwingrouptype)
        let retdict[grouptypename] = grouptype.toIdentify
    endfor
    call s:Log.DBG('Retrieved: ', retdict)
    return retdict
endfunction

" Get a dict of all subwins' toIdentify functions keyed by their group type
function! wince_model#ToIdentifySubwins()
    call s:Log.DBG('wince_model#ToIdentifySubwins')
    let retdict = {}
    for [grouptypename, group] in items(g:wince_subwingrouptype)
        let retdict[grouptypename] = group.toIdentify
    endfor
    call s:Log.DBG('Retrieved: ', retdict)
    return retdict
endfunction

" Uberwin group manipulation
function! wince_model#UberwinGroupExists(grouptypename)
    call s:Log.DBG('wince_model#UberwinGroupExists ', a:grouptypename)
    call s:EnsureModelExists()
    call wince_model#AssertUberwinGroupTypeExists(a:grouptypename)
    return has_key(t:wince_uberwin, a:grouptypename)
endfunction
function! wince_model#AssertUberwinGroupExists(grouptypename)
    call s:Log.DBG('wince_model#AssertUberwinGroupExists ', a:grouptypename)
    call s:EnsureModelExists()
    call wince_model#AssertUberwinGroupTypeExists(a:grouptypename)
    let group = get(t:wince_uberwin, a:grouptypename)
    if type(group) !=# s:t.dict
        throw 'nonexistent uberwin group ' . a:grouptypename
    endif
    return group
endfunction
function! wince_model#AssertUberwinGroupDoesntExist(grouptypename)
    call s:Log.DBG('wince_model#AssertUberwinGroupDoesntExist ', a:grouptypename)
    call s:EnsureModelExists()
    call wince_model#AssertUberwinGroupTypeExists(a:grouptypename)
    if has_key(t:wince_uberwin, a:grouptypename)
        throw 'uberwin group ' . a:grouptypename . ' exists'
    endif
endfunction

function! wince_model#UberwinGroupIsHidden(grouptypename)
    call s:Log.DBG('wince_model#UberwinGroupIsHidden ', a:grouptypename)
    return wince_model#AssertUberwinGroupExists(a:grouptypename).hidden
endfunction
function! wince_model#AssertUberwinGroupIsHidden(grouptypename)
    call s:Log.DBG('wince_model#AssertUberwinGroupIsHidden ', a:grouptypename)
    let group = wince_model#AssertUberwinGroupExists(a:grouptypename)
    if !group.hidden
       throw 'uberwin group ' . a:grouptypename . ' is not hidden'
    endif
    return group
endfunction
function! wince_model#AssertUberwinGroupIsNotHidden(grouptypename)
    call s:Log.DBG('wince_model#AssertUberwinGroupIsNotHidden ', a:grouptypename)
    let group = wince_model#AssertUberwinGroupExists(a:grouptypename)
    if group.hidden
        throw 'uberwin group ' . a:grouptypename . ' is hidden'
    endif
    return group
endfunction
function! wince_model#ShownUberwinGroupExists(grouptypename)
    call s:Log.DBG('wince_model#ShownUberwinGroupExists ', a:grouptypename)
    call s:EnsureModelExists()
    let group = get(t:wince_uberwin, a:grouptypename)
    if type(group) !=# s:t.dict
        return 0
    endif
    return !group.hidden
endfunction
function! wince_model#UberwinGroupTypeNames()
    call s:Log.DBG('wince_model#UberwinGroupTypeNames ', a:grouptypename)
    return keys(g:wince_uberwingrouptype)
endfunction
function! wince_model#ShownUberwinGroupTypeNames()
    call s:Log.DBG('wince_model#ShownUberwinGroupTypeNames')
    call s:EnsureModelExists()
    let grouptypenames = copy(g:wince_ordered_uberwingrouptype)
    call filter(grouptypenames, 'wince_model#ShownUberwinGroupExists(v:val)')
    return grouptypenames
endfunction
function! wince_model#UberwinTypeNamesByGroupTypeName(grouptypename)
    call s:Log.DBG('wince_model#UberwinTypeNamesByGroupTypeName ', a:grouptypename)
    let typenames =  wince_model#AssertUberwinGroupTypeExists(a:grouptypename).typenames
    call s:Log.DBG('Type names for uberwin group ', a:grouptypename, ': ', typenames)
    return typenames
endfunction
function! wince_model#UberwinDimensionsByTypeName(grouptypename, typename)
    call s:Log.DBG('wince_model#UberwinDimensionsByTypeName ', a:grouptypename, ':', a:typename)
    call wince_model#AssertUberwinGroupIsNotHidden(a:grouptypename)
    call wince_model#AssertUberwinTypeExists(a:grouptypename, a:typename)
    let windict = t:wince_uberwin[a:grouptypename].uberwin[a:typename]
    call s:Log.DBG('Dimensions of uberwin ', a:grouptypename, ':', a:typename, ': ', windict)
    return windict
endfunction
function! wince_model#UberwinDimensionsByGroupTypeName(grouptypename)
    call s:Log.DBG('wince_model#UberwinDimensionsByGroupTypeName ', a:grouptypename)
    return wince_model#AssertUberwinGroupIsNotHidden(a:grouptypename).uberwin
endfunction

function! wince_model#AddUberwins(grouptypename, winids, dimensions)
    call s:Log.INF('wince_model#AddUberwins ', a:grouptypename, ' ', a:winids, ' ', a:dimensions)
    call wince_model#AssertUberwinGroupDoesntExist(a:grouptypename)
    
    " If no winids are supplied, the uberwin is initially hidden
    if empty(a:winids)
        call s:Log.VRB('No winids given, Adding uberwin group ', a:grouptypename, ' as hidden')
        let hidden = 1
        let uberwindict = {}

    " If winids are supplied, the uberwin is initially visible
    else
        let typenames = g:wince_uberwingrouptype[a:grouptypename].typenames
        let numuberwins = len(typenames)
        call s:ValidateNewWinids(a:winids, numuberwins)

        let vdimensions = s:ValidateNewUberwinDimensionsList(
       \    a:grouptypename,
       \    a:dimensions,
       \)
        
        call s:Log.VRB('Winids and dimensions valid. Adding uberwin group ', a:grouptypename, ' as shown')
        
        let hidden = 0

        " Build the model for this uberwin group
        let uberwindict = {}
        for i in range(numuberwins)
            let winid = a:winids[i]
            let vdim = vdimensions[i]
            let vdim.id = winid
            let uberwindict[typenames[i]] = vdim
            let t:wince_all[winid] = 1
        endfor
    endif

    " Record the model
    let t:wince_uberwin[a:grouptypename] = {'hidden': hidden,'uberwin': uberwindict}
endfunction

function! wince_model#RemoveUberwins(grouptypename)
    call s:Log.INF('wince_model#RemoveUberwins ', a:grouptypename)
    let group = wince_model#AssertUberwinGroupExists(a:grouptypename)
    for uberwin in values(group.uberwin)
        unlet t:wince_all[uberwin.id]
    endfor
    unlet t:wince_uberwin[a:grouptypename]
endfunction

function! wince_model#HideUberwins(grouptypename)
    call s:Log.DBG('wince_model#HideUberwins ', a:grouptypename)
    let group = wince_model#AssertUberwinGroupIsNotHidden(a:grouptypename)

    for uberwin in values(group.uberwin)
        unlet t:wince_all[uberwin.id]
    endfor

    let group.hidden = 1
    let group.uberwin = {}
endfunction

function! wince_model#ShowUberwins(grouptypename, winids, dimensions)
    call s:Log.INF('wince_model#ShowUberwins ', a:grouptypename, ' ', a:winids, ' ', a:dimensions)
    let group = wince_model#AssertUberwinGroupIsHidden(a:grouptypename)
    let typenames = g:wince_uberwingrouptype[a:grouptypename].typenames
    let numuberwins = len(typenames)
    call s:ValidateNewWinids(a:winids,numuberwins)
    let vdimensions = s:ValidateNewUberwinDimensionsList(
   \    a:grouptypename,
   \    a:dimensions,
   \)

    let uberwindict = {}
    for i in range(numuberwins)
        let winid = a:winids[i]
        let vdim = vdimensions[i]
        let vdim.id = winid
        let uberwindict[typenames[i]] = vdim
        let t:wince_all[winid] = 1
    endfor
    let group.hidden = 0
    let group.uberwin = uberwindict
endfunction

function! wince_model#AddOrShowUberwins(grouptypename, uberwinids, dimensions)
    call s:Log.INF('wince_model#AddOrShowUberwins ', a:grouptypename, ' ', a:uberwinids, ' ', a:dimensions)
    if !wince_model#UberwinGroupExists(a:grouptypename)
        call s:Log.VRB('Uberwin group ', a:grouptypename, ' not present in model. Adding.')
        call wince_model#AddUberwins(a:grouptypename, a:uberwinids, a:dimensions)
    else
        call s:Log.VRB('Uberwin group ', a:grouptypename, ' hidden in model. Showing.')
        call wince_model#ShowUberwins(a:grouptypename, a:uberwinids, a:dimensions)
    endif
endfunction

function! wince_model#ChangeUberwinIds(grouptypename, winids)
    call s:Log.INF('wince_model#ChangeUberwinIds ', a:grouptypename, ' ', a:winids)
    let uberwins = wince_model#AssertUberwinGroupIsNotHidden(a:grouptypename).uberwin
    let typenames = g:wince_uberwingrouptype[a:grouptypename].typenames
    let numuberwins = len(typenames)
    call s:ValidateNewWinids(a:winids,numuberwins)

    let uberwindict = {}
    for i in range(numuberwins)
        let uberwin = uberwins[typenames[i]]
        let id = a:winids[i]
        unlet t:wince_all[uberwin.id]
        let t:wince_all[id] = 1
        let uberwin.id = id
    endfor
endfunction

function! wince_model#ChangeUberwinDimensions(grouptypename, typename, nr, w, h)
    call s:Log.DBG('wince_model#ChangeUberwinDimensions ', a:grouptypename, ':', a:typename, ' [', a:nr, ',', a:w, ',', a:h, ']')
    call wince_model#AssertUberwinTypeExists(a:grouptypename, a:typename)
    let uberwin = wince_model#AssertUberwinGroupIsNotHidden(a:grouptypename).uberwin[a:typename]
    call s:ValidateNewUberwinDimensions(a:grouptypename, a:typename, a:nr, a:w, a:h)

    let uberwin.nr = a:nr
    let uberwin.w = a:w
    let uberwin.h = a:h
endfunction

function! wince_model#ChangeUberwinGroupDimensions(grouptypename, dims)
    call s:Log.DBG('wince_model#ChangeUberwinGroupDimensions ', a:grouptypename, ' ', a:dims)
    let vdims = s:ValidateNewUberwinDimensionsList(a:grouptypename, a:dims)

    let typenames = g:wince_uberwingrouptype[a:grouptypename].typenames
    for typeidx in range(len(typenames))
        let vdim = vdims[typeidx]
        call wince_model#ChangeUberwinDimensions(
       \    a:grouptypename,
       \    typenames[typeidx],
       \    vdim.nr,
       \    vdim.w,
       \    vdim.h
       \)
    endfor
endfunction

" Supwin manipulation
function! wince_model#SupwinExists(winid)
    call s:Log.DBG('wince_model#SupwinExists ', a:winid)
    call s:EnsureModelExists()
    return has_key(t:wince_supwin, a:winid)
endfunction
function! wince_model#AssertSupwinExists(winid)
    call s:Log.DBG('wince_model#AssertSupwinExists ', a:winid)
    call s:EnsureModelExists()
    let supwin = get(t:wince_supwin, a:winid)
    if type(supwin) !=# s:t.dict
        throw 'nonexistent supwin ' . a:winid
    endif
    return supwin
endfunction
function! wince_model#AssertSupwinDoesntExist(winid)
    call s:Log.DBG('wince_model#AssertSupwinDoesntExist ', a:winid)
    call s:EnsureModelExists()
    if has_key(t:wince_supwin, a:winid)
        throw 'supwin ' . a:winid . ' exists'
    endif
endfunction
function! wince_model#SupwinDimensions(supwinid)
    call s:Log.DBG('wince_model#SupwinDimensions ', a:supwinid)
    let supwin =  wince_model#AssertSupwinExists(a:supwinid)
    let retdict = {'nr':supwin.nr,'w':supwin.w,'h':supwin.h}
    call s:Log.DBG('Dimensions of supwin ', a:supwinid, ': ', retdict)
    return retdict
endfunction

function! wince_model#ChangeSupwinDimensions(supwinid, nr, w, h)
    call s:Log.DBG('wince_model#ChangeSupwinDimensions ', a:supwinid, ' [', a:nr, ',', a:w, ',', a:h, ']')
    let supwin = wince_model#AssertSupwinExists(a:supwinid)
    call s:ValidateNewDimensions(a:nr, a:w, a:h)

    let supwin.nr = a:nr
    let supwin.w = a:w
    let supwin.h = a:h
endfunction

" Subwin group manipulation
function! wince_model#SubwinGroupExists(supwinid, grouptypename)
    call s:Log.DBG('wince_model#SubwinGroupExists ', a:supwinid, ':', a:grouptypename)
    call wince_model#AssertSubwinGroupTypeExists(a:grouptypename)
    let supwin = wince_model#AssertSupwinExists(a:supwinid)
    return has_key(supwin.subwin, a:grouptypename)
endfunction
function! wince_model#AssertSubwinGroupExists(supwinid, grouptypename)
    call s:Log.DBG('wince_model#AssertSubwinGroupExists ', a:supwinid, ':', a:grouptypename)
    let supwin = wince_model#AssertSupwinExists(a:supwinid)
    call wince_model#AssertSubwinGroupTypeExists(a:grouptypename)
    let subwin = get(supwin.subwin, a:grouptypename)
    if type(subwin) !=# s:t.dict
        throw 'supwin ' . a:supwinid . ' has no subwin group of type ' . a:grouptypename
    endif
    return subwin
endfunction
function! wince_model#AssertSubwinGroupDoesntExist(supwinid, grouptypename)
    call s:Log.DBG('wince_model#AssertSubwinGroupDoesntExist ', a:supwinid, ':', a:grouptypename)
    let supwin = wince_model#AssertSupwinExists(a:supwinid)
    call wince_model#AssertSubwinGroupTypeExists(a:grouptypename)
    if has_key(supwin.subwin, a:grouptypename)
        throw 'supwin ' . a:supwinid . ' has subwin group of type ' . a:grouptypename
    endif
endfunction
function! wince_model#SubwinGroupIsHidden(supwinid, grouptypename)
    call s:Log.DBG('wince_model#SubwinGroupIsHidden ', a:supwinid, ':', a:grouptypename)
    return wince_model#AssertSubwinGroupExists(a:supwinid, a:grouptypename).hidden
endfunction
function! wince_model#AssertSubwinGroupIsHidden(supwinid, grouptypename)
    call s:Log.DBG('wince_model#AssertSubwinGroupIsHidden ', a:supwinid, ':', a:grouptypename)
    let group = wince_model#AssertSubwinGroupExists(a:supwinid, a:grouptypename)
    if !group.hidden
        throw 'subwin group ' . a:grouptypename . ' not hidden for supwin ' . a:supwinid
    endif
    return group
endfunction
function! wince_model#AssertSubwinGroupIsNotHidden(supwinid, grouptypename)
    call s:Log.DBG('wince_model#AssertSubwinGroupIsNotHidden ', a:supwinid, ':', a:grouptypename)
    let group = wince_model#AssertSubwinGroupExists(a:supwinid, a:grouptypename)
    if group.hidden
        throw 'subwin group ' . a:grouptypename . ' is hidden for supwin ' . a:supwinid
    endif
    return group
endfunction
function! wince_model#ShownSubwinGroupExists(supwinid, grouptypename)
    call s:Log.DBG('wince_model#ShownSubwinGroupExists ', a:supwinid, ':', a:grouptypename)
    call s:EnsureModelExists()
    let supwin = get(t:wince_supwin, a:supwinid, 0)
    if type(supwin) !=# s:t.dict
        return 0
    endif
    let group = get(supwin.subwin, a:grouptypename)
    if type(group) !=# s:t.dict
        return 0
    endif
    return !group.hidden
endfunction
function! wince_model#SubwinGroupIsAfterimaged(supwinid, grouptypename)
    call s:Log.DBG('wince_model#SubwinGroupIsAfterimaged ', a:supwinid, ':', a:grouptypename)
    return wince_model#AssertSubwinGroupIsNotHidden(a:supwinid, a:grouptypename).afterimaged
endfunction
function! wince_model#AssertSubwinGroupIsAfterimaged(supwinid, grouptypename)
    call s:Log.DBG('wince_model#AssertSubwinGroupIsAfterimaged ', a:supwinid, ':', a:grouptypename)
    let group = wince_model#AssertSubwinGroupIsNotHidden(a:supwinid, a:grouptypename)
    if !group.afterimaged
        throw 'subwin group ' . a:supwinid . ':' . a:grouptypename . ' is not afterimaged'
    endif
    return group
endfunction
function! wince_model#AssertSubwinGroupIsNotAfterimaged(supwinid, grouptypename)
    call s:Log.DBG('wince_model#AssertSubwinGroupIsNotAfterimaged ', a:supwinid, ':', a:grouptypename)
    let group = wince_model#AssertSubwinGroupIsNotHidden(a:supwinid, a:grouptypename)
    if group.afterimaged
        throw 'subwin group ' . a:supwinid . ':' . a:grouptypename . ' is afterimaged'
    endif
    return group
endfunction
function! s:AssertSubwinidIsInSubwinList(subwinid)
    call s:Log.DBG('AssertSubwinidIsInSubwinList ', a:subwinid)
    call s:EnsureModelExists()
    let subwin = get(t:wince_subwin, a:subwinid)
    if type(subwin) !=# s:t.dict
        throw 'subwin id ' . a:subwinid . ' not in subwin list'
    endif
    return subwin
endfunction
function! wince_model#SubwinGroupTypeNames()
    call s:Log.DBG('wince_model#SubwinGroupTypeNames')
    let grouptypenames = keys(g:wince_subwingrouptype)
    call s:Log.DBG('Subwin group type names: ', grouptypenames)
    return grouptypenames
endfunction
function! wince_model#ShownSubwinGroupTypeNamesBySupwinId(supwinid)
    call s:Log.DBG('wince_model#ShownSubwinGroupTypeNamesBySupwinId ', a:supwinid)
    call s:EnsureModelExists()
    let grouptypenames = copy(g:wince_ordered_subwingrouptype)
    call filter(grouptypenames, 'wince_model#ShownSubwinGroupExists(' . a:supwinid . ', v:val)')
    return grouptypenames
endfunction
function! wince_model#SubwinTypeNamesByGroupTypeName(grouptypename)
    call s:Log.DBG('wince_model#SubwinTypeNamesByGroupTypeName ', a:grouptypename)
    let typenames = wince_model#AssertSubwinGroupTypeExists(a:grouptypename).typenames
    call s:Log.DBG('Type names for subwin group ', a:grouptypename, ': ', typenames)
    return typenames
endfunction
function! wince_model#SubwinDimensionsByTypeName(supwinid, grouptypename, typename)
    call s:Log.DBG('wince_model#SubwinDimensionsByTypeName ', a:supwinid, ':', a:grouptypename, ':', a:typename)
    call wince_model#AssertSubwinTypeExists(a:grouptypename, a:typename)
    let subwinid = wince_model#AssertSubwinGroupIsNotHidden(a:supwinid, a:grouptypename).subwin[a:typename].id
    let windict = t:wince_subwin[subwinid]
    let retdict =  {'relnr':windict.relnr,'w':windict.w,'h':windict.h}
    call s:Log.DBG('Dimensions of subwin ', a:supwinid, ':', a:grouptypename, ':', a:typename, ': ', retdict)
    return retdict
endfunction
function! wince_model#SubwinDimensionsByGroupTypeName(supwinid, grouptypename)
    call s:Log.DBG('wince_model#SubwinDimensionsByGroupTypeName ', a:supwinid, ':', a:grouptypename)
    let retdict = {}
    for subwin in values(wince_model#AssertSubwinGroupIsNotHidden(a:supwinid, a:grouptypename).subwin)
        let id = subwin.id
        let retdict[id] = t:wince_subwin[id]
    endfor
    return retdict
endfunction
function! wince_model#SubwinAibufBySubwinId(subwinid)
    call s:Log.DBG('wince_model#SubwinAibufBySubwinId ', a:subwinid)
    call s:EnsureModelExists()
    let aibuf = s:AssertSubwinidIsInSubwinList(a:subwinid).aibuf
    call s:Log.DBG('Afterimage buffer for subwin ', a:subwinid, ': ', aibuf)
    return aibuf
endfunction
function! wince_model#ShownSubwinIdsBySupwinId(supwinid)
    call s:Log.DBG('wince_model#ShownSubwinIdsBySupwinId ', a:supwinid)
    let supwin =  wince_model#AssertSupwinExists(a:supwinid)
    let winids = []
    for [grouptypename, group] in items(supwin.subwin)
        if !group.hidden
            for [typename, subwin] in items(group.subwin)
                let id = subwin.id
                call s:Log.VRB('Shown subwin ', a:supwinid, ':', grouptypename, ':', typename, ' has ID ', id)
                call add(winids, id)
            endfor
        endif
    endfor
    call s:Log.DBG('IDs of shown subwins of supwin ', a:supwinid, ': ', winids)
    return winids
endfunction

function! wince_model#AddSupwin(winid, nr, w, h)
    call s:Log.INF('wince_model#AddSupwin ', a:winid, ' [', a:nr, ',', a:w, ',', a:h, ']')
    call s:EnsureModelExists()
    if has_key(t:wince_supwin, a:winid)
        throw 'window ' . a:winid . ' is already a supwin'
    endif
    call s:ValidateNewDimensions(a:nr, a:w, a:h)
    let t:wince_supwin[a:winid] = {'subwin':{},'nr':a:nr,'w':a:w,'h':a:h}
    let t:wince_all[a:winid] = 1
endfunction

" This function returns a data structure containing all of the information
" that was removed from the model, so that it can later be added back by
" wince_model#RestoreSupwin
function! wince_model#RemoveSupwin(winid)
    call s:Log.INF('wince_model#RemoveSupwin ', a:winid)
    let supwin = wince_model#AssertSupwinExists(a:winid)

    let subwindata = {}
    for [grouptypename, group] in items(supwin.subwin)
        for [typename, subwin] in items(group.subwin)
            let subwinid = subwin.id
            call s:Log.DBG('Removing subwin ', a:winid, ':', grouptypename, ':', typename, ' with ID ', subwinid, ' from subwin list')
            let subwindata[subwinid] = t:wince_subwin[subwinid]
            unlet t:wince_subwin[subwinid]
            unlet t:wince_all[subwinid]
        endfor
    endfor

    let supwindata = t:wince_supwin[a:winid]
    unlet t:wince_supwin[a:winid]
    unlet t:wince_all[a:winid]

    return {'id':a:winid,'supwin':supwindata,'subwin':subwindata}
endfunction

" Use the return value of wince_model#RemoveSupwin to re-add a supwin to the model
function! wince_model#RestoreSupwin(data)
    call s:Log.INF('wince_model#RestoreSupwin ', a:data)
    call s:EnsureModelExists()
    let id = a:data.id
    call wince_model#AssertSupwinDoesntExist(id)

    let t:wince_supwin[id] = a:data.supwin
    let t:wince_all[id] = 1
    for [subwinid, subwin] in items(a:data.subwin)
        let t:wince_subwin[subwinid] = subwin
        let t:wince_all[subwinid] = 1
    endfor
endfunction

function! wince_model#AddSubwins(supwinid, grouptypename, subwinids, dimensions)
    call s:Log.INF('wince_model#AddSubwins ', a:supwinid, ':', a:grouptypename, ' ', a:subwinids, ' ', a:dimensions)
    call wince_model#AssertSubwinGroupDoesntExist(a:supwinid, a:grouptypename)
    
    " If no winids are supplied, the uberwin is initially hidden
    if empty(a:subwinids)
        call s:Log.VRB('No winids given. Adding subwin group ', a:supwinid, ':', a:grouptypename, ' as hidden')
        let hidden = 1
        let subwindict = {}

    " If winids are supplied, the subwin is initially visible
    else
        let typenames = g:wince_subwingrouptype[a:grouptypename].typenames
        let numsubwins = len(typenames)
        call s:ValidateNewWinids(a:subwinids, numsubwins)

        let vdimensions = s:ValidateNewSubwinDimensionsList(
       \    a:grouptypename,
       \    a:dimensions,
       \)

        call s:Log.VRB('Winids and dimensions valid. Adding subwin group ', a:supwinid, ':', a:grouptypename, ' as shown')
        
        let hidden = 0

        " Build the model for this subwin group
        let subwindict = {}
        for i in range(numsubwins)
            let typename = typenames[i]
            let subwinid = a:subwinids[i]
            let vdim = vdimensions[i]

            let subwindict[typename] = {'id': subwinid}

            let t:wince_subwin[subwinid] = {
           \    'supwin': a:supwinid,
           \    'grouptypename': a:grouptypename,
           \    'typename': typename,
           \    'aibuf': -1,
           \    'relnr': vdim.relnr,
           \    'w': vdim.w,
           \    'h': vdim.h
           \}
            let t:wince_all[subwinid] = 1
        endfor
    endif

    " Record the model
    let t:wince_supwin[a:supwinid].subwin[a:grouptypename] = {
   \    'hidden': hidden,
   \    'afterimaged': 0,
   \    'subwin': subwindict
   \}
endfunction

function! wince_model#RemoveSubwins(supwinid, grouptypename)
    call s:Log.INF('wince_model#RemoveSubwins ', a:supwinid, ':', a:grouptypename)
    let groups = wince_model#AssertSupwinExists(a:supwinid).subwin
    let group = get(groups, a:grouptypename, 0)
    if type(group) != s:t.dict
        throw 'No subwin ' . a:supwinid . ':' . a:grouptypename
    endif
    if !group.hidden
        for [subwintypename, subwin] in items(group.subwin)
            let id = subwin.id
            call s:Log.DBG('Removing subwin ', a:supwinid, ':', a:grouptypename, ':', subwintypename, ' with ID ', id, ' from subwin list')
            unlet t:wince_subwin[id]
            unlet t:wince_all[id]
        endfor
    endif
    unlet groups[a:grouptypename]
endfunction

function! wince_model#HideSubwins(supwinid, grouptypename)
    call s:Log.INF('wince_model#HideSubwins ', a:supwinid, ':', a:grouptypename)
    let group =  wince_model#AssertSubwinGroupIsNotHidden(a:supwinid, a:grouptypename)

    for [subwintypename, subwin] in items(group.subwin)
        let id = subwin.id
        call s:Log.DBG('Removing subwin ', a:supwinid, ':', a:grouptypename, ':', subwintypename, ' with ID ', id, ' from subwin list')
        unlet t:wince_subwin[id]
        unlet t:wince_all[id]
    endfor

    let group.hidden = 1
    let group.afterimaged = 0
    let group.subwin = {}
endfunction

function! wince_model#ShowSubwins(supwinid, grouptypename, subwinids, dimensions)
    call s:Log.INF('wince_model#ShowSubwins ', a:supwinid, ':', a:grouptypename, ' ', a:subwinids, ' ', a:dimensions)
    let group =  wince_model#AssertSubwinGroupIsHidden(a:supwinid, a:grouptypename)
    let grouptype = g:wince_subwingrouptype[a:grouptypename]
    let typenames = grouptype.typenames
    let numsubwins = len(typenames)
    call s:ValidateNewWinids(a:subwinids, numsubwins)
    let vdimensions = s:ValidateNewSubwinDimensionsList(
   \    a:grouptypename,
   \    a:dimensions,
   \)

    let group.hidden = 0
    let group.afterimaged = 0
    let subwindict = {}
    for i in range(numsubwins)
        let typename = typenames[i]
        let subwinid = a:subwinids[i]
        let vdim = vdimensions[i]
        let subwindict[typename] = {'id': subwinid}

        let t:wince_subwin[subwinid] = {
       \    'supwin': a:supwinid,
       \    'grouptypename': a:grouptypename,
       \    'typename': typename,
       \    'aibuf': -1,
       \    'relnr': vdim.relnr,
       \    'w': vdim.w,
       \    'h': vdim.h
       \}
        let t:wince_all[subwinid] = 1
    endfor
    let group.subwin = subwindict
endfunction

function! wince_model#AddOrShowSubwins(supwinid, grouptypename, subwinids, dimensions)
    call s:Log.INF('wince_model#AddOrShowSubwins ', a:supwinid, ':', a:grouptypename, ' ', a:subwinids, ' ', a:dimensions)
    if !wince_model#SubwinGroupExists(a:supwinid, a:grouptypename)
        call s:Log.VRB('Subwin group ', a:supwinid, ':', a:grouptypename, ' not present in model. Adding.')
        call wince_model#AddSubwins(a:supwinid, a:grouptypename, a:subwinids, a:dimensions)
    else
        call s:Log.VRB('Subwin group ', a:supwinid, ':', a:grouptypename, ' hidden in model. Showing.')
        call wince_model#ShowSubwins(a:supwinid, a:grouptypename, a:subwinids, a:dimensions)
    endif
endfunction

function! wince_model#ChangeSubwinIds(supwinid, grouptypename, subwinids)
    call s:Log.INF('wince_model#ChangeSubwinIds ', a:supwinid, ':', a:grouptypename, ' ', a:subwinids)
    let group = wince_model#AssertSubwinGroupIsNotHidden(a:supwinid, a:grouptypename).subwin
    let typenames = g:wince_subwingrouptype[a:grouptypename].typenames
    let numsubwins = len(typenames)
    call s:ValidateNewWinids(a:subwinids, numsubwins)
 
    for i in range(numsubwins)
        let typename = typenames[i]
        let subwin = group[typename]
        let id = a:subwinids[i]
        let oldsubwinid = group[typename].id

        call s:Log.DBG('Moving subwin ', a:supwinid, ':', a:grouptypename, ':', typename, ' from ID ', oldsubwinid, ' to ', id, ' in subwin list')

        let t:wince_subwin[id] = t:wince_subwin[oldsubwinid]
        let t:wince_all[id] = 1
        unlet t:wince_subwin[oldsubwinid]
        unlet t:wince_all[oldsubwinid]

        let subwin.id = id
    endfor
endfunction

function! wince_model#ChangeSubwinDimensions(supwinid, grouptypename, typename, relnr, w, h)
    call s:Log.DBG('wince_model#ChangeSubwinDimensions ', a:supwinid, ':', a:grouptypename, ':', a:typename, ' [', a:relnr, ',', a:w, ',', a:h, ']')
    call s:ValidateNewSubwinDimensions(a:grouptypename, a:typename, a:relnr, a:w, a:h)
    let subwinid = wince_model#AssertSubwinGroupIsNotHidden(a:supwinid, a:grouptypename).subwin[a:typename].id

    let subwin = t:wince_subwin[subwinid]
    let subwin.relnr = a:relnr
    let subwin.w = a:w
    let subwin.h = a:h
endfunction

function! wince_model#ChangeSubwinGroupDimensions(supwinid, grouptypename, dims)
    call s:Log.DBG('wince_model#ChangeSubwinGroupDimensions ', a:supwinid, ':', a:grouptypename, ' ', a:dims)
    let vdims = s:ValidateNewSubwinDimensionsList(a:grouptypename, a:dims)

    let typenames = g:wince_subwingrouptype[a:grouptypename].typenames
    for typeidx in range(len(typenames))
        let vdim = vdims[typeidx]
        call wince_model#ChangeSubwinDimensions(
       \    a:supwinid,
       \    a:grouptypename,
       \    typenames[typeidx],
       \    vdim.relnr,
       \    vdim.w,
       \    vdim.h
       \)
    endfor
endfunction

function! wince_model#AfterimageSubwinsByGroup(supwinid, grouptypename, aibufs)
    call s:Log.INF('wince_model#AfterimageSubwinsByGroup ', a:supwinid, ':', a:grouptypename, ' ', a:aibufs)
    let group = wince_model#AssertSubwinGroupIsNotHidden(a:supwinid, a:grouptypename)
    let afterimaging = g:wince_subwingrouptype[a:grouptypename].afterimaging
    let subwins = group.subwin
    for typename in keys(afterimaging)
        if !has_key(a:aibufs, typename)
            throw 'subwin type ' . typename . ' missing from afterimage buffers given for ' . a:supwinid . ':' . a:grouptypename
        endif
    endfor
    for [typename, aibuf] in items(a:aibufs)
        if aibuf < 0
            throw 'bad afterimage buffer number ' . aibuf
        endif
        if !has_key(afterimaging, typename)
            throw 'cannot afterimage subwin of nonexistent or non-afterimaging type ' .
           \      a:grouptypename . ':' . a:typename
        endif
        let subwin = s:AssertSubwinidIsInSubwinList(subwins[typename].id)
        let subwin.aibuf = aibuf
    endfor
    let group.afterimaged = 1
endfunction

function! wince_model#DeafterimageSubwinsByGroup(supwinid, grouptypename)
    call s:Log.INF('wince_model#DeafterimageSubwinsByGroup ', a:supwinid, ':', a:grouptypename)
    let group = wince_model#AssertSubwinGroupIsNotHidden(a:supwinid, a:grouptypename)
    if !group.afterimaged
        return
    endif
    let subwins = group.subwin

    for typename in keys(g:wince_subwingrouptype[a:grouptypename].afterimaging)
        let subwin = s:AssertSubwinidIsInSubwinList(subwins[typename].id)
        let subwin.aibuf = -1
    endfor

    let group.afterimaged = 0
endfunction

function! wince_model#ReplaceWinid(oldwinid, newwinid)
    call s:Log.INF('wince_model#ReplaceWinid ', a:oldwinid, a:newwinid)
    let info = wince_model#InfoById(a:oldwinid)
    if has_key(t:wince_all, a:newwinid)
        throw 'Winid ' . a:newwinid . ' already present'
    endif

    let category = s:cases[info.category]

    if category ==# 2
        let supwin = t:wince_supwin[a:oldwinid]
        let t:wince_supwin[a:newwinid] = supwin
        unlet t:wince_supwin[a:oldwinid]
        for [grouptypename, group] in items(supwin.subwin)
            for [typename, subwin] in items(group.subwin)
                let t:wince_subwin[subwin.id].supwin = a:newwinid
            endfor
        endfor

    elseif category ==# 3
        let t:wince_supwin[info.supwin].subwin[info.grouptype].subwin[info.typename].id = a:newwinid
        let t:wince_subwin[a:newwinid] = t:wince_subwin[a:oldwinid]
        unlet t:wince_subwin[a:oldwinid]

    elseif category ==# 1
        let t:wince_uberwin[info.grouptype].uberwin[info.typename].id = a:newwinid

    else
        throw 'Window with changed winid is neither uberwin nor supwin nor subwin'
    endif

    unlet t:wince_all[a:oldwinid]
    let t:wince_all[a:newwinid] = 1

    if t:curwin.id ==# a:oldwinid
        let t:curwin.id = a:newwinid
    endif
    if t:prevwin.id ==# a:oldwinid
        let t:prevwin.id = a:newwinid
    endif
endfunction

" TODO? Some individual types may need an option for a non-default toClose
" callback so that the resolver doesn't have to stomp them with :q! when their groups
" become incomplete
" - So far there's been no need for something like that
