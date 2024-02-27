local Table = require('sc-im.table')
local U = require('sc-im.utils')

local t = Table:new()

describe("find_table_boundaries", function()
    local find_table_boundaries -- assuming this is the function you want to test

    before_each(function()
        -- Set up a new buffer with a markdown table
        vim.cmd('enew') -- open a new buffer
        local lines = {
            "Some text",
            "| Header1 | Header2 |",
            "|---------|---------|",
            "| Row1    | Data1   |",
            "| Row2    | Data2   |",
            "[link text](c7933a1a-7cdf-4514-92f0-672476c845d5.sc)"
        }
        vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    end)

    it("detects the correct boundaries of a table", function()
        -- Place cursor on the table (e.g., on the third line)
        vim.api.nvim_win_set_cursor(0, { 3, 0 })

        -- Call your function
        local top, bottom = U.find_table_boundaries(vim.api.nvim_win_get_cursor(0)[1])

        -- Assert the boundaries are correct
        assert.are.same(2, top)
        assert.are.same(5, bottom)
    end)

    it("get table lines", function()
        -- Place cursor on the table (e.g., on the third line)
        vim.api.nvim_win_set_cursor(0, { 3, 0 })

        -- Call your function
        local top, bottom = U.find_table_boundaries(vim.api.nvim_win_get_cursor(0)[1])
        local lines = U.get_table_lines(top, bottom)

        assert.are.same(#lines, 4)
        assert.are.same(lines[1], "| Header1 | Header2 |")
        assert.are.same(lines[2], "|---------|---------|")
        assert.are.same(lines[3], "| Row1    | Data1   |")
        assert.are.same(lines[4], "| Row2    | Data2   |")
    end)

    it("detects the sc file link", function()
        -- Place cursor on the table (e.g., on the third line)
        vim.api.nvim_win_set_cursor(0, { 3, 0 })

        -- Call your function
        local top, bottom = U.find_table_boundaries(vim.api.nvim_win_get_cursor(0)[1])
        local name, path = U.get_sc_file_from_link(bottom)

        -- Assert the boundaries are correct
        assert.are.same("link text", name)
        assert.are.same("c7933a1a-7cdf-4514-92f0-672476c845d5.sc", path)
    end)
end)

describe("compare", function()
    it("get sheets", function()
        current_sheet, sheets = U.get_sheets("tests/data/test2.sc")
        assert.are.same(current_sheet, "Sheet1")
        assert.are.same(sheets[1], "Sheet1")
        assert.are.same(sheets[2], "Sheet2")
    end)
end)

describe("compare", function()
    -- see if the file exists
    local function file_exists(file)
        local f = io.open(file, "rb")
        if f then f:close() end
        return f ~= nil
    end

    -- get all lines from a file, returns an empty
    -- list/table if the file does not exist
    local function lines_from(file)
        if not file_exists(file) then return {} end
        local lines = {}
        for line in io.lines(file) do
            lines[#lines + 1] = line
        end
        return lines
    end

    it("compare text", function()
        local lines = lines_from("tests/data/test1.md")
        local table_lines = U.get

        local current_sheet, sc_data = U.parse_sc_file(U.make_absolute_path("tests/data/test1.sc"))
        local is_different, result = U.compare(lines, sc_data)

        assert.are.same(is_different, true)

        assert.are.same(result["A2"].sc_content, "test 3")
        assert.are.same(result["A2"].md_content, "test 3a")

        assert.are.same(result["A4"].sc_content, nil)
        assert.are.same(result["A4"].md_content, "new line")
    end)
end)

describe("table parsing", function()
    it("parse markdown table", function()
        local lines = {
            "| Header1 | Header2 |",
            "|---------|---------|",
            "| Row1    | Data1   |",
            "| Row2    | Data2   |",
            "|         | Data3   |",
        }

        local md_data = U.parse_markdown_table(lines)

        assert.are.same({ content = 'Header1' }, md_data['A0'])
        assert.are.same({ content = 'Header2' }, md_data['B0'])
        assert.are.same({ content = 'Row1' }, md_data['A1'])
        assert.are.same({ content = 'Data1' }, md_data['B1'])
        assert.are.same({ content = 'Row2' }, md_data['A2'])
        assert.are.same({ content = 'Data2' }, md_data['B2'])
        assert.are.same({ content = nil }, md_data['A3'])
        assert.are.same({ content = 'Data3' }, md_data['B3'])

        -- assert.are.same({ content = 'Header1', start = 2, ["end"] = 10 }, md_data['A0'])
        -- assert.are.same({ content = 'Header2', start = 12, ["end"] = 20 }, md_data['B0'])
        -- assert.are.same({ content = 'Row1', start = 2, ["end"] = 10 }, md_data['A1'])
        -- assert.are.same({ content = 'Data1', start = 12, ["end"] = 20 }, md_data['B1'])
        -- assert.are.same({ content = 'Row2', start = 2, ["end"] = 10 }, md_data['A2'])
        -- assert.are.same({ content = 'Data2', start = 12, ["end"] = 20 }, md_data['B2'])
        -- assert.are.same({ content = nil, start = 2, ["end"] = 10 }, md_data['A3'])
        -- assert.are.same({ content = 'Data3', start = 12, ["end"] = 20 }, md_data['B3'])
    end)
end)
