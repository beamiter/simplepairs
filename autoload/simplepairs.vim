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

def Escaped(before: string): bool
  var slash_count = 0
  var index = strlen(before) - 1
  while index >= 0 && strpart(before, index, 1) ==# '\'
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
  if Escaped(before)
    return opening
  endif
  var closing = PAIRS[opening]
  if closing ==# opening
    if strpart(after, 0, strlen(closing)) ==# closing
      return "\<Right>"
    endif
    # Apostrophes inside identifiers and prose are text, not string delimiters.
    if opening ==# "'" && before =~# '\k$' && after =~# '^\k'
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
