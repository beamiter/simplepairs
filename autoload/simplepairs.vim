vim9script

const PAIRS = {'(': ')', '[': ']', '{': '}', '"': '"', "'": "'", '`': '`'}
const REVERSE = {')': '(', ']': '[', '}': '{'}

def Disabled(): bool
  return get(b:, 'simplepairs_disable', 0) != 0
    || index(get(g:, 'simplepairs_disabled_filetypes', []), &l:filetype) >= 0
    || !&l:modifiable || &l:readonly || &l:paste
enddef

def Around(): list<string>
  var text = getline('.')
  var byte = col('.') - 1
  var before = byte > 0 ? strpart(text, 0, byte) : ''
  var after = byte < strlen(text) ? strpart(text, byte) : ''
  return [before, after]
enddef

# Everything Open() decides about the text behind the cursor, it decides from
# the last few characters of it, so it works from a bounded tail and never from
# the whole prefix.  Three separate costs grew with the length of that prefix,
# and every mapping here is <expr>, so every one of them was paid before the
# typed character reached the screen.  `before =~# '\k$'` made the regex engine
# walk the entire prefix to reach a match that can only ever be at the end;
# Escaped() walked every backslash of a run; and passing the prefix to a :def
# copies it, because Vim9 copies string arguments, which is why Escaped() takes
# the tail rather than `before`.  On a 128 KB line -- the shape a minifier or a
# code generator leaves behind -- Open("'") went from 2756 us to 91 us and
# Open('"') after a run of 8000 backslashes from 1498 us to 7.5 us.  The 91 us
# that is left is almost entirely Around(), which still copies the whole line
# twice: measured on its own it is 52 us of that 91, and Open('(') -- which
# never reaches either test above -- costs the same 91 us before and after this
# change.  So the tail bounds these three tests, not the function; whoever wants
# the rest has to change Around()'s contract and all four entry points.
#
# 64 bytes is far more than either test can read.  The keyword test needs the
# last character with its composing characters, and Vim caps those at
# 'maxcombine', so the widest sequence that exists is well under half the tail.
# Escaped() needs only the parity of the backslash run, and a run longer than
# the tail -- reported as even here whatever its true parity -- does not occur
# in text a human or a formatter produces.  Cutting the tail mid-character is
# harmless: both tests are anchored to the end of it, and a UTF-8 continuation
# byte is neither '\' nor a match for '\k'.  Cutting a single *byte* instead of
# a tail would not be harmless, which is why this is not `strpart(before,
# strlen(before) - 1, 1)`: for any multibyte character that byte is a
# continuation byte, so `naï'` would pair where `naive'` correctly does not.
const PREFIX_TAIL = 64

def Escaped(tail: string): bool
  var slash_count = 0
  var index = strlen(tail) - 1
  while index >= 0 && strpart(tail, index, 1) ==# '\'
    slash_count += 1
    index -= 1
  endwhile
  return slash_count % 2 == 1
enddef

export def Open(opening: string): string
  if Disabled() || !has_key(PAIRS, opening)
    return opening
  endif
  var [before, after] = Around()
  var tail = strpart(before, strlen(before) - PREFIX_TAIL, PREFIX_TAIL)
  if Escaped(tail)
    return opening
  endif
  var closing = PAIRS[opening]
  if closing ==# opening
    if strpart(after, 0, strlen(closing)) ==# closing
      return "\<Right>"
    endif
    # Apostrophes inside identifiers and prose are text, not string delimiters.
    if opening ==# "'" && tail =~# '\k$' && after =~# '^\k'
      return opening
    endif
  endif
  return opening .. closing .. "\<Left>"
enddef

export def Close(closing: string): string
  if Disabled() || !has_key(REVERSE, closing)
    return closing
  endif
  var after = Around()[1]
  return strpart(after, 0, strlen(closing)) ==# closing ? "\<Right>" : closing
enddef

export def Backspace(): string
  if Disabled()
    return "\<BS>"
  endif
  var [before, after] = Around()
  if empty(before) || empty(after)
    return "\<BS>"
  endif
  var opening = strpart(before, strlen(before) - 1, 1)
  var closing = strpart(after, 0, 1)
  return get(PAIRS, opening, '') ==# closing ? "\<BS>\<Del>" : "\<BS>"
enddef

export def Enter(): string
  if Disabled()
    return "\<CR>"
  endif
  var [before, after] = Around()
  if empty(before) || empty(after)
    return "\<CR>"
  endif
  var opening = strpart(before, strlen(before) - 1, 1)
  var closing = strpart(after, 0, 1)
  if get(PAIRS, opening, '') ==# closing && index(['(', '[', '{', '`'], opening) >= 0
    return "\<CR>\<Esc>O"
  endif
  return "\<CR>"
enddef

export def Health()
  echomsg 'SimplePairs health'
  echomsg $'  buffer: {Disabled() ? "disabled" : "enabled"}'
  echomsg $'  default mappings: {get(g:, "simplepairs_default_mappings", 1) ? "yes" : "no"}'
  echomsg $'  filetype: {empty(&l:filetype) ? "(none)" : &l:filetype}'
enddef
