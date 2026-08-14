# SimplePairs

Small Vim9 auto-pairing with smart close, backspace and newline behavior.
The public expression functions are intentionally composable with completion
plugins; for example, use `simplecc#SelectEnterKey()` while a popup is visible
and `simplepairs#Enter()` otherwise.

Set `g:simplepairs_default_mappings = 0` before loading to install no insert
maps. `:SimplePairsEnable`, `:SimplePairsDisable` and `:SimplePairsToggle`
control the current buffer.
