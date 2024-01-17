clean:
	nvim --headless --clean -n -c "lua vim.fn.delete('./tests/.deps', 'rf')" +q
test:
	nvim --headless --clean -u tests/test.lua "$(FILE)"
format:
	stylua lua/ tests/
