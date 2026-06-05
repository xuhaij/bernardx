--- 统一初始化模块 — 无障碍服务(Nd) + Chrome CDP + Worker
MIN_ACTION_REPONSE_TIME = 3000
MAX_ACTION_REPONSE_TIME = 4000

local class   = require("class")
local json    = require("dkjson")
local random  = require("randomlua")
local frame   = require("frame")
local ca      = require("common_action")

local INIT = { nd_ok = false, chrome_ok = false, worker_ok = false }

local function initNd(retries)
    retries = retries or 5
    print("[init] Phase 1: Nd...")
    local connected = false
    for i = 1, retries do
        if Nd.connect(3) then connected = true; break end
        ca.randomSleep(3000, 5000)
    end
    if not connected then print("[init] Nd 失败"); return false end
    ca.unlockP2()
    frame.ensureEngineVersion(97)
    SUI.startGlint(160)
    print("[init] Nd 就绪")
    INIT.nd_ok = true
    return true
end

local function initChrome(timeout)
    timeout = timeout or 15000
    print("[init] Phase 2: Chrome...")
    local ok, chrome = pcall(function() return require("android.chrome") end)
    if not ok then print("[init] Chrome 加载失败"); return false end
    if not pcall(function() return chrome.ensureInit(timeout) end) then
        print("[init] Chrome init 失败"); return false
    end
    INIT.chrome = chrome
    INIT.cdp = require("android.cdp_wrapper")
    INIT.chrome_ok = true
    print("[init] Chrome 就绪, " .. #chrome.tabInfo() .. " tabs")
    return true
end

local function initWorker()
    print("[init] Phase 3: Worker...")
    local ok, worker = pcall(function() return require("worker") end)
    if not ok then print("[init] Worker 加载失败"); return false end
    if not pcall(function() return worker.init(10000) end) then
        print("[init] Worker init 失败"); return false
    end
    INIT.worker = worker
    INIT.worker_ok = true
    print("[init] Worker 就绪")
    return true
end

function INIT.setup(opts)
    opts = opts or {}
    local nd     = opts.nd ~= false
    local chrome = opts.chrome ~= false
    local worker = opts.worker ~= false
    print("===== Init Nd=" .. tostring(nd) .. " Chrome=" .. tostring(chrome) .. " Worker=" .. tostring(worker) .. " =====")
    if nd     then initNd(opts.nd_retries) else print("[init] Nd skip") end
    if chrome then initChrome(opts.cdp_timeout) else print("[init] Chrome skip") end
    if worker and INIT.chrome_ok then initWorker() else print("[init] Worker skip") end
    print("===== Ready: Nd=" .. (INIT.nd_ok and "Y" or "N") .. " Chrome=" .. (INIT.chrome_ok and "Y" or "N") .. " Worker=" .. (INIT.worker_ok and "Y" or "N") .. " =====")
    return INIT
end

return INIT
