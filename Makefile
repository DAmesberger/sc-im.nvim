clean:
	nvim --headless --clean -n -c "lua vim.fn.delete('./tests/.deps', 'rf')" +q
	rm docs/demo.cast
	rm docs/demo.svg

test:
	nvim --headless --clean -u tests/test.lua "$(FILE)"

docs: docs/demo.cast docs/demo.svg

docs/demo.cast: docs/demo.yaml
	autocast docs/demo.yaml docs/demo.cast --overwrite

docs/demo.svg: docs/demo.cast
	svg-term --in docs/demo.cast --out docs/demo.svg --no-optimize

format:
	stylua lua/ tests/
