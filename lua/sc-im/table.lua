local A = vim.api
local U = require('sc-im.utils')

local unpack = table.unpack or unpack

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
---@field update_sc_from_md boolean: if true, the sc file is updated from detected changes in markdown (default: true)
---@field split string: 'floating', 'vertical', 'horizontal' (default 'floating')
---@field float_config FloatConfig: Dimensions of the floating window

---@type Config
local defaults = {
    ft = 'scim',
    include_sc_file = true,
    update_sc_from_md = true,
    link_fmt = 1,
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

local function check_sc_im()
    -- Check if sc-im is executable
    if vim.fn.executable('sc-im') == 0 then
        -- sc-im is not found
        vim.api.nvim_err_writeln("sc-im is not installed or not in PATH.")
        return false
    else
        -- sc-im is found, try to get its version
        local version_command = 'sc-im --version'
        local major, minor, patch = vim.fn.systemlist(version_command)[1]:match(".*version (%d+)%.(%d+)%.(%d+).*")

        if not major or not minor or not patch then
            vim.api.nvim_err_writeln("Failed to get sc-im version.")
            return false
        else
            if tonumber(major) < 1 and (tonumber(minor) < 8 or tonumber(patch) < 3) then
                vim.api.nvim_err_writeln("sc-im version 0.8.3 or higher is required.")
                return false
            end
            return true
        end
    end
end

function Table:new()
    check_sc_im()
    return setmetatable({
        win = nil,
        buf = nil,
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

    if not U.validate_link_fmt(self.config.link_fmt) then
        vim.notify('sc-im: Invalid link format provided', vim.log.levels.ERROR)
        self.config.link_fmt = 1
    end

    return self
end

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

-- Internal function to read data back from sc-im
function Table:read_from_scim(table_top_line, table_bottom_line, add_link, md_file, sc_file, sc_file_absolute, link_fmt)
    -- Read the updated content from the markdown file
    local md_content = vim.fn.readfile(md_file)

    -- Determine the range of lines to replace, excluding the old .sc file link
    local end_line = table_bottom_line
    local next_line = A.nvim_buf_get_lines(0, end_line, end_line + 1, false)[1] or ""

    -- Replace the old table content in the buffer, excluding the .sc file link
    A.nvim_buf_set_lines(0, table_top_line - 1, end_line + 1, false, md_content)

    if link_fmt == nil then
        link_fmt = self.config.link_fmt
    end

    local current_sheet, sheet_names = U.get_sheets(sc_file_absolute)

    -- If .sc file should be included, handle the .sc file link
    if add_link then
        local sc_link_line = table_top_line - 1 + #md_content
        U.insert_sc_link(sc_link_line, current_sheet, sc_file, link_fmt)
    end
end

--- Compares the content of the current table with the content of the .sc file and returns the differences
-- @param file_lines string[] The content of the current buffer
--  @param sc_filename string The name of the .sc file
--  @return table[] Differences between the current table and the .sc file { cell_id, sc_cell, md_cell }
-- @return table A table of differences between the current table and the .sc file, indexed by cell_id, each value is a table containing { cell_type, sc_cell_content, md_cell_content }, where `cell_type` is the type of the cell from the .sc file, `sc_cell_content` is the content from the .sc file, and `md_cell_content` is the content from the Markdown table. If there is no corresponding cell in the .sc or Markdown data, the respective field will be nil.
function Table:compare(file_lines, sc_filename)
    -- Parse SC file
    local current_sheet, sc_data = U.parse_sc_file(sc_filename)

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
            return first_cell == second_cell
        end
    end

    -- iterate sc data
    if sc_data ~= nil and sc_data[current_sheet] ~= nil then
        for cell_id, cell_details in pairs(sc_data[current_sheet]) do
            local cell_type, is_formula, cell_content = unpack(cell_details)
            if is_formula == false and not is_equal(cell_type, md_data[cell_id], cell_content) then
                differences[cell_id] = { cell_type, cell_content, md_data[cell_id] or nil }
                is_different = true
            end
            checked_cells[cell_id] = true
        end

        -- iterate new md data
        for cell_id, cell_content in pairs(md_data) do
            if checked_cells[cell_id] ~= true then
                local num = tonumber(cell_content)
                local cell_type = "leftstring"
                if num then
                    cell_type = "let"
                end
                differences[cell_id] = { cell_type, nil, cell_content }
                is_different = true
            end
        end
    end

    -- Return differences
    return is_different, differences
end

function Table:diff_to_script(differences)
    local commands = {}

    -- Iterate through all differences
    for cell_id, diff in pairs(differences) do
        local cell_type, sc_cell_content, md_cell_content = unpack(diff)

        -- Determine the command based on the logic provided
        local command = ""
        if md_cell_content ~= nil then
            -- Changes were made to md_cell or new md_cell was added
            if cell_type == "let" then
                -- For numerical values or formulas
                command = string.format("LET %s = %s", cell_id, md_cell_content)
            else
                -- For text with specific alignment
                command = string.format("%s %s = \"%s\"", cell_type:upper(), cell_id, md_cell_content)
            end
        elseif sc_cell_content ~= nil and md_cell_content == nil then
            -- sc_cell exists but md_cell was removed or cleared
            if cell_type == "let" then
                -- Setting numerical cells to an empty value
                command = string.format("LET %s = ", cell_id) -- Assuming '0' as the 'empty' state for numerical values
            else
                -- Setting text cells to an empty string
                command = string.format("%s %s = \"\"", cell_type:upper(), cell_id)
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

-- Internal function to open the current table in sc-im
function Table:open_in_scim(add_link)
    local file_lines = {}
    local cursor_line = A.nvim_win_get_cursor(0)[1]
    local table_top_line, table_bottom_line = U.find_table_boundaries(cursor_line)

    if add_link == nil then
        add_link = self.config.include_sc_file
    end

    -- If no table is found, do not proceed
    if not table_top_line or not table_bottom_line then
        --print("No table found under the cursor, creating new one.")
        table_top_line = cursor_line
        table_bottom_line = cursor_line
    else
        file_lines = U.get_table_lines(table_top_line, table_bottom_line)
    end


    -- Check the line below the table for an .sc file link
    local sc_link_name, sc_file_path, sc_link_fmt = U.get_sc_file_from_link(table_bottom_line)

    -- files
    local buffer_dir = vim.fn.expand('%:p:h') .. '/'
    local temp_file_base = vim.fn.tempname()
    local md_file = temp_file_base .. '.md'
    local sc_file = sc_file_path or U.generate_random_file_name()
    local sc_file_absolute = U.make_absolute_path(buffer_dir, sc_file)

    local scim_command
    local sc_to_md_command = 'echo "EXECUTE \\"load ' ..
        sc_file_absolute:gsub('"', '\\"') ..
        '\\"\nEXECUTE \\"w! ' .. md_file:gsub('"', '\\"') .. '\\"" | sc-im --nocurses --quit_afterload'

    local changes = ""
    if self.config.update_sc_from_md then
        local is_different, differences = self:compare(file_lines, sc_file_absolute)
        if is_different == true then
            print('it is different')
            print(dump(differences))
            changes = self:diff_to_script(differences):gsub('"', '\\"') .. '\n' .. "RECALC"
        end
    end

    if not sc_file_path and add_link then
        -- No existing .sc file link found, create it from markdown
        vim.fn.writefile(file_lines, md_file)
        local script = 'EXECUTE "load ' ..
            md_file:gsub('"', '\\"') .. '"\nEXECUTE "w! ' .. sc_file_absolute:gsub('"', '\\"') .. '\n' .. changes
        scim_command = 'echo "' .. script:gsub('"', '\\"') .. '" | sc-im'
    else
        -- Existing .sc file link found, use it
        scim_command = 'sc-im ' .. sc_file_absolute:gsub('"', '\\"')
        if changes ~= "" then
            scim_command = 'echo "' .. changes .. '" | ' .. scim_command
        end
    end

    -- local _original_bufnr = vim.api.nvim_get_current_buf()

    -- Create a new buffer for the terminal
    local term_bufnr = vim.api.nvim_create_buf(true, false)

    -- Open a new split and switch to the terminal buffer
    if self.config.split == "vertical" then
        vim.cmd('vsplit')
        vim.api.nvim_win_set_buf(0, term_bufnr)
    elseif self.config.split == "floating" then
        local win_config = self:get_float_config()
        local float_win = vim.api.nvim_open_win(term_bufnr, true, win_config)
        -- Set winhighlight to use the Normal highlight group
        A.nvim_win_set_option(float_win, 'winhl', ('Normal:%s'):format(self.config.float_config.hl))
        A.nvim_win_set_option(float_win, 'winblend', self.config.float_config.blend)

        A.nvim_win_set_option(float_win, 'number', false)
        A.nvim_win_set_option(float_win, 'relativenumber', false)
        A.nvim_win_set_option(float_win, 'signcolumn', 'no')

        A.nvim_buf_set_option(term_bufnr, 'filetype', self.config.ft)

        self.win = float_win
        self.buf = term_bufnr
    else
        vim.cmd('split')
        vim.api.nvim_win_set_buf(0, term_bufnr)
    end


    -- Run the sc-im command in the new buffer
    vim.fn.termopen(scim_command, {
        on_exit = function()
            -- Run the scim_command and get its output (if needed)
            local _ = vim.fn.system(sc_to_md_command)

            self.win = nil

            --if vim.v.shell_error ~= 0 then
            -- TODO not sure why I get a "No such devices or address" error here
            -- but it seems to work anyway
            -- print("Error: " .. command_output)
            --end
            if U.is_buf_valid(self.buf) then
                vim.api.nvim_buf_delete(self.buf, { force = true })
            end
            self.buf = nil

            self:read_from_scim(table_top_line, table_bottom_line, add_link, md_file, sc_file, sc_file_absolute,
                sc_link_fmt)
        end
    })

    -- Start insert mode in the terminal
    vim.cmd('startinsert')
end

function Table:toggle_table_link_fmt()
    local sc_link_line, sc_link_name, sc_file_path, sc_link_fmt = U.get_link_from_cursor_pos()

    if sc_link_name and sc_file_path and sc_link_fmt then
        sc_link_fmt = U.next_link_fmt(sc_link_fmt)
        U.update_sc_link(sc_link_line, sc_link_name, sc_file_path, sc_link_fmt)
    end
end

function Table:rename_table_file(new_name)
    local sc_link_line, sc_link_name, sc_file_path, sc_link_fmt = U.get_link_from_cursor_pos()

    if not sc_link_name or not sc_file_path then
        return vim.notify('No table link found', vim.log.levels.INFO)
    end
    --
    -- If new_name is nil, prompt for input
    if new_name == nil then
        new_name = vim.fn.input('New name: ', sc_file_path or '')
    end

    -- Check if the user has provided a new name
    if new_name == '' or new_name == nil then
        return vim.notify('No new name provided', vim.log.levels.INFO)
    end

    local dir = vim.fn.expand('%:p:h') .. '/'
    local is_absolute = U.is_absolute_path(new_name)
    local old_fullpath = U.make_absolute_path(dir, sc_file_path)
    local new_fullpath = U.make_absolute_path(dir, new_name)

    if U.rename_file(old_fullpath, new_fullpath) then
        if is_absolute then
            U.update_sc_link(sc_link_line, sc_link_name, new_name, sc_link_fmt)
        else
            U.update_sc_link(sc_link_line, sc_link_name, U.make_relative_path(dir, new_name), sc_link_fmt)
        end
    end
end

function Table:close()
    if self.win and vim.api.nvim_win_is_valid(self.win) then
        A.nvim_win_close(self.win, {})

        self.win = nil
    end
    if self.buf and vim.api.nvim_buf_is_loaded(self.buf) then
        A.nvim_buf_delete(self.buf, { force = true })
    end
end

return Table
