local U = {}

local A = vim.api

local sc_file_link_patterns = {
    { "^<!--.*%[(.+)%]%((.+)%).*-->$", "<!--[%name%](%link%)-->" },
    { "^%[(.+)%]%((.+)%)$",            "[%name%](%link%)" },
}


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

-- Function to get the .sc file link from the line below the last line of the table
function U.get_sc_file_from_link(table_bottom_line)
    if not table_bottom_line then
        return nil, nil -- Invalid input
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
