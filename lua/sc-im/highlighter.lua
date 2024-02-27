local H = {}
local U = require('sc-im.utils')


-- Function to link custom highlight groups to theme highlight groups dynamically
local function link_to_theme(group_name, theme_group_name, fallback_color)
    local status, hl = pcall(vim.api.nvim_get_hl_by_name, theme_group_name, true)
    if hl.foreground ~= nil and status == true then
        vim.cmd(string.format("hi! link %s %s", group_name, theme_group_name))
    else
        -- If the theme highlight group doesn't exist or doesn't define a foreground color, use fallback or defaults
        vim.notify(
            string.format("Theme highlight group '%s' not found or doesn't define a foreground color", theme_group_name),
            vim.log.levels.WARN)
        local fg_color = fallback_color or "NONE"
        vim.cmd(string.format("hi! %s guifg=%s", group_name, fg_color))
    end
end

function H.init(cfg)
    -- Define colors for Markdown table syntax highlighting by linking to theme highlight groups or using fallbacks
    -- Header
    link_to_theme("MarkdownTableHeader", "Normal", "#ffff00")          -- Yellow as default
    -- Text Cell
    link_to_theme("MarkdownTableCell", "string", "#ffffff")            -- White as default
    -- Number Cell
    link_to_theme("MarkdownTableNumberCell", "number", "#ff0000")      -- Green as default
    -- Formula Cell
    link_to_theme("MarkdownTableFormulaCell", "identifier", "#00ff00") -- Red as default
    -- Grid
    link_to_theme("MarkdownTableGrid", "string", "#666666")            -- Dark gray as default
    -- Cell changed
    link_to_theme("MarkdownTableDiffCell", "error", "#666666")         -- Dark gray as default

    -- Hook into BufEnter and BufWritePost events to update highlighting and continue parsing
    vim.api.nvim_exec([[
    augroup MarkdownTableHighlight
        autocmd!
        autocmd BufEnter,BufWritePost *.md lua require('sc-im').update_highlighting()
    augroup END
]], false)
end

-- Function to search for the next table start asynchronously
local function find_next_table_start_async(start_line, max_lines)
    local num_lines = vim.api.nvim_buf_line_count(0)
    local end_line = math.min(start_line + max_lines - 1, num_lines)
    for line = start_line, end_line do
        local current_line = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1]
        if current_line:match("|.*|$") then
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
    local table_lines = U.get_table_lines(start_line, end_line)
    local sc_sheet_name, sc_file_path, sc_link_fmt = U.get_sc_file_from_link(end_line)

    local sc_data = U.get_sc_data(sc_file_path, sc_sheet_name)
    local is_different, differences = U.compare(table_lines, sc_data)

    local table_line = 0

    for i, line in ipairs(table_lines) do
        local current_col = 0
        if i == 2 then
            -- formatting line
            vim.schedule(function()
                vim.api.nvim_buf_add_highlight(0, -1, 'MarkdownTableGrid', start_line + i - 2, 0, -1)
            end)
        else
            local cells = U.parse_markdown_table_line(table_line, line)
            local buffer_line = start_line + i - 2

            for _, cell in ipairs(cells) do
                -- Highlight the cell asynchronously
                vim.schedule(function()
                    local highlight_group = 'MarkdownTableCell'
                    local cell_type = sc_data and sc_data[cell.cell_id] and sc_data[cell.cell_id].type
                    local is_formula = sc_data and sc_data[cell.cell_id] and sc_data[cell.cell_id].is_formula

                    if differences and differences[cell.cell_id] then
                        highlight_group = 'MarkdownTableDiffCell'
                    elseif cell_type ~= nil then
                        if cell_type == 'let' then
                            if is_formula then
                                highlight_group = 'MarkdownTableFormulaCell'
                            else
                                highlight_group = 'MarkdownTableNumberCell'
                            end
                        end
                    end
                    vim.api.nvim_buf_add_highlight(0, -1, 'MarkdownTableGrid', buffer_line, current_col,
                        cell.startcol)

                    vim.api.nvim_buf_add_highlight(0, -1, highlight_group, buffer_line, cell.startcol,
                        cell.endcol)
                    current_col = cell.endcol
                end)
            end
            vim.api.nvim_buf_add_highlight(0, -1, 'MarkdownTableGrid', buffer_line, current_col,
                string.len(line))

            -- Highlight the line asynchronously
            -- vim.schedule(function()
            --     if line == start_line then
            --         vim.api.nvim_buf_add_highlight(0, -1, 'MarkdownTableHeader', line - 1, 0, -1)
            --     else
            --         vim.api.nvim_buf_add_highlight(0, -1, 'MarkdownTableGrid', line - 1, 0, -1)
            --     end
            -- end)
            table_line = table_line + 1
        end
    end
end

-- Function to asynchronously update highlighting and continue parsing tables
function H.update_highlighting_with_range(start_line, max_lines)
    -- Find the start of the next table asynchronously
    local next_table_start_line = find_next_table_start_async(start_line, max_lines)
    if next_table_start_line then
        -- Find the end of the current table asynchronously
        local table_end_line = find_table_end_async(next_table_start_line, max_lines)
        -- Process and highlight the table range asynchronously
        process_and_highlight_table_range(next_table_start_line, table_end_line)
        -- Continue parsing from the end of the current table asynchronously
        H.update_highlighting_with_range(table_end_line + 1, max_lines)
    end
end

return H
