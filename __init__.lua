-- bootstrap: Nd 连接 + 解锁 + SUI
MIN_ACTION_REPONSE_TIME = 3000
MAX_ACTION_REPONSE_TIME = 4000

ca = require("common_action")

local ok = false
for i = 1, 5 do
    if Nd.connect(3) then ok = true; break end
    ca.randomSleep(3000, 5000)
end
if ok then
    ca.unlockP2()
    SUI.startGlint(160)
end
