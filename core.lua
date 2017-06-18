local GlobalAddonName, InTerroremRT = ...
local ExRT = _G.GExRT

InTerroremRT.L = {} --> localization

InTerroremRT.mod = {}
InTerroremRT.Modules = {}
function InTerroremRT.mod:New(moduleName, localizatedName, disableOptions, enableLoadInCombat)
    local _self = ExRT.mod:New(moduleName, localizatedName, disableOptions, enableLoadInCombat)
    table.insert(InTerroremRT.Modules, _self)
    return _self
end

InTerroremRT.frame = CreateFrame("Frame")

InTerroremRT.frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName ~= GlobalAddonName then
            return
        end
        _G.VInTerroremRT = _G.VInTerroremRT or {}
        for _, module in ipairs(InTerroremRT.Modules) do
            ExRT.A[module.name].main:ADDON_LOADED()
            ExRT.A[module.name]:Enable()
        end
    end
end)

InTerroremRT.F = {}
InTerroremRT.F.split = function(str, sSeparator, nMax, bRegexp)
    assert(sSeparator ~= '')
    assert(nMax == nil or nMax >= 1)

    local aRecord = {}

    if str:len() > 0 then
        local bPlain = not bRegexp
        nMax = nMax or -1

        local nField, nStart = 1, 1
        local nFirst, nLast = str:find(sSeparator, nStart, bPlain)
        while nFirst and nMax ~= 0 do
            aRecord[nField] = str:sub(nStart, nFirst - 1)
            nField = nField + 1
            nStart = nLast + 1
            nFirst, nLast = str:find(sSeparator, nStart, bPlain)
            nMax = nMax - 1
        end
        aRecord[nField] = str:sub(nStart)
    end

    return aRecord
end

InTerroremRT.F.tindex = function(tbl, element)
    for idx, elem in ipairs(tbl) do
        if elem == element then
            return idx
        end
    end
    return nil
end

InTerroremRT.F.tsetdefault = function(tbl, element, defaultValue)
    local value = tbl[element]
    if value == nil then
        value = defaultValue
        tbl[element] = value
    end
    return value
end

InTerroremRT.F.tremoveElement = function(tbl, element)
    local idx = InTerroremRT.F.tindex(tbl, element)
    if idx ~= nil then
        table.remove(tbl, idx)
    end
end

InTerroremRT.F.shallowcopy = function(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

InTerroremRT.F.buildMessageList = function(listName, lst, separator, handler, maxLen)
    if #lst > 0 then
        if maxLen == nil then
            maxLen = 255
        end
        local str = format('%s: ', listName)
        local appendSeparator = false
        local len = strlen(str)
        for _, value in ipairs(lst) do
            local newLen = len + strlen(value)
            if appendSeparator then
                newLen = newLen + strlen(separator)
            end
            if newLen > maxLen then
                handler(str)
                str = value
            else
                if appendSeparator then
                    str = str .. separator
                else
                    appendSeparator = true
                end
                str = str .. value
            end

            len = strlen(str)
        end
        if strlen(str) > 0 then
            handler(str)
        end
    end
end

-- map(table, function)
-- e.g: map({1,2,3}, double)    -> {2,4,6}
function InTerroremRT.F.map(tbl, func)
    local newtbl = {}
    for i, v in pairs(tbl) do
        newtbl[i] = func(v)
    end
    return newtbl
end

-- keys(table)
-- e.g: keys({a = 1, b = 2})    -> {a, b}
function InTerroremRT.F.keys(tbl)
    local newtbl = {}
    for k, _ in pairs(tbl) do
        tinsert(newtbl, k)
    end
    return newtbl
end

InTerroremRT.frame:RegisterEvent("ADDON_LOADED")