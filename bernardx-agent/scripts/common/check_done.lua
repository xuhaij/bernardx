-- BT Script: Check if loop should end. Returns success when task is done.
local bb = require('blackboard')

local M = {}

function M:Enter(args) end

function M:Tick()
    local done = bb.get("task_done")
    if done then
        print("[check_done] Task completed, exiting loop")
        return "success"
    end
    return "failure"
end

return M
