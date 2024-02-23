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

function U.make_absolute_path(path)
    local base_dir = vim.fn.expand('%:p:h') .. '/'
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

function U.make_relative_path(path)
    local base_dir = vim.fn.expand('%:p:h') .. '/'
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

function U.parse_markdown_table_line(line_number, line)
    local col_index = 1
    local col_letter = ""
    local last_pipe = 1 -- Start after the first pipe of the original line
    local cells = {}

    for i = 2, #line do                             -- Start from the second character to skip initial pipe
        if line:sub(i, i) == '|' or i == #line then -- Check for pipe or end of line
            local end_position = i - 1
            local content_segment = line:sub(last_pipe + 1, i - 1)
            local content = content_segment:match("^%s*(.-)%s*$") -- Trim spaces

            -- Convert column index to letter for cell ID
            col_letter = ""
            local n = col_index
            repeat
                n = n - 1
                local remainder = n % 26
                col_letter = string.char(65 + remainder) .. col_letter
                n = (n - remainder) / 26
            until n == 0

            local cell_id = col_letter ..
                tostring(line_number)

            -- Add to md_data, set content as nil if the cell is visually empty
            table.insert(cells,
                {
                    cell_id = cell_id,
                    content = (content ~= "" and content or nil),
                    startcol = last_pipe + 1,
                    endcol =
                        end_position
                })

            col_index = col_index + 1
            last_pipe = i -- Move past the pipe position for next cell start
        end
    end
    return cells
end

function U.parse_markdown_table(file_lines)
    local md_data = {}
    local line_number = 0 -- Initialize line_number to track the current line

    for j, line in ipairs(file_lines) do
        -- Skip the second line, assuming it's the formatting line
        if j ~= 2 and string.match(line, "|.*|$") then
            local cells = U.parse_markdown_table_line(line_number, line)
            for _, cell in ipairs(cells) do
                md_data[cell.cell_id] = { content = cell.content }
            end
            line_number = line_number + 1 -- Increment line number at the start of the loop
        end
    end

    return md_data
end

function U.get_sheets(sc_filename)
    local sc_file = io.open(sc_filename, "r")
    local sheet_names = {}
    local current_sheet = nil
    if not sc_file then
        return "Error: Unable to open SC file."
    end

    for line in sc_file:lines() do
        local action, sheetname
        if string.match(line, "^newsheet") then
            action, sheetname = string.match(line, "^(newsheet) \"([^\"]*)\"")
        elseif string.match(line, "^movetosheet") then
            action, sheetname = string.match(line, "^(movetosheet) \"([^\"]*)\"")
        end
        if action and sheetname then
            if action == "newsheet" then
                table.insert(sheet_names, sheetname)
            elseif action == "movetosheet" then
                current_sheet = sheetname
            end
        end
    end

    return current_sheet, sheet_names
end

function U.get_table_under_cursor()
    local table_found = true
    local file_lines = {}
    local cursor_line = A.nvim_win_get_cursor(0)[1]
    local table_top_line, table_bottom_line = U.find_table_boundaries(cursor_line)

    local sc_sheet_name = nil
    local sc_file_path = nil
    local sc_link_fmt = nil

    -- If no table is found
    if not table_top_line or not table_bottom_line then
        -- set defaults for a new table
        table_top_line = cursor_line
        table_bottom_line = cursor_line

        -- lets first check if we find a link to a .sc file
        sc_sheet_name, sc_file_path, sc_link_fmt = U.get_sc_file_from_link(cursor_line - 1)
        if sc_sheet_name and sc_file_path and sc_link_fmt then
            table_top_line, table_bottom_line = U.find_table_boundaries(cursor_line - 1)
            file_lines = U.get_table_lines(table_top_line, table_bottom_line)
            if not table_top_line or not table_bottom_line then
                table_top_line = cursor_line
                table_bottom_line = cursor_line
                table_found = false
            end
        end
    else
        file_lines = U.get_table_lines(table_top_line, table_bottom_line)
        sc_sheet_name, sc_file_path, sc_link_fmt = U.get_sc_file_from_link(table_bottom_line)
    end

    return table_found, table_top_line, table_bottom_line, file_lines, sc_sheet_name, sc_file_path, sc_link_fmt
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
        end

        --local cell_type, cell_id, content = string.match(line, "(%w+) (%w+) = \"([^\"]*)\"")
        local cell_type, cell_id, content = string.match(line, "(%w+) (%w+) =%s*\"?([^\"]*)\"?")

        if cell_type and cell_id and content then
            local is_formula = false
            if cell_type == "let" and tonumber(content) == nil then
                is_formula = true
            end
            sc_data[current_sheet][cell_id] = { type = cell_type, is_formula = is_formula, content = content }
        end
    end
    sc_file:close()
    return current_sheet, sc_data
end

function U.sc_to_md(sc_filename, script)
    local temp_file_base = vim.fn.tempname()
    local md_file = temp_file_base .. '.md'

    if script == nil then
        script = ""
    end

    local sc_file_absolute = U.make_absolute_path(sc_filename)

    local command = 'echo "EXECUTE \\"load ' ..
        sc_file_absolute:gsub('"', '\\"') .. '\n' ..
        script:gsub('"', '\\"') ..
        '\\"\nEXECUTE \\"w! ' .. md_file:gsub('"', '\\"') .. '\\"" | sc-im --nocurses --quit_afterload'

    vim.fn.system(command)

    local md_content = vim.fn.readfile(md_file)

    os.remove(md_file)

    return md_content
end

-- Function to extract .sc name and link from a line
function U.extract_sc_link(line)
    if not line then
        return nil, nil, nil -- Invalid input
    end

    for idx, patternInfo in ipairs(sc_file_link_patterns) do
        local pattern = patternInfo[1]
        local name, file = line:match(pattern)
        if name and file and file:match("%.sc$") then
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

--- Compares the content of the current table with the content of the .sc file and returns the differences
-- @param file_lines string[] The content of the current buffer
--  @param sc_filename string The name of the .sc file
--  @return table[] Differences between the current table and the .sc file { cell_id, sc_cell, md_cell }
-- @return table A table of differences between the current table and the .sc file, indexed by cell_id, each value is a table containing { cell_type, sc_cell_content, md_cell_content }, where `cell_type` is the type of the cell from the .sc file, `sc_cell_content` is the content from the .sc file, and `md_cell_content` is the content from the Markdown table. If there is no corresponding cell in the .sc or Markdown data, the respective field will be nil.
function U.compare(file_lines, sc_filename)
    -- Parse SC file
    local current_sheet, sc_data = U.parse_sc_file(U.make_absolute_path(sc_filename))

    -- Parse Markdown table
    local md_data = U.parse_markdown_table(file_lines)

    -- Compare data
    local checked_cells = {}
    local differences = {}
    local is_different = false

    local function is_equal(cell_type, first_cell, second_cell)
        if cell_type == "let" then
            return tonumber(first_cell) == tonumber(second_cell)
        else
            if first_cell == nil and second_cell == nil then
                return true
            else
                return first_cell == second_cell
            end
        end
    end

    -- iterate sc data
    if sc_data ~= nil and sc_data[current_sheet] ~= nil then
        for cell_id, cell in pairs(sc_data[current_sheet]) do
            if cell.is_formula == false and not is_equal(cell.type, md_data[cell_id].content, cell.content) then
                differences[cell_id] = {
                    type = cell.type,
                    sc_content = cell.content,
                    md_content = md_data[cell_id]
                        .content or nil
                }
                is_different = true
            end
            checked_cells[cell_id] = true
        end

        -- iterate new md data
        for cell_id, cell_info in pairs(md_data) do
            if checked_cells[cell_id] ~= true then
                local num = tonumber(cell_info.content)
                local cell_type = "leftstring"
                if num then
                    cell_type = "let"
                end
                if cell_info.content ~= nil then -- if both are nil it is not a difference
                    differences[cell_id] = { type = cell_type, sc_content = nil, md_content = cell_info.content }
                    is_different = true
                end
            end
        end
    end

    -- Return differences
    return is_different, differences, sc_data
end

function U.diff_to_script(differences)
    local commands = {}

    -- Iterate through all differences
    for cell_id, diff in pairs(differences) do
        -- Determine the command based on the logic provided
        local command = ""
        if diff.md_content ~= nil then
            -- Changes were made to md_cell or new md_cell was added
            if diff.type == "let" then
                -- For numerical values or formulas
                command = string.format("LET %s = %s", cell_id, diff.md_content)
            else
                -- For text with specific alignment
                command = string.format("%s %s = \"%s\"", diff.type:upper(), cell_id, diff.md_content)
            end
        elseif diff.sc_content ~= nil and diff.md_content == nil then
            -- sc_cell exists but md_cell was removed or cleared
            if diff.type == "let" then
                -- Setting numerical cells to an empty value
                command = string.format("LET %s = ", cell_id) -- Assuming '0' as the 'empty' state for numerical values
            else
                -- Setting text cells to an empty string
                command = string.format("%s %s = \"\"", diff.type:upper(), cell_id)
            end
        end

        -- Add the command to the list if one was generated
        if command ~= "" then
            table.insert(commands, command)
        end
    end

    -- Return the list of commands
    return table.concat(commands, "\n")
end

function U.dump(o, indentLevel)
    indentLevel = indentLevel or 0                 -- Set default indent level if none is provided
    local indent = string.rep("    ", indentLevel) -- Define the indentation (4 spaces in this example)

    if type(o) == 'table' then
        local s = '{\n' -- Start with a new line after opening brace
        for k, v in pairs(o) do
            local key = type(k) == 'number' and '[' .. k .. ']' or '["' .. k .. '"]'
            s = s .. indent .. '    ' .. key .. ' = ' .. U.dump(v, indentLevel + 1) .. ',\n'
        end
        return s .. indent .. '}'
    else
        return tostring(o)
    end
end

return U
