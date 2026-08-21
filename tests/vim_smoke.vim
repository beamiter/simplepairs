vim9script

set nocompatible nomore
# 'encoding' follows the locale, so a run under LANG=C would compare latin1
# bytes and quietly skip everything the multibyte assertions below are for.
set encoding=utf-8
const ROOT = fnamemodify(resolve(expand('<sfile>:p')), ':h:h')
execute 'set runtimepath^=' .. fnameescape(ROOT)
g:simplepairs_default_mappings = 'invalid'
g:simplepairs_disabled_filetypes = 'invalid'
execute 'source ' .. fnameescape(ROOT .. '/plugin/simplepairs.vim')
assert_equal(1, g:simplepairs_default_mappings)
assert_true(index(g:simplepairs_disabled_filetypes, 'help') >= 0)

new
setlocal filetype=vim
setline(1, '')
cursor(1, 1)
assert_equal("()\<Left>", simplepairs#Open('('))
setline(1, '()')
cursor(1, 2)
assert_equal("\<Right>", simplepairs#Close(')'))
assert_equal("\<BS>\<Del>", simplepairs#Backspace())
assert_equal("\<CR>\<Esc>O", simplepairs#Enter())

setline(1, 'cant')
cursor(1, 4)
assert_equal("'", simplepairs#Open("'"))

# The character on either side of the cursor is a character, not a byte.  Open()
# reads the one behind the cursor out of a fixed-size tail of the line, so a
# multibyte character has to survive that cut: reading the last *byte* instead
# would hand '\k' a UTF-8 continuation byte, which never matches, and an
# apostrophe typed inside naive would be left alone while one typed inside
# naïve got a spurious partner.  Built with nr2char() so the encoding this file
# is read in cannot change what is being tested.
const IDIAERESIS = nr2char(0xef)
const CJK = nr2char(0x8a9e)
setline(1, 'na' .. IDIAERESIS .. 've')
cursor(1, 5)
assert_equal("'", simplepairs#Open("'"))
setline(1, CJK .. CJK)
cursor(1, 4)
assert_equal("'", simplepairs#Open("'"))
# Same again with the multibyte character at the far end of a long prefix, which
# is the case the tail exists for.
setline(1, repeat('a', 5000) .. IDIAERESIS .. 've')
cursor(1, 5003)
assert_equal("'", simplepairs#Open("'"))
# A multibyte character behind the cursor with no keyword character in front of
# it pairs, exactly as an ASCII one does.
setline(1, CJK .. ' x')
cursor(1, 4)
assert_equal("''\<Left>", simplepairs#Open("'"))

# Backslash parity still decides, and it is now read out of the same bounded
# tail: an odd run escapes the quote, an even one does not.
setline(1, 'x\y')
cursor(1, 3)
assert_equal("'", simplepairs#Open("'"))
setline(1, 'x\\y')
cursor(1, 4)
assert_equal("''\<Left>", simplepairs#Open("'"))
# A run longer than the tail has unknown parity.  It fails closed instead of
# inventing a partner: unbounded, a line ending in 8000 backslashes cost 1465
# us on a single keystroke, while a missed partner is safer than a wrong one.
setline(1, repeat('\', 65) .. 'y')
cursor(1, 66)
assert_equal("'", simplepairs#Open("'"))
setline(1, repeat('\', 66) .. 'y')
cursor(1, 67)
assert_equal("'", simplepairs#Open("'"))
setline(1, repeat('\', 63) .. 'y')
cursor(1, 64)
assert_equal("'", simplepairs#Open("'"))

# An apostrophe at the end of a word in prose still pairs, and inside a comment
# it is wrong in every language.  The guard needs a keyword character on BOTH
# sides, so `don't` is handled and `the parsers' desk` is not.  Telling them
# apart needs the syntax group at the cursor, and synstack() measured 15.5 us
# against the 1.85 us the whole of Open() costs on a realistic C buffer -- 8x
# the keystroke, on every quote typed -- so the heuristic is left alone.  This
# pins the behaviour so the next attempt at it is a deliberate change.
setline(1, '# the parsers desk')
cursor(1, 14)
assert_equal("''\<Left>", simplepairs#Open("'"))

b:simplepairs_disable = 1
assert_equal('(', simplepairs#Open('('))
assert_equal("\<CR>", simplepairs#Enter())

# Runtime configuration corruption must not escape from an <expr> mapping.
b:simplepairs_disable = 'invalid'
g:simplepairs_disabled_filetypes = 'invalid'
assert_equal("()\<Left>", simplepairs#Open('('))
setlocal filetype=help
assert_equal('(', simplepairs#Open('('))
setlocal filetype=vim
b:simplepairs_disable = v:true
assert_equal('(', simplepairs#Open('('))
b:simplepairs_disable = 0
g:simplepairs_disabled_filetypes = ['vim', 42]
assert_equal('(', simplepairs#Open('('))
g:simplepairs_disabled_filetypes = []

assert_equal(2, exists(':SimplePairsToggle'))
assert_match('simplepairs#Open', maparg('(', 'i'))
silent simplepairs#Health()

if !empty(v:errors)
  writefile(v:errors, ROOT .. '/tests/errors.log')
  cquit
endif
qa!
