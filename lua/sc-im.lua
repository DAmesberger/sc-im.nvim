local M = {}

-- Configuration options
local config = {
    include_sc_file = false,
    link_text = "sc file",
    split = "horizontal",
    float_config = {
        relative = 'editor',
        width = 0.8,
        height = 0.8,
        row = 1,
        col = 1,
        style = 'minimal',
        border = 'single',
    }
}

local sc_file_link_pattern = "%[(.+)%]%((.+)%)"


local function generate_random_file_name()
    math.randomseed(os.time())
    local random = math.random
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end) .. '.sc'
end

-- Function to find the start and end line numbers of the table
local function find_table_boundaries(cursor_line)
    local line_content = vim.api.nvim_buf_get_lines(0, cursor_line - 1, cursor_line, false)[1]
    local table_top_line = nil

    -- Find the top line of the table
    while cursor_line > 0 and string.match(line_content, "|.*|$") do
        cursor_line = cursor_line - 1
        table_top_line = cursor_line + 1
        if cursor_line > 0 then
            line_content = vim.api.nvim_buf_get_lines(0, cursor_line - 1, cursor_line, false)[1]
        end
    end

    if not table_top_line then
        return nil, nil -- No table found
    end

    -- Find the bottom line of the table
    local table_bottom_line = table_top_line
    while true do
        local lines = vim.api.nvim_buf_get_lines(0, table_bottom_line, table_bottom_line + 1, false)
        if #lines == 0 or not string.match(lines[1], "|.*|$") then
            break
        end
        table_bottom_line = table_bottom_line + 1
    end

    return table_top_line, table_bottom_line
end

-- Function to get the lines of a markdown table as a lua table
local function get_table_lines(table_top_line, table_bottom_line)
    if not table_top_line or not table_bottom_line then
        return nil -- Invalid input
    end

    local table_lines = vim.api.nvim_buf_get_lines(0, table_top_line - 1, table_bottom_line, false)
    return table_lines
end

-- Function to extract .sc name and link from a line
local function extract_sc_link(line)
    if not line then
        return nil, nil -- Invalid input
    end

    local name, file = line:match(sc_file_link_pattern)
    return name, file
end

-- Function to get the .sc file link from the line below the last line of the table
local function get_sc_file_from_link(table_bottom_line)
    if not table_bottom_line then
        return nil, nil -- Invalid input
    end

    local sc_link_line = vim.api.nvim_buf_get_lines(0, table_bottom_line, table_bottom_line + 1, false)[1] or ""
    return extract_sc_link(sc_link_line)
end

-- Internal function to read data back from sc-im
local function read_from_scim(table_top_line, table_bottom_line, md_file, sc_file, effective_config)
    -- Read the updated content from the markdown file
    local md_content = vim.fn.readfile(md_file)

    -- Determine the range of lines to replace, excluding the old .sc file link
    local end_line = table_bottom_line
    local next_line = vim.api.nvim_buf_get_lines(0, end_line, end_line + 1, false)[1] or ""
    if next_line:match(sc_file_link_pattern) then
        -- If the next line is an .sc file link, exclude it from the replacement range
        end_line = end_line - 1
    end

    -- Replace the old table content in the buffer, excluding the .sc file link
    vim.api.nvim_buf_set_lines(0, table_top_line - 1, end_line + 1, false, md_content)

    -- If .sc file should be included, handle the .sc file link
    if effective_config.include_sc_file then
        local sc_link_line = table_top_line - 1 + #md_content
        local sc_link = "[" .. effective_config.link_text .. "](" .. sc_file .. ")"
        -- Replace or add the .sc file link
        vim.api.nvim_buf_set_lines(0, sc_link_line, sc_link_line + 1, false, { sc_link })
    end
end

-- Function to check if a path is absolute
local function is_absolute_path(path)
    if path:sub(1, 1) == "/" then          -- Unix-like absolute path
        return true
    elseif path:match("^[A-Za-z]:\\") then -- Windows absolute path
        return true
    end
    return false
end

-- Internal function to open the current table in sc-im
local function open_in_scim(effective_config)
    local table_top_line, table_bottom_line = find_table_boundaries(vim.api.nvim_win_get_cursor(0)[1])

    -- If no table is found, do not proceed
    if not table_top_line or not table_bottom_line then
        print("No table found under the cursor, creating new one.")
        table_top_line = cursor_line
    end

    local file_lines = get_table_lines(table_top_line, table_bottom_line)

    -- Check the line below the table for an .sc file link
    local sc_name, sc_file_path = get_sc_file_from_link(table_bottom_line)

    -- files
    local buffer_dir = vim.fn.expand('%:p:h') .. '/'
    local temp_file_base = vim.fn.tempname()
    local md_file = temp_file_base .. '.md'
    local sc_file = sc_file_path or generate_random_file_name()
    local sc_file_absolute = sc_file

    if not is_absolute_path(sc_file) then
        sc_file_absolute = buffer_dir .. "/" .. sc_file
    end

    local scim_command
    local sc_to_md_command = 'echo "EXECUTE \\"load ' ..
        sc_file_absolute:gsub('"', '\\"') ..
        '\\"\nEXECUTE \\"w! ' .. md_file:gsub('"', '\\"') .. '\\"" | sc-im --nocurses --quit_afterload'

    if not sc_file_path and effective_config.include_sc_file then
        -- No existing .sc file link found, create it from markdown
        vim.fn.writefile(file_lines, md_file)
        local script = 'EXECUTE "load ' ..
            md_file:gsub('"', '\\"') .. '"\nEXECUTE "w! ' .. sc_file_absolute:gsub('"', '\\"') .. '"\n'
        scim_command = 'echo "' .. script:gsub('"', '\\"') .. '" | sc-im'
    else
        -- Existing .sc file link found, use it
        scim_command = 'sc-im ' .. sc_file_absolute:gsub('"', '\\"')
    end


    -- Save the current buffer number
    local original_bufnr = vim.api.nvim_get_current_buf()

    -- Create a new buffer for the terminal
    local term_bufnr = vim.api.nvim_create_buf(true, false)

    -- Open a new split and switch to the terminal buffer
    if effective_config.split == "vertical" then
        vim.cmd('vsplit')
    elseif effective_config.split == "floating" then
        local float_win = vim.api.nvim_open_win(0, true, effective_config.float_config)
    else
        vim.cmd('split')
    end

    vim.api.nvim_win_set_buf(0, term_bufnr)

    -- Run the sc-im command in the new buffer
    vim.fn.termopen(scim_command, {
        on_exit = function()
            -- Run the scim_command and get its output (if needed)
            local command_output = vim.fn.system(sc_to_md_command)

            -- Optionally, you can check the output or handle errors
            if vim.v.shell_error ~= 0 then
                -- TODO not sure why I get a "No such devices or address" error here
                -- but it seems to work anyway
                -- print("Error: " .. command_output)
            end
            vim.api.nvim_buf_delete(term_bufnr, { force = true })

            read_from_scim(table_top_line, table_bottom_line, md_file, sc_file, effective_config)
        end
    })

    -- Start insert mode in the terminal
    vim.cmd('startinsert')
end

-- Public function to setup the plugin
function M.setup(user_config)
    -- Update configuration with user settings
    for k, v in pairs(user_config or {}) do
        config[k] = v
    end
end

-- Public function to open in sc-im
function M.open_in_scim(override_config)
    -- Merge the default config with any overrides
    local effective_config = {}
    for key, value in pairs(config) do
        effective_config[key] = value
    end
    if override_config then
        for key, value in pairs(override_config) do
            effective_config[key] = value
        end
    end

    open_in_scim(effective_config)
end

-- testing interface
function M._testing_interface()
    return {
        find_table_boundaries = find_table_boundaries,
        get_sc_file_from_link = get_sc_file_from_link,
        get_table_lines = get_table_lines,
    }
end

return setmetatable(M, {
    __index = function(_, k)
        -- You can use this to expose internal state or functions if needed
    end,
})
