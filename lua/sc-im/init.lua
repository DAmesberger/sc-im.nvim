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
function M.open_in_scim()
    t:open_in_scim()
end

function M.rename(new_file)
    t:rename_table_file(new_file)
end

return M
