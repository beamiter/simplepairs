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
  var out = filter(copy(value), (_, item) => type(item) == v:t_string && !empty(item))
  # An empty list is a real request ("disable nothing"). A list that contains
  # only unusable items is a mistake, same as a wrong type.
  return empty(out) && !empty(value) ? copy(fallback) : out
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

# Every key simplepairs would take has a <Plug> target, defined whether or not
# the defaults are installed.  Without them the only control a user had over
# eleven insert-mode keys was g:simplepairs_default_mappings, which turns all
# eleven off together; with them a key can be moved, or pairing kept on just
# the brackets, without giving up the rest.
inoremap <silent> <expr> <Plug>(simplepairs-open-paren) simplepairs#Open('(')
inoremap <silent> <expr> <Plug>(simplepairs-open-bracket) simplepairs#Open('[')
inoremap <silent> <expr> <Plug>(simplepairs-open-brace) simplepairs#Open('{')
inoremap <silent> <expr> <Plug>(simplepairs-open-double-quote) simplepairs#Open('"')
inoremap <silent> <expr> <Plug>(simplepairs-open-single-quote) simplepairs#Open("'")
inoremap <silent> <expr> <Plug>(simplepairs-open-backtick) simplepairs#Open('`')
inoremap <silent> <expr> <Plug>(simplepairs-close-paren) simplepairs#Close(')')
inoremap <silent> <expr> <Plug>(simplepairs-close-bracket) simplepairs#Close(']')
inoremap <silent> <expr> <Plug>(simplepairs-close-brace) simplepairs#Close('}')
inoremap <silent> <expr> <Plug>(simplepairs-backspace) simplepairs#Backspace()
inoremap <silent> <expr> <Plug>(simplepairs-enter) simplepairs#Enter()

# The suite-wide guard: a default key is installed only into a slot that is
# still empty and that the user has not already pointed at the <Plug> target
# from somewhere else.  :inoremap overwrites without warning and simplepairs
# keeps no copy of what it displaced, so the eleven bare :inoremap lines this
# replaces destroyed a user's own insert-mode maps, and any earlier plugin's,
# with no message and nothing to restore.  Inside this suite the casualty was
# simplecc's completion-accept: it installs `imap <CR>
# <Plug>(simplecc-select-enter)` behind exactly this guard, so an unguarded map
# here won every time, and simplecc's own guard -- which found the slot free
# and then lost it -- is what made the loss silent.  Guarded on both sides,
# load order decides and neither plugin takes a key its owner already claimed.
if g:simplepairs_default_mappings
  for [lhs, plug] in simplepairs#DEFAULT_MAPPINGS
    # maparg() without a dict prefers a buffer-local mapping in the current
    # buffer, which is not a claim on the global slot.
    var info = maparg(lhs, 'i', false, true)
    if (empty(info) || get(info, 'buffer', 0) != 0) && !hasmapto(plug, 'i')
      execute 'imap <silent> ' .. lhs .. ' ' .. plug
    endif
  endfor
endif
