vim9script

const PAIRS = {'(': ')', '[': ']', '{': '}', '"': '"', "'": "'", '`': '`'}
const REVERSE = {')': '(', ']': '[', '}': '{'}
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

def FiletypeDisabled(value: any): bool
  if type(value) != v:t_list
    return index(DISABLED_FILETYPE_FALLBACK, &l:filetype) >= 0
  endif
  for item in value
    if type(item) == v:t_string && item ==# &l:filetype
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
  var slash_count = 0
  var index = strlen(tail) - 1
  while index >= 0 && strpart(tail, index, 1) ==# '\'
    slash_count += 1
    index -= 1
  endwhile
  # A run longer than the bounded tail has unknowable parity without turning
  # a keystroke back into an O(line length) scan.  Fail closed: leaving the
  # typed quote alone is reversible; inventing a closing quote is not.
  return (slash_count == strlen(tail) && continues_before_tail)
    || slash_count % 2 == 1
enddef

export def Open(opening: string): string
  if Disabled() || !has_key(PAIRS, opening)
    return opening
  endif
  var text = getline('.')
  var byte = col('.') - 1
  var tail_start = max([0, byte - PREFIX_TAIL])
  var tail = strpart(text, tail_start, byte - tail_start)
  var run_continues = tail_start > 0
    && strpart(text, tail_start - 1, 1) ==# '\'
    && !empty(tail) && strpart(tail, 0, 1) ==# '\'
  if Escaped(tail, run_continues)
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
  return strpart(text, byte, strlen(closing)) ==# closing ? "\<Right>" : closing
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
  return get(PAIRS, opening, '') ==# closing ? "\<BS>\<Del>" : "\<BS>"
enddef

export def Enter(): string
  if Disabled()
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
    return "\<CR>\<Esc>O"
  endif
  return "\<CR>"
enddef

export def Health()
  echomsg 'SimplePairs health'
  echomsg $'  buffer: {Disabled() ? "disabled" : "enabled"}'
  var mappings_on = Flagged(get(g:, 'simplepairs_default_mappings', 1), true)
  echomsg $'  default mappings: {mappings_on ? "yes" : "no"}'
  echomsg $'  filetype: {empty(&l:filetype) ? "(none)" : &l:filetype}'
enddef
