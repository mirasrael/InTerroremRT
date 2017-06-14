local GlobalAddonName, InTerroremRT = ...
local ExRT = _G.GExRT

if ExRT.locale ~= "ruRU" and not ExRT.alwaysRU then
    return
end

local L = InTerroremRT.L


L.RaidRoster = 'Ростер'
L.DefaultStaticName = 'Гильд статик'
L.RaidRosterInviteAll = 'Пригласить всех'
L.RaidRosterAddAll = 'Добавить группу/рейд'