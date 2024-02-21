clean_docs:
	rm -f docs/demo.cast docs/demo.svg

clean_deps:
	nvim --headless --clean -n -c "lua vim.fn.delete('./tests/.deps', 'rf')" +q

clean: clean_docs clean_deps

test:
	nvim --headless --clean -u tests/test.lua "$(FILE)"

docs: docs/demo.cast docs/demo.svg

docs/demo.cast: docs/demo.yaml
	rm -f /tmp/demo.md
	autocast docs/demo.yaml docs/demo.cast --overwrite

docs/demo.svg: docs/demo.cast
	svg-term --in docs/demo.cast --out docs/demo.svg --no-optimize

format:
	stylua lua/ tests/
