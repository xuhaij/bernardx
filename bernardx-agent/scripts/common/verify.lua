-- BT Script: Check playground verification API.
-- Calls /verify/:scenarioId and sets task_done on success.
-- Always returns success (does not block the tree).
local bb = require('blackboard')
local json = require('json')

local M = {}

function M:Enter(args) end

function M:Tick()
    -- Auto-detect: check playground verify API
    local scenario_id = bb.get("scenario_id")
    local playground_url = bb.get("playground_url")
    if scenario_id and playground_url then
        local http = require('http')
        local verify_url = playground_url .. "/verify/" .. scenario_id
        local status, body, req_err = http.get(verify_url)
        if not req_err and status and body then
            local pok, data = pcall(json.decode, body)
            if pok and data then
                if data.passed then
                    print("[verify] PASSED: " .. (data.message or ""))
                    bb.set("task_done", true)
                else
                    print("[verify] NOT YET: " .. (data.message or ""))
                end
            end
        end
    else
        print("[verify] No scenario_id/playground_url configured")
    end

    return "success"
end

return M
