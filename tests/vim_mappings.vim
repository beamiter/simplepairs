vim9script

# The eleven insert-mode keys simplepairs installs by default used to be bare
# :inoremap lines.  :inoremap overwrites without a message and simplepairs keeps
# no copy of what it displaced, so whatever the user -- or a plugin sourced
# earlier -- had on those keys was destroyed with nothing to restore.  Inside
# this suite the casualty was simplecc's completion-accept on <CR>, and
# simplecc's own maparg() guard is what made the loss silent: it found the slot
# free, installed, and simplepairs then took it.
#
# What is pinned here is simplepairs' half of that contract, in both spellings
# of the suite-wide guard:
#
#   * maparg(lhs, 'i') ==# ''      -- an occupied slot is left alone;
#   * !hasmapto(plug, 'i')         -- a <Plug> target the user has already
#                                     bound to a key of their own does not also
#                                     claim the default key.
#
# Delete either half in plugin/simplepairs.vim and this file fails.

set nocompatible nomore
set encoding=utf-8
const ROOT = fnamemodify(resolve(expand('<sfile>:p')), ':h:h')
execute 'set runtimepath^=' .. fnameescape(ROOT)

# Every default key, the <Plug> target it goes through, and the function that
# target must reach.  Named in full so that dropping a <Plug> target -- the
# thing that makes any of this rebindable -- is a test failure and not a
# silently smaller plugin.
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

# Claimed before the plugin loads: two of the user's own insert-mode maps, and
# a stand-in for simplecc's completion-accept.  simplecc itself is deliberately
# not sourced -- this repo's gate must not depend on a sibling checkout being
# on disk -- but the stand-in is installed through the identical guard simplecc
# uses (simplecc.vim: `if maparg('<CR>', 'i') ==# '' | imap <silent> <CR>
# <Plug>(simplecc-select-enter) | endif`), because the failure being pinned is
# precisely that guard finding the slot free and then losing it.
inoremap ( USER-PAREN
inoremap <BS> USER-BACKSPACE
inoremap <silent> <expr> <Plug>(othercc-select-enter) "\<C-y>"
if maparg('<CR>', 'i') ==# ''
  imap <silent> <CR> <Plug>(othercc-select-enter)
endif
assert_equal('<Plug>(othercc-select-enter)', maparg('<CR>', 'i'))

# A user who has moved a <Plug> target onto a key of their own has answered the
# question of where it lives; the default key must not be taken as well.  The
# target does not exist yet, which is the realistic case -- this is what a
# vimrc line looks like, sourced before the plugin.
imap <silent> <C-l> <Plug>(simplepairs-close-paren)

execute 'source ' .. fnameescape(ROOT .. '/plugin/simplepairs.vim')
assert_equal(1, g:simplepairs_default_mappings)

# Slots that were already spoken for, and what must still be in them.
const CLAIMED = {
  '(': 'USER-PAREN',
  '<BS>': 'USER-BACKSPACE',
  '<CR>': '<Plug>(othercc-select-enter)',
}

for [lhs, plug, fn] in PLUGS
  assert_match(fn, maparg(plug, 'i'),
    $'{plug} is not defined, so this key cannot be rebound at all')
  if has_key(CLAIMED, lhs)
    assert_equal(CLAIMED[lhs], maparg(lhs, 'i'),
      $'simplepairs overwrote the insert-mode mapping already on {lhs}')
  elseif lhs ==# ')'
    # The hasmapto half: the target is bound to <C-l>, so ) stays free.
    assert_equal('', maparg(lhs, 'i'),
      $'simplepairs claimed {lhs} although its <Plug> target is already bound')
  else
    assert_equal(plug, maparg(lhs, 'i'),
      $'{lhs} did not get its default mapping')
  endif
endfor

# The mapping that was lost in the field: still reachable, still simplecc's.
assert_equal(1, hasmapto('<Plug>(othercc-select-enter)', 'i'))
assert_equal('<Plug>(simplepairs-close-paren)', maparg('<C-l>', 'i'))

# Declining a key is the right thing to do and, on its own, invisible: nothing
# is echoed and 'default mappings: yes' still says yes.  :SimplePairsHealth is
# where a user finds out which of the eleven simplepairs actually got, and who
# has the rest -- so the report has to name all three states.
const report = simplepairs#MappingReport()
assert_equal(len(PLUGS), len(report))
assert_true(index(report, '( held by USER-PAREN') >= 0, string(report))
assert_true(index(report, '<BS> held by USER-BACKSPACE') >= 0, string(report))
assert_true(index(report, '<CR> held by <Plug>(othercc-select-enter)') >= 0, string(report))
assert_true(index(report, ') unmapped') >= 0, string(report))
assert_true(index(report, '[ -> <Plug>(simplepairs-open-bracket)') >= 0, string(report))
silent simplepairs#Health()

# Going through a <Plug> target must not change what the key does.
new
setlocal filetype=text
setline(1, '')
cursor(1, 1)
assert_equal("[]\<Left>", simplepairs#Open('['))
setline(1, '[]')
cursor(1, 2)
assert_equal("\<Right>", simplepairs#Close(']'))

if !empty(v:errors)
  writefile(v:errors, ROOT .. '/tests/errors.log')
  cquit
endif
qa!
