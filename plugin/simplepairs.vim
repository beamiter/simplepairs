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

def Flag(value: any, fallback: number): number
  if type(value) == v:t_bool
    return value ? 1 : 0
  endif
  if type(value) == v:t_number
    return value == 0 ? 0 : 1
  endif
  return fallback
enddef

def Filetypes(value: any, fallback: list<string>): list<string>
  if type(value) != v:t_list
    return copy(fallback)
  endif
  return filter(copy(value), (_, item) => type(item) == v:t_string)
enddef

const DEFAULT_DISABLED_FILETYPES = [
  'help', 'qf', 'terminal', 'simpletree', 'simpleminimap', 'simpleplug',
]
g:simplepairs_default_mappings = Flag(get(g:, 'simplepairs_default_mappings', 1), 1)
g:simplepairs_disabled_filetypes = Filetypes(
  get(g:, 'simplepairs_disabled_filetypes', DEFAULT_DISABLED_FILETYPES),
  DEFAULT_DISABLED_FILETYPES)

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
