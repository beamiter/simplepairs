# SimplePairs

Small Vim9 auto-pairing with smart close, backspace and newline behavior.

The eleven insert-mode keys it maps by default -- `(` `[` `{` `"` `'` `` ` ``
`)` `]` `}` `<BS>` `<CR>` -- are each installed only into a slot that is still
free and whose `<Plug>` target is not already bound, so a key that belongs to
your vimrc or to another plugin is never taken. A completion plugin's `<CR>`
keeps working, and `simplepairs#Enter()` returns a plain `<CR>` while a popup
is visible in any case. `:SimplePairsHealth` lists all eleven keys and says who
holds each one.

Every key has a `<Plug>` target -- `<Plug>(simplepairs-open-paren)`,
`<Plug>(simplepairs-enter)` and so on, defined whether or not the defaults are
installed -- so one key can be moved without giving up the other ten. Set
`g:simplepairs_default_mappings = 0` before loading to install none of them.
`:SimplePairsEnable`, `:SimplePairsDisable` and `:SimplePairsToggle` control
the current buffer.

`g:simplepairs_disabled_filetypes` defaults to help, quickfix, terminal and the
simple* UI buffers. Configuration is type-checked at load and again on each
expression mapping, so a later malformed assignment cannot break insert mode.

Expression mappings inspect only a bounded neighborhood around the cursor, so
pairing remains responsive on minified or generated single-line files.
If an escape-backslash run exceeds that bound, quote pairing fails closed
instead of guessing its parity and inserting a possibly wrong closing quote.
