local table = require "tablex"

---@class Object
---@field toString fun(self:Object):string
---@field instanceOf fun(self:Object,class:Object):boolean


local _M = {}
local _classes = {}
_M._classes = _classes
_M.newTable = {}
_M.nilFunction = function( ) end
_M.abstractMethod = function ()
	return error("abstract method",1)
end

local function newClassTableMember( sourceTable )
	local result
	if sourceTable == _M.newTable then
    result = {}
  elseif _classes[sourceTable] then
    result = sourceTable:newInstance()
  else
    result = table.copy(sourceTable)
	end
  return result
end


local function rawSet(object,key,value)
	if type(value) == "table" then
		value = newClassTableMember( value )
	end
	rawset(object,key,value)
	return value
end

local function toString(self)
	return string.format("%s instance of %s",tostring(self),self._class_name)
end

local function instanceOf(object,class)
	if not _classes[class] then
		error("Invalid class")
	end
	local mt = getmetatable(object)
	while mt do
		if mt == class then
			return true
		end
		mt = getmetatable(mt)
	end
	return false
end


function _M.instanceOf(t,class)
	return instanceOf(t,class)
end

function _M.new(name,superclass,...)
	local class = {
		toString = toString,
		_class_name = name,
		_super = superclass,
		_included = _M.newTable,
		instanceOf = instanceOf
	}
	if superclass then
		if _classes[superclass] then
			setmetatable(class,superclass)
		else
			error("Invalid superclass")
		end
	end



	if select("#",...)>0 then
		local included = {...}
		class._included = included
		class.__index = function (self,key)
			local value = class[key]
			if value then
				return rawSet(self,key,value)
			end
			for _,class in ipairs(included) do
				if not _classes[class] then
					error("Invalid mixin")
				end
				value = class[key]
				if value then
					return rawSet(self,key,value)
				end
			end
		end
	else
		class.__index = function (self,key)
			local value = class[key]
			return rawSet(self,key,value)
		end
	end

	_classes[class] = true
	if not class.ctor then
		class.ctor = _M.nilFunction
	end
	return class
end


---@generic T
---@param class T
---@return T
function _M.instance(class,...)
	if not _classes[class] then
		error("Invalid class")
	end
	local object = setmetatable( {}, class)
	class.ctor(object,...)
	return object
end

return  _M