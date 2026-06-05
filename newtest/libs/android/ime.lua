local shell = require "android.shell"

local alonePackageName<const> = "com.maiku.simpleinputmethod"
local compositivePackageName<const> = "com.maiku.runoffer.worker"
local packageName<const> = InputMethod and compositivePackageName or alonePackageName


local mInputName = packageName .. "/.SimulateInputMethodService"

local function aloneInput(text)
  http.request {
    url = "http://localhost:8889/input",
    method = "POST",
    body = text,
  }
end

local input = InputMethod and InputMethod.input or aloneInput


local M = {}

local function getCurrentInputMethodName()
  return shell.exec("settings get secure default_input_method"):match("%g+")
end

local function getEnabledInputMethodNames()
  local result = {}
  for name in shell.exec("ime list -s"):gmatch("%g+") do
    table.insert(result, name)
  end
  return result
end

local function enableMyInputMethod()
  shell.exec("ime enable " .. mInputName)
end

local function useInputMethod(name)
  shell.exec("ime set " .. name)
end

local function enabledInputMethod(name)
  local names = getEnabledInputMethodNames()
  for _, n in ipairs(names) do
    if n == name then
      return true
    end
  end
  return false
end

function M.ensureMyInputMethod()
  if getCurrentInputMethodName() ~= mInputName then
    if not enabledInputMethod(mInputName) then
      enableMyInputMethod()
      ca.commonSleep()
    end
    useInputMethod(mInputName)
  end
  return true
end

function M.simInput(text)
  local cs = {}
  for c in string.gmatch(text,utf8.charpattern) do
    table.insert(cs,c)
  end
  for i,c in ipairs(cs) do
    input(c)
    ca.randomSleep(340,430)
  end
  return true
end

function M.delete()
  keyPress(KeyCode.MENU)
end

function M.enable()
  return InputMethod.enable()
end

function M.dismiss()
  return false
end



return M