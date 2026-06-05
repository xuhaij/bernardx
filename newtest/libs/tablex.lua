---@diagnostic disable: need-check-nil
local table = require "table"
local string = require "string"
local io = require "io"

local COMMON_TABLE_NAME = "LOCAL_TABLE_"

local KEY_OTHER = 0
local KEY_INDEX = 1
local KEY_COMMON_STRING = 2

local tableToString

local function addAloneTable( 
    aTable ,site,nativeTableName,allTableRecords,aloneTableRecords,supplementRecords)
    local name = string.format( "%s%i",nativeTableName,aloneTableRecords.count)
    aloneTableRecords.count = aloneTableRecords.count + 1
    for k,record in pairs(aloneTableRecords) do
        if k ~= "count" and record.site >= site then
            record.site = record.site + 1
        end
    end
    local mainTableRecord = {site = site,name = name}
    aloneTableRecords[aTable] = mainTableRecord
    allTableRecords[aTable] = {
        name = name ,
        mainTableRecord = mainTableRecord
    }
    mainTableRecord.code = tableToString(
        aTable,1,nativeTableName,allTableRecords,aloneTableRecords,supplementRecords)
    return name
end



local function keyToString(
    k,indexCount,mainTableSite,nativeTableName,allTableRecords,aloneTableRecords,supplementRecords)
    local kStr
    local keyType = KEY_OTHER
    local kt = type(k)
    local isSupplement = false
    if k == indexCount+1 then
        keyType = KEY_INDEX
    elseif kt == "string" then
        if k:match("^[_%a][_%w]*$") then
            kStr = k
            keyType = KEY_COMMON_STRING
        else
            kStr = string.format( "[%q]",k)
        end
    elseif kt == "number" or kt == "boolean" then
        kStr =  string.format( "[%d]",k)
    elseif kt == "table" then
        local valueTableRecord = allTableRecords[k]
        if valueTableRecord ~= nil then
            if valueTableRecord.mainTableRecord.site > mainTableSite then
                isSupplement = true
            end
            kStr =string.format("[%s]",valueTableRecord.name) 
        else
            kStr = string.format("[%s]",
            addAloneTable(k,mainTableSite,nativeTableName,
            allTableRecords,aloneTableRecords,supplementRecords))
        end
    else
        error(string.format( "error type %s in keyToString",kt))
    end
    return kStr,keyType,isSupplement
end 



tableToString = function (
    aTable,blankSize,nativeTableName,allTableRecords,aloneTableRecords,supplementRecords)
	local kStr,vStr
    local isSupplement
    local keyType
	local indexCount = 0
    local strings = {}
    local valueType
    local tableRecord = allTableRecords[aTable]
    for k,v in pairs(aTable) do
        kStr,keyType,isSupplement = keyToString(
            k,indexCount,tableRecord.mainTableRecord.site,
            nativeTableName,allTableRecords,aloneTableRecords,supplementRecords)
        if keyType == KEY_INDEX then
            indexCount = indexCount + 1
        end
        valueType = type(v)
        
        if valueType == "string" then
            vStr = string.format( "%q",v )
        elseif valueType == "table" then
            local valueTableRecord = allTableRecords[v]
            if isSupplement then
                if valueTableRecord then
                    vStr = valueTableRecord.name
                else
                    vStr = addAloneTable(v,tableRecord.mainTableRecord.site,
                    nativeTableName,allTableRecords,aloneTableRecords,supplementRecords)
                end
            elseif valueTableRecord then
                if  valueTableRecord.mainTableRecord.site >= tableRecord.mainTableRecord.site then
                    isSupplement = true
                end
                vStr = valueTableRecord.name
            elseif keyType == KEY_INDEX then
                vStr = addAloneTable(v,tableRecord.mainTableRecord.site,
                nativeTableName,allTableRecords,aloneTableRecords,supplementRecords)
            else
                allTableRecords[v] = {
                    name = string.format( "%s%s",tableRecord.name,(keyType==KEY_COMMON_STRING and string.format( ".%s",kStr)) or  kStr ),
                    mainTableRecord = tableRecord.mainTableRecord
                }
                vStr = tableToString( v,blankSize+1,
                nativeTableName,allTableRecords,aloneTableRecords,supplementRecords)
            end
        elseif valueType == "number" or valueType == "boolean" then
            vStr = tostring(v)
        else
            error(string.format( "error type %s in valueToString",valueType))
        end

        if isSupplement then
            if keyType == KEY_INDEX then
                table.insert( strings,"nil" )
                kStr = string.format( "[%i]",k )
            elseif keyType == KEY_COMMON_STRING then
                kStr = string.format( ".%s",kStr )
            end
			table.insert(supplementRecords,string.format( "%s%s = %s",tableRecord.name,kStr,vStr))
        elseif keyType == KEY_INDEX then
            table.insert( strings,vStr )
        else
			table.insert(strings,string.format( "%s = %s",kStr,vStr) )
		end
	end
    if #strings == 0 then
        return "{}"
    elseif indexCount > 0 then 
        if indexCount == #strings then
            return string.format( "{%s}",table.concat( strings,","))
        end
        local headChunk = table.concat( strings, ",",1,indexCount )
        for i = indexCount+1 ,#strings do
            strings[i] = string.format( "%s%s",string.rep( "    ",blankSize),strings[i] )
        end
        local endChunk = table.concat( strings, ",\n",indexCount+1,#strings )
        return string.format( "{%s,\n%s\n%s}",headChunk,endChunk,string.rep( "    ",blankSize -1 ))
    end

    for i,v in ipairs(strings) do
        strings[i] = string.format( "%s%s",string.rep( "    ",blankSize),strings[i] )
    end
	return string.format( "{\n%s\n%s}",table.concat( strings,",\n"),string.rep( "    ",blankSize -1 ))
end

function table.toString( aTable,tableName )

    local nativeTableName = tableName or COMMON_TABLE_NAME
    local aloneTableRecords = {count = 0}
    local allTableRecords = {}
    local supplementRecords = {}

    addAloneTable(aTable,1,nativeTableName,allTableRecords,aloneTableRecords,supplementRecords)
    local order = {}
    aloneTableRecords.count = nil
    for k,v in pairs(aloneTableRecords)do
        order[v.site] = v
    end

    for i,aloneTable in ipairs(order)do
        order[i] = string.format( "local %s = %s",aloneTable.name,aloneTable.code )
    end

    return string.format( "%s\n%s\nreturn %s0",table.concat( order, "\n"),table.concat( supplementRecords, "\n"),nativeTableName) 
end


function table.commonToString(aTable)
    local nativeTableName = COMMON_TABLE_NAME
    local aloneTableRecords = {count = 0}
    local allTableRecords = {}
    local supplementRecords = {}

    addAloneTable(aTable,1,nativeTableName,allTableRecords,aloneTableRecords,supplementRecords)
    local order = {}
    aloneTableRecords.count = nil
    for k,v in pairs(aloneTableRecords)do
        order[v.site] = v
    end

    for i,aloneTable in ipairs(order)do
        return aloneTable.code
    end
end

function table.read( filePath )
	local aFunction = loadfile(filePath)
	local request
	if aFunction then
		request = aFunction()
	end
	return request
end

function table.write( aTable,filePath)
	local str = table.toString(aTable)
	local file = io.open(filePath,"w")
	file:write(str)
	file:flush()
	file:close()
end


local function copyTable(sourceTable,recordTable)
	local newTable = {}
	recordTable[sourceTable] = newTable
	for k,v in pairs(sourceTable)do
		if type(v)== "table" then
			v = recordTable[v] or copyTable(v,recordTable)
		end
		newTable[k] = v
	end
	return newTable
end

function table.copy(sourceTable)
	return copyTable(sourceTable,{})
end

function table.getKey(t,value)
	for k,v in pairs(t)do
		if v == value then 
			return k
		end
	end
end

function table.moveIndex(t,origin,destination)
	if origin > #t or destination > #t then
		return false
	end
	if origin ~= destination then
		local size = (origin > destination and -1) or 1
		local value = t[origin]
		for i = origin,destination-size ,size do
			t[i] = t[i+size]
		end
		t[destination] = value
	end
	return true
end


function table.split(t,splitPoint)
    return {table.unpack(t,1,splitPoint),table.unpack(t,splitPoint+1)}
end

function table.keys(t)
    local keys = {}
    for k,v in pairs(t)do
        table.insert(keys,k)
    end
    return keys
end

---@param t table
---@param f fun(v:any):boolean
function table.find(t,f)
    for k,v in pairs(t)do
        if f(v) then
            return k,v
        end
    end
end

---@param t table
---@param f fun(v:any):boolean
function table.removes(t,f)
    local index = 1
    while index<#t do
        local v = t[index]
        if f(v) then
            table.remove(t,index)
        else
            index = index + 1
        end        
    end
end


---@param t table
function table.valueMap(t)
    local r = {}
    for key , value in pairs(t) do
        r[value] = key
    end
    return r
end

function table.randomSelect(t,count)
    local target = {}
    count = math.min(count,#t)
    local localt = copyTable(t,{})
    for i = 1,count do
        local index = math.random(1,#localt)
        table.insert(target,localt[index])
        table.remove(localt,index)
    end
    return target
end

return table