" Wince: The WINdow Constraint Engine for Terminal Vim
"
" Wince is a Vim plugin that constrains the positions and dimensions of
" split-windows.
" Some split-windows are constrained and some are not. Which ones are constrained
" is decided by extensions to Wince.
" Wince includes a set of such extensions (called 'reference definitions'). By
" default, all the reference definitions are disabled and so Wince constrains
" no split-windows. A plugin or vimrc depending on Wince may provide its own
" extensions.
"
" Wince was developed with Vim 8.0+ in mind. There is compatibility with Vim
" 7.3, but not all features will work.
" 
" Wince is developed and validated with the terminal version of Vim.
" Theoretically the GUI version should be compatible, but this has not been
" tested.
" 
" WHY?
"
" Vim does not natively enforce any correlation between the purpose of a
" window and its position, or between the position of a window and the positions
" of its related windows. A window can exist at the far left, with its
" location window on the far right and six other windows inbetween. A quickfix
" window can be in any position, and so easily mistaken for a location window.
" Wince's main purpose is to enforce such correlations. A window's
" location window should only ever directly below. The quickfix window should only
" ever be at the bottom of the screen. And so on and so forth.
"
" CORE CONCEPTS
"
" The primary design goal is extensibility: incorporation of new types of
" windows must be easy, especially ones added by plugins (like the undotree and
" undodiff windows from mbbill/undotree). Therefore there needs to be a scheme
" for classification of windows into categories more general than 'the quickfix
" window' or 'a location window'. Constraints on windows can then be enforced
" agnostically, based only on the window's category.
" The categories used are:
"     - Supwin (Superwindow): The standard kind of window
"     - Subwin (Subwindow): A window that is slaved to a supwin, like a location
"                           window. Subwins are allowed to exist only when their
"                           supwins exist, and are always in the same position
"                           relative the position of their supwins
"     - Uberwin (Uberwindow): A window that is always against the edge of the
"                             screen and whose content is either tab-specific or
"                             session-global, like the quickfix window
"
" Since some types of windows appear and disappear together (such as the undotree
" and undodiff windows from the mbbill/undotree plugin), uberwins and subwins
" are managed in groups.
"
" An uberwin group is a collection of uberwins that are only ever opened and closed
" at the same time as each other. An uberwin group is associated with a single tab.
"
" Similarly, a subwin group is a collection of subwins that are only ever opened and
" closed at the same time as each other. A subwin group is associated with a single
" supwin.
" 
" FEATURES
"
" The positions and dimensions of all Uberwins and Subwins recognized by Wince,
" are constrained accordingly. Wince may repeatedly open and close windows to
" achieve this end. Great care has been taken to ensure this process is as
" unintrusive as possible to the Vim user - window-local and buffer-local options
" are persisted and resored. So are cursor and scroll positions.
"
" By default, Wince does not redraw the screen while doing this. You can
" switch on g:wince_extraredraw to see the windows opening and closing
"
" For additional flexibility, uberwin and subwin groups can be 'hidden' -
" closed in Vim but still accounted for in Wince's data structures. A hidden
" uberwin or subwin group is ready to be restored ('shown') at any time. For
" instance, if a supwin has a location list but its location window isn't open,
" a location window management script (such as the one included with Wince as
" a reference definition) may choose to consider the location list subwin to
" be hidden for that supwin.
" 
" Sometimes, as is the case with the mbbill/undotree plugin, content in windows is
" associated with specific supwins/buffers but only the content for one of those
" supwins/buffers can be displayed at any given time. Wince, in addition to
" constraining positions and dimensions, mitigates this problem with a feature
" called afterimaging, which gives the user the impression that the content in a
" subwin group is being displayed simultaneously for multiple supwins. If a subwin
" type is designated as afterimaging, then subwins of that type are 'afterimaged' -
" replaced with visually identical (but inert) copies called afterimages - whenever
" the user leaves the supwin of those subwins. At any given time, no more than one
" supwin may have a non-afterimaged subwin of that type. So really, the user
" is looking at what amounts to one real subwin and multiple cardboard cutouts
" of subwins.
"
" INTERNALS
"
" Wince's core architectural components are:
"     1 The State - meaning the state of Vim's window tiling.
"     2 The Model - a collection of Vim-Global, Script-local and Tab-local data
"                   structures that represent the *intended* state of the window
"                   tiling in terms of supwins, subwins, and uberwins. At any time,
"                   the model may be consistent or inconsistent with the the state.
"                   But it is always internally consistent.
"     3 The User Operations - A collection of functions that manipulate the model and
"                             state under the assumption that they are already
"                             consistent with each other. The user operations
"                             can be used as an interface to Wince when writing a
"                             script
"
" If the State were to be mutated by *only* the user operations, it would
" always be consistent with the model... but unfortunately we can't make that
" assumption. All it takes to ruin the consistency is a single invocation of
" something like 'wincmd r' in a plugin. That's why there's a 4th core component:
"
"     4 The Resolver - an algorithm that guarantees on completion that the model
"                      and state are consistent with each other, even if they
"                      were inconsistent when the resolver started. Runs under
"                      autocmds that fire after any event that could introduce
"                      an inconsistency between the state and model
"
"     There is also a place for code that is common to the Resolver and User
"     Operations.
" 
" Since the user operations are cumbersome as a user interface, there are two
" more components sitting on top of the user operations:
"
"     5 The Commands - A collection of custom commands that make calls to the
"                      user operations
"     6 The Mappings - A collection of mappings that replace native Vim window
"                      operations with invocations of the custom commands.
"                      These mappings may interact in unwelcome ways with
"                      scripts, so they are optional.
"                      I've done my best to cover every native Vim window
"                      operation.
"
" In short, the user interacts with the state and model by means of mappings
" and custom commands that call user operations, which keep the state and
" model consistent. Scripts may also use the user operations for more
" fine-grained control. If anything goes wrong and the state and model become
" inconsistent, the resolver will quickly swoop in and fix the inconsistency
" anyway.
" In versions of Vim without the SafeState autocmd event (i.e. pre-8.1),
" The resolver is registered under the CursorHold autocmd event. This event
" fires after Vim has been sitting idle long enough (outside of Insert mode).
" How long exactly depends on the value of the 'updatetime' option.
" If updatetime is set to a small enough value, the inconsistency is
" visible only for a split second. I recommend an updatetime of 100, as I've
" found that anything shorter can sometimes lead to weird race conditions
"
" EXTENSIONS
"
" Extensions to Wince take the form of definitions of uberwin and subwin group
" types (i.e. calls to the wince_user#AddUberwinGroupType and wince_user#AddSubwinGroupType user
" operations). Reference definitions are provided for help, preview, and
" quickfix uberwins. A reference definition is provided for a loclist subwin.
" All these reference definitions are disabled by default because Wince may be
" loaded as a dependency of another plugin - in that case, the user wouldn't
" expect any constraints to be applied to windows not added by that other
" plugin
" 
" LIMITATIONS
"
" - If the mappings are enabled, invoking a mapped command of the form
"   <c-w>{nr}<cr> or z{nr}<cr> from visual or select mode will cause the
"   mode indicator to disappear while {nr} is being typed in
"
" - If the mappings are enabled, invoking a mapped command in visual or
"   select mode will cause the mode indicator and highlighted area to
"   flicker - even if the mapped command has no effect (e.g. <c-w>w when
"   there's only one window)
"
" - Compatibility with session reloading is dubious. In theory, the resolver is
"   defensive enough to handle any and all possible changes to the state - but
"   consistency between the state and model may not reasonably be enough for a
"   smooth experience. For instance, sessions do not preserve location lists. So
"   any location list subwins that exist during the :mksession invocation will
"   be restored as supwins. It is the responsibility of the subwin group writers
"   to deal with issues like these on a case-by-case basis. As an example, the
"   reference definition of the location list subwin group (see: wince-loclist.vim)
"   handles the above case by closing all the
"   supwins-that-were-subwins-in-a-previous-life.
"
" TODO? Preserve folds, signs, etc. when subwins and uberwins are hidden. Not
"       sure if this is desirable - would they still be restored after
"       location list contents change? Would different blobs of persisted
"       state be stored for each location list? Maybe just leave it as the
"       responsibility of files like loclist.vim and undotree.vim. Probably
"       too complicated - the state of subwins and uberwins is currently only
"       persisted when they quickly close and then reopen without unwinding to
"       the event loop. Trying to persist state across multiple events is
"       asking for trouble.
" TODO? Figure out why folds keep appearing in the help window on
"       WinShowUberwin. Haven't seen this happen in some time - maybe it's
"       fixed? Or maybe I just don't use folds enough to see it
" TODO? Think of a way to avoid creating a new buffer every time a subwin is
"       afterimaged
"       - Only real reason to do this is to avoid buffer numbers getting
"         really big, since the buffers themselves are freed when they leave
"         windows
"       - This would mean reusing buffers and completely cleaning them between
"         uses
"       - Buffer numbers need to be 'freed' every time an afterimaged subwin is
"         closed, but the user (or some plugin) may do it directly without
"         freeing. So the Resolver needs to check if any have disappeared by
"         maintaining a list. That list needs to be tab-local because
"         afterimage buffers may be in use in other tabs, and it needs to go in
"         the model because everything in the core is stateless except for the
"         state (duh) and model and t:wince_resolvetabenteredcond which is bad
"         but pretty unavoidable
" TODO? Figure out why terminal windows keep breaking the resolver and
"       statuslines
"       - It's got to do with an internal bug in Vim. Maybe it can be
"         mitigated?
"       - The internal error is caught now, but it seems to add ranges to
"         a bunch of commands that run after it gets caught
"       - All the statuslines and tabline get cleared

" TODO: Only run the resolver inside user operations with reloyonresolver if
"       there's no SafeState
" TODO: Audit all the core code for references to specific group types
" TODO: Audit all the user operations and common code for direct accesses to
"       the state and model
" TODO: Audit the common code for functions that are not common to the
"       resolver and user operations
" TODO: Comment out every logging statement that gets skipped by the default
"       levels. Write some kind of awk or sed script that uncomments and
"       recomments them
" TODO: Audit every function for calls to it
" TODO: Audit all files for ignoble terminology
" TODO: Audit all files for user-exposed names that don't make sense
" TODO: Audit all files for insufficient documentation
" TODO: Audit all files for lines longer than 80 characters
" TODO: Audit all files for 'endfunction!'
" TODO: Write docs

" Avoid loading twice
if exists('s:loaded')
    finish
endif
let s:loaded = 0

" Dependency on vim-jersuite-core for logging, legacy winids, and
" miscellaneous utilities
JerCheckDep wince
\           jersuite_core
\           github.com/jeremy-quicklearner/vim-jersuite-core
\           1.2.0
\           2.0.0
let g:wince_version = '0.2.3'
call jer_log#LogFunctions('jersuite').CFG('wince version ',
                                         \ g:wince_version)

" Logging facilities
call jer_log#SetLevel('wince-model',   'CFG', 'WRN')
call jer_log#SetLevel('wince-state',   'CFG', 'WRN')
call jer_log#SetLevel('wince-common',  'INF', 'WRN')
call jer_log#SetLevel('wince-resolve', 'INF', 'WRN')
call jer_log#SetLevel('wince-user',    'INF', 'WRN')

call jer_log#SetLevel('wince-commands', 'INF', 'WRN')
call jer_log#SetLevel('wince-mappings', 'INF', 'WRN')

call jer_log#SetLevel('wince-help-uberwin',     'CFG', 'WRN')
call jer_log#SetLevel('wince-preview-uberwin',  'CFG', 'WRN')
call jer_log#SetLevel('wince-quickfix-uberwin', 'CFG', 'WRN')
call jer_log#SetLevel('wince-option-uberwin',   'CFG', 'WRN')
call jer_log#SetLevel('wince-loclist-subwin',   'CFG', 'WRN')

" Commands, mappings, and reference definitions are not fully autoloaded
source <sfile>:p:h:h/src/cmd.vim
source <sfile>:p:h:h/src/map.vim

" Reference Definitions
source <sfile>:p:h:h/src/help.vim
source <sfile>:p:h:h/src/preview.vim
source <sfile>:p:h:h/src/quickfix.vim
source <sfile>:p:h:h/src/option.vim
source <sfile>:p:h:h/src/loclist.vim

" Enforce correct statuslines
source <sfile>:p:h:h/src/statusline.vim

" Setup the resolver to run as a post-event callback, after any changes to
" the state. Use the priority value 0 - every other post-event callback's
" priority is decided by its relationship with the resolver
if !exists('g:wince_resolve_chc')
    let g:wince_resolve_chc = 1
    call jer_pec#Register(function('wince_resolve#Resolve'), [], 1, 0, 1, 0, 1)
endif

augroup Wince
    autocmd!

    " When the resolver runs in a new tab, it should run as if the tab was entered
    autocmd VimEnter,TabNew * let t:winresolvetabenteredcond = 1

    " Run the resolver when Vim is resized
    autocmd VimResized * call wince_resolve#Resolve()
augroup END

" TODO? raise an error in an 'after' script if any of these options have
" different values

" Don't equalize window sizes when windows are closed
set noequalalways

" Allow windows to be arbitratily small
set winheight=1
set winwidth=1
set winminheight=1
set winminheight=1
