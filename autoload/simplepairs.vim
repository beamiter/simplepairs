vim9script

const PAIRS = {'(': ')', '[': ']', '{': '}', '"': '"', "'": "'", '`': '`'}
const REVERSE = {')': '(', ']': '[', '}': '{'}

# The key each default mapping goes on and the <Plug> target it goes through.
# It lives here, not in plugin/simplepairs.vim, so that the guard that installs
# these and the health check that reports on them read the same eleven rows: a
# health check carrying its own copy of the table can only ever agree with
# itself.
export const DEFAULT_MAPPINGS = [
  ['(', '<Plug>(simplepairs-open-paren)'],
  ['[', '<Plug>(simplepairs-open-bracket)'],
  ['{', '<Plug>(simplepairs-open-brace)'],
  ['"', '<Plug>(simplepairs-open-double-quote)'],
  ["'", '<Plug>(simplepairs-open-single-quote)'],
  ['`', '<Plug>(simplepairs-open-backtick)'],
  [')', '<Plug>(simplepairs-close-paren)'],
  [']', '<Plug>(simplepairs-close-bracket)'],
  ['}', '<Plug>(simplepairs-close-brace)'],
  ['<BS>', '<Plug>(simplepairs-backspace)'],
  ['<CR>', '<Plug>(simplepairs-enter)'],
]

const DISABLED_FILETYPE_FALLBACK = [
  'help', 'qf', 'terminal', 'simpletree', 'simpleminimap', 'simpleplug',
]

def Flagged(value: any, fallback: bool = false): bool
  if type(value) == v:t_bool
    return value
  endif
  if type(value) == v:t_number
    return value != 0
  endif
  return fallback
enddef

def FiletypeHits(item: string): bool
  if empty(item)
    return false
  endif
  if item ==? &l:filetype
    return true
  endif
  for part in split(&l:filetype, '\m\.')
    if part ==? item
      return true
    endif
  endfor
  return false
enddef

def FiletypeDisabled(value: any): bool
  if type(value) != v:t_list
    return FiletypeHitsList(DISABLED_FILETYPE_FALLBACK)
  endif
  var valid = 0
  for item in value
    if type(item) != v:t_string || empty(item)
      continue
    endif
    valid += 1
    if FiletypeHits(item)
      return true
    endif
  endfor
  if valid == 0 && !empty(value)
    return FiletypeHitsList(DISABLED_FILETYPE_FALLBACK)
  endif
  return false
enddef

def FiletypeHitsList(items: list<string>): bool
  for item in items
    if FiletypeHits(item)
      return true
    endif
  endfor
  return false
enddef

def Disabled(): bool
  return Flagged(get(b:, 'simplepairs_disable', 0))
    || FiletypeDisabled(get(g:, 'simplepairs_disabled_filetypes', []))
    || !&l:modifiable || &l:readonly || &l:paste
enddef

def DisableReason(): string
  if Flagged(get(b:, 'simplepairs_disable', 0))
    return 'buffer toggle'
  endif
  if FiletypeDisabled(get(g:, 'simplepairs_disabled_filetypes', []))
    return 'filetype'
  endif
  if !&l:modifiable
    return 'nomodifiable'
  endif
  if &l:readonly
    return 'readonly'
  endif
  if &l:paste
    return 'paste'
  endif
  return ''
enddef

# Everything Open() decides about the text behind the cursor, it decides from
# the last few characters of it, so it works from a bounded tail and never from
# the whole prefix.  Four separate costs grew with the length of that prefix,
# and every mapping here is <expr>, so every one of them was paid before the
# typed character reached the screen.  `before =~# '\k$'` made the regex engine
# walk the entire prefix to reach a match that can only ever be at the end;
# Escaped() walked every backslash of a run; and passing the prefix to a :def
# copies it, because Vim9 copies string arguments.  The old Around() helper
# also materialized both halves of the line for every call.  On a 128 KB line --
# the shape a minifier or a code generator leaves behind -- that last copy was
# most of the remaining work even for Open('('), which needs neither half.
# Each entry point now keeps getline() intact and slices only this tail and the
# one byte after the cursor.  Work is bounded at both ends of the line.
#
# 64 bytes is far more than either test can read.  The keyword test needs the
# last character with its composing characters, and Vim caps those at
# 'maxcombine', so the widest sequence that exists is well under half the tail.
# Escaped() needs only the parity of the backslash run; a run longer than the
# tail is detected from the preceding byte and fails closed rather than being
# scanned without bound.  Cutting the tail mid-character is
# harmless: both tests are anchored to the end of it, and a UTF-8 continuation
# byte is neither '\' nor a match for '\k'.  Cutting a single *byte* instead of
# a tail would not be harmless, which is why this is not `strpart(before,
# strlen(before) - 1, 1)`: for any multibyte character that byte is a
# continuation byte, so `naï'` would pair where `naive'` correctly does not.
const PREFIX_TAIL = 64

def Escaped(tail: string, continues_before_tail: bool): bool
  var quoteescape = &l:quoteescape
  if empty(quoteescape)
    return false
  endif
  var slash_count = 0
  var index = strlen(tail) - 1
  while index >= 0 && stridx(quoteescape, strpart(tail, index, 1)) >= 0
    slash_count += 1
    index -= 1
  endwhile
  # A run longer than the bounded tail has unknowable parity without turning
  # a keystroke back into an O(line length) scan.  Fail closed: leaving the
  # typed quote alone is reversible; inventing a closing quote is not.
  return (slash_count == strlen(tail) && continues_before_tail)
    || slash_count % 2 == 1
enddef

# Whether the character at `byte` is escaped by a 'quoteescape' run immediately
# before it.  Open() uses this for the character about to be typed; Close(),
# Backspace() and Enter() use it for a character already in the line.
def PrecedingEscaped(text: string, byte: number): bool
  var quoteescape = &l:quoteescape
  if byte <= 0 || empty(quoteescape)
    return false
  endif
  var tail_start = max([0, byte - PREFIX_TAIL])
  var tail = strpart(text, tail_start, byte - tail_start)
  var run_continues = tail_start > 0
    && stridx(quoteescape, strpart(text, tail_start - 1, 1)) >= 0
    && !empty(tail) && stridx(quoteescape, strpart(tail, 0, 1)) >= 0
  return Escaped(tail, run_continues)
enddef

export def Open(opening: string): string
  if Disabled() || !has_key(PAIRS, opening)
    return opening
  endif
  var text = getline('.')
  var byte = col('.') - 1
  if PrecedingEscaped(text, byte)
    return opening
  endif
  var closing = PAIRS[opening]
  if closing ==# opening
    if strpart(text, byte, strlen(closing)) ==# closing
      return "\<Right>"
    endif
    # Apostrophes inside identifiers and prose are text, not string delimiters.
    # The forward slice is bounded too.  It is wider than one byte so the
    # leading character can be multibyte; the anchored test reads no further.
    var tail = strpart(text, max([0, byte - PREFIX_TAIL]), min([byte, PREFIX_TAIL]))
    if opening ==# "'" && tail =~# '\k$'
        && strpart(text, byte, PREFIX_TAIL) =~# '^\k'
      return opening
    endif
  endif
  return opening .. closing .. "\<Left>"
enddef

export def Close(closing: string): string
  if Disabled() || !has_key(REVERSE, closing)
    return closing
  endif
  var text = getline('.')
  var byte = col('.') - 1
  if strpart(text, byte, strlen(closing)) !=# closing || PrecedingEscaped(text, byte)
    return closing
  endif
  return "\<Right>"
enddef

export def Backspace(): string
  if Disabled()
    return "\<BS>"
  endif
  var text = getline('.')
  var byte = col('.') - 1
  if byte <= 0 || byte >= strlen(text)
    return "\<BS>"
  endif
  var opening = strpart(text, byte - 1, 1)
  var closing = strpart(text, byte, 1)
  return get(PAIRS, opening, '') ==# closing && !PrecedingEscaped(text, byte - 1)
    ? "\<BS>\<Del>" : "\<BS>"
enddef

export def Enter(): string
  # A visible completion menu owns <CR>: Vim's popup accepts the selected match
  # on it, and expanding a pair instead would insert a newline into whatever
  # the menu left behind and then open a line above it.  This matters because
  # the mapping guard alone cannot decide the composition both ways round --
  # simplecc installs its completion-accept behind a maparg() guard, so in the
  # load order where simplepairs reaches <CR> first simplecc declines and this
  # is the only thing left between the popup and a mangled buffer.
  if Disabled() || pumvisible()
    return "\<CR>"
  endif
  var text = getline('.')
  var byte = col('.') - 1
  if byte <= 0 || byte >= strlen(text)
    return "\<CR>"
  endif
  var opening = strpart(text, byte - 1, 1)
  var closing = strpart(text, byte, 1)
  if get(PAIRS, opening, '') ==# closing && index(['(', '[', '{', '`'], opening) >= 0
      && !PrecedingEscaped(text, byte - 1)
    return "\<CR>\<Esc>O"
  endif
  return "\<CR>"
enddef

# Which of the eleven keys simplepairs actually holds right now.  The load-time
# guard leaves a key alone when something is already bound to it, which is the
# right thing to do and also invisible -- and 'default mappings: yes' answers a
# different question, whether installing was attempted.  A user whose <CR>
# belongs to a completion plugin, or whose ( belongs to their own vimrc, can
# read it off here instead of guessing from behaviour.
export def MappingReport(): list<string>
  var report: list<string> = []
  for [lhs, plug] in DEFAULT_MAPPINGS
    var rhs = maparg(lhs, 'i')
    if rhs ==# plug
      report->add($'{lhs} -> {plug}')
    elseif rhs ==# ''
      report->add($'{lhs} unmapped')
    else
      report->add($'{lhs} held by {rhs}')
    endif
  endfor
  return report
enddef

export def Health()
  echomsg 'SimplePairs health'
  var reason = DisableReason()
  echomsg '  buffer: ' .. (empty(reason) ? 'enabled' : 'disabled (' .. reason .. ')')
  var held = 0
  for [lhs, plug] in DEFAULT_MAPPINGS
    if maparg(lhs, 'i') ==# plug
      held += 1
    endif
  endfor
  echomsg $'  default mappings: {held > 0 ? "yes" : "no"}'
  echomsg $'  filetype: {empty(&l:filetype) ? "(none)" : &l:filetype}'
  echomsg '  insert-mode keys:'
  for line in MappingReport()
    echomsg $'    {line}'
  endfor
enddef
