local A = vim.api
local U = require('sc-im.utils')
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
---@field link_name string: Text used for the sc file link (default: 'sc file')
---@field split string: 'floating', 'vertical', 'horizontal' (default 'floating')
---@field float_config FloatConfig: Dimensions of the floating window

---@type Config
local defaults = {
    include_sc_file = true,
    link_name = "table link",
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
function Table:read_from_scim(table_top_line, table_bottom_line, md_file, sc_file, link_name, link_fmt)
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
    if link_name == nil then
        link_name = self.config.link_name
    end
    -- If .sc file should be included, handle the .sc file link
    if self.config.include_sc_file then
        local sc_link_line = table_top_line - 1 + #md_content
        U.update_sc_link(sc_link_line, link_name, sc_file, link_fmt)
    end
end

-- Internal function to open the current table in sc-im
function Table:open_in_scim()
    local file_lines = {}
    local cursor_line = A.nvim_win_get_cursor(0)[1]
    local table_top_line, table_bottom_line = U.find_table_boundaries(cursor_line)

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

            self:read_from_scim(table_top_line, table_bottom_line, md_file, sc_file, sc_link_name, sc_link_fmt)
        end
    })

    -- Start insert mode in the terminal
    vim.cmd('startinsert')
end

function Table:rename_table_file(new_name)
    local cursor_line = A.nvim_win_get_cursor(0)[1]
    local table_top_line, table_bottom_line = U.find_table_boundaries(cursor_line)

    -- If no table is found, do not proceed
    if not table_top_line or not table_bottom_line then
        return vim.notify('No table found', vim.log.levels.INFO)
    else
        file_lines = U.get_table_lines(table_top_line, table_bottom_line)
    end

    -- Check the line below the table for an .sc file link
    local sc_link_name, sc_file_path, sc_link_fmt = U.get_sc_file_from_link(table_bottom_line)

    if not sc_link_name or not sc_file_path then
        return vim.notify('No table link found', vim.log.levels.INFO)
    end

    local dir = vim.fn.expand('%:p:h') .. '/'
    local is_absolute = U.is_absolute_path(new_name)
    local old_fullpath = U.make_absolute_path(dir, sc_file_path)
    local new_fullpath = U.make_absolute_path(dir, new_name)

    if U.rename_file(old_fullpath, new_fullpath) then
        if is_absolute then
            U.update_sc_link(table_bottom_line, sc_link_name, new_name, sc_link_fmt)
        else
            U.update_sc_link(table_bottom_line, sc_link_name, U.make_relative_path(dir, new_name), sc_link_fmt)
        end
    end
end

return Table