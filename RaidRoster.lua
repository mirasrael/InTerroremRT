local GlobalAddonName, InTerroremRT = ...

local VInTerroremRT
local ExRT = _G.GExRT
local InviteTool = ExRT.A.InviteTool
if not InviteTool then
    return
end

local module = ExRT.mod:New("RaidRoster", InTerroremRT.L.RaidRoster, nil, true)
local ELib, L = ExRT.lib, InTerroremRT.L
local raidProfiles = {
    ["Цитадель ночи"] = {
        aliases = { "цн" },
        bosses = {
            [1] = { "Скорпирон", "скорпион" },
            [2] = { "Хрономатическая аномалия", "аномалия" },
            [3] = { "Триллиакс", "трилакс" },
            [4] = { "Заклинательница клинков Ауриэль", "ауриэль", "заклинательница" },
            [5] = { "Тихондрий" },
            [6] = { "Крос" },
            [7] = { "Верховный ботаник Тел'арн", "ботаник", "теларн" },
            [8] = { "Звездный авгур Этрей", "авгур", "этрей" },
            [9] = { "Великий магистр Элисанда", "элисанда", "магистр" },
            [10] = { "Гул'дан", "гулдан" },
        }
    },
    ["Гробница Саргераса"] = {
        aliases = { "гс", "gs", "tos" },
        bosses = {
            [1] = { "Горот", "гор" },
            [2] = { "Демоническая инквизиция", "инквизиция" },
            [3] = { "Харджатан", "хаджатан", "хадж" },
            [4] = { "Сестры Луны", "сестры" },
            [5] = { "Госпожа Сашж'ин", "госпожа", "сашж", "саш" },
            [6] = { "Сонм страданий", "сонм" },
            [7] = { "Бдительная дева", "дева" },
            [8] = { "Аватара Падшего", "аватара", "падший" },
            [9] = { "Кил'джеден", "килджеден", "килджаден" },
        }
    },
}

local raidAliasToRaidName = {}
for raidName, raidProfile in pairs(raidProfiles) do
    raidAliasToRaidName[raidName] = raidName
    for _, alias in ipairs(raidProfile.aliases) do
        raidAliasToRaidName[alias] = raidName
    end
end

module.db.perPage = 18
module.db.page = 1

function module.main:ADDON_LOADED()
    VInTerroremRT = _G.VInTerroremRT
    VInTerroremRT.RaidRoster = VInTerroremRT.RaidRoster or {}
    -- TODO: Calculate defaults based on average rank
    VInTerroremRT.RaiderRank = VInTerroremRT.RaiderRank or 'Legioner'
    VInTerroremRT.ActiveRaiderRank = VInTerroremRT.ActiveRaiderRank or 'Option'
    VInTerroremRT.SelectedRaid = VInTerroremRT.SelectedRaid or 'Гробница Саргераса'

    module:RegisterSlash()
    module:RegisterAddonMessage()

    module.db.realmName = GetRealmName():gsub(' ', '')

    module.db.raiderRank = 'Alt' -- VInTerroremRT.RaiderRank
    module.db.activeRaiderRank = VInTerroremRT.ActiveRaiderRank
    module.db.selectedRaid = VInTerroremRT.SelectedRaid

    module:_LoadVariables()
end

local function filterOutITRTMessage(self, event, msg, author)
    if event == 'CHAT_MSG_WHISPER' and msg:find("^itrt") ~= nil then
        return true
    elseif event == 'CHAT_MSG_WHISPER_INFORM' and msg:find("^<itrt>") ~= nil then
        return true
    end
    return false
end

function module:Enable()
    module:RegisterEvents('GROUP_ROSTER_UPDATE', 'CHAT_MSG_WHISPER')
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", filterOutITRTMessage)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", filterOutITRTMessage)
    module.main:GROUP_ROSTER_UPDATE()
end

function module:Disable()
    module:UnregisterEvents('GROUP_ROSTER_UPDATE', 'CHAT_MSG_WHISPER')
    ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER", filterOutITRTMessage)
    ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER_INFORM", filterOutITRTMessage)
end

function module.main:GROUP_ROSTER_UPDATE()
    module.db.guildMembers = nil
end

function module:GetBossMapping(raidName)
    local raidProfile = raidProfiles[raidName]
    local bossMapping = {}
    for bossNum, bossNames in ipairs(raidProfile.bosses) do
        local bossName = bossNames[1]
        bossMapping['' .. bossNum] = bossName
        for _, bossAlias in ipairs(bossNames) do
            bossMapping[bossAlias:lower()] = bossName
        end
    end
    return bossMapping
end

function module:HandleBossesCommand(name, args)
    local raidNames = {}
    for raidName, raidProfile in pairs(raidProfiles) do
        table.insert(raidNames, raidProfile.aliases[1] .. ' - ' .. raidName)
    end
    if #args == 1 then
        return { "Укажите рейд и список боссов через пробел (- чтобы убрать). Например: itrt b цн +1 -2 ботаник -крос" }
    end
    local raidName = raidAliasToRaidName[args[2]]
    local raidProfile = raidProfiles[raidName]
    if raidProfile == nil then
        return { format("Неизвестный рейд. Укажите один из списка: %s", table.concat(raidNames, ", ")) }
    end

    -- collect boss mappings
    -- TODO: extract to separate method or pre-cache
    local bossMapping = self:GetBossMapping(raidName)
    local bossNums = {}
    for bossNum, bossNames in ipairs(raidProfile.bosses) do
        bossNums[bossNames[1]] = bossNum
    end

    -- Collect requested boss changes
    local unknownBossNames = {}
    local includeBossNames = {}
    local excludeBossNames = {}
    for i = 3, #args do
        local arg = args[i]
        local op = arg:sub(1, 1)
        if op == '+' or op == '-' then
            arg = arg:sub(2)
        else
            op = '+'
        end
        local bossName = bossMapping[arg:lower()]
        if bossName ~= nil then
            if op == '+' then
                table.insert(includeBossNames, bossName)
            else
                table.insert(excludeBossNames, bossName)
            end
        else
            table.insert(unknownBossNames, arg)
        end
    end

    -- Get raidBosses collection (ensure it exists)
    local raidBosses = module.db.bosses[raidName]
    if raidBosses == nil then
        raidBosses = {}
        for idx, bossNames in ipairs(raidProfile.bosses) do
            raidBosses[bossNames[1]] = {}
        end
        module.db.bosses[raidName] = raidBosses
    end

    -- Collect required and non-required bosses and modify by requested changes
    name = Ambiguate(name, "all")
    local requiredBosses = {}
    local notRequiredBosses = {}
    for bossNum, bossNames in ipairs(raidProfile.bosses) do
        local required = false
        local bossName = bossNames[1]
        local players = raidBosses[bossName]
        local playerIdx = InTerroremRT.F.tindex(players, name)
        if playerIdx ~= nil then
            if InTerroremRT.F.tindex(excludeBossNames, bossName) ~= nil then
                table.remove(players, playerIdx)
            else
                table.insert(requiredBosses, bossName)
                required = true
            end
        end
        if not required then
            if InTerroremRT.F.tindex(includeBossNames, bossName) ~= nil then
                table.insert(players, name)
                table.insert(requiredBosses, bossName)
            else
                table.insert(notRequiredBosses, bossName)
            end
        end
    end

    -- Build result
    local function appendBossList(result, listName, bossList)
        if #bossList > 0 then
            local bossRefs = {}
            for _, bossName in ipairs(bossList) do
                local bossNum = bossNums[bossName]
                local bossRef = bossName
                if bossNum ~= nil then
                    bossRef = bossNum .. '-' .. bossRef
                end
                table.insert(bossRefs, bossRef)
            end
            InTerroremRT.F.buildMessageList(listName, bossRefs, ', ', function(msg) table.insert(result, msg) end, 248)
        end
    end

    module:SaveBosses()

    local result = {}
    appendBossList(result, "Нужны", requiredBosses)
    appendBossList(result, "Не нужны", notRequiredBosses)
    appendBossList(result, "Неизвестные", unknownBossNames)
    return result
end

function module.main:CHAT_MSG_WHISPER(msg, sender)
    if msg:find("^itrt") ~= nil then
        msg = msg:sub(5):gsub("^[ ]*", "")
        local parts = InTerroremRT.F.split(msg, '[%s]+', nil, true)
        local result = {}
        if #parts == 0 then
            result = { "itrt b или itrt bosses - указать список боссов" }
        else
            if parts[1] == "b" or parts[1] == "bosses" then
                result = module:HandleBossesCommand(sender, parts)
            end
        end
        for _, msg in ipairs(result) do
            SendChatMessage('<itrt> ' .. msg, "WHISPER", "Common", sender)
        end
    end
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
    module.db.bosses = raidRoster.Bosses or {}
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

function module:SaveBosses()
    local raidRoster = VInTerroremRT.RaidRoster
    raidRoster.Bosses = module.db.bosses
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

function module:ShowBossMembers(raidName, boss)
    local printFunction = print
    if IsInRaid() then
        printFunction = function(msg)
            SendChatMessage(msg, "RAID")
        end
    end
    local function printPlayers(listName, lst)
        InTerroremRT.F.buildMessageList(listName, lst, ', ', printFunction)
    end

    local bossMapping = self:GetBossMapping(raidName)
    local bossName = bossMapping[boss:lower()]
    if bossName == nil then
        print(format("[%s] Неправильное имя босса: %s", raidName, boss))
        return
    end
    printFunction(format("[%s] %s", raidName, bossName))
    local players = self.db.bosses[raidName] and self.db.bosses[raidName][bossName]
    local n = GetNumGroupMembers() or 0
    if n ~= 0 then
        local unwantedPlayers = {}
        local wantedPlayers = InTerroremRT.F.shallowcopy(players)

        for i = 1, n do
            local name, rank, subgroup = GetRaidRosterInfo(i)
            local playerIdx = InTerroremRT.F.tindex(wantedPlayers, name)
            if subgroup <= 4 then
                if playerIdx == nil then
                    table.insert(unwantedPlayers, name)
                else
                    table.remove(wantedPlayers, playerIdx)
                end
            end
        end

        printPlayers("Нужно взять", wantedPlayers)
        printPlayers("Можно заменить", unwantedPlayers)
    else
        printPlayers("Босс нужен", players)
    end
end

function module:ShowPlayerBosses(player)
    local result = self:HandleBossesCommand(player, {"b", "гс"})
    for _, msg in ipairs(result) do
        print(msg)
    end
end

function module:SelectRaid(raid)
    module.db.selectedRaid = VInTerroremRT.SelectedRaid
    VInTerroremRT.SelectedRaid = raid
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
        elseif argL:find("boss ") ~= nil then
            local boss = arg:match("boss[ ]+(.+)")
            self:ShowBossMembers(module.db.selectedRaid, boss)
        elseif argL:find("bosses ") ~= nil then
            local player = arg:match("bosses[ ]+(.+)")
            self:ShowPlayerBosses(player)
        elseif argL:find("raid ") ~= nil then
            local raid = arg:match("raid[ ]+(.+)")
            self:SelectRaid(raid)
        else
            print("Unknown command: " .. argL)
        end
    end
end