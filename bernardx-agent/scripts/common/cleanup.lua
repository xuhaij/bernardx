-- BT Script: Cleanup - close CDP connection
local bb = require('blackboard')

local M = {}

function M:Enter(args)
    -- nothing
end

function M:Tick()
    local client = bb.get("cdp_client")
    if client then
        client:close()
        bb.set("cdp_client", nil)
        print("[cleanup] CDP client closed")
    end
    return "success"
end

return M
