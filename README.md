# SimplePairs

Small Vim9 auto-pairing with smart close, backspace and newline behavior.
The public expression functions are intentionally composable with completion
plugins; for example, use `simplecc#SelectEnterKey()` while a popup is visible
and `simplepairs#Enter()` otherwise.

Set `g:simplepairs_default_mappings = 0` before loading to install no insert
maps. `:SimplePairsEnable`, `:SimplePairsDisable` and `:SimplePairsToggle`
control the current buffer.

`g:simplepairs_disabled_filetypes` defaults to help, quickfix, terminal and the
simple* UI buffers. Configuration is type-checked at load and again on each
expression mapping, so a later malformed assignment cannot break insert mode.

Expression mappings inspect only a bounded neighborhood around the cursor, so
pairing remains responsive on minified or generated single-line files.
If an escape-backslash run exceeds that bound, quote pairing fails closed
instead of guessing its parity and inserting a possibly wrong closing quote.
