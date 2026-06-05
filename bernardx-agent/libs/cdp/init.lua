--- Chrome DevTools Protocol (CDP) client
-- @module cdp
--
-- Basic usage:
--   local cdp = require('cdp')
--
--   -- Connect to Chrome (must be launched with --remote-debugging-port=9222)
--   local client = cdp.new({ port = 9222 })
--
--   -- List open tabs
--   local targets = client:list_targets()
--
--   -- Connect to first page
--   client:connect()
--
--   -- Navigate
--   client:navigate("https://example.com")
--
--   -- Evaluate JS
--   local resp = client:evaluate("document.title")
--   print(resp.result.result.value)
--
--   -- Handle events
--   client:on("Page.loadEventFired", function(params)
--     print("page loaded")
--   end)
--
--   -- Close
--   client:close()

local json = require('json')
local http = require('http')

local M = {}

---------------------------------------------------------------------------
-- Type definitions
---------------------------------------------------------------------------

---@class CDP.Config
---@field host? string default "localhost"
---@field port? integer default 9222

---@class CDP.Target
---@field id string target id
---@field type string "page"|"iframe"|"worker"|"other"
---@field title string page title
---@field url string page URL
---@field webSocketDebuggerUrl string WS endpoint

---@class CDP.Response
---@field id integer command id
---@field result? table command result
---@field error? { code: integer, message: string } error info

---------------------------------------------------------------------------
-- Client constructor
---------------------------------------------------------------------------

--- Create a new CDP client
---@param config? CDP.Config
---@return table client
function M.new(config)
    config = config or {}

    local client = {
        host = config.host or "localhost",
        port = config.port or 9222,
        _ws = nil,
        _target = nil,
        _id = 0,
        _pending = {},
        _event_handlers = {},
    }

    setmetatable(client, { __index = M })
    return client
end

---------------------------------------------------------------------------
-- HTTP: Target discovery
---------------------------------------------------------------------------

--- Get the HTTP base URL for the DevTools endpoint
---@return string url
function M:base_url()
    return string.format("http://%s:%d", self.host, self.port)
end

--- List all available targets
---@return CDP.Target[]|nil targets
---@return string|nil error
function M:list_targets()
    local status, body, err = http.get(self:base_url() .. "/json")
    if err then
        return nil, "http error: " .. err
    end
    if status ~= 200 then
        return nil, "unexpected status " .. tostring(status)
    end

    local ok, parsed = pcall(json.decode, body)
    if not ok then
        return nil, "json decode error: " .. tostring(parsed)
    end

    return parsed
end

--- Get the first page-type target
---@return CDP.Target|nil target
---@return string|nil error
function M:get_page()
    local targets, err = self:list_targets()
    if err then return nil, err end

    for _, t in ipairs(targets) do
        if t.type == "page" and t.webSocketDebuggerUrl then
            return t
        end
    end
    return nil, "no page target found"
end

--- Get a target by id
---@param target_id string
---@return CDP.Target|nil target
---@return string|nil error
function M:get_target(target_id)
    local targets, err = self:list_targets()
    if err then return nil, err end

    for _, t in ipairs(targets) do
        if t.id == target_id then
            return t
        end
    end
    return nil, "target not found: " .. tostring(target_id)
end

---------------------------------------------------------------------------
-- WebSocket: Connection
---------------------------------------------------------------------------

--- Connect to a target via WebSocket
---@param target? CDP.Target target to connect to (defaults to first page)
---@return boolean ok
---@return string|nil error
function M:connect(target)
    if self._ws then
        return nil, "already connected"
    end

    if not target then
        local t, err = self:get_page()
        if err then return nil, err end
        target = t
    end

    if not target.webSocketDebuggerUrl then
        return nil, "target has no webSocketDebuggerUrl"
    end

    local ws = http.ws_create(target.webSocketDebuggerUrl)

    local client_self = self
    ws.onmessage = function(msg)
        local ok, data = pcall(json.decode, msg)
        if not ok then return end

        if data.id then
            -- Command response
            local cb = client_self._pending[data.id]
            if cb then
                client_self._pending[data.id] = nil
                cb(data)
            end
        elseif data.method then
            -- Event
            local handlers = client_self._event_handlers[data.method]
            if handlers then
                for _, h in ipairs(handlers) do
                    h(data.params or {})
                end
            end
            -- Wildcard handlers
            local all = client_self._event_handlers["*"]
            if all then
                for _, h in ipairs(all) do
                    h(data.method, data.params or {})
                end
            end
        end
    end

    local ok, err = ws:connect()
    if not ok then
        return nil, "ws connect failed: " .. (err or "unknown")
    end

    self._ws = ws
    self._target = target
    return true
end

--- Check if connected
---@return boolean
function M:is_connected()
    return self._ws ~= nil
end

---------------------------------------------------------------------------
-- WebSocket: Commands
---------------------------------------------------------------------------

--- Send a CDP command (async, callback-based)
---@param method string CDP method name e.g. "Page.navigate"
---@param params? table parameters
---@param callback? fun(resp: CDP.Response) called when response arrives
---@return integer|nil id command id
---@return string|nil error
function M:send(method, params, callback)
    if not self._ws then
        return nil, "not connected"
    end

    self._id = self._id + 1
    local id = self._id

    local msg = json.encode({
        id = id,
        method = method,
        params = params or {},
    })

    if callback then
        self._pending[id] = callback
    end

    local ok, err = self._ws:send(msg)
    if not ok then
        self._pending[id] = nil
        return nil, "ws send failed: " .. (err or "unknown")
    end

    return id
end

--- Send a CDP command and wait for response
---@param method string CDP method name
---@param params? table parameters
---@return CDP.Response|nil response
---@return string|nil error
function M:send_sync(method, params)
    return await(function(resolve, reject)
        local id, err = self:send(method, params, function(resp)
            resolve(resp)
        end)
        if not id then
            reject(err or "send failed")
        end
    end)
end

---------------------------------------------------------------------------
-- WebSocket: Events
---------------------------------------------------------------------------

--- Register an event handler
---@param event string CDP event name, or "*" for all events
---@param handler fun(params: table) event handler
function M:on(event, handler)
    if not self._event_handlers[event] then
        self._event_handlers[event] = {}
    end
    table.insert(self._event_handlers[event], handler)
end

--- Remove all handlers for an event
---@param event string CDP event name
function M:off(event)
    self._event_handlers[event] = nil
end

---------------------------------------------------------------------------
-- Convenience methods
---------------------------------------------------------------------------

--- Enable a CDP domain (e.g. "Page", "Runtime", "Network")
---@param domain string domain name
---@return CDP.Response?
function M:enable(domain)
    return self:send_sync(domain .. ".enable", {})
end

--- Disable a CDP domain
---@param domain string domain name
---@return CDP.Response?
function M:disable(domain)
    return self:send_sync(domain .. ".disable", {})
end

--- Navigate to a URL
---@param url string target URL
---@return CDP.Response?
function M:navigate(url)
    return self:send_sync("Page.navigate", { url = url })
end

--- Evaluate a JavaScript expression
---@param expression string JS code
---@param options? table { awaitPromise?: boolean, returnByValue?: boolean }
---@return CDP.Response
function M:evaluate(expression, options)
    local params = {
        expression = expression,
        returnByValue = true,
    }
    if options then
        for k, v in pairs(options) do params[k] = v end
    end
    return self:send_sync("Runtime.evaluate", params)
end

--- Call a function on an object
---@param function_declaration string JS function body
---@param object_id? string remote object id
---@param options? table { awaitPromise?: boolean, returnByValue?: boolean }
---@return CDP.Response
function M:call_function(function_declaration, object_id, options)
    local params = {
        functionDeclaration = function_declaration,
        returnByValue = true,
    }
    if object_id then
        params.objectId = object_id
    end
    if options then
        for k, v in pairs(options) do params[k] = v end
    end
    return self:send_sync("Runtime.callFunctionOn", params)
end

--- Get the page title
---@return string|nil title
function M:title()
    local resp = self:evaluate("document.title")
    if resp and resp.result and resp.result.result then
        return resp.result.result.value
    end
    return nil
end

--- Get the current URL
---@return string|nil url
function M:current_url()
    local resp = self:evaluate("window.location.href")
    if resp and resp.result and resp.result.result then
        return resp.result.result.value
    end
    return nil
end

--- Take a PNG screenshot (base64)
---@param options? table { format?: string, quality?: integer, clip?: table }
---@return string|nil base64_data
function M:screenshot(options)
    local params = options or { format = "png" }
    local resp = self:send_sync("Page.captureScreenshot", params)
    if resp and resp.result then
        return resp.result.data
    end
    return nil
end

--- Click an element by CSS selector
---@param selector string CSS selector
---@return CDP.Response?
function M:click(selector)
    return self:evaluate(string.format(
        'document.querySelector(%q).click()',
        selector
    ))
end

--- Type text into a focused element
---@param text string text to type
---@return CDP.Response?
function M:type_text(text)
    return self:send_sync("Input.insertText", { text = text })
end

--- Press a key
---@param key string key name e.g. "Enter", "Tab"
---@param options? table { modifiers?: integer }
---@return CDP.Response?
function M:press_key(key, options)
    local params = {
        type = "keyDown",
        key = key,
        text = key:len() == 1 and key or nil,
    }
    if options then
        for k, v in pairs(options) do params[k] = v end
    end
    self:send_sync("Input.dispatchKeyEvent", params)
    params.type = "keyUp"
    return self:send_sync("Input.dispatchKeyEvent", params)
end

--- Wait for a selector to appear (polls via evaluate)
---@param selector string CSS selector
---@param timeout? integer timeout in ms (default 5000)
---@return boolean found
function M:wait_for_selector(selector, timeout)
    timeout = timeout or 5000
    local deadline = now() + timeout

    while now() < deadline do
        local resp = self:evaluate(string.format(
            'document.querySelector(%q) !== null',
            selector
        ))
        if resp and resp.result and resp.result.result
            and resp.result.result.value == true then
            return true
        end
        sleep(100)
    end
    return false
end

--- Close the WebSocket connection
function M:close()
    if self._ws then
        self._ws:close()
        self._ws = nil
    end
    self._target = nil
    self._pending = {}
end

return M