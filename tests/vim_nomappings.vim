vim9script

# g:simplepairs_default_mappings = 0 used to be the only control a user had over
# eleven insert-mode keys, and it is all-or-nothing.  It stays supported, but it
# is no longer the escape hatch: the <Plug> targets are defined either way, so
# turning the defaults off leaves the keys free and the behaviour reachable.
# This pins both halves -- no default key is taken, every target still exists.

set nocompatible nomore
set encoding=utf-8
const ROOT = fnamemodify(resolve(expand('<sfile>:p')), ':h:h')
execute 'set runtimepath^=' .. fnameescape(ROOT)

const PLUGS = [
  ['(', '<Plug>(simplepairs-open-paren)', 'simplepairs#Open'],
  ['[', '<Plug>(simplepairs-open-bracket)', 'simplepairs#Open'],
  ['{', '<Plug>(simplepairs-open-brace)', 'simplepairs#Open'],
  ['"', '<Plug>(simplepairs-open-double-quote)', 'simplepairs#Open'],
  ["'", '<Plug>(simplepairs-open-single-quote)', 'simplepairs#Open'],
  ['`', '<Plug>(simplepairs-open-backtick)', 'simplepairs#Open'],
  [')', '<Plug>(simplepairs-close-paren)', 'simplepairs#Close'],
  [']', '<Plug>(simplepairs-close-bracket)', 'simplepairs#Close'],
  ['}', '<Plug>(simplepairs-close-brace)', 'simplepairs#Close'],
  ['<BS>', '<Plug>(simplepairs-backspace)', 'simplepairs#Backspace'],
  ['<CR>', '<Plug>(simplepairs-enter)', 'simplepairs#Enter'],
]

g:simplepairs_default_mappings = 0
execute 'source ' .. fnameescape(ROOT .. '/plugin/simplepairs.vim')
assert_equal(0, g:simplepairs_default_mappings)

for [lhs, plug, fn] in PLUGS
  assert_equal('', maparg(lhs, 'i'),
    $'{lhs} was mapped although default mappings are switched off')
  assert_match(fn, maparg(plug, 'i'),
    $'{plug} is not defined, so this key cannot be rebound at all')
endfor

# With the defaults off, the health report says so key by key rather than
# leaving the user to infer it from 'default mappings: no'.
const report = simplepairs#MappingReport()
assert_equal(len(PLUGS), len(report))
assert_equal([], filter(copy(report), (_, line) => line !~# ' unmapped$'))
silent simplepairs#Health()

# The user rebinds one of them by hand, the way the <Plug> targets exist for.
imap <silent> <C-j> <Plug>(simplepairs-enter)
assert_equal(1, hasmapto('<Plug>(simplepairs-enter)', 'i'))

new
setlocal filetype=text
setline(1, '()')
cursor(1, 2)
assert_equal("\<CR>\<Esc>O", simplepairs#Enter())

if !empty(v:errors)
  writefile(v:errors, ROOT .. '/tests/errors.log')
  cquit
endif
qa!
