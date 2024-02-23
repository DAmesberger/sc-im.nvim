-- luacheck: globals vim

local Table = require('sc-im.table')
local H = require('sc-im.table_highlighter')

local M = {}

local t = Table:new()

---(Optional) Configure the defaults
---@param cfg Config
function M.setup(cfg)
    t:setup(cfg)
end

---Opens table under the cursor in sc-im
function M.open_in_scim(add_link)
    t:open_in_scim(add_link)
end

--- Toggle the table link format
function M.toggle()
    t:toggle_table_link_fmt()
end

--- Rename the current table file
function M.rename(new_file)
    t:rename_table_file(new_file)
end

function M.update(save_sc)
    t:update_table(save_sc)
end

function M.show_changes()
    t:show_changes()
end

--- closes floating sc-im
function M.close()
    t:close()
end

function M.update_highlighting(start_line, max_buf)
    print("update_highlighting")
    H.update_highlighting(start_line, max_buf)
end

-- Function to link custom highlight groups to theme highlight groups dynamically
local function link_to_theme(group_name, theme_group_name, fallback_color)
    local hl = vim.api.nvim_get_hl_by_name(theme_group_name, true)
    if hl.foreground ~= nil then
        vim.cmd(string.format("hi! link %s %s", group_name, theme_group_name))
    else
        -- If the theme highlight group doesn't exist or doesn't define a foreground color, use fallback or defaults
        local fg_color = fallback_color or "NONE"
        vim.cmd(string.format("hi! %s guifg=%s", group_name, fg_color))
    end
end

-- Define colors for Markdown table syntax highlighting by linking to theme highlight groups or using fallbacks
-- Header
link_to_theme("MarkdownTableHeader", "Normal", "#ffff00")        -- Yellow as default
-- Text Cell
link_to_theme("MarkdownTableCell", "Normal", "#ffffff")          -- White as default
-- Number Cell
link_to_theme("MarkdownTableNumberCell", "Number", "#00ff00")    -- Green as default
-- Formula Cell
link_to_theme("MarkdownTableFormulaCell", "Function", "#ff0000") -- Red as default
-- Grid
link_to_theme("MarkdownTableGrid", "CursorLine", "#444444")      -- Dark gray as default

-- Hook into BufEnter and BufWritePost events to update highlighting and continue parsing
-- vim.api.nvim_exec([[
--     augroup MarkdownTableHighlight
--         autocmd!
--         autocmd BufEnter,BufWritePost *.md lua require('sc-im').update_highlighting(1, 100) -- 100 is the configurable max amount of lines
--     augroup END
-- ]], false)

return M
