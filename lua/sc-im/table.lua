local A = vim.api

--
---@alias WinId number Floating Window's ID

---@class Table
---@field win WinId
local Table = {}


---@class FloatConfig - Every field inside the dimensions should be b/w `0` to `1`
---@field height number: Height of the floating window (default: `0.8`)
---@field width number: Width of the floating window (default: `0.8`)
---@field style string: default 'minimal'
---@field border string: defalut'single'
---@field hl string: Highlight group for the terminal buffer (default: `Normal`)
---@field blend number: Transparency of the floating window (default: `true`)

---@class Config
---@field include_sc_file boolean: if true, the sc file is linked below the table (default: true)
---@field link_text string: Text used for the sc file link (default: 'sc file')
---@field split string: 'floating', 'vertical', 'horizontal' (default 'floating')
---@field float_config FloatConfig: Dimensions of the floating window

---@type Config
local defaults = {
    include_sc_file = true,
    link_text = "sc file",
    split = "floating",
    float_config = {
        height = 0.9,
        width = 0.9,
        style = 'minimal',
        border = 'single',
        hl = 'Normal',
        blend = 0
    }
}

function Table:new()
    return setmetatable({
        win = nil,
        config = defaults,
    }, { __index = self })
end

---Term:setup overrides the terminal windows configuration ie. dimensions
---@param cfg Config
---@return Table
function Table:setup(cfg)
    if not cfg then
        return vim.notify('sc-im: setup() is optional. Please remove it!', vim.log.levels.WARN)
    end

    self.config = vim.tbl_deep_extend('force', self.config, cfg)

    return self
end

local sc_file_link_pattern = "%[(.+)%]%((.+)%)"

function Table:get_float_config()
    local columns = vim.o.columns
    local lines = vim.o.lines

    local width = self.config.float_config.width
    local height = self.config.float_config.height

    if width < 1 then
        width = math.floor(columns * width)
    end

    if height < 1 then
        height = math.floor(lines * height)
    end

    return {
        relative = 'editor',
        width = width,
        height = height,
        col = math.min((vim.o.columns - width) / 2),
        row = math.min((vim.o.lines - height) / 2 - 1),
        style = self.config.float_config.style or 'minimal',
        border = self.config.float_config.border or 'single',
    }
end

function Table:generate_random_file_name()
    math.randomseed(os.time())
    local random = math.random
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end) .. '.sc'
end

-- Function to find the start and end line numbers of the table
function Table:find_table_boundaries(cursor_line)
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
function Table:get_table_lines(table_top_line, table_bottom_line)
    if not table_top_line or not table_bottom_line then
        return nil -- Invalid input
    end

    local table_lines = A.nvim_buf_get_lines(0, table_top_line - 1, table_bottom_line, false)
    return table_lines
end

-- Function to extract .sc name and link from a line
function Table:extract_sc_link(line)
    if not line then
        return nil, nil -- Invalid input
    end

    local name, file = line:match(sc_file_link_pattern)
    return name, file
end

-- Function to get the .sc file link from the line below the last line of the table
function Table:get_sc_file_from_link(table_bottom_line)
    if not table_bottom_line then
        return nil, nil -- Invalid input
    end

    local sc_link_line = A.nvim_buf_get_lines(0, table_bottom_line, table_bottom_line + 1, false)[1] or ""

    return self:extract_sc_link(sc_link_line)
end

-- Internal function to read data back from sc-im
function Table:read_from_scim(table_top_line, table_bottom_line, md_file, sc_file)
    -- Read the updated content from the markdown file
    local md_content = vim.fn.readfile(md_file)

    -- Determine the range of lines to replace, excluding the old .sc file link
    local end_line = table_bottom_line
    local next_line = A.nvim_buf_get_lines(0, end_line, end_line + 1, false)[1] or ""
    if next_line:match(sc_file_link_pattern) then
        -- If the next line is an .sc file link, exclude it from the replacement range
        end_line = end_line - 1
    end

    -- Replace the old table content in the buffer, excluding the .sc file link
    A.nvim_buf_set_lines(0, table_top_line - 1, end_line + 1, false, md_content)

    -- If .sc file should be included, handle the .sc file link
    if self.config.include_sc_file then
        local sc_link_line = table_top_line - 1 + #md_content
        local sc_link = "[" .. self.config.link_text .. "](" .. sc_file .. ")"
        -- Replace or add the .sc file link
        A.nvim_buf_set_lines(0, sc_link_line, sc_link_line + 1, false, { sc_link })
    end
end

-- Function to check if a path is absolute
function Table:is_absolute_path(path)
    if path:sub(1, 1) == "/" then          -- Unix-like absolute path
        return true
    elseif path:match("^[A-Za-z]:\\") then -- Windows absolute path
        return true
    end
    return false
end

-- Internal function to open the current table in sc-im
function Table:open_in_scim()
    local file_lines = {}
    local cursor_line = A.nvim_win_get_cursor(0)[1]
    local table_top_line, table_bottom_line = self:find_table_boundaries(cursor_line)

    -- If no table is found, do not proceed
    if not table_top_line or not table_bottom_line then
        print("No table found under the cursor, creating new one.")
        table_top_line = cursor_line
        table_bottom_line = cursor_line
    else
        file_lines = self:get_table_lines(table_top_line, table_bottom_line)
    end


    -- Check the line below the table for an .sc file link
    local _, sc_file_path = self:get_sc_file_from_link(table_bottom_line)

    -- files
    local buffer_dir = vim.fn.expand('%:p:h') .. '/'
    local temp_file_base = vim.fn.tempname()
    local md_file = temp_file_base .. '.md'
    local sc_file = sc_file_path or self:generate_random_file_name()
    local sc_file_absolute = sc_file

    if not self:is_absolute_path(sc_file) then
        sc_file_absolute = buffer_dir .. "/" .. sc_file
    end

    local scim_command
    local sc_to_md_command = 'echo "EXECUTE \\"load ' ..
        sc_file_absolute:gsub('"', '\\"') ..
        '\\"\nEXECUTE \\"w! ' .. md_file:gsub('"', '\\"') .. '\\"" | sc-im --nocurses --quit_afterload'

    if not sc_file_path and self.config.include_sc_file then
        -- No existing .sc file link found, create it from markdown
        vim.fn.writefile(file_lines, md_file)
        local script = 'EXECUTE "load ' ..
            md_file:gsub('"', '\\"') .. '"\nEXECUTE "w! ' .. sc_file_absolute:gsub('"', '\\"') .. '"\n'
        scim_command = 'echo "' .. script:gsub('"', '\\"') .. '" | sc-im'
    else
        -- Existing .sc file link found, use it
        scim_command = 'sc-im ' .. sc_file_absolute:gsub('"', '\\"')
    end


    -- local _original_bufnr = vim.api.nvim_get_current_buf()

    -- Create a new buffer for the terminal
    local term_bufnr = vim.api.nvim_create_buf(true, false)

    -- Open a new split and switch to the terminal buffer
    if self.config.split == "vertical" then
        vim.cmd('vsplit')
    elseif self.config.split == "floating" then
        local win_config = self:get_float_config()
        local float_win = vim.api.nvim_open_win(0, true, win_config)
        -- Set winhighlight to use the Normal highlight group
        A.nvim_win_set_option(float_win, 'winhl', ('Normal:%s'):format(self.config.float_config.hl))
        A.nvim_win_set_option(float_win, 'winblend', self.config.float_config.blend)
    else
        vim.cmd('split')
    end

    vim.api.nvim_win_set_buf(0, term_bufnr)

    -- Run the sc-im command in the new buffer
    vim.fn.termopen(scim_command, {
        on_exit = function()
            -- Run the scim_command and get its output (if needed)
            local _ = vim.fn.system(sc_to_md_command)

            --if vim.v.shell_error ~= 0 then
            -- TODO not sure why I get a "No such devices or address" error here
            -- but it seems to work anyway
            -- print("Error: " .. command_output)
            --end
            vim.api.nvim_buf_delete(term_bufnr, { force = true })

            self:read_from_scim(table_top_line, table_bottom_line, md_file, sc_file)
        end
    })

    -- Start insert mode in the terminal
    vim.cmd('startinsert')
end

return Table
