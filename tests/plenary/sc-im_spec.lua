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

    local function dump(o)
        if type(o) == 'table' then
            local s = '{ '
            for k, v in pairs(o) do
                if type(k) ~= 'number' then k = '"' .. k .. '"' end
                s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
            end
            return s .. '} '
        else
            return tostring(o)
        end
    end

    it("compare text", function()
        local lines = lines_from("tests/data/test1.md")
        local result = t:compare(lines, "tests/data/test1.sc")
        -- print(dump(result))

        assert.are.same(result["A2"][1], "test 3")
        assert.are.same(result["A2"][2], "test 3a")

        assert.are.same(result["A4"][1], nil)
        assert.are.same(result["A4"][2], "new line")

        assert.are.same(result["B4"][1], nil)
        assert.are.same(result["B4"][2], "")
    end)
end)
