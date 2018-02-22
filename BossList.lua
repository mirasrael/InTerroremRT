--
-- Created by IntelliJ IDEA.
-- User: Alexander Bondarev
-- Date: 17-Jun-17
-- Time: 20:48
-- To change this template use File | Settings | File Templates.
--
local GlobalAddonName, InTerroremRT = ...

local tsetdefault, map, keys = InTerroremRT.F.tsetdefault, InTerroremRT.F.map, InTerroremRT.F.keys

local VInTerroremRT
local ExRT = _G.GExRT

local ELib, L = ExRT.lib, InTerroremRT.L
local module = InTerroremRT.mod:New("BossList", L.BossList, nil, true)
local raidProfiles = {}
if ExRT.locale == "ruRU" then
    raidProfiles["Цитадель Ночи"] = {
        aliases = { "цн", "nh" },
        instanceId = 786,
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
    }
    raidProfiles["Гробница Саргераса"] = {
        aliases = { "гс", "gs", "tos" },
        instanceId = 875,
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
    }
end

local function collectBosses(instanceId)
    local encounters = {}
    local encounterIndex = 1
    EJ_SelectInstance(instanceId)
    while encounterIndex > 0 do
        local name, description, encounterID = EJ_GetEncounterInfoByIndex(encounterIndex, instanceId)
        if name == nil then
            return encounters
        end
        encounters[encounterIndex] = { name }
        encounterIndex = encounterIndex + 1
    end
    return encounters
end

local function collectInstances()
    -- select last tier
    EJ_SelectTier(EJ_GetNumTiers())
    local instanceIndex = 1
    local instanceId, name, description
    while instanceIndex > 0 do
        instanceId, name, description = EJ_GetInstanceByIndex(instanceIndex, true)
        if instanceId == nil then
            return
        end
        instanceIndex = instanceIndex + 1
        if not raidProfiles[name] then
            local alias = string.gsub(name, ' ', ''):gsub(',', '')
            local raidProfile = {
                aliases = { alias },
                instanceId = instanceId,
                bosses = collectBosses(instanceId)
            }
            raidProfiles[name] = raidProfile
        end
    end
end

local raidAliasToRaidName = {}

local function buildBossLists()
    collectInstances()

    for raidName, raidProfile in pairs(raidProfiles) do
        raidAliasToRaidName[raidName] = raidName
        for _, alias in ipairs(raidProfile.aliases) do
            raidAliasToRaidName[alias] = raidName
        end
    end
end

module.db.perPage = 18
module.db.page = 1

function module.main:ADDON_LOADED()
    VInTerroremRT = _G.VInTerroremRT

    module:RegisterSlash()
    module:RegisterAddonMessage()

    module.db.realmName = GetRealmName():gsub(' ', '')

    buildBossLists()
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
    module:RegisterEvents('CHAT_MSG_WHISPER')
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", filterOutITRTMessage)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", filterOutITRTMessage)
end

function module:Disable()
    module:UnregisterEvents('CHAT_MSG_WHISPER')
    ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER", filterOutITRTMessage)
    ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER_INFORM", filterOutITRTMessage)
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

function module:_CreateBossesTable(borderList)
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

        line.encounterNeeded = ELib:Check(line, "", false):Point('TOPLEFT', 10, -5):OnClick(function(self)
            local encounterName = self:GetParent().name:GetText()
            module:_SetEncounterNeeded(module.db.selectedRaid, encounterName, self:GetChecked())
        end)
        line.name = ELib:Text(line, L.Encounter, 14):Color():Point('TOPLEFT', line.encounterNeeded, 'TOPRIGHT', 10, 4):Size(200, 30):Shadow()

        line.back = line:CreateTexture(nil, "BACKGROUND", nil, -3)
        line.back:SetPoint("TOPLEFT", 0, 0)
        line.back:SetPoint("BOTTOMRIGHT", 0, 0)
        line.back:SetColorTexture(1, 1, 1, 1)
        line.back:SetGradientAlpha("HORIZONTAL", 0, 0, 0, 1, 0, 0, 0, 0)
    end
end

function module:_SetEncounterNeeded(instanceName, encounterName, needed)
    local instanceConfig = tsetdefault(self.db.playerBosses, instanceName, {})
    local encounterConfig = tsetdefault(instanceConfig, encounterName, {})
    encounterConfig.needed = needed
end

function module:_IsEncounterNeeded(instanceName, encounterName)
    local instanceConfig = self.db.playerBosses[instanceName]
    local encounterConfig = instanceConfig and instanceConfig[encounterName]
    return encounterConfig and encounterConfig.needed
end

function module:_LoadVariables()
    if not (VInTerroremRT.SelectedRaid and raidProfiles[VInTerroremRT.SelectedRaid]) then
        VInTerroremRT.SelectedRaid = pairs(raidProfiles)(raidProfiles)
        print(VInTerroremRT.SelectedRaid)
    end
    module.db.selectedRaid = VInTerroremRT.SelectedRaid
    module.db.bosses = VInTerroremRT.Bosses or {}
    module.db.raidLeader = VInTerroremRT.RaidLeader or ''
    -- player selected bosess for each raid
    module.db.playerBosses = tsetdefault(VInTerroremRT, 'PlayerBosses', {})
end

function module.options:_CreateScrollableTable(options, titleProvider, itemsProvider, itemRenderer)
    local perPage = module.db.perPage
    local borderList = CreateFrame("Frame", nil, self)

    borderList:SetSize(648, perPage * 30)
    ELib:Border(borderList, 2, .24, .25, .30, 1)

    borderList:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            options.ScrollBar.buttonUP:Click("LeftButton")
        else
            options.ScrollBar.buttonDown:Click("LeftButton")
        end
    end)

    borderList.ScrollBar = ELib:ScrollBar(borderList):Size(16, 0):Point("TOPRIGHT", -3, -3):Point("BOTTOMRIGHT", -3, 3):Range(1, 20)

    function borderList:Invalidate()
        local count = #itemsProvider()
        borderList.ScrollBar:SetMinMaxValues(1, max(count - perPage + 1, 1)):UpdateButtons()
        options.ReloadPage()
    end

    function options.ReloadPage()
        local nowDb = itemsProvider()
        options.title:SetText(titleProvider(nowDb))

        local scrollNow = ExRT.F.Round(borderList.ScrollBar:GetValue())
        local linesToShow = math.min(perPage, #nowDb - scrollNow + 1)
        for i = scrollNow, scrollNow + linesToShow - 1 do
            local line = options.lines[i - scrollNow + 1]
            local data = nowDb[i]
            itemRenderer(line, data)
            line:Show()
        end
        for i = linesToShow + 1, perPage do
            options.lines[i]:Hide()
        end
    end

    borderList.ScrollBar:SetScript("OnValueChanged", options.ReloadPage)
    module:_CreateBossesTable(borderList)

    return borderList
end

function module.options:_CreateBossListPage()
    -- boss table
    local titleProvider = function(items)
        return L.BossList
    end
    local itemsProvider = function()
        return raidProfiles[module.db.selectedRaid].bosses
    end
    local itemRenderer = function(line, data)
        local encounterName = data[1]
        line.name:SetText(encounterName)
        line.encounterNeeded:SetChecked(module:_IsEncounterNeeded(module.db.selectedRaid, encounterName))
    end
    self.borderList = module.options:_CreateScrollableTable(module.options, titleProvider, itemsProvider, itemRenderer)
    self.borderList:SetPoint("TOP", 0, -25)

    -- raid switcher
    local raidNames = keys(raidProfiles)
    self.selectedRaidDropDown = ELib:DropDown(self, 200, #raidNames):Point('TOPRIGHT', -5, 0):Size(200):SetText(module.db.selectedRaid)
    function self.selectedRaidDropDown:SetValue(raidName)
        module:SelectRaid(raidName)
        module.options.selectedRaidDropDown:SetText(raidName)
        ELib:DropDownClose()
    end

    self.selectedRaidDropDown.List = map(raidNames, function(raidName)
        return {
            text = raidName,
            arg1 = raidName,
            func = self.selectedRaidDropDown.SetValue
        }
    end)

    -- send block
    self.txtRaidLeaderName = ELib:Text(self, L.RaidLeader, 14):Point('TOPLEFT', self.borderList, 'BOTTOMLEFT', 0, -18)
    self.edtRaidLeaderName = ELib:Edit(self):Point('TOPLEFT', self.txtRaidLeaderName, 'TOPRIGHT', 10, 3):Size(200, 20):Text(module.db.raidLeader):OnChange(function(self)
        module:SetRaidLeader(self:GetText())
    end)
    self.btnSend = ELib:Button(self, L.SendToRaidLeader):Point('TOPRIGHT', self.borderList, 'BOTTOMRIGHT', 0, -15):Size(150, 22)
    self.btnSend:Point('TOPLEFT', self.edtRaidLeaderName, 'TOPRIGHT', 10, 1)
    self.btnSend:OnClick(function()
        module:SendPlayerBosses(module.db.selectedRaid)
    end)
end

function module:addonMessage(sender, prefix, ...)
end

function module.options:Load()
    self:CreateTilte()
    self:_CreateBossListPage()

    function module.options.showPage()
        module.options.borderList:Invalidate()
    end

    self.OnShow_disableNil = true
    self:SetScript("OnShow", module.options.showPage)
    self:showPage()
end

function module:ReloadUI()
    if module.options.borderList ~= nil then
        module.options.borderList:Invalidate()
    end
end

function module:SaveBosses()
    VInTerroremRT.Bosses = module.db.bosses
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
    local players = (self.db.bosses[raidName] and self.db.bosses[raidName][bossName]) or {}
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
    local result = self:HandleBossesCommand(player, { "b", "гс" })
    for _, msg in ipairs(result) do
        print(msg)
    end
end

function module:SendPlayerBosses(targetIstanceName)
    for instanceName, raidProfile in pairs(raidProfiles) do
        if not targetIstanceName or instanceName == targetIstanceName then
            local msg = 'itrt b ' .. raidProfile.aliases[1]
            for no, encounterNames in ipairs(raidProfile.bosses) do
                local encounterName = encounterNames[1]
                if self:_IsEncounterNeeded(instanceName, encounterName) then
                    msg = msg .. ' ' .. no
                else
                    msg = msg .. ' -' .. no
                end
            end
            SendChatMessage(msg, "WHISPER", "Common", module.db.raidLeader)
        end
    end
end

function module:SelectRaid(raid)
    local resolvedRaidName = raidAliasToRaidName[raid]
    if resolvedRaidName == nil then
        print("Invalid raid name: " .. raid)
        return
    end
    module.db.selectedRaid = resolvedRaidName
    VInTerroremRT.SelectedRaid = module.db.selectedRaid
    self:ReloadUI()
end

function module:SetRaidLeader(raidLeaderName)
    VInTerroremRT.RaidLeader = raidLeaderName
    module.db.raidLeader = VInTerroremRT.RaidLeader
end

function module:slash(argL, arg)
    if argL:find("^bosslist ?") or argL:find("^b ?") then
        if argL == "bosslist" or argL == "b" then
            ExRT.Options:Open(module.options)
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

