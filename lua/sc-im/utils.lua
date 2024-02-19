local U = {}

local A = vim.api

local sc_file_link_patterns = {
    { "^<!--.*%[(.+)%]%((.+)%).*-->$", "<!--[%name%](%link%)-->" },
    { "^%[(.+)%]%((.+)%)$",            "[%name%](%link%)" },
}

function U.validate_link_fmt(idx)
    return idx >= 1 and idx <= #sc_file_link_patterns
end

function U.next_link_fmt(idx)
    if U.validate_link_fmt(idx) then
        return (idx % #sc_file_link_patterns) + 1
    else
        return 1 -- Return the first index if the current index is invalid
    end
end

---Check whether the window is valid
---@param win number Window ID
---@return boolean
function U.is_win_valid(win)
    return win and vim.api.nvim_win_is_valid(win)
end

---Check whether the buffer is valid
---@param buf number Buffer ID
---@return boolean
function U.is_buf_valid(buf)
    return buf and vim.api.nvim_buf_is_loaded(buf)
end

-- Function to check if a path is absolute
function U.is_absolute_path(path)
    if path:sub(1, 1) == "/" then          -- Unix-like absolute path
        return true
    elseif path:match("^[A-Za-z]:\\") then -- Windows absolute path
        return true
    end
    return false
end

function U.make_absolute_path(base_dir, path)
    if not U.is_absolute_path(path) then
        -- Ensure the base_dir ends with a "/"
        if base_dir:sub(-1) ~= "/" then
            base_dir = base_dir .. "/"
        end
        return base_dir .. path
    else
        return path
    end
end

function U.make_relative_path(base_dir, path)
    -- Ensure the base_dir ends with a "/"
    if base_dir:sub(-1) ~= "/" then
        base_dir = base_dir .. "/"
    end

    -- Check if the path starts with base_dir
    if path:sub(1, #base_dir) == base_dir then
        -- Remove the base_dir part from path
        return path:sub(#base_dir + 1)
    else
        -- Path is not a subpath of base_dir; return it as is
        return path
    end
end

-- Function to find the start and end line numbers of the table
function U.find_table_boundaries(cursor_line)
    local line_content = A.nvim_buf_get_lines(0, cursor_line - 1, cursor_line, false)[1]
    local table_top_line = nil

    -- Find the top line of the table
    while cursor_line > 0 and string.match(line_content, "|.*|$") do
        cursor_line = cursor_line - 1
        table_top_line = cursor_line + 1
        if cursor_line > 0 then
            line_content = A.nvim_buf_get_lines(0, cursor_line - 1, cursor_line, false)[1]
        end
    end

    if not table_top_line then
        return nil, nil -- No table found
    end

    -- Find the bottom line of the table
    local table_bottom_line = table_top_line
    while true do
        local lines = A.nvim_buf_get_lines(0, table_bottom_line, table_bottom_line + 1, false)
        if #lines == 0 or not string.match(lines[1], "|.*|$") then
            break
        end
        table_bottom_line = table_bottom_line + 1
    end

    return table_top_line, table_bottom_line
end

-- Function to get the lines of a markdown table as a lua table
function U.get_table_lines(table_top_line, table_bottom_line)
    if not table_top_line or not table_bottom_line then
        return nil -- Invalid input
    end

    local table_lines = A.nvim_buf_get_lines(0, table_top_line - 1, table_bottom_line, false)
    return table_lines
end

function U.parse_markdown_table(file_lines)
    local md_data = {}
    local row_number = 0 -- Initialize row_number

    for _, line in ipairs(file_lines) do
        -- Trim leading and trailing pipes and spaces
        local trimmed_line = line:match("^|%s*(.-)%s*|$")
        if trimmed_line and not trimmed_line:match("^[-:| ]+$") then
            local col_index = 1
            local col_letter = ""
            -- Split the trimmed line at each pipe
            for content in string.gmatch(trimmed_line, "([^|]+)") do
                col_letter = ""
                local n = col_index
                repeat
                    n = n - 1
                    local remainder = n % 26
                    col_letter = string.char(65 + remainder) .. col_letter
                    n = (n - remainder) / 26
                until n == 0

                local cell_id = col_letter .. tostring(row_number)
                -- Trim the content to remove extra spaces
                content = content:match("^%s*(.-)%s*$")
                md_data[cell_id] = content
                col_index = col_index + 1
            end
            row_number = row_number + 1 -- Increment row_number for each data row
        end
    end

    return md_data
end

function U.get_sheet_names(sc_filename)
    local sc_file = io.open(sc_filename, "r")
    local found = false
    local sheet_names = {}
    if not sc_file then
        return "Error: Unable to open SC file."
    end

    for line in sc_file:lines() do
        local sheetname = string.match(line, "newsheet \"([^\"]*)\"")
        if sheetname then
            table.insert(sheet_names, sheetname)
            found = true
        else
            -- newsheet is contiguous, so if we found at least one,
            -- and we find the first line after that not containing one
            -- we can stop searching
            if found then
                return sheet_names
            end
        end
    end
    return sheet_names
end

--
--- Parses an SC (spreadsheet calculator) file and extracts its data into a structured Lua table.
-- The function iterates through each line of the file, identifying and storing information about sheets and cell data.
-- @param sc_filename The path and filename of the SC file to parse.
-- @return current_sheet The name of the last sheet processed in the SC file; returns nil if no sheets are defined.
-- @return sc_data A table structured with sheet names as keys, each containing a sub-table where each key is a cell identifier (e.g., 'A1', 'B2') and its value is a table containing cell type, whether it's a formula, and the cell's content.
--
-- Example of the returned sc_data table:
-- {
--     Sheet1 = {
--         A1 = {"label", false, "Header"},
--         B1 = {"let", false, "100"},
--         C1 = {"let", true, "@sum(A1:B1)"}
--     },
--     Sheet2 = {
--         A1 = {"leftstring", false, "Introduction"},
--         B2 = {"rightstring", false, "Conclusion"}
--     }
-- }
function U.parse_sc_file(sc_filename)
    -- Parse SC file
    local sc_data = {}
    local current_sheet = nil
    local sc_file = io.open(sc_filename, "r")
    if not sc_file then
        return "Error: Unable to open SC file."
    end

    for line in sc_file:lines() do
        local sheetname = string.match(line, "movetosheet \"([^\"]*)\"")
        if sheetname then
            current_sheet = sheetname
            if not sc_data[current_sheet] then
                sc_data[current_sheet] = {}
            end
            sc_data[""] = sheetname
        end

        --local cell_type, cell_id, content = string.match(line, "(%w+) (%w+) = \"([^\"]*)\"")
        local cell_type, cell_id, content = string.match(line, "(%w+) (%w+) =%s*\"?([^\"]*)\"?")

        if cell_type and cell_id and content then
            local is_formula = false
            if cell_type == "let" and string.sub(content, 1, 1) == "@" then
                is_formula = true
            end
            sc_data[current_sheet][cell_id] = { cell_type, is_formula, content }
        end
    end
    sc_file:close()
    return current_sheet, sc_data
end

-- Function to extract .sc name and link from a line
function U.extract_sc_link(line)
    if not line then
        return nil, nil, nil -- Invalid input
    end

    for idx, patternInfo in ipairs(sc_file_link_patterns) do
        local pattern = patternInfo[1]
        local name, file = line:match(pattern)
        if name and file then
            return name, file, idx
        end
    end

    return nil, nil, nil -- No match found
end

function U.create_sc_link(idx, name, link)
    local formatString = sc_file_link_patterns[idx][2]
    -- Replace placeholders with actual name and link
    formatString = formatString:gsub("%%name%%", name)
    formatString = formatString:gsub("%%link%%", link)
    return formatString
end

function U.update_sc_link(link_line, link_name, link_file, link_fmt)
    local sc_link = U.create_sc_link(link_fmt, link_name, link_file)
    A.nvim_buf_set_lines(0, link_line, link_line + 1, false, { sc_link })
end

function U.insert_sc_link(link_line, link_name, link_file, link_fmt)
    local sc_link = U.create_sc_link(link_fmt, link_name, link_file)
    A.nvim_buf_set_lines(0, link_line, link_line, false, { sc_link })
end

-- Function to get the .sc file link from the line below the last line of the table
function U.get_sc_file_from_link(table_bottom_line)
    if not table_bottom_line then
        return nil, nil, nil -- Invalid input
    end

    local sc_link_line = A.nvim_buf_get_lines(0, table_bottom_line, table_bottom_line + 1, false)[1] or ""

    return U.extract_sc_link(sc_link_line)
end

function U.generate_random_file_name()
    math.randomseed(os.time())
    local random = math.random
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end) .. '.sc'
end

function U.get_link_from_cursor_pos()
    local cursor_line = A.nvim_win_get_cursor(0)[1]
    local table_top_line, table_bottom_line = U.find_table_boundaries(cursor_line)

    -- If no table is found, do not proceed
    if not table_top_line or not table_bottom_line then
        vim.notify('No table found', vim.log.levels.INFO)
        return nil, nil, nil
    else
        file_lines = U.get_table_lines(table_top_line, table_bottom_line)
    end

    return table_bottom_line, U.get_sc_file_from_link(table_bottom_line)
end

function U.rename_file(old_path, new_path)
    if vim.fn.filereadable(old_path) == 0 then
        vim.notify('File does not exist', vim.log.levels.ERROR)
        return false
    end

    local success, err = os.rename(old_path, new_path)
    if not success then
        vim.notify('Error renaming file: ' .. err, vim.log.levels.ERROR)
        return false
    end

    return true
end

return U
