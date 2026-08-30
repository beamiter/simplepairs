.PHONY: check defcompile test mappings nomappings perf

check: defcompile test mappings nomappings perf

defcompile:
	vim -N -u NONE -n -i NONE -es -S tests/defcompile.vim

test:
	vim -N -u NONE -n -i NONE -es -S tests/vim_smoke.vim

# Both of these decide what happens at load time, before any mapping is used,
# so each needs a Vim that has not sourced the plugin yet: the plugin file
# returns early on g:loaded_simplepairs, and g:simplepairs_default_mappings is
# read once.  Hence two targets rather than two more blocks in vim_smoke.vim.
mappings:
	vim -N -u NONE -n -i NONE -es -S tests/vim_mappings.vim

nomappings:
	vim -N -u NONE -n -i NONE -es -S tests/vim_nomappings.vim

perf:
	vim -N -u NONE -n -i NONE -es -S tests/perf.vim
