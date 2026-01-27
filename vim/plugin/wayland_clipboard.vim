if exists('g:loaded_wayland_clipboard_vim')
  finish
endif
let g:loaded_wayland_clipboard_vim = 1

" Only on Wayland and only if wl-copy exists
if !empty($WAYLAND_DISPLAY) && executable('wl-copy') && executable('wl-paste')
  xnoremap "+y y:call system('wl-copy', @")<CR>
  nnoremap "+p :let @"=system('wl-paste --no-newline')<CR>p
  nnoremap "+P :let @"=system('wl-paste --no-newline')<CR>P
endif

