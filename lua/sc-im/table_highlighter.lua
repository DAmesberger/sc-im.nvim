local H = {}
local U = require('sc-im.utils')

-- Function to search for the next table start asynchronously
local function find_next_table_start_async(start_line, max_lines)
    local num_lines = vim.api.nvim_buf_line_count(0)
    local end_line = math.min(start_line + max_lines - 1, num_lines)
    for line = start_line, end_line do
        local current_line = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1]
        if current_line:match(current_line, "|.*|$") then
            return line
        end
    end
    -- If no more tables found, return nil
    return nil
end

-- Function to find the end of the current table asynchronously
local function find_table_end_async(start_line, max_lines)
    local num_lines = vim.api.nvim_buf_line_count(0)
    local end_line = math.min(start_line + max_lines - 1, num_lines)
    for line = start_line, end_line do
        local current_line = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1]
        if not current_line:match("|.*|$") then
            return line - 1 -- Previous line is the end of the table
        end
    end
    -- If end of buffer reached, return the current line as the end of the table
    return end_line
end

-- Function to process and highlight the table range asynchronously
local function process_and_highlight_table_range(start_line, end_line)
    -- Perform custom processing and highlighting for the table range
    for line = start_line, end_line do
        -- Highlight the line asynchronously
        vim.schedule(function()
            if line == start_line then
                vim.api.nvim_buf_add_highlight(0, -1, 'MarkdownTableHeader', line - 1, 0, -1)
            else
                vim.api.nvim_buf_add_highlight(0, -1, 'MarkdownTableGrid', line - 1, 0, -1)
            end
        end)
    end
end

-- Function to asynchronously update highlighting and continue parsing tables
function H.update_highlighting(start_line, max_lines)
    -- Find the start of the next table asynchronously
    local next_table_start_line = find_next_table_start_async(start_line, max_lines)
    if next_table_start_line then
        -- Find the end of the current table asynchronously
        local table_end_line = find_table_end_async(next_table_start_line, max_lines)
        -- Process and highlight the table range asynchronously
        process_and_highlight_table_range(next_table_start_line, table_end_line)
        -- Continue parsing from the end of the current table asynchronously
        H.update_highlighting(table_end_line + 1, max_lines)
    end
end

return H
