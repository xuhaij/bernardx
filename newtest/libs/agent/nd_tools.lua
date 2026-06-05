--- Nd (Android 无障碍服务) 工具定义 + dispatch
-- @module agent.nd_tools
--
-- 用于 AI agent 操控手机系统级操作：
--   打开 App、按键、滑动、查找文本并点击等

local M = {}

---------------------------------------------------------------------------
-- 工具定义（Anthropic 格式）
---------------------------------------------------------------------------

function M.nd_tools(ai)
    return {
        ai.tool({
            name = "open_app",
            description = [[Open an Android app by package name.
Common packages:
  com.android.chrome / org.chromium.chrome — Chrome browser
  com.google.android.gm — Gmail
  com.google.android.googlequicksearchbox — Google Search
  com.google.android.apps.maps — Google Maps
  com.google.android.youtube — YouTube
  com.android.settings — Settings
  com.google.android.deskclock — Clock
  com.sec.android.app.clockpackage — Samsung Clock]],
            input_schema = ai.schema(
                { package_name = ai.string_prop("Android package name to open") },
                { "package_name" }
            ),
        }),
        ai.tool({
            name = "press_key",
            description = [[Press an Android key.
Common keys: HOME(3), BACK(4), ENTER(66), VOLUME_UP(24), VOLUME_DOWN(25), POWER(26)]],
            input_schema = ai.schema(
                {
                    key_code = ai.integer_prop("Android key code, e.g. 3=HOME, 4=BACK, 66=ENTER"),
                },
                { "key_code" }
            ),
        }),
        ai.tool({
            name = "tap_by_text",
            description = "Find an element on screen by its visible text and tap it. Use for buttons, menu items, app icons etc.",
            input_schema = ai.schema(
                {
                    text = ai.string_prop("Visible text of the element to tap"),
                    exact = ai.boolean_prop("If true, require exact match; if false, partial match (default: false)"),
                },
                { "text" }
            ),
        }),
        ai.tool({
            name = "type_by_hint",
            description = "Find an input field by its hint/placeholder text and type into it. Use for login forms, search boxes, etc.",
            input_schema = ai.schema(
                {
                    hint = ai.string_prop("Hint/placeholder text shown in the input field"),
                    text = ai.string_prop("Text to type"),
                },
                { "hint", "text" }
            ),
        }),
        ai.tool({
            name = "swipe_screen",
            description = "Swipe on the screen from one point to another. Coordinates are screen percentages (0.0 to 1.0).",
            input_schema = ai.schema(
                {
                    x1 = ai.number_prop("Start X (0-1, fraction of screen width)"),
                    y1 = ai.number_prop("Start Y (0-1, fraction of screen height)"),
                    x2 = ai.number_prop("End X (0-1)"),
                    y2 = ai.number_prop("End Y (0-1)"),
                },
                { "x1", "y1", "x2", "y2" }
            ),
        }),
        ai.tool({
            name = "wait",
            description = "Wait for a number of milliseconds (use after opening apps, clicking, or when loading)",
            input_schema = ai.schema(
                { ms = ai.integer_prop("Milliseconds to wait") },
                { "ms" }
            ),
        }),
        ai.tool({
            name = "done",
            description = "Signal that the task is complete",
            input_schema = ai.schema({}, {}),
        }),
    }
end

---------------------------------------------------------------------------
-- Dispatch: tool name → handler
---------------------------------------------------------------------------

function M.nd_dispatch()
    return {
        open_app = function(input)
            local pkg = input.package_name
            print("[nd] 打开 App: " .. pkg)
            System.openApp(pkg)
            ca.randomSleep(2000, 3000)
            return "opened " .. pkg
        end,

        press_key = function(input)
            local code = input.key_code
            local names = { [3] = "HOME", [4] = "BACK", [66] = "ENTER",
                            [24] = "VOLUME_UP", [25] = "VOLUME_DOWN", [26] = "POWER" }
            local name = names[code] or tostring(code)
            print("[nd] 按键: " .. name .. " (" .. code .. ")")
            System.pressKey(code)
            ca.randomSleep(300, 600)
            return "pressed " .. name
        end,

        tap_by_text = function(input)
            local text = input.text
            local exact = input.exact
            print("[nd] 查找并点击: " .. text)

            local node
            if exact then
                node = By.text(text):find()
            else
                -- 先尝试精确，再尝试包含
                node = By.text(text):find()
                if not node then
                    local all = By.clz("android.widget.TextView"):finds()
                    if all then
                        for _, n in ipairs(all) do
                            local t = n:text()
                            if t and string.find(t, text, 1, true) then
                                node = n
                                break
                            end
                        end
                    end
                end
            end

            if not node then
                return "error: could not find element with text '" .. text .. "'"
            end

            ca.commonClickNode(node)
            ca.randomSleep(500, 1000)
            return "tapped '" .. text .. "'"
        end,

        type_by_hint = function(input)
            local hint = input.hint
            local text = input.text
            print("[nd] 在 '" .. hint .. "' 输入: " .. text)

            -- 找 EditText 节点
            local fields = By.clz("android.widget.EditText"):finds()
            local target = nil
            if fields then
                for _, f in ipairs(fields) do
                    local h = f:text() or ""
                    if string.find(h, hint, 1, true) then
                        target = f
                        break
                    end
                end
            end

            if not target then
                -- 回退: 找 hint 文本旁边最近的输入框
                local hint_node = By.text(hint):find()
                if hint_node then
                    -- 点击 hint 所在的区域，期望聚焦到输入框
                    ca.commonClickNode(hint_node)
                    ca.randomSleep(300, 500)
                    Nd.setText(text)
                    ca.randomSleep(300, 500)
                    return "typed '" .. text .. "' by clicking hint '" .. hint .. "'"
                end
                return "error: could not find input field with hint '" .. hint .. "'"
            end

            ca.commonClickNode(target)
            ca.randomSleep(300, 500)
            Nd.setText(text)
            ca.randomSleep(300, 500)
            return "typed '" .. text .. "' into field '" .. hint .. "'"
        end,

        swipe_screen = function(input)
            local w, h = Display:getSize()
            local x1 = math.floor(w * input.x1)
            local y1 = math.floor(h * input.y1)
            local x2 = math.floor(w * input.x2)
            local y2 = math.floor(h * input.y2)
            print(string.format("[nd] 滑动: (%.0f,%.0f) → (%.0f,%.0f)", x1, y1, x2, y2))
            ca.swipe(x1, y1, x2, y2)
            ca.randomSleep(300, 500)
            return "swiped"
        end,

        wait = function(input)
            local ms = input.ms or 1000
            print("[nd] 等待: " .. ms .. "ms")
            ca.randomSleep(ms, ms + 500)
            return "waited " .. ms .. "ms"
        end,

        done = function()
            return "task_done"
        end,
    }
end

return M
