" Wince Resolver
" See wince.vim
let s:Log = jer_log#LogFunctions('wince-resolve')

" Internal variables - used by different helpers to communicate with each other
let s:curpos = {}
let s:modelchanged = 0
let s:nonsupwincache = {}

" Input conditions - flags that influence the resolver's behaviour, set before
" it runs
let t:wince_resolvetabenteredcond = 1

" Helpers

" Run all the toIdentify callbacks against a window until one of
" them succeeds. Return the model info obtained.
function! s:IdentifyWindow(winid)
    call s:Log.DBG('IdentifyWindow ', a:winid)

    " While validating info for a subwin, we need to make sure that its listed
    " supwin really is a supwin. This operation needs to consider every non-supwin
    " winid in the model, and it's done lots of time, so it's worth doing some
    " caching. This dict contains every non-supwin model winid in its keys, and
    " should be invalidated with every model write.
    if empty(s:nonsupwincache)
        let uberwinids = wince_model#UberwinIds()
        let subwinids = wince_model#SubwinIds()
        for uberwinid in uberwinids
            let s:nonsupwincache[uberwinid] = 1
        endfor
        for subwinid in subwinids
            let s:nonsupwincache[subwinid] = 1
        endfor
    endif

    " If the state and model for this window are consistent, we can save lots
    " of time by just confirming that the model info is accurate to the state.
    " Unfortunately this can't be done with supwins because a supwin is only
    " identifiable by confirming that it doesn't satisfy ANY uberwin or subwin
    " conditions
    if wince_model#WinExists(a:winid)
        let modelinfo = wince_model#InfoById(a:winid)
        if modelinfo.category ==# 'uberwin'
            if s:toIdentifyUberwins[modelinfo.grouptype](a:winid) ==# modelinfo.typename
                call s:Log.DBG('Model info for window ', a:winid, ' confirmed in state as uberwin ', modelinfo.grouptype, ':', modelinfo.typename)
                let modelinfo.id = a:winid
                return modelinfo
            endif
        elseif modelinfo.category ==# 'subwin'
            if wince_model#SubwinAibufBySubwinId(a:winid) ==#
           \   wince_state#GetBufnrByWinidOrWinnr(a:winid)
                call s:Log.VRB('Model info for window ', a:winid, ' confirmed in state as afterimaged subwin ', modelinfo.supwin, ':', modelinfo.grouptype, ':', modelinfo.typename)
                let modelinfo.id = a:winid
                return modelinfo
            endif
            let stateinfo = s:toIdentifySubwins[modelinfo.grouptype](a:winid)
            let modelsupwinid = modelinfo.supwin
            if !empty(stateinfo) &&
           \   stateinfo.typename ==# modelinfo.typename &&
           \   stateinfo.supwin ==# modelsupwinid &&
           \   modelsupwinid !=# -1 &&
           \   !has_key(s:nonsupwincache, modelsupwinid)
                call s:Log.DBG('Model info for window ', a:winid, ' confirmed in state as subwin ', modelsupwinid, ':', modelinfo.grouptype, ':', modelinfo.typename)
                let modelinfo.id = a:winid
                return modelinfo
            endif
        endif
    endif
    
    " Check if the window is an uberwin
    for uberwingrouptypename in wince_model#AllUberwinGroupTypeNamesByPriority()
        call s:Log.VRB('Invoking toIdentify from ', uberwingrouptypename, ' uberwin group type')
        let uberwintypename = s:toIdentifyUberwins[uberwingrouptypename](a:winid)
        if !empty(uberwintypename)
            call s:Log.DBG('Window ', a:winid, ' identified as ', uberwingrouptypename, ':', uberwintypename)
            return {
           \    'category': 'uberwin',
           \    'grouptype': uberwingrouptypename,
           \    'typename': uberwintypename,
           \    'id': a:winid
           \}
        endif
    endfor

    " Check if the window is a subwin
    for subwingrouptypename in wince_model#AllSubwinGroupTypeNamesByPriority()
        call s:Log.VRB('Invoking toIdentify from ', subwingrouptypename, ' subwin group type')
        let subwindict = s:toIdentifySubwins[subwingrouptypename](a:winid)
        if !empty(subwindict)
            call s:Log.DBG('Window ', a:winid, ' identified as ', subwindict.supwin, ':', subwingrouptypename, ':', subwindict.typename)
            " If there is no supwin, or if the identified 'supwin' isn't a
            " supwin, the window we are identifying has no place in the model
            if subwindict.supwin ==# -1 || has_key(s:nonsupwincache, subwindict.supwin)
                call s:Log.DBG('Identified subwin gives non-supwin ', subwindict.supwin, ' as its supwin. Identification failed.')
                return {'category':'none','id':a:winid}
            endif
            return {
           \    'category': 'subwin',
           \    'supwin': subwindict.supwin,
           \    'grouptype': subwingrouptypename,
           \    'typename': subwindict.typename,
           \    'id': a:winid
           \}
        endif
    endfor

    call s:Log.DBG('Window ', a:winid, ' identified as supwin')
    return {'category':'supwin', 'id':a:winid}
endfunction

" Convert a list of window info dicts (as returned by
" s:IdentifyWindow) and group them by category, supwin id, group
" type, and type. Any incomplete groups are dropped. Any duplicates
" are dropped. The choice of which duplicate to drop is arbitrary.
function! s:GroupInfo(wininfos)
    call s:Log.VRB('s:GroupInfo ', a:wininfos)
    let uberwingroupinfo = {}
    let subwingroupinfo = {}
    let supwininfo = []
    " Group the window info
    for wininfo in a:wininfos
        call s:Log.VRB('Examining ', wininfo)
        if wininfo.category ==# 'uberwin'
            if !has_key(uberwingroupinfo, wininfo.grouptype)
                let uberwingroupinfo[wininfo.grouptype] = {}
            endif
            " If there are two uberwins of the same type, whichever one this
            " loop sees last will survive
            let uberwingroupinfo[wininfo.grouptype][wininfo.typename] = wininfo.id
        elseif wininfo.category ==# 'subwin'
            if !has_key(subwingroupinfo, wininfo.supwin)
                let subwingroupinfo[wininfo.supwin] = {}
            endif
            let supwindict = subwingroupinfo[wininfo.supwin]
            if !has_key(supwindict, wininfo.grouptype)
                let supwindict[wininfo.grouptype] = {}
            endif
            " If there are two subwins of the same type for the same supwin,
            " whichever one this loop sees last will survive
            let supwindict[wininfo.grouptype][wininfo.typename] = wininfo.id
        elseif wininfo.category ==# 'supwin'
            call add(supwininfo, wininfo.id)
        endif
    endfor
   
    call s:Log.VRB('Grouped Uberwins: ', uberwingroupinfo)
    call s:Log.VRB('Supwins: ', supwininfo)
    call s:Log.VRB('Grouped Subwins: ', subwingroupinfo)

    " Validate groups. Prune any incomplete groups. Convert typename-keyed
    " winid dicts to lists
    for [grouptypename,group] in items(uberwingroupinfo)
        call s:Log.VRB('Validating uberwin group ', grouptypename)
        for typename in keys(group)
            call wince_model#AssertUberwinTypeExists(grouptypename, typename)
        endfor
        let group.winids = []
        for typename in wince_model#UberwinTypeNamesByGroupTypeName(grouptypename)
            if !has_key(group, typename)
                call s:Log.VRB('Uberwin with type ', typename, ' missing. Dropping group.')
                unlet uberwingroupinfo[grouptypename]
                break
            endif
            call add(group.winids,group[typename])
        endfor
    endfor
    for [supwinid,supwin] in items(subwingroupinfo)
        for [grouptypename,group] in items(supwin)
            call s:Log.VRB('Validating subwin group ', supwinid, ':', grouptypename)
            for typename in keys(group)
                call wince_model#AssertSubwinTypeExists(grouptypename, typename)
            endfor
            let group.winids = []
            for typename in wince_model#SubwinTypeNamesByGroupTypeName(grouptypename)
                if !has_key(group, typename)
                    call s:Log.VRB('Subwin with type ', typename, ' missing. Dropping group.')
                    unlet supwin[grouptypename]
                    break
                endif
                call add(group.winids, group[typename])
            endfor
        endfor
    endfor
    let retdict = {'uberwin':uberwingroupinfo,'supwin':supwininfo,'subwin':subwingroupinfo}

    call s:Log.VRB('Grouped: ', retdict)
    return retdict
endfunction

" Resolver steps

" STEP 1 - Adjust the model so it accounts for recent changes to the state
function! s:ResolveStateToModel(statewinids)
    " STEP 1.1: If any window in the model isn't in the state, remove it from
    "           the model. Also make sure all terminal windows are supwins.
    call s:Log.VRB('Step 1.1')
    let s:modelchanged = 0

    " If any uberwin group in the model isn't fully represented in the state,
    " mark it hidden in the model
    " If any terminal window is listed in the model as an uberwin, mark that
    " uberwin group hidden in the model and relist the window as a supwin
    " If there are multiple uberwins in this group and only one of them has
    " become a terminal window or been closed, then this change renders that
    " uberwin group incomplete in the state and the non-state-terminal windows
    " in the model group will be ignored in STEP 1.3, then stomped in STEP 2.1
    let uberwingrouptypestohide = {}
    for modeluberwinid in wince_model#UberwinIds()
        call s:Log.VRB('Checking if model uberwin ', modeluberwinid, ' is a non-terminal window in the state')
        let dohidegroup = 1
        let dorelistwin = 0
        if wince_state#WinExists(modeluberwinid)
            if wince_state#WinIsTerminal(modeluberwinid)
                call s:Log.VRB('Model uberwin ', modeluberwinid, ' is a terminal window in the state')
                let dorelistwin = 1
            else
                let dohidegroup = 0
            endif
        else
            call s:Log.VRB('Model uberwin ', modeluberwinid, ' does not exist in state')
        endif

        if dohidegroup
            let modelinfo = wince_model#InfoById(modeluberwinid)
            if modelinfo.category !=# 'uberwin'
                throw 'Inconsistency in model. winid ' . modeluberwinid . ' is both' .
                      ' uberwin and ' . modelinfo.category
            endif
            if !has_key(uberwingrouptypestohide, modelinfo.grouptype)
                let uberwingrouptypestohide[modelinfo.grouptype] = []
            endif
            if dorelistwin
                call add(uberwingrouptypestohide[modelinfo.grouptype], modeluberwinid)
            endif
        endif
    endfor
    for [grouptypename,terminalwinids] in items(uberwingrouptypestohide)
       call s:Log.INF('Step 1.1 hiding non-state-complete uberwin group ', grouptypename)
       call wince_model#HideUberwins(grouptypename)
       for terminalwinid in terminalwinids
           call s:Log.INF('Step 1.1 relisting terminal window ', terminalwinid, ' from uberwin of group ', grouptypename, ' to supwin')
           call wince_model#AddSupwin(terminalwinid, -1, -1, -1)
       endfor
       let s:modelchanged = 1
       let s:nonsupwincache = {}
    endfor

    " If any supwin in the model isn't in the state, remove it and its subwins
    " from the model
    for modelsupwinid in wince_model#SupwinIds()
        call s:Log.VRB('Checking if model supwin ', modelsupwinid, ' still exists in state')
        if !wince_state#WinExists(modelsupwinid)
            call s:Log.INF('Step 1.1 removing state-missing supwin ', modelsupwinid, ' from model')
            let s:nonsupwincache = {}
            let s:modelchanged = 1
            call wince_model#RemoveSupwin(modelsupwinid)
        endif
    endfor

    " If any subwin group in the model isn't fully represented in the state,
    " mark it hidden in the model
    " If any terminal window is listed in the model as a subwin, mark that
    " subwin group hidden in the model and relist the window as a supwin
    " If there are multiple subwins in this group and only one of them has
    " become a terminal window or been closed, then this change renders that
    " subwin group incomplete and the non-state-terminal windows in the model
    " group will be ignored in STEP 1.3, then stomped in STEP 2.1
    let subwingrouptypestohidebysupwin = {}
    for modelsubwinid in wince_model#SubwinIds()
        call s:Log.VRB('Checking if model subwin ', modelsubwinid, ' is a non-terminal window in the state')
        let dohidegroup = 1
        let dorelistwin = 0
        if wince_state#WinExists(modelsubwinid)
            if wince_state#WinIsTerminal(modelsubwinid)
                call s:Log.VRB('Model subwin ', modelsubwinid, ' is a terminal window in the state')
                let dorelistwin = 1
            else
                let dohidegroup = 0
            endif
        else
            call s:Log.VRB('Model subwin ', modelsubwinid, ' does not exist in state')
        endif

        if dohidegroup
            let modelinfo = wince_model#InfoById(modelsubwinid)
            if modelinfo.category !=# 'subwin'
                throw 'Inconsistency in model. winid ' . modelsubwinid .
                      ' is both subwin and ' . modelinfo.category
            endif
            if !has_key(subwingrouptypestohidebysupwin, modelinfo.supwin)
                let subwingrouptypestohidebysupwin[modelinfo.supwin] = {}
            endif
            if !has_key(subwingrouptypestohidebysupwin[modelinfo.supwin], modelinfo.grouptype)
                let subwingrouptypestohidebysupwin[modelinfo.supwin][modelinfo.grouptype] = []
            endif
            if dorelistwin
                call add(subwingrouptypestohidebysupwin[modelinfo.supwin][modelinfo.grouptype], modelsubwinid)
            endif
        endif
    endfor
    for [supwinid, subwingrouptypestohide] in items(subwingrouptypestohidebysupwin)
        for [grouptypename, terminalwinids] in items(subwingrouptypestohide)
            call s:Log.INF('Step 1.1 hiding non-state-complete subwin group ', supwinid, ':', grouptypename)
            call wince_model#HideSubwins(supwinid, grouptypename)
            for terminalwinid in terminalwinids
                call s:Log.INF('Step 1.1 relisting terminal window ', terminalwinid, ' from subwin of group ', supwinid, ':', grouptypename, ' to supwin')
                call wince_model#AddSupwin(terminalwinid, -1, -1, -1)
            endfor
            let s:modelchanged = 1
            let s:nonsupwincache = {}
        endfor
    endfor
    
    " STEP 1.2: If any window in the state doesn't look the way the model
    "           says it should, relist it in the model. This is a separate
    "           step from STEP 1.1 because it iterates over groups/types
    "           instead of over winids
    call s:Log.VRB('Step 1.2')

    " If any window is listed in the model as an uberwin but doesn't
    " satisfy its type's constraints, mark the uberwin group hidden
    " in the model and relist the window as a supwin.
    for grouptypename in wince_model#ShownUberwinGroupTypeNames()
        " There are two loops here because if there was only one loop, we'd
        " potentially hide an uberwin and then not be able to check the rest
        " of the group due to winids being absent from the model. So
        " pre-retrieve all the winids and then check them.
        let typenamewinids = []
        for typename in wince_model#UberwinTypeNamesByGroupTypeName(grouptypename)
            call add(typenamewinids, [typename, wince_model#IdByInfo({
           \    'category': 'uberwin',
           \    'grouptype': grouptypename,
           \    'typename': typename
           \})])
        endfor
        let hidgroup = 0
        for [typename, winid] in typenamewinids
            call s:Log.VRB('Checking model uberwin ', grouptypename, ':', typename, ' for toIdentify compliance')
            if s:toIdentifyUberwins[grouptypename](winid) !=# typename
                call s:Log.INF('Step 1.2 relisting non-compliant uberwin ', winid, ' from ', grouptypename, ':', typename, ' to supwin and hiding group')
                let s:nonsupwincache = {}
                if !hidgroup
                    call wince_model#HideUberwins(grouptypename)
                    let hidgroup = 1
                endif
                call wince_model#AddSupwin(winid, -1, -1, -1)
                let s:modelchanged = 1
            endif
        endfor
    endfor

    " If any window is listed in the model as a subwin but doesn't
    " satisfy its type's constraints, mark the subwin group hidden
    " in the model and relist the window as a supwin.
    for supwinid in wince_model#SupwinIds()
        for grouptypename in wince_model#ShownSubwinGroupTypeNamesBySupwinId(supwinid)
            " There are two loops here because if there was only one loop, we'd
            " potentially hide a subwin and then not be able to check the rest
            " of the group due to winids being absent from the model. So
            " pre-retrieve all the winids and then check them.
            let typenamewinids = []
            for typename in wince_model#SubwinTypeNamesByGroupTypeName(grouptypename)
                call add(typenamewinids, [typename, wince_model#IdByInfo({
               \    'category': 'subwin',
               \    'supwin': supwinid,
               \    'grouptype': grouptypename,
               \    'typename': typename
               \})])
            endfor
            let hidgroup = 0
            let groupisafterimaged = wince_model#SubwinGroupIsAfterimaged(supwinid, grouptypename)
            let afterimagingtypes = g:wince_subwingrouptype[grouptypename].afterimaging
            for [typename, winid] in typenamewinids
                " toIdentify consistency isn't required if the subwin is
                " afterimaged
                if groupisafterimaged && has_key(afterimagingtypes, typename)
                    call s:Log.VRB('Afterimaged subwin ', supwinid, ':', grouptypename, ':', typename, ' is exempt from toIdentify compliance')
                    continue
                endif
                call s:Log.VRB('Checking model subwin ', supwinid, ':', grouptypename, ':', typename, ' for toIdentify compliance')
                let identified = s:toIdentifySubwins[grouptypename](winid)
                if empty(identified) ||
                  \identified.supwin !=# supwinid ||
                  \identified.typename !=# typename
                    call s:Log.INF('Step 1.2 relisting non-compliant subwin ', winid, ' from ', supwinid, ':', grouptypename, ':', typename, ' to supwin and hiding group')
                    let s:nonsupwincache = {}
                    if !hidgroup
                        call wince_model#HideSubwins(supwinid, grouptypename)
                        let hidgroup = 1
                    endif
                    call wince_model#AddSupwin(winid, -1, -1, -1)
                    let s:modelchanged = 1
                endif
            endfor
        endfor
    endfor

    " If any window is listed in the model as a supwin but it satisfies the
    " constraints of an uberwin or subwin, remove it and its subwins from the model.
    " STEP 1.3 will pick it up and add it as the appropriate uberwin/subwin type.
    for supwinid in wince_model#SupwinIds()
        call s:Log.VRB('Checking that model supwin ', supwinid, ' is a supwin in the state')
        let wininfo = s:IdentifyWindow(supwinid)
        if wininfo.category !=# 'supwin'
           call s:Log.INF('Step 1.2 found winid ', supwinid, ' listed as a supwin in the model but identified in the state as ', wininfo.category, ' ', wininfo.grouptype, ':', wininfo.typename, '. Removing from the model.')
            let s:nonsupwincache = {}
            let s:modelchanged = 1
            call wince_model#RemoveSupwin(supwinid)
        endif
    endfor

    " STEP 1.3: If any window in the state isn't in the model, add it to the model
    " All winids in the state
    call s:Log.VRB('Step 1.3')

    " Winids in the state that aren't in the model
    let missingwinids = []
    for statewinid in a:statewinids
        call s:Log.VRB('Checking state winid ', statewinid, ' for model presence')
        if !wince_model#WinExists(statewinid)
            call s:Log.VRB('State winid ', statewinid, ' not present in model')
            call add(missingwinids, statewinid)
        endif
    endfor
    " Model info for those winids
    let missingwininfos = []
    for missingwinid in missingwinids
        call s:Log.VRB('Identify model-missing window ', missingwinid)
        let missingwininfo = s:IdentifyWindow(missingwinid)
        if len(missingwininfo)
            call add(missingwininfos, missingwininfo)
        endif
    endfor
    " Model info for those winids, grouped by category, supwin id, group type,
    " and type
    call s:Log.VRB('Group info for model-missing windows')
    let groupedmissingwininfo = s:GroupInfo(missingwininfos)
    call s:Log.VRB('Add model-missing uberwins to model: ', groupedmissingwininfo.uberwin)
    for [grouptypename, group] in items(groupedmissingwininfo.uberwin)
        call s:Log.INF('Step 1.3 adding uberwin group ', grouptypename, ' to model with winids ', group.winids)
        try
            let s:nonsupwincache = {}
            let s:modelchanged = 1
            call wince_model#AddOrShowUberwins(grouptypename, group.winids, [])
        catch /.*/
            call s:Log.WRN('Step 1.3 failed to add uberwin group ', grouptypename, ' to model:')
            call s:Log.DBG(v:throwpoint)
            call s:Log.WRN(v:exception)
        endtry
    endfor
    call s:Log.VRB('Add model-missing supwins to model: ', groupedmissingwininfo.supwin)
    for supwinid in groupedmissingwininfo.supwin
        call s:Log.INF('Step 1.3 adding window ', supwinid, ' to model as supwin')
        call wince_model#AddSupwin(supwinid, -1, -1, -1)
        let s:modelchanged = 1
    endfor
    call s:Log.VRB('Add model-missing subwins to model: ', groupedmissingwininfo.subwin)
    for [supwinid, supwin] in items(groupedmissingwininfo.subwin)
        call s:Log.VRB('Subwins of supwin ', supwinid)
        if !wince_model#SupwinExists(supwinid)
            call s:Log.VRB('Supwin ', supwinid, ' does not exist')
            continue
        endif
        for [grouptypename, group] in items(supwin)
            call s:Log.INF('Step 1.3 adding subwin group ', supwinid, ':', grouptypename, ' to model with winids ', group.winids)
            try
                let s:nonsupwincache = {}
                let s:modelchanged = 1
                call wince_model#AddOrShowSubwins(
               \    supwinid,
               \    grouptypename,
               \    group.winids,
               \    []
               \)
            catch /.*/
                call s:Log.WRN('Step 1.3 failed to add subwin group ', grouptypename, ' to model:')
                call s:Log.DBG(v:throwpoint)
                call s:Log.WRN(v:exception)
            endtry
        endfor
    endfor

    " STEP 1.4: Supwins that have become terminal windows need to have their
    "      subwins hidden, but this must be done after STEP 1.3 which would add the
    "      subwins back
    call s:Log.VRB('Step 1.4')

    " If any supwin is a terminal window with shown subwins, mark them as
    " hidden in the model
    for supwinid in wince_model#SupwinIds()
        call s:Log.VRB('Checking if supwin ', supwinid, ' is a terminal window in the state')
        if wince_state#WinIsTerminal(supwinid)
            call s:Log.VRB('Supwin ', supwinid, ' is a terminal window in the state')
            for grouptypename in wince_model#ShownSubwinGroupTypeNamesBySupwinId(supwinid)
                call s:Log.DBG('Step 1.4 hiding subwin group ', grouptypename, ' of terminal supwin ', supwinid, ' in model')
                let s:nonsupwincache = {}
                let s:modelchanged = 1
                call wince_model#HideSubwins(supwinid, grouptypename)
            endfor
        endif
    endfor
endfunction

" STEP 2: Adjust the state so that it matches the model
function! s:ResolveModelToState(statewinids)
    " STEP 2.1: Purge the state of windows that aren't in the model
    call s:Log.VRB('Step 2.1')

    " TODO? Do something more civilized than stomping each window
    "       individually. So far it's ok but some other group type
    "       may require it in the future. This would require a new
    "       parameter for WinceAdd(Uber|Sub)winGroupType - a list of
    "       callbacks which close individual windows and not whole
    "       groups
    for winid in a:statewinids
        " WinStateCloseWindow used to close windows without noautocmd. If a
        " window triggered autocommands when closed, and those autocommands
        " closed other windows that were later in the list, this check would
        " fire. I'm leaving it here in case there are more bugs
        if !wince_state#WinExists(winid)
            call s:Log.ERR('State is inconsistent - winid ', winid, ' is both present and not present')
            continue
        endif

        let wininfo = s:IdentifyWindow(winid)
        call s:Log.DBG('Identified state window ', winid, ' as ', wininfo)

        " If any window in the state isn't categorizable, remove it from the
        " state
        if wininfo.category ==# 'none'
            call s:Log.INF('Step 2.1 removing uncategorizable window ', winid, ' from state')
            call wince_state#CloseWindow(winid, 0)
            continue
        endif

        " If any supwin in the state isn't in the model, remove it from the
        " state.
        if wininfo.category ==# 'supwin' && !wince_model#SupwinExists(wininfo.id)
            call s:Log.INF('Step 2.1 removing supwin ', winid, ' from state')
            call wince_state#CloseWindow(winid, 0)
            continue
        endif

        " If any uberwin in the state isn't shown in the model or has a
        " different winid than the model lists, remove it from the state
        if wininfo.category ==# 'uberwin' && (
       \    !wince_model#ShownUberwinGroupExists(wininfo.grouptype) ||
       \    wince_model#IdByInfo(wininfo) !=# winid
       \)
            call s:Log.INF("Step 2.1 removing non-model-shown or mis-model-winid'd uberwin ", wininfo.grouptype, ':', wininfo.typename, ' with winid ', winid, ' from state')
            call wince_state#CloseWindow(winid, 0)
            continue
        endif

        " If any subwin in the state isn't shown in the model or has a
        " different winid than the model lists, remove it from the state
        if wininfo.category ==# 'subwin' && (
       \    !wince_model#ShownSubwinGroupExists(wininfo.supwin, wininfo.grouptype) ||
       \    wince_model#IdByInfo(wininfo) !=# winid
       \)
           call s:Log.INF("Step 2.1 removing non-model-shown or mis-model-winid'd subwin ", wininfo.supwin, ':', wininfo.grouptype, ':', wininfo.typename, ' with winid ', winid, ' from state')
           call wince_state#CloseWindow(winid, g:wince_subwingrouptype[wininfo.grouptype].stompWithBelowRight)
           continue
        endif
    endfor

    " For the rest of STEP 2, supwin IDs in the model don't change - so cache
    " them
    let supwinids = wince_model#SupwinIds()

    " STEP 2.2: If any window has a chance of being in the wrong place,
    "           temporarily close all uberwins and subwins.
    "           A note on the algorithm used here: There was an older approach
    "           that involved scanning all windows and closing them
    "           individually if they had inconsistent or dummy dimensions
    "           (since STEP 1 is the only place where windows are added to the
    "           model with dummy dimensions). This approach required multiple
    "           passes (since closing windows changes the dimensions of other
    "           windows) and caused trouble with certain edge cases - in
    "           particular, wince_common#RecordAllDimensions() could not be
    "           called on the supwins because there was no guarantee of a 
    "           moment with all subwins closed and all uberwins open.
    call s:Log.VRB('Step 2.2')
    let doclose = 0
    
    " STEP 1 only makes changes to the model when it finds inconsistencies
    " between the model and state. Such inconsistencies can only exist at the
    " start of a resolver run if the state was touched by something other than
    " the user operations since the end of the previous resolver run. So we
    " know that happened if STEP 1 did anything, and we have to do the
    " closing.
    if s:modelchanged
        call s:Log.INF('Step 2.2 to temporarily close all uberwins and subwins to account for changes in the model')
        let doclose = 1
    endif

    " It's also possible for the user to make some change to the state (e.g.
    " resizing a window) that doesn't set off any of STEP 1's checks. So we
    " need to check that every window's state dimensions match its model
    " dimensions. Any inconsistency means the state's been touched and we have
    " to do the closing. Start by checking uberwins.
    if !doclose
        for grouptypename in wince_model#ShownUberwinGroupTypeNames()
            call s:Log.VRB('Check uberwin group ', grouptypename)
            if !wince_common#UberwinGroupDimensionsMatch(grouptypename)
                call s:Log.INF('Step 2.2 found uberwin group ', grouptypename, ' inconsistent. All uberwins and subwins to be temporarily closed')
                let doclose = 1
                break
            endif
        endfor
    endif 

    " Then check supwins and subwins
    if !doclose
        for supwinid in supwinids
            call s:Log.VRB('Check supwin ', supwinid)
            if !wince_common#SupwinDimensionsMatch(supwinid)
                call s:Log.INF('Step 2.2 found supwin ', supwinid, ' inconsistent. All uberwins and subwins to be temporarily closed')
                let doclose = 1
                break
            endif
            for grouptypename in wince_model#ShownSubwinGroupTypeNamesBySupwinId(
           \    supwinid
           \)
                if !wince_common#SubwinGroupDimensionsMatch(supwinid, grouptypename)
                    call s:Log.INF('Step 2.2 found subwin group ', supwinid, ':', grouptypename, ' inconsistent. All uberwins and subwins to be temporarily closed')
                    let doclose = 1
                    break
                endif
            endfor
            if doclose
                break
            endif
        endfor
    endif

    " Do the closing
    let preserveduberwins = {}
    let preservedsubwins = {}
    let dims = {}
    let views = {}
    if doclose
        for supwinid in supwinids
            " use reverse() so that we close subwins in
            " descending priority order. See comments in
            " wince_common#CloseSubwinsWithHigherPriorityThan
            for grouptypename in reverse(
           \    wince_model#ShownSubwinGroupTypeNamesBySupwinId(supwinid)
           \)
                let preservedsubwins[supwinid] = {}
                let preservedsubwins[supwinid][grouptypename] =
               \    wince_common#PreCloseAndReopenSubwins(supwinid, grouptypename)
                call s:Log.VRB('Preserved info from subwin group ', supwinid, ':', grouptypename, ': ', preservedsubwins[supwinid][grouptypename])
                call s:Log.INF('Step 2.2 removing subwin group ', supwinid, ':', grouptypename, ' from state')
                " TODO? Wrap in try-catch? Never seen it fail
                call wince_common#CloseSubwins(supwinid, grouptypename)
            endfor
        endfor

        for supwinid in supwinids
            " Save dimensions and view of supwin
            let dims[supwinid] = wince_state#GetWinDimensions(supwinid)
            let views[supwinid] = wince_state#ShieldWindow(supwinid)
        endfor

        for grouptypename in wince_model#ShownUberwinGroupTypeNames()
            let preserveduberwins[grouptypename] =
           \    wince_common#PreCloseAndReopenUberwins(grouptypename)
            call s:Log.VRB('Preserved info from uberwin group ', grouptypename, ': ', preserveduberwins[grouptypename])
            call s:Log.INF('Step 2.2 removing uberwin group ', grouptypename, ' from state')
            " TODO? Wrap in try-catch? Never seen it fail
            call wince_common#CloseUberwinsByGroupTypeName(grouptypename)
        endfor
    endif

    " STEP 2.3: Add any missing windows to the state, including those that
    "           were temporarily removed, in the correct places
    call s:Log.VRB('Step 2.3')

    " If any shown uberwin in the model isn't in the state,
    " add it to the state
    for grouptypename in wince_model#ShownUberwinGroupTypeNames()
        call s:Log.VRB('Checking model uberwin group ', grouptypename)
        if !wince_common#UberwinGroupExistsInState(grouptypename)
            try
                call s:Log.INF('Step 2.3 adding uberwin group ', grouptypename, ' to state')
                let winids = wince_common#OpenUberwins(grouptypename)
                for uberwinid in winids
                    let dims[uberwinid] = wince_state#GetWinDimensions(uberwinid)
                endfor
                " This Model write in ResolveModelToState is unfortunate, but I
                " see no sensible way to put it anywhere else
                let s:nonsupwincache = {}
                call wince_model#ChangeUberwinIds(grouptypename, winids)
                if has_key(preserveduberwins, grouptypename)
                    call s:Log.DBG('Uberwin group ', grouptypename, ' was closed in Step 2.2. Restoring.')
                    call wince_common#PostCloseAndReopenUberwins(
                   \    grouptypename,
                   \    preserveduberwins[grouptypename]
                   \)
                endif
            catch /.*/
                call s:Log.WRN('Step 2.3 failed to add ', grouptypename, ' uberwin group to state:')
                call s:Log.DBG(v:throwpoint)
                call s:Log.WRN(v:exception)
                let s:nonsupwincache = {}
                call wince_model#HideUberwins(grouptypename)
            endtry
        endif
    endfor

    " If we saved supwin dimensions and views in STEP 2.2, restore them
    call wince_common#RestoreDimensions(dims)
    call wince_common#UnshieldWindows(views)

    " If any shown subwin in the model isn't in the state,
    " add it to the state
    for supwinid in supwinids
        for grouptypename in wince_model#ShownSubwinGroupTypeNamesBySupwinId(supwinid)
            call s:Log.VRB('Checking model subwin group ', supwinid, ':', grouptypename)
            if !wince_common#SubwinGroupExistsInState(supwinid, grouptypename)
                call s:Log.VRB('Model subwin group ', supwinid, ':', grouptypename, ' is missing from state')
                if wince_model#SubwinGroupTypeHasAfterimagingSubwin(grouptypename)
                    call s:Log.VRB('State-missing subwin group ', supwinid, ':', grouptypename, ' is afterimaging. Afterimaging all other subwins of this group type first before restoring')
                    " Afterimaging subwins may be state-open in at most one supwin
                    " at a time. So if we're opening an afterimaging subwin, it
                    " must first be afterimaged everywhere else.
                    for othersupwinid in supwinids
                        if othersupwinid ==# supwinid
                            continue
                        endif
                        call s:Log.VRB('Checking supwin ', othersupwinid, ' for subwins of group type ', grouptypename)
                        if wince_model#ShownSubwinGroupExists(
                       \    othersupwinid,
                       \    grouptypename
                       \) && !wince_model#SubwinGroupIsAfterimaged(
                       \    othersupwinid,
                       \    grouptypename
                       \) && wince_common#SubwinGroupExistsInState(
                       \    othersupwinid,
                       \    grouptypename
                       \)
                            call s:Log.DBG('Step 2.3 afterimaging subwin group ', othersupwinid, ':', grouptypename)
                            call wince_common#AfterimageSubwinsByInfo(
                           \    othersupwinid,
                           \    grouptypename
                           \)
                        endif
                    endfor
                endif
                try
                    call s:Log.INF('Step 2.3 adding subwin group ', supwinid, ':', grouptypename, ' to state')
                    let winids = wince_common#OpenSubwins(supwinid, grouptypename)
                    " This Model write in ResolveModelToState is unfortunate, but I
                    " see no sensible way to put it anywhere else
                    let s:nonsupwincache = {}
                    call wince_model#ChangeSubwinIds(supwinid, grouptypename, winids)
                    if has_key(preservedsubwins, supwinid) &&
                   \   has_key(preservedsubwins[supwinid], grouptypename)
                        call s:Log.DBG('Subwin group ', supwinid, ':', grouptypename, ' was closed in Step 2.2. Restoring.')
                        call wince_common#PostCloseAndReopenSubwins(
                       \    supwinid,
                       \    grouptypename,
                       \    preservedsubwins[supwinid][grouptypename]
                       \)
                    endif
                catch /.*/
                    call s:Log.WRN('Step 2.3 failed to add ', grouptypename, ' subwin group to supwin ', supwinid, ':')
                    call s:Log.DBG(v:throwpoint)
                    call s:Log.WRN(v:exception)
                    let s:nonsupwincache = {}
                    call wince_model#HideSubwins(supwinid, grouptypename)
                endtry
            endif
        endfor
    endfor
endfunction

" STEP 3: Make sure that the subwins are afterimaged according to the cursor's
"         final position
function! s:ResolveCursor()
    " STEP 3.1: Reselect cursor window and update afterimaging
    call s:Log.VRB('Step 3.1')
    let curwin = wince_common#ReselectCursorWindow(s:curpos.win)
    call wince_common#UpdateAfterimagingByCursorWindow(curwin)

    " STEP 3.2: If the model's current window does not match the state's
    "           current window (as it was at the start of this resolver run), then
    "           the state's current window was touched between resolver runs by
    "           something other than the user operations. That other thing won't have
    "           updated the model's previous window, so update it here by using the
    "           model's current window. Then update the model's current window using
    "           the state's current window.
    call s:Log.VRB('Step 3.2')
    let modelcurrentwininfo = wince_model#CurrentWinInfo()
    let modelcurrentwinid = wince_model#IdByInfo(modelcurrentwininfo)
    let resolvecurrentwinid = wince_model#IdByInfo(curwin)
    if wince_model#IdByInfo(wince_model#PreviousWinInfo()) && modelcurrentwinid &&
   \   resolvecurrentwinid !=# modelcurrentwinid
        " If the current window doesn't exist in the state, then this resolver
        " run must have closed it. Set the current window to the previous
        " window.
        if !wince_state#WinExists(resolvecurrentwinid)
            call wince_model#SetCurrentWinInfo(wince_model#PreviousWinInfo())
        else
            call wince_model#SetPreviousWinInfo(modelcurrentwininfo)
            call wince_model#SetCurrentWinInfo(curwin)
        endif
    endif
endfunction

" Resolver implementation
function! s:ResolveInner()
    " Retrieve the toIdentify functions
    call s:Log.VRB('Retrieve toIdentify functions')
    let s:toIdentifyUberwins = wince_model#ToIdentifyUberwins()
    let s:toIdentifySubwins = wince_model#ToIdentifySubwins()

    " If this is the first time running the resolver after entering a tab, run
    " the appropriate callbacks
    if t:wince_resolvetabenteredcond
        call s:Log.DBG('Tab entered. Running callbacks')
        for TabEnterCallback in wince_model#TabEnterPreResolveCallbacks()
            call s:Log.VRB('Running tab-entered callback ', TabEnterCallback)
            call TabEnterCallback()
        endfor
        let t:wince_resolvetabenteredcond = 0
    endif

    " A list of winids in the state is used in both STEP 1.3 and STEP 2.1,
    " without changing inbetween. So retrieve it only once
    let statewinids = wince_state#GetWinidsByCurrentTab()

    " STEP 1: The state may have changed since the last resolver run. Adapt the
    "         model to fit it.
    call s:ResolveStateToModel(statewinids)

    " Save the cursor position to be restored at the end of the resolver. This
    " is done here because the position is stored in terms of model keys which
    " may not have existed until now
    call s:Log.VRB('Save cursor position')
    let s:curpos = wince_common#GetCursorPosition()

    " Save the current number of tabs
    let tabcount = wince_state#GetTabCount()

    " STEP 2: Now the model is the way it should be, so adjust the state to fit it.
    call s:ResolveModelToState(statewinids)

    " It is possible that STEP 2 closed the tab, and we are now in a
    " different tab. If that is the case, end the resolver run
    " immediately. We can tell the tab has been closed by checking the number
    " of tabs. The resolver will never open a new tab or rearrange existing
    " tabs.
    if tabcount !=# wince_state#GetTabCount()
        let s:resolveIsRunning = 0
        return
    endif

    " STEP 3: The model and state are now consistent with each other, but
    "         afterimaging and tracked cursor positions may be inconsistent with the
    "         final position of the cursor. Make them consistent.
    call s:ResolveCursor()

    " STEP 4: Now everything is consistent, so record the dimensions of all
    "         windows in the model. The next resolver run will consider those
    "         dimensions as being the last known consistent data, unless a
    "         user operation overwrites them with its own (also consistent)
    "         data.
    call s:Log.VRB('Step 4')
    call wince_common#RecordAllDimensions()

    " Restore the (possibly-reselected) cursor position from when the
    " resolver run started
    call s:Log.VRB('Restore cursor position')
    call wince_common#RestoreCursorPosition(s:curpos)
    let s:curpos = {}
endfunction

" Resolver entry point
let s:resolveIsRunning = 0
function! wince_resolve#Resolve()
    if s:resolveIsRunning
        call s:Log.DBG('Resolver reentrance detected')
        return
    endif

    let s:resolveIsRunning = 1
    call s:Log.DBG('Resolver start')

    let s:nonsupwincache = {}

    try
        call s:ResolveInner()
        call s:Log.DBG('Resolver end')
    catch /.*/
        call s:Log.ERR('Resolver abort:')
        call s:Log.DBG(v:throwpoint)
        call s:Log.WRN(v:exception)
    finally
        let s:resolveIsRunning = 0
    endtry
endfunction

" Since the resolver runs as a CursorHold callback, autocmd events
" need to be explicitly signalled to it
augroup WinceResolve
    autocmd!
    
    " Use the TabEnter event to detect when a tab has been entered
    autocmd TabEnter * let t:wince_resolvetabenteredcond = 1
augroup END
