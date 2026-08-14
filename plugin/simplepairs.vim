vim9script

if exists('g:loaded_simplepairs')
  finish
endif
g:loaded_simplepairs = 1

if v:version < 901
  echohl WarningMsg
  echomsg '[SimplePairs] Vim 9.1 or newer is required.'
  echohl None
  finish
endif

g:simplepairs_default_mappings = get(g:, 'simplepairs_default_mappings', 1)
g:simplepairs_disabled_filetypes = get(g:, 'simplepairs_disabled_filetypes', [
  'help', 'qf', 'terminal', 'simpletree', 'simpleminimap', 'simpleplug',
])

command! SimplePairsEnable let b:simplepairs_disable = 0
command! SimplePairsDisable let b:simplepairs_disable = 1
command! SimplePairsToggle let b:simplepairs_disable = !get(b:, 'simplepairs_disable', 0)
command! SimplePairsHealth simplepairs#Health()

if g:simplepairs_default_mappings
  inoremap <silent><expr> ( simplepairs#Open('(')
  inoremap <silent><expr> [ simplepairs#Open('[')
  inoremap <silent><expr> { simplepairs#Open('{')
  inoremap <silent><expr> " simplepairs#Open('"')
  inoremap <silent><expr> ' simplepairs#Open("'")
  inoremap <silent><expr> ` simplepairs#Open('`')
  inoremap <silent><expr> ) simplepairs#Close(')')
  inoremap <silent><expr> ] simplepairs#Close(']')
  inoremap <silent><expr> } simplepairs#Close('}')
  inoremap <silent><expr> <BS> simplepairs#Backspace()
  inoremap <silent><expr> <CR> simplepairs#Enter()
endif
