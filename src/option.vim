" Wince Reference Definition for Option uberwin
let s:Log = jer_log#LogFunctions('wince-option-uberwin')

if !exists('g:wince_enable_option') || !g:wince_enable_option
    call s:Log.CFG('Option uberwin disabled')
    finish
endif

" TODO? Close and reopen the option window whenever the current window
"       changes, so as to update its record of window-local options
"       - Probably not worth doing. The options and their possible values
"         all stay the same anway - only the positions of the possible values
"         would change

if !exists('g:wince_option_right')
    let g:wince_option_right = 0
endif

if !exists('g:wince_option_width')
    let g:wince_option_width = 85
endif

if !exists('g:wince_option_statusline')
    let g:wince_option_statusline = '%!wince_option#StatusLine()'
endif

" The option window is an uberwin
call wince_user#AddUberwinGroupType('option', ['option'],
                           \[g:wince_option_statusline],
                           \'O', 'o', 6,
                           \60, [0],
                           \[g:wince_option_width], [-1],
                           \function('wince_option#ToOpen'),
                           \function('wince_option#ToClose'),
                           \function('wince_option#ToIdentify'))

" Mappings
if exists('g:wince_disable_option_mappings') && g:wince_disable_option_mappings
    call s:Log.CFG('Option uberwin mappings disabled')
else
    call wince_map#MapUserOp('<leader>os', 'call wince_user#AddOrShowUberwinGroup("option")')
    call wince_map#MapUserOp('<leader>oo', 'let g:wince_map_mode = wince_user#AddOrGotoUberwin("option","option",g:wince_map_mode)')
    call wince_map#MapUserOp('<leader>oh', 'call wince_user#RemoveUberwinGroup("option")')
    call wince_map#MapUserOp('<leader>oc', 'call wince_user#RemoveUberwinGroup("option")')
endif
