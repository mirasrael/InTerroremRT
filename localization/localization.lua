local GlobalAddonName, InTerroremRT = ...

local localization = InTerroremRT.L
InTerroremRT.Ldef = localization

InTerroremRT.L = setmetatable({}, {__index=function (t, k)
    return localization[k] or k
end})

local L = localization

-- Raid Roster
L.RaidRoster = 'Roster'
L.DefaultStaticName = 'Guild Static'
L.RaidRosterInviteAll = 'Invite All'
L.RaidRosterAddAll = 'Add group/raid'

-- Boss List
L.BossList = 'Encounters List'
L.Encounter = "Encounter"
L.RaidLeader = "Raid Leader"
L.SendToRaidLeader = "Send to Raid Leader"