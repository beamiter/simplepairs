vim9script

set nocompatible nomore
const ROOT = fnamemodify(resolve(expand('<sfile>:p')), ':h:h')
execute 'set runtimepath^=' .. fnameescape(ROOT)
execute 'source ' .. fnameescape(ROOT .. '/plugin/simplepairs.vim')

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
b:simplepairs_disable = 1
assert_equal('(', simplepairs#Open('('))
assert_equal("\<CR>", simplepairs#Enter())

assert_equal(2, exists(':SimplePairsToggle'))
assert_match('simplepairs#Open', maparg('(', 'i'))

if !empty(v:errors)
  writefile(v:errors, ROOT .. '/tests/errors.log')
  cquit
endif
qa!
