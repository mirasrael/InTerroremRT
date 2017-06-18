local GlobalAddonName, InTerroremRT = ...
local ExRT = _G.GExRT

if ExRT.locale ~= "ruRU" and not ExRT.alwaysRU then
    return
end

local L = InTerroremRT.L

-- Raid Roster
L.RaidRoster = 'Ростер'
L.DefaultStaticName = 'Гильд статик'
L.RaidRosterInviteAll = 'Пригласить всех'
L.RaidRosterAddAll = 'Добавить группу/рейд'

-- Boss List
L.BossList = 'Список боссов'
L.Encounter = "Босс"
L.RaidLeader = "Лидер рейда"
L.SendToRaidLeader = "Отправить рейд лидеру"