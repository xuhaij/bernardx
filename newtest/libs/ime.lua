local M = {}

local delegate

if IOS then
  delegate = require "ios.ime"
else
  delegate = require "android.ime"
end


function M.ensureMyInputMethod()
  return delegate.ensureMyInputMethod()
end

function M.simInput(text)
  return delegate.simInput(text)
end

function M.delete()
  return delegate.delete()
end

function M.enable()
  return delegate.enable()
end

function M.dismiss()
  return delegate.dismiss()
end

return M