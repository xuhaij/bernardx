--- Service Worker 操控模块
local M = {}

local cdp_wrapper = nil

local function ensureWrapper()
    if not cdp_wrapper then
        cdp_wrapper = require("android.cdp_wrapper")
    end
    return cdp_wrapper
end

function M.init(timeout)
    local cw = ensureWrapper()
    local ok = cw.ensureInit(timeout or 10000)
    if not ok then return false end
    cw.enableServiceWorker()
    return true
end

---@return table[] workers
function M.listAll()
    local cw = ensureWrapper()
    local targets = cw.workerTargets()
    local workers = {}
    for _, t in ipairs(targets) do
        table.insert(workers, {
            targetId = t.targetId,
            type = t.type,
            title = t.title or "",
            url = t.url or "",
        })
    end
    return workers
end

function M.listServiceWorkers()
    local cw = ensureWrapper()
    local targets = cw.serviceWorkerTargets()
    local workers = {}
    for _, t in ipairs(targets) do
        table.insert(workers, {
            targetId = t.targetId,
            type = t.type,
            title = t.title or "",
            url = t.url or "",
        })
    end
    return workers
end

function M.startByScope(scopeURL)
    local cw = ensureWrapper()
    return cw.startWorker(scopeURL)
end

function M.stopById(versionId)
    local cw = ensureWrapper()
    return cw.stopWorker(versionId)
end

function M.unregister(scopeURL)
    local cw = ensureWrapper()
    return cw.unregisterServiceWorker(scopeURL)
end

function M.pushByScope(origin, registrationId, payload)
    local cw = ensureWrapper()
    return cw.deliverPushMessage(origin, registrationId, payload)
end

function M.syncByScope(origin, registrationId, tag, lastChance)
    local cw = ensureWrapper()
    return cw.dispatchSyncEvent(origin, registrationId, tag, lastChance)
end

--- 在 Worker 内执行 JS
function M.execute(browser, targetId, expression)
    local session = browser:attachToWorker(targetId)
    if not session then return nil, "attach failed" end
    session:call("Runtime.enable")
    return session:eval(expression)
end

return M
