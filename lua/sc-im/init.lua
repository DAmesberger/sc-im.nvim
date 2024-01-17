-- luacheck: globals vim

local Table = require('sc-im.table')

local M = {}

local t = Table:new()

---(Optional) Configure the defaults
---@param cfg Config
function M.setup(cfg)
    t:setup(cfg)
end

---Opens the default terminal
function M.open_in_scim()
    t:open_in_scim()
end

return M
