vim9script
set nocompatible nomore backspace=indent,eol,start
const ROOT = fnamemodify(resolve(expand('<sfile>:p')), ':h:h')
execute 'set runtimepath^=' .. fnameescape(ROOT)
execute 'source ' .. fnameescape(ROOT .. '/plugin/simplepairs.vim')

# Replace modes must keep Vim's native one-character replacement and backspace
# restoration.  Inserting partners or skipping a delimiter loses source text.
for start in ['R', 'gR']
  new
  setline(1, 'abc')
  feedkeys(start .. "(\<Esc>", 'xt')
  assert_equal('(bc', getline(1), start .. ' opener overwrote an extra character')
  setline(1, ')abc')
  cursor(1, 1)
  feedkeys(start .. ")x\<Esc>", 'xt')
  assert_equal(')xbc', getline(1), start .. ' closer skipped instead of replacing')
  setline(1, 'abc')
  cursor(1, 1)
  feedkeys(start .. "\"\<Esc>", 'xt')
  assert_equal('"bc', getline(1), start .. ' quote overwrote an extra character')
  setline(1, 'a)tail')
  cursor(1, 1)
  feedkeys(start .. "(\<BS>\<Esc>", 'xt')
  assert_equal('a)tail', getline(1), start .. ' backspace did not restore source')
  # Compare Enter with the plugin disabled rather than assuming indentation
  # settings: a pair expansion must not add an extra line in Replace mode.
  var results: list<list<string>> = []
  for disabled in [true, false]
    b:simplepairs_disable = disabled
    setline(1, '()')
    cursor(1, 2)
    feedkeys(start .. "\<CR>\<Esc>", 'xt')
    add(results, getline(1, '$'))
    deletebufline(bufnr(), 2, '$')
  endfor
  assert_equal(results[0], results[1], start .. ' Enter expanded a pair')
  bwipe!
endfor

if !empty(v:errors)
  writefile(v:errors, ROOT .. '/tests/errors.log')
  cquit
endif
qa!
