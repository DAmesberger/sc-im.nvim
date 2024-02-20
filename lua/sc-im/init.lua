-- luacheck: globals vim

local Table = require('sc-im.table')

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

--- closes floating sc-im
function M.close()
    t:close()
end

return M
