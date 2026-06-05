-- Quick test: just extract DOM info from the test page
local cdp = require('cdp')
local dom = require('dom_helper')

local client = cdp.new({ port = 9222 })
client:connect()
client:enable("Page")
client:navigate("http://localhost:3000")
sleep(1500)

local text, data = dom.extract_page_info(client)
if text then
    print(text)
else
    print("[FAIL] " .. tostring(data))
end

client:close()
