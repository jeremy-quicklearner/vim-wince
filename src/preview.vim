" Wince Reference Definition for Preview uberwin
let s:Log = jer_log#LogFunctions('wince-preview-uberwin')

if !exists('g:wince_enable_preview') || !g:wince_enable_preview
    call s:Log.CFG('Preview uberwin disabled')
    finish
endif

if !exists('g:wince_preview_bottom')
    let g:wince_preview_bottom = 0
endif

if !exists('g:wince_preview_statusline')
    let g:wince_preview_statusline = '%!wince_preview#StatusLine()'
endif

" The preview window is an uberwin
call wince_user#AddUberwinGroupType('preview', ['preview'],
                             \[g:wince_preview_statusline],
                             \'P', 'p', 7,
                             \30, [0],
                             \[-1], [&previewheight],
                             \function('wince_preview#ToOpen'),
                             \function('wince_preview#ToClose'),
                             \function('wince_preview#ToIdentify'))

if !exists('g:wince_preview_chc')
    let g:wince_preview_chc = 1
    call jer_chc#Register(function('wince_preview#Update'), [], 0, -70, 1, 0, 1)
endif

" The preview uberwin is intended to only ever be opened by native commands like
" ptag and pjump - no user operations. Therefore the window engine code interacts
" with it only via the resolver and wince_preview#ToOpen only ever gets called when the
" resolver closes and reopens the window. So the implementation of
" wince_preview#ToOpen assumes that wince_preview#ToClose has recently been called.
augroup WincePreview
    autocmd!
    autocmd VimEnter, TabNew * let t:j_preview = {}
augroup END

" Mappings
if exists('g:wince_disable_preview_mappings') && g:wince_disable_preview_mappings
    call s:Log.CFG('Preview uberwin mappings disabled')
else
    call wince_map#MapUserOp('<leader>ps', 'call wince_user#ShowUberwinGroup("preview", 1)')
    call wince_map#MapUserOp('<leader>ph', 'call wince_user#HideUberwinGroup("preview")')
    call wince_map#MapUserOp('<leader>pc', 'call wince_user#HideUberwinGroup("preview")')
    call wince_map#MapUserOp('<leader>pp', 'let g:wince_map_mode = wince_user#GotoUberwin("preview", "preview", g:wince_map_mode, 1)')
endif
