.PHONY: check defcompile test perf

check: defcompile test perf

defcompile:
	vim -N -u NONE -n -es -S tests/defcompile.vim

test:
	vim -N -u NONE -n -es -S tests/vim_smoke.vim

perf:
	vim -N -u NONE -n -es -S tests/perf.vim
