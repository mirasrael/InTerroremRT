local GlobalAddonName, InTerroremRT = ...

local VInTerroremRT
local ExRT = _G.GExRT
local InviteTool = ExRT.A.InviteTool
if not InviteTool then
    return
end

local module = InTerroremRT.mod:New("RaidRoster", InTerroremRT.L.RaidRoster, nil, true)
local ELib, L = ExRT.lib, InTerroremRT.L

module.db.perPage = 18
module.db.page = 1

function module.main:ADDON_LOADED()
    VInTerroremRT = _G.VInTerroremRT
    VInTerroremRT.RaidRoster = VInTerroremRT.RaidRoster or {}
    -- TODO: Calculate defaults based on average rank
    VInTerroremRT.RaiderRank = VInTerroremRT.RaiderRank or 'Legioner'
    VInTerroremRT.ActiveRaiderRank = VInTerroremRT.ActiveRaiderRank or 'Option'

    module:RegisterSlash()
    module:RegisterAddonMessage()

    module.db.realmName = GetRealmName():gsub(' ', '')

    module.db.raiderRank = 'Alt' -- VInTerroremRT.RaiderRank
    module.db.activeRaiderRank = VInTerroremRT.ActiveRaiderRank

    module:_LoadVariables()
end

function module:Enable()
    module:RegisterEvents('GROUP_ROSTER_UPDATE')
    module.main:GROUP_ROSTER_UPDATE()
end

function module:Disable()
    module:UnregisterEvents('GROUP_ROSTER_UPDATE')
end

function module.main:GROUP_ROSTER_UPDATE()
    module.db.guildMembers = nil
end

function module:_CreateRosterTable(borderList)
    local function Lines_Button_OnEnter(self)
        local color = self.texture.highlightColor
        self.texture:SetVertexColor(color.r, color.g, color.b, color.a)
        -- local left, top, _, bottom, right = self.texture:GetTexCoord()
        -- print(left, top, bottom, right)
        -- self.texture:SetTexCoord(left + 0.0625, right + 0.0625, top, bottom)
    end

    local function Lines_Button_OnLeave(self)
        self.texture:SetVertexColor(1, 1, 1, 0.7)
    end

    module.options.lines = {}
    for i = 1, module.db.perPage do
        local line = CreateFrame("Frame", nil, borderList)
        module.options.lines[i] = line
        line:SetSize(625, 30)
        line:SetPoint("TOPLEFT", 0, -(i - 1) * 30)

        line.name = ELib:Text(line, "Name", 11):Color():Point(5, 0):Size(94, 30):Shadow()

        line.class = ELib:Icon(line, nil, 24):Point(100, -3)

        line.spec = ELib:Icon(line, nil, 24):Point(130, -3)
        line.spec:SetScript("OnEnter", Lines_SpecIcon_OnEnter)
        line.spec:SetScript("OnLeave", GameTooltip_Hide)

        line.ilvl = ELib:Text(line, "630.52", 11):Color():Point(160, 0):Size(50, 30):Shadow()

        line.removeButton = ELib:Icon(line, [[Interface\AddOns\ExRT\media\DiesalGUIcons16x256x128]], 18, true):Point(210 + (24 * 16) + 4, -8)
        line.removeButton.texture:SetTexCoord(0.5, 0.5625, 0.5, 0.625)
        line.removeButton.texture:SetVertexColor(1, 1, 1, 0.7)
        line.removeButton.texture.highlightColor = { r = 0.9, g = 0, b = 0, a = 1 }
        line.removeButton:SetScript("OnEnter", Lines_Button_OnEnter)
        line.removeButton:SetScript("OnLeave", Lines_Button_OnLeave)
        line.removeButton:SetScript("OnClick", function(self)
            module:RemoveMember(module:_NormalizeName(line.name:GetText()))
            module:ReloadUI()
        end)

        line.time = ELib:Text(line, date("%H:%M:%S", time()), 11):Color():Point(205, 0):Size(80, 30):Shadow():Center()
        line.otherInfo = ELib:Text(line, "", 10):Color():Point(285, 0):Size(335, 30):Shadow()

        line.otherInfoTooltipFrame = CreateFrame("Frame", nil, line)
        line.otherInfoTooltipFrame:SetAllPoints(line.otherInfo)
        line.otherInfoTooltipFrame:SetScript("OnEnter", otherInfoHover)
        line.otherInfoTooltipFrame:SetScript("OnLeave", GameTooltip_Hide)

        line.back = line:CreateTexture(nil, "BACKGROUND", nil, -3)
        line.back:SetPoint("TOPLEFT", 0, 0)
        line.back:SetPoint("BOTTOMRIGHT", 0, 0)
        line.back:SetColorTexture(1, 1, 1, 1)
        line.back:SetGradientAlpha("HORIZONTAL", 0, 0, 0, 1, 0, 0, 0, 0)
    end
end

function module:_LoadVariables()
    local raidRoster = VInTerroremRT.RaidRoster
    module.db.currentStaticName = raidRoster.CurrentStaticName or L.DefaultStaticName
    module.db.statics = raidRoster.Statics or {}
    module.db.currentStatic = module.db.statics[module.db.currentStaticName] or {}
end

function module.options:_CreateRaidRosterPage()
    self.borderList = CreateFrame("Frame", nil, self)
    self.borderList:SetSize(648, module.db.perPage * 30)
    self.borderList:SetPoint("TOP", 0, -50)
    ELib:Border(self.borderList, 2, .24, .25, .30, 1)

    self.borderList:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            module.options.ScrollBar.buttonUP:Click("LeftButton")
        else
            module.options.ScrollBar.buttonDown:Click("LeftButton")
        end
    end)

    self.ScrollBar = ELib:ScrollBar(self.borderList):Size(16, 0):Point("TOPRIGHT", -3, -3):Point("BOTTOMRIGHT", -3, 3):Range(1, 20)

    function module.options.ReloadPage()
        local nowDb = module.db.currentStatic
        module.options.title:SetText(L.RaidRoster .. ' - ' .. module.db.currentStaticName .. ' (' .. #nowDb .. ')')

        local scrollNow = ExRT.F.Round(module.options.ScrollBar:GetValue())
        local linesToShow = math.min(module.db.perPage, #nowDb - scrollNow + 1)
        local inspectDB = ExRT.A.InspectViewer.db.inspectDB
        for i = scrollNow, scrollNow + linesToShow - 1 do
            local line = module.options.lines[i - scrollNow + 1]
            local data = nowDb[i]
            local name = Ambiguate(data.name, 'all')
            local ilvl = ''
            if inspectDB[name] then
                ilvl = format("%.2f", inspectDB[name].ilvl or 0)
            end
            line.name:SetText(name)
            line.unit = name
            line.ilvl:SetText(ilvl)
            line:Show()
        end
        for i = linesToShow + 1, module.db.perPage do
            module.options.lines[i]:Hide()
        end
    end

    self.ScrollBar:SetScript("OnValueChanged", module.options.ReloadPage)
    module:_CreateRosterTable(self.borderList)

    self.inviteAllButton = ELib:Button(self, L.RaidRosterInviteAll):Size(150, 20):Point("TOPRIGHT", self.borderList, "BOTTOMRIGHT", 2, -4):OnClick(function()
        module:InviteAll()
    end)

    self.addAllButton = ELib:Button(self, L.RaidRosterAddAll):Size(150, 20):Point("TOPLEFT", self.borderList, "BOTTOMLEFT", -2, -4):OnClick(function()
        module:AddPartyOrRaidMembers()
        module:ReloadUI()
    end)
end

function module:addonMessage(sender, prefix, ...)
end

function module.options:Load()
    self:CreateTilte()
    self:_CreateRaidRosterPage()

    function module.options.showPage()
        local count = #module.db.currentStatic
        self.ScrollBar:SetMinMaxValues(1, max(count - module.db.perPage + 1, 1)):UpdateButtons()
        module.options.ReloadPage()
    end

    self.OnShow_disableNil = true
    self:SetScript("OnShow", module.options.showPage)
    self:showPage()
end

function module:ReloadUI()
    if module.options.ReloadPage ~= nil then
        local count = #module.db.currentStatic
        module.options.ScrollBar:SetMinMaxValues(1, max(count - module.db.perPage + 1, 1)):UpdateButtons()
        module.options.ReloadPage()
    end
end

function module:SaveStatic()
    local raidRoster = VInTerroremRT.RaidRoster
    if not raidRoster.Statics then
        raidRoster.Statics = {}
    end
    table.sort(module.db.currentStatic, function(a, b) return a.name < b.name; end)
    raidRoster.Statics[module.db.currentStaticName] = module.db.currentStatic
    raidRoster.CurrentStaticName = module.db.currentStaticName
end

function module:AddMember(name)
    if name == nil then
        return
    end
    if self:_GetMemberIndex(name) ~= nil then
        return
    end
    table.insert(self.db.currentStatic, {
        name = name
    })
    self:SaveStatic()
end

module.invitesActive = false
function module:AddPartyOrRaidMembers()
    local n = GetNumGroupMembers() or 0
    if n == 0 then
        n = 1
    end
    local addUnit = function(unitID)
        local name, realm = UnitFullName(unitID)
        if name then
            if realm ~= nil and realm ~= "" then
                name = name .. '-' .. realm
            end
            self:AddMember(self:_NormalizeName(name))
        end
    end

    local isRaid = IsInRaid()
    if not isRaid then
        for i = 1, n do
            local unit = "party" .. i
            if i == n then unit = "player" end
            addUnit(unit)
        end
    else
        for i = 1, n do
            addUnit("raid" .. i)
        end
    end
end

function module:InviteAll()
    if self.invitesActive then
        return
    end

    self.invitesActive = true
    InviteTool.db.converttoraid = true
    C_Timer.After(20, function()
        module.invitesActive = false
        InviteTool.db.converttoraid = false
        print('Invites finished')
    end)
    local raidMembers = {}
    local n = GetNumGroupMembers() or 0
    if n ~= 0 then
        for i = 1, n do
            local name = GetRaidRosterInfo(i)
            raidMembers[self:_NormalizeName(name):lower()] = true
        end
    else
        raidMembers[self:_NormalizeName(UnitName('player')):lower()] = true
    end
    for _, member in ipairs(self.db.currentStatic) do
        -- print(member.name:lower(), raidMembers[member.name:lower()])
        if not raidMembers[member.name:lower()] then
            -- print(member.name)
            InviteUnit(member.name)
        end
    end
end

function module:_NormalizeName(name)
    name = (ExRT.F:utf8sub(name, 1, 1):upper()) .. ExRT.F:utf8sub(name, 2, -1) --> capitalize
    if not name:find('-') then
        name = name .. '-' .. self.db.realmName
    end
    return name
end

function module:_GetMemberIndex(name)
    for idx, member in ipairs(self.db.currentStatic) do
        if member.name:lower() == name:lower() then
            return idx
        end
    end
    return nil
end

function module:RemoveMember(name)
    local idx = self:_GetMemberIndex(name)
    table.remove(self.db.currentStatic, idx)
    local result = self:HandleBossesCommand(name, {"b", "цн", "-1", "-2", "-3", "-4", "-5", "-6", "-7", "-8", "-9", "-10", "-11", "-12", "-13", "-14"})
    self:SaveStatic()
end

function module:RemoveAllMembers()
    self.db.currentStatic = {}
    self:SaveStatic()
end

function module:NotifyAll(message)
    for idx, member in ipairs(self.db.currentStatic) do
        SendChatMessage(message, "WHISPER", nil, member.name)
    end
    SendChatMessage(message, "GUILD")
end

function module:_GetGuildMembers()
    if self.db.guildMembers == nil then
        local db = {}
        local n = GetNumGuildMembers()
        for i = 1, n do
            local name, rank, rankIndex, level, class, zone, note,
            officernote, online, status, classFileName,
            achievementPoints, achievementRank, isMobile, isSoREligible, standingID = GetGuildRosterInfo(i)
            db[self:_NormalizeName(name)] = {
                name = name,
                rank = rank,
                rankIndex = rankIndex,
            }
        end
        self.db.guildMembers = db
    end
    return self.db.guildMembers
end

function module:AddAllInRank(rank)
    local nRanks = GuildControlGetNumRanks()
    local minRankIndex = 1
    for i = 1, nRanks do
        if GuildControlGetRankName(i) == rank then
            minRankIndex = i - 1
            break
        end
    end

    local n = GetNumGuildMembers()
    for i = 1, n do
        local name, rank, rankIndex, level, class, zone, note,
        officernote, online, status, classFileName,
        achievementPoints, achievementRank, isMobile, isSoREligible, standingID = GetGuildRosterInfo(i)
        if rankIndex <= minRankIndex then
            self:AddMember(self:_NormalizeName(name))
        end
    end
end

function module:_ChangeRank(fromRank, promoteWith)
    local nowDb = self.db.currentStatic
    local guildMembers = self:_GetGuildMembers()

    for i, member in ipairs(nowDb) do
        local guildMember = guildMembers[member.name]
        if guildMember.rank == fromRank then
            if strlen(guildMember.name) <= 48 then
                promoteWith(guildMember.name)
            else
                print("Can't promote: " .. guildMember.name)
            end
        end
    end
end

function module:PromoteAll()
    self:_ChangeRank(self.db.raiderRank, GuildPromote)
end

function module:DemoteAll()
    self:_ChangeRank(self.db.activeRaiderRank, function(name)
        GuildDemote(Ambiguate(name, 'guild'))
    end)
end

function module:slash(argL, arg)
    if argL:find("^raidroster ?") or argL:find("^rr ?") then
        if argL == "raidroster" or argL == "rr" then
            ExRT.Options:Open(module.options)
        elseif argL:find('addmember ') ~= nil then
            local name = arg:match("addmember[ ]+([^ ]+)")
            self:AddMember(self:_NormalizeName(name))
            self:ReloadUI()
        elseif argL:find('addall$') ~= nil then
            self:AddPartyOrRaidMembers()
            self:ReloadUI()
        elseif argL:find("invite$") ~= nil then
            self:InviteAll()
        elseif argL:find("removemember ") ~= nil then
            local name = argL:match("removemember[ ]+([^ ]+)")
            self:RemoveMember(self:_NormalizeName(name))
            self:ReloadUI()
        elseif argL:find("removeallmembers$") ~= nil then
            self:RemoveAllMembers()
            self:ReloadUI()
        elseif argL:find("addallinrank ") ~= nil then
            local rank = arg:match("addallinrank[ ]+([^ ]+)")
            self:AddAllInRank(rank)
            self:ReloadUI()
        elseif argL:find("notify ") ~= nil then
            local message = arg:match("notify[ ]+(.+)")
            if message then
                self:NotifyAll(message)
            end
        elseif argL:find("promoteall$") ~= nil then
            self:PromoteAll()
        elseif argL:find("demoteall$") ~= nil then
            self:DemoteAll()
        else
            print("Unknown command: " .. argL)
        end
    end
end