local GlobalAddonName, InTerroremRT = ...

local localization = InTerroremRT.L
InTerroremRT.Ldef = localization

InTerroremRT.L = setmetatable({}, {__index=function (t, k)
    return localization[k] or k
end})

local L = localization