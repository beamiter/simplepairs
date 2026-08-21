vim9script

set nocompatible nomore
const ROOT = fnamemodify(resolve(expand('<sfile>:p')), ':h:h')
execute 'set runtimepath^=' .. fnameescape(ROOT)
execute 'source ' .. fnameescape(ROOT .. '/plugin/simplepairs.vim')

# Every mapping this plugin installs is <expr>, so whatever these functions cost
# is paid before the typed character reaches the screen -- there is no timer and
# no redraw to hide behind.  What used to cost anything grew with the length of
# the line, so the assertions here are made on a line no human typed: 128 KB on
# one line, the shape a minifier or a code generator leaves behind, and a run of
# backslashes long enough to make an unbounded parity walk visible.
#
# Two kinds of assertion.  The absolute budget is what a keystroke may cost and
# is deliberately loose, because this runs on whatever machine is free.  The
# ratios under it are the ones with teeth: they compare two calls made on the
# same line in the same process, so they say "this test does not scale with the
# length of the line" without caring how fast the machine is.  Timings are the
# best of several batches rather than the mean for the same reason -- one
# descheduled batch should not fail the suite.

const BUDGET_US = 1000.0
const RATIO = 10.0

def Best(N: number, F: func(): any): float
  for _ in range(5)
    F()
  endfor
  var best = 1.0e9
  for _ in range(7)
    var start = reltime()
    for _ in range(N)
      F()
    endfor
    var us = reltimefloat(reltime(start)) * 1000000.0 / N
    if us < best
      best = us
    endif
  endfor
  return best
enddef

def Budget(name: string, us: float)
  assert_true(us < BUDGET_US,
    printf('%s took %.1f us, budget %.0f us', name, us, BUDGET_US))
enddef

new
setlocal filetype=text

# 131072 keyword characters behind the cursor and a keyword character in front
# of it: the combination that reaches the keyword test in Open(), which an
# earlier benchmark of this plugin missed because Open('(') returns before it.
setline(1, repeat('a', 131072) .. 'b')
cursor(1, 131073)
assert_equal("'", simplepairs#Open("'"))

const open_quote = Best(20, () => simplepairs#Open("'"))
const open_paren = Best(20, () => simplepairs#Open('('))
const close_paren = Best(20, () => simplepairs#Close(')'))
const backspace = Best(20, () => simplepairs#Backspace())
const enter = Best(20, () => simplepairs#Enter())

Budget('Open("''") on a 128 KB line', open_quote)
Budget('Open("(") on a 128 KB line', open_paren)
Budget('Close(")") on a 128 KB line', close_paren)
Budget('Backspace() on a 128 KB line', backspace)
Budget('Enter() on a 128 KB line', enter)

# Close() reads the same line through the same getline() and strpart(), and then
# looks at one character.  Open("'") does that and adds the tests on the text
# behind the cursor, so on any machine the two are within a small factor of each
# other.  Through this harness, anchoring the keyword test to the end of the
# whole prefix rather than to a bounded tail read 2751 us against Close()'s 79.7
# us, a factor of 34; bounded, it reads 90.9 against 69.2, a factor of 1.3.
assert_true(open_quote < close_paren * RATIO,
  printf('the keyword test is scanning the prefix again: Open("''") %.1f us '
    .. 'is over %.0fx Close(")") %.1f us on the same 128 KB line',
    open_quote, RATIO, close_paren))

# The parity of a backslash run is read from the same bounded tail, so the
# length of the run cannot matter.  Unbounded it did: through this harness, 1451
# us for a run of 8000 against 6.2 us for a run of 64, on one keystroke.
setline(1, repeat('\', 8000) .. 'x')
cursor(1, 8001)
const long_run = Best(20, () => simplepairs#Open('"'))
setline(1, repeat('\', 64) .. 'x')
cursor(1, 65)
const short_run = Best(20, () => simplepairs#Open('"'))

Budget('Open("\"") after a run of 8000 backslashes', long_run)
assert_true(long_run < short_run * RATIO,
  printf('the parity walk is unbounded again: Open() after 8000 backslashes '
    .. '%.1f us is over %.0fx the same after 64 %.1f us',
    long_run, RATIO, short_run))

# A bounded regex is not enough if preparing its arguments still copies the
# entire prefix and suffix.  Around() used to materialize both halves on every
# expression mapping; compare the same operation at opposite ends of a 128 KB
# line with its one-byte equivalent to keep both directions constant-time.
setline(1, repeat('a', 131072))
cursor(1, 131072)
const long_prefix = Best(20, () => simplepairs#Open('('))
setline(1, 'a')
cursor(1, 1)
const short_prefix = Best(20, () => simplepairs#Open('('))
assert_true(long_prefix < short_prefix * RATIO,
  printf('Open() copied the whole prefix again: 128 KB %.1f us is over %.0fx '
    .. 'one byte %.1f us', long_prefix, RATIO, short_prefix))

setline(1, repeat('a', 131072))
cursor(1, 1)
const long_suffix = Best(20, () => simplepairs#Close(')'))
setline(1, 'a')
cursor(1, 1)
const short_suffix = Best(20, () => simplepairs#Close(')'))
assert_true(long_suffix < short_suffix * RATIO,
  printf('Close() copied the whole suffix again: 128 KB %.1f us is over %.0fx '
    .. 'one byte %.1f us', long_suffix, RATIO, short_suffix))

if !empty(v:errors)
  writefile(v:errors, ROOT .. '/tests/errors.log')
  cquit
endif
qa!
