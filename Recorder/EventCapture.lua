local addonName, ns = ...
ns = ns or _G.RXP_Studio or {}
_G.RXP_Studio = ns

ns.Recorder = ns.Recorder or {}
local Recorder = ns.Recorder

-- ============================================================================
-- Constants & State Initialization
-- ============================================================================

Recorder.LOGIN_COOLDOWN_SECONDS = 3.0
Recorder.DEDUP_WINDOW_SECONDS = 15.0
Recorder.DEATHSKIP_MIN_YARDS = 80.0

Recorder.isRecording = (Recorder.isRecording ~= nil) and Recorder.isRecording or true
Recorder.loginTimestamp = Recorder.loginTimestamp or 0
Recorder.questSnapshot = Recorder.questSnapshot or {}
Recorder.questTitles = Recorder.questTitles or {}
Recorder.watchedQuestIds = Recorder.watchedQuestIds or {}
Recorder.completedObjectives = Recorder.completedObjectives or {}
Recorder.deathState = nil
Recorder.lastTrainerVisit = { npc = nil, time = -100, zone = nil }
Recorder.lastVendorVisit = { npc = nil, time = -100, zone = nil }
Recorder.lastBinderRecord = { loc = nil, time = -100 }
Recorder.lastTaxiNPC = nil
Recorder.hooksInstalled = false

local _recorderCardIdSeq = 700000

local function getNow()
    if type(_G.GetTime) == "function" then
        local t = _G.GetTime()
        if type(t) == "number" then
            return t
        end
    end
    if type(os) == "table" and type(os.clock) == "function" then
        return os.clock()
    end
    return 0
end

local function trim(s)
    if type(s) ~= "string" then return "" end
    return s:match("^%s*(.-)%s*$") or ""
end

local function roundCoord(val)
    local n = tonumber(val)
    if not n then return nil end
    return math.floor(n * 100 + 0.5) / 100
end

local function nextCardId()
    if ns.Core and type(ns.Core.NextId) == "function" then
        return ns.Core:NextId()
    end
    _recorderCardIdSeq = _recorderCardIdSeq + 1
    return _recorderCardIdSeq
end

-- ============================================================================
-- Position & Relevant NPC Target Helpers
-- ============================================================================

function Recorder:GetPlayerLocation()
    local mapID = nil
    local zoneName = nil
    local x, y = nil, nil

    local C_Map = _G.C_Map
    if C_Map and type(C_Map.GetBestMapForUnit) == "function" then
        mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            if type(C_Map.GetMapInfo) == "function" then
                local info = C_Map.GetMapInfo(mapID)
                if info and type(info.name) == "string" and info.name ~= "" then
                    zoneName = info.name
                end
            end
            if type(C_Map.GetPlayerMapPosition) == "function" then
                local pos = C_Map.GetPlayerMapPosition(mapID, "player")
                if pos then
                    local px, py
                    if type(pos.GetXY) == "function" then
                        px, py = pos:GetXY()
                    else
                        px, py = pos.x, pos.y
                    end
                    if type(px) == "number" and type(py) == "number" and (px > 0 or py > 0) then
                        x = roundCoord(px * 100)
                        y = roundCoord(py * 100)
                    end
                end
            end
        end
    end

    if (not zoneName or zoneName == "") and type(_G.GetRealZoneText) == "function" then
        local rz = _G.GetRealZoneText()
        if type(rz) == "string" and rz ~= "" then
            zoneName = rz
        end
    end

    if (not zoneName or zoneName == "") and type(_G.GetZoneText) == "function" then
        local zt = _G.GetZoneText()
        if type(zt) == "string" and zt ~= "" then
            zoneName = zt
        end
    end

    return zoneName, x, y, mapID
end

-- Prevents legacy RXP_Recorder bug where stale dead/hostile mob targets (e.g. Battleboar,
-- Prairie Stalker) polluted GameObject quest accepts and turn-ins.
function Recorder:GetRelevantNPCName(isInteractionEvent)
    if isInteractionEvent == nil then
        isInteractionEvent = true
    end

    local UnitExists = _G.UnitExists
    local UnitName = _G.UnitName
    local UnitIsDead = _G.UnitIsDead
    local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
    local UnitCanAttack = _G.UnitCanAttack
    local UnitIsUnit = _G.UnitIsUnit

    -- 1. Prefer the active dialog/interaction unit token ("npc" / "questnpc")
    if type(UnitExists) == "function" and type(UnitName) == "function" then
        if UnitExists("npc") then
            if not (type(UnitIsUnit) == "function" and UnitIsUnit("npc", "player")) then
                local npcName = UnitName("npc")
                if type(npcName) == "string" and trim(npcName) ~= "" and npcName ~= _G.UNKNOWNOBJECT then
                    return trim(npcName)
                end
            end
        end
        if UnitExists("questnpc") then
            if not (type(UnitIsUnit) == "function" and UnitIsUnit("questnpc", "player")) then
                local qNpcName = UnitName("questnpc")
                if type(qNpcName) == "string" and trim(qNpcName) ~= "" and qNpcName ~= _G.UNKNOWNOBJECT then
                    return trim(qNpcName)
                end
            end
        end
    end

    -- 2. Fall back to "target" ONLY if valid for the interaction context
    if type(UnitExists) == "function" and type(UnitName) == "function" and UnitExists("target") then
        if type(UnitIsUnit) == "function" and UnitIsUnit("target", "player") then
            return nil
        end

        if isInteractionEvent then
            if type(UnitIsDead) == "function" and UnitIsDead("target") then
                return nil
            end
            if type(UnitIsDeadOrGhost) == "function" and UnitIsDeadOrGhost("target") then
                return nil
            end
            if type(UnitCanAttack) == "function" and UnitCanAttack("player", "target") then
                return nil
            end
        end

        local targetName = UnitName("target")
        if type(targetName) == "string" and trim(targetName) ~= "" and targetName ~= _G.UNKNOWNOBJECT then
            return trim(targetName)
        end
    end

    return nil
end

function Recorder:GetRelevantCombatMobName()
    local UnitExists = _G.UnitExists
    local UnitName = _G.UnitName
    local UnitCanAttack = _G.UnitCanAttack
    if type(UnitExists) == "function" and type(UnitName) == "function" and UnitExists("target") then
        if type(UnitCanAttack) ~= "function" or UnitCanAttack("player", "target") then
            local mobName = UnitName("target")
            if type(mobName) == "string" and trim(mobName) ~= "" and mobName ~= _G.UNKNOWNOBJECT then
                return trim(mobName)
            end
        end
    end
    return nil
end

-- ============================================================================
-- Quest Title & Objective Snapshot Helpers
-- ============================================================================

function Recorder:GetQuestTitleByID(questId, questLogIndex)
    local qid = tonumber(questId)
    if not qid then return "Unknown Quest" end

    if self.questTitles[qid] and self.questTitles[qid] ~= "" then
        return self.questTitles[qid]
    end
    if self.questSnapshot[qid] and self.questSnapshot[qid].title and self.questSnapshot[qid].title ~= "" then
        return self.questSnapshot[qid].title
    end

    local C_QuestLog = _G.C_QuestLog
    if C_QuestLog then
        if type(C_QuestLog.GetTitleForQuestID) == "function" then
            local t = C_QuestLog.GetTitleForQuestID(qid)
            if type(t) == "string" and trim(t) ~= "" then
                self.questTitles[qid] = trim(t)
                return self.questTitles[qid]
            end
        end
        if type(C_QuestLog.GetQuestInfo) == "function" then
            local t = C_QuestLog.GetQuestInfo(qid)
            if type(t) == "string" and trim(t) ~= "" then
                self.questTitles[qid] = trim(t)
                return self.questTitles[qid]
            end
        end
    end

    local GetQuestLogTitle = _G.GetQuestLogTitle
    local GetNumQuestLogEntries = _G.GetNumQuestLogEntries
    if type(GetQuestLogTitle) == "function" then
        local idx = tonumber(questLogIndex)
        if idx and idx > 0 and idx <= 100 then
            local title, _, _, isHeader, _, _, _, entryQuestId = GetQuestLogTitle(idx)
            if not isHeader and type(title) == "string" and trim(title) ~= "" then
                if not entryQuestId or tonumber(entryQuestId) == qid then
                    self.questTitles[qid] = trim(title)
                    return self.questTitles[qid]
                end
            end
        end
        if type(GetNumQuestLogEntries) == "function" then
            local numEntries = GetNumQuestLogEntries() or 0
            for i = 1, numEntries do
                local title, _, _, isHeader, _, _, _, entryQuestId = GetQuestLogTitle(i)
                if not isHeader and tonumber(entryQuestId) == qid and type(title) == "string" and trim(title) ~= "" then
                    self.questTitles[qid] = trim(title)
                    return self.questTitles[qid]
                end
            end
        end
    end

    if type(_G.GetTitleText) == "function" then
        local dialogTitle = _G.GetTitleText()
        if type(dialogTitle) == "string" and trim(dialogTitle) ~= "" then
            self.questTitles[qid] = trim(dialogTitle)
            return self.questTitles[qid]
        end
    end

    return "Quest " .. tostring(qid)
end

local function parseObjectiveBoardText(rawText, numFulfilled, numRequired)
    local text = trim(rawText or "")
    local cur = tonumber(numFulfilled)
    local max = tonumber(numRequired)
    local desc = text

    -- Format 1: "Juvenile Vuldren slain: 8/8" -> "8/8 Juvenile Vuldren slain"
    local namePart, c1, m1 = text:match("^(.-)%s*:%s*(%d+)%s*/%s*(%d+)%s*$")
    if namePart and c1 and m1 then
        cur = cur or tonumber(c1)
        max = max or tonumber(m1)
        desc = trim(namePart)
        return cur, max, string.format("%d/%d %s", cur, max, desc), desc
    end

    -- Format 2: "8/8 Juvenile Vuldren slain"
    local c2, m2, rest = text:match("^(%d+)%s*/%s*(%d+)%s*(.-)$")
    if c2 and m2 then
        cur = cur or tonumber(c2)
        max = max or tonumber(m2)
        desc = trim(rest)
        if desc ~= "" then
            return cur, max, string.format("%d/%d %s", cur, max, desc), desc
        else
            return cur, max, text, ""
        end
    end

    -- Format 3: Explicit numeric counters + plain description
    if cur and max and max > 0 then
        if desc ~= "" then
            return cur, max, string.format("%d/%d %s", cur, max, desc), desc
        else
            return cur, max, string.format("%d/%d", cur, max), ""
        end
    end

    return cur or 0, max or 0, text, desc
end

local function isUnloadedObjectiveCacheText(formattedText, rawDesc)
    local clean = trim(formattedText or "")
    if clean == "" then return true end
    -- Guard against unloaded creature/item cache on login: e.g. "1/1  " or "1/1   slain"
    if clean:match("^%d+/%d+%s*$") then
        return true
    end
    if clean:match("^%d+/%d+%s+slain%s*$") then
        return true
    end
    if rawDesc and trim(rawDesc) == "slain" then
        return true
    end
    return false
end

function Recorder:IsInLoginCooldown()
    if not self.loginTimestamp or self.loginTimestamp <= 0 then
        return false
    end
    local now = getNow()
    return (now - self.loginTimestamp) < self.LOGIN_COOLDOWN_SECONDS
end

function Recorder:ReadQuestObjectivesFromClient()
    local quests = {}
    local GetNumQuestLogEntries = _G.GetNumQuestLogEntries
    local GetQuestLogTitle = _G.GetQuestLogTitle
    local GetNumQuestLeaderBoards = _G.GetNumQuestLeaderBoards
    local GetQuestLogLeaderBoard = _G.GetQuestLogLeaderBoard
    local C_QuestLog = _G.C_QuestLog

    if type(GetNumQuestLogEntries) == "function" and type(GetQuestLogTitle) == "function" then
        local numEntries = GetNumQuestLogEntries() or 0
        for i = 1, numEntries do
            local title, _, _, isHeader, _, _, _, questId = GetQuestLogTitle(i)
            local qid = tonumber(questId)
            if not isHeader and qid and qid > 0 then
                if type(title) == "string" and trim(title) ~= "" then
                    self.questTitles[qid] = trim(title)
                end
                local objList = {}
                local usedCQuestLog = false
                if C_QuestLog and type(C_QuestLog.GetQuestObjectives) == "function" then
                    local cObjs = C_QuestLog.GetQuestObjectives(qid)
                    if type(cObjs) == "table" and #cObjs > 0 then
                        usedCQuestLog = true
                        for objIdx = 1, #cObjs do
                            local o = cObjs[objIdx]
                            if o then
                                local cur, max, formatted, rawDesc = parseObjectiveBoardText(o.text, o.numFulfilled, o.numRequired)
                                local done = (o.finished == true) or (max and max > 0 and cur >= max) or false
                                objList[objIdx] = {
                                    numFulfilled = cur,
                                    numRequired = max,
                                    objText = formatted,
                                    rawDesc = rawDesc,
                                    finished = done,
                                }
                            end
                        end
                    end
                end

                if not usedCQuestLog and type(GetNumQuestLeaderBoards) == "function" and type(GetQuestLogLeaderBoard) == "function" then
                    local numObj = GetNumQuestLeaderBoards(i) or 0
                    for objIdx = 1, numObj do
                        local text, _, finished = GetQuestLogLeaderBoard(objIdx, i)
                        local cur, max, formatted, rawDesc = parseObjectiveBoardText(text, nil, nil)
                        local done = (finished == true or finished == 1) or (max and max > 0 and cur >= max) or false
                        objList[objIdx] = {
                            numFulfilled = cur,
                            numRequired = max,
                            objText = formatted,
                            rawDesc = rawDesc,
                            finished = done,
                        }
                    end
                end

                quests[qid] = {
                    questId = qid,
                    title = self.questTitles[qid] or title or ("Quest " .. tostring(qid)),
                    objectives = objList,
                }
            end
        end
    elseif C_QuestLog and type(C_QuestLog.GetNumQuestLogEntries) == "function" then
        local numEntries = C_QuestLog.GetNumQuestLogEntries() or 0
        for i = 1, numEntries do
            local info = C_QuestLog.GetInfo and C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.questID then
                local qid = tonumber(info.questID)
                if info.title then self.questTitles[qid] = info.title end
                local objList = {}
                local cObjs = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(qid)
                if type(cObjs) == "table" then
                    for objIdx = 1, #cObjs do
                        local o = cObjs[objIdx]
                        if o then
                            local cur, max, formatted, rawDesc = parseObjectiveBoardText(o.text, o.numFulfilled, o.numRequired)
                            local done = (o.finished == true) or (max and max > 0 and cur >= max) or false
                            objList[objIdx] = {
                                numFulfilled = cur,
                                numRequired = max,
                                objText = formatted,
                                rawDesc = rawDesc,
                                finished = done,
                            }
                        end
                    end
                end
                quests[qid] = {
                    questId = qid,
                    title = self.questTitles[qid] or ("Quest " .. tostring(qid)),
                    objectives = objList,
                }
            end
        end
    end

    return quests
end

function Recorder:UpdateQuestSnapshot(allowRecordTransitions)
    local inCooldown = self:IsInLoginCooldown()
    local shouldRecord = allowRecordTransitions and self.isRecording and not inCooldown
    local currentQuests = self:ReadQuestObjectivesFromClient()

    for qid, qData in pairs(currentQuests) do
        local prevQuest = self.questSnapshot[qid]
        if not prevQuest then
            -- First time seeing this quest in snapshot.
            -- Only record transition if this quest was explicitly flagged by QUEST_WATCH_UPDATE
            -- after the login cooldown (prevents unaccepted login-flush quests in Kalimdor).
            self.questSnapshot[qid] = {
                questId = qid,
                title = qData.title,
                objectives = {},
            }
            for objIdx, obj in pairs(qData.objectives) do
                self.questSnapshot[qid].objectives[objIdx] = {
                    numFulfilled = obj.numFulfilled,
                    numRequired = obj.numRequired,
                    objText = obj.objText,
                    finished = obj.finished,
                }
                if shouldRecord and self.watchedQuestIds[qid] and obj.finished then
                    self:TryRecordObjectiveComplete(qid, objIdx, obj)
                end
            end
        else
            prevQuest.title = qData.title or prevQuest.title
            for objIdx, obj in pairs(qData.objectives) do
                local prevObj = prevQuest.objectives[objIdx]
                local wasComplete = prevObj and prevObj.finished
                if prevObj and prevObj.numRequired and prevObj.numRequired > 0 and prevObj.numFulfilled >= prevObj.numRequired then
                    wasComplete = true
                end

                local isNowComplete = obj.finished or (obj.numRequired and obj.numRequired > 0 and obj.numFulfilled >= obj.numRequired)
                if shouldRecord and not wasComplete and isNowComplete then
                    self:TryRecordObjectiveComplete(qid, objIdx, obj)
                end

                prevQuest.objectives[objIdx] = {
                    numFulfilled = obj.numFulfilled,
                    numRequired = obj.numRequired,
                    objText = obj.objText,
                    finished = isNowComplete and true or false,
                }
            end
        end
        self.watchedQuestIds[qid] = nil
    end
end

function Recorder:TryRecordObjectiveComplete(questId, objIndex, objData)
    local qid = tonumber(questId)
    local oIdx = tonumber(objIndex) or 1
    if not qid or not objData then return nil end

    -- Skip unloaded cache strings ("1/1  " or "1/1   slain")
    if isUnloadedObjectiveCacheText(objData.objText, objData.rawDesc) then
        return nil
    end

    local zone, x, y = self:GetPlayerLocation()
    -- Extra protection against continent-level "Kalimdor" login flushes for unaccepted quests
    if zone == "Kalimdor" and not self.questTitles[qid] then
        return nil
    end

    local dedupKey = tostring(qid) .. ":" .. tostring(oIdx)
    local now = getNow()
    if self.completedObjectives[dedupKey] and (now - self.completedObjectives[dedupKey]) < self.DEDUP_WINDOW_SECONDS then
        return nil
    end
    self.completedObjectives[dedupKey] = now

    local mobName = self:GetRelevantCombatMobName()
    local card = self:CommitAction({
        type = "complete",
        questId = qid,
        questTitle = self:GetQuestTitleByID(qid),
        objIndex = oIdx,
        objMax = objData.numRequired,
        objText = objData.objText,
        text = objData.objText,
        zone = zone,
        x = x,
        y = y,
    }, {
        zone = zone,
        x = x,
        y = y,
        mobs = mobName and { mobName } or {},
    })

    return card
end

-- ============================================================================
-- Core Action & Card Commit Pipeline
-- ============================================================================

function Recorder:GetOrCreateActiveGuide()
    if ns.Core then
        if type(ns.Core.GetActiveGuide) == "function" then
            local g = ns.Core:GetActiveGuide()
            if g then return g end
        end
        if type(ns.Core.InitDB) == "function" then
            ns.Core:InitDB()
            if type(ns.Core.GetActiveGuide) == "function" then
                local g = ns.Core:GetActiveGuide()
                if g then return g end
            end
        end
    end

    -- Fallback guide structure for standalone/headless environments when Core isn't initialized yet
    _G.RXP_StudioDB = _G.RXP_StudioDB or {
        version = 1,
        activeGuideId = "default",
        guides = {},
        settings = { autoMerge = true, autoMergeRadius = 15, showHUD = true, rawSyntaxMode = false },
    }
    if not _G.RXP_StudioDB.guides["default"] and not _G.RXP_StudioDB.guides[1] then
        local defaultGuide = {
            id = "default",
            name = "01-12 Recorded Speedrun",
            group = "My Recorded Guides",
            subgroup = "",
            version = 1,
            faction = "",
            classes = {},
            races = {},
            steps = {},
        }
        _G.RXP_StudioDB.guides[1] = defaultGuide
        _G.RXP_StudioDB.guides["default"] = defaultGuide
    end
    return _G.RXP_StudioDB.guides["default"] or _G.RXP_StudioDB.guides[1]
end

function Recorder:BuildCardFromAction(action, cardMeta)
    cardMeta = cardMeta or {}
    local zone = cardMeta.zone or action.zone
    local x = cardMeta.x or action.x
    local y = cardMeta.y or action.y
    if not zone then
        local pz, px, py = self:GetPlayerLocation()
        zone = zone or pz
        x = x or px
        y = y or py
    end

    action.zone = action.zone or zone
    action.x = action.x or x
    action.y = action.y or y

    local targets = {}
    if type(cardMeta.targets) == "table" then
        for i = 1, #cardMeta.targets do
            table.insert(targets, cardMeta.targets[i])
        end
    elseif action.target and trim(action.target) ~= "" then
        table.insert(targets, trim(action.target))
    end

    local mobs = {}
    if type(cardMeta.mobs) == "table" then
        for i = 1, #cardMeta.mobs do
            table.insert(mobs, cardMeta.mobs[i])
        end
    end

    return {
        id = nextCardId(),
        title = cardMeta.title or "",
        zone = zone,
        x = x,
        y = y,
        loopWaypoints = {},
        targets = targets,
        mobs = mobs,
        sticky = cardMeta.sticky or false,
        completeWithNext = cardMeta.completeWithNext or false,
        optional = cardMeta.optional or false,
        hideWindow = cardMeta.hideWindow or false,
        loop = cardMeta.loop or false,
        completeTogether = true,
        note = cardMeta.note or "",
        conditions = { classes = {}, races = {} },
        rawOverride = nil,
        actions = { action },
        lintIssues = {},
    }
end

function Recorder:CommitAction(action, cardMeta, mergeOptions)
    if not action then return nil end
    local guide = self:GetOrCreateActiveGuide()
    if not guide then return nil end

    local newCard = self:BuildCardFromAction(action, cardMeta)
    local resultCard, wasMerged, stepIndex

    if ns.AutoMerger and type(ns.AutoMerger.AppendOrMergeCard) == "function" then
        resultCard, wasMerged, stepIndex = ns.AutoMerger:AppendOrMergeCard(guide, newCard, mergeOptions)
    else
        guide.steps = guide.steps or {}
        table.insert(guide.steps, newCard)
        resultCard = newCard
        wasMerged = false
        stepIndex = #guide.steps
        if ns.FireCallback then
            ns:FireCallback("STEP_RECORDED", resultCard, guide, stepIndex, false)
            ns:FireCallback("GUIDE_UPDATED", guide)
        end
    end

    -- Also mirror raw step string to RXP_RecorderDB.steps if legacy table exists
    if type(_G.RXP_RecorderDB) == "table" and type(_G.RXP_RecorderDB.steps) == "table" then
        if ns.Compiler and type(ns.Compiler.CompileStepCard) == "function" then
            local rawStep = ns.Compiler:CompileStepCard(newCard)
            if type(rawStep) == "string" and rawStep ~= "" then
                table.insert(_G.RXP_RecorderDB.steps, rawStep)
            end
        end
    end

    return resultCard, wasMerged, stepIndex
end

-- ============================================================================
-- Recording Control API
-- ============================================================================

function Recorder:SetRecording(enabled)
    self.isRecording = enabled and true or false
    if type(_G.RXP_RecorderDB) == "table" then
        _G.RXP_RecorderDB.isRecording = self.isRecording
    end
    if ns.FireCallback then
        ns:FireCallback("RECORDING_STATE_CHANGED", self.isRecording)
    end
    if ns.Print then
        if self.isRecording then
            ns:Print("Live recording |cff10B981RESUMED|r.")
        else
            ns:Print("Live recording |cffF59E0BPAUSED|r.")
        end
    end
    return self.isRecording
end

function Recorder:IsRecording()
    return self.isRecording and true or false
end

function Recorder:ToggleRecording()
    return self:SetRecording(not self.isRecording)
end

-- ============================================================================
-- WoW Event Handlers
-- ============================================================================

function Recorder:HandlePlayerEnteringWorld()
    self.loginTimestamp = getNow()
    self.watchedQuestIds = {}
    self:UpdateQuestSnapshot(false)
end

function Recorder:HandleQuestAccepted(arg1, arg2)
    if not self.isRecording then return nil end

    local questLogIndex, questId
    if arg2 ~= nil then
        questLogIndex = tonumber(arg1)
        questId = tonumber(arg2)
    else
        questId = tonumber(arg1)
    end
    if not questId or questId <= 0 then return nil end

    local questTitle = self:GetQuestTitleByID(questId, questLogIndex)
    self.questTitles[questId] = questTitle

    -- Initialize quest snapshot entry so objective tracking knows this quest is active
    self.questSnapshot[questId] = self.questSnapshot[questId] or {
        questId = questId,
        title = questTitle,
        objectives = {},
    }

    local zone, x, y = self:GetPlayerLocation()
    local npcName = self:GetRelevantNPCName(true)

    return self:CommitAction({
        type = "accept",
        questId = questId,
        questTitle = questTitle,
        text = "Accept " .. questTitle,
        target = npcName,
        zone = zone,
        x = x,
        y = y,
    })
end

function Recorder:HandleQuestTurnedIn(questId, xpReward, moneyReward)
    if not self.isRecording then return nil end

    local qid = tonumber(questId)
    if not qid or qid <= 0 then return nil end

    local questTitle = self:GetQuestTitleByID(qid)
    local zone, x, y = self:GetPlayerLocation()
    local npcName = self:GetRelevantNPCName(true)

    self.questSnapshot[qid] = nil
    self.watchedQuestIds[qid] = nil

    return self:CommitAction({
        type = "turnin",
        questId = qid,
        questTitle = questTitle,
        text = "Turn in " .. questTitle,
        target = npcName,
        zone = zone,
        x = x,
        y = y,
    })
end

function Recorder:HandleQuestWatchUpdate(questLogIndexOrId)
    local val = tonumber(questLogIndexOrId)
    if val then
        if type(_G.GetQuestLogTitle) == "function" and val <= 100 then
            local _, _, _, isHeader, _, _, _, qid = _G.GetQuestLogTitle(val)
            if not isHeader and tonumber(qid) then
                self.watchedQuestIds[tonumber(qid)] = true
            else
                self.watchedQuestIds[val] = true
            end
        else
            self.watchedQuestIds[val] = true
        end
    end
    if self.isRecording and not self:IsInLoginCooldown() then
        self:UpdateQuestSnapshot(true)
    end
end

function Recorder:HandleQuestLogUpdate()
    if self:IsInLoginCooldown() then
        self:UpdateQuestSnapshot(false)
        return
    end
    self:UpdateQuestSnapshot(self.isRecording)
end

function Recorder:HandleUIInfoMessage(errorType, message)
    if not self.isRecording or self:IsInLoginCooldown() then return end
    if type(message) == "string" then
        -- Detect new flight path discovered message if applicable
        if _G.ERR_NEWTAXIPATH and message == _G.ERR_NEWTAXIPATH then
            local zone, x, y = self:GetPlayerLocation()
            local npcName = self:GetRelevantNPCName(true)
            local subzone = (type(_G.GetSubZoneText) == "function" and trim(_G.GetSubZoneText())) or ""
            local dest = (subzone ~= "" and subzone) or zone or "Flight Path"
            self:CommitAction({
                type = "fp",
                destination = dest,
                text = "Get the " .. dest .. " flight path",
                target = npcName,
                zone = zone,
                x = x,
                y = y,
            })
            return
        end
    end
    self:UpdateQuestSnapshot(true)
end

function Recorder:HandleTrainerShow()
    if not self.isRecording then return nil end

    local zone, x, y = self:GetPlayerLocation()
    local npcName = self:GetRelevantNPCName(true)
    local now = getNow()

    if self.lastTrainerVisit.npc == (npcName or "") and
       self.lastTrainerVisit.zone == (zone or "") and
       (now - self.lastTrainerVisit.time) < self.DEDUP_WINDOW_SECONDS then
        return nil
    end

    self.lastTrainerVisit = { npc = npcName or "", zone = zone or "", time = now }

    return self:CommitAction({
        type = "trainer",
        text = "Train spells",
        target = npcName,
        zone = zone,
        x = x,
        y = y,
    })
end

function Recorder:HandleMerchantShow()
    if not self.isRecording then return nil end

    local zone, x, y = self:GetPlayerLocation()
    local npcName = self:GetRelevantNPCName(true)
    local now = getNow()

    if self.lastVendorVisit.npc == (npcName or "") and
       self.lastVendorVisit.zone == (zone or "") and
       (now - self.lastVendorVisit.time) < self.DEDUP_WINDOW_SECONDS then
        return nil
    end

    self.lastVendorVisit = { npc = npcName or "", zone = zone or "", time = now }

    return self:CommitAction({
        type = "vendor",
        text = "Sell junk / resupply",
        target = npcName,
        zone = zone,
        x = x,
        y = y,
    })
end

function Recorder:OnBuyMerchantItem(index, quantity)
    if not self.isRecording then return nil end
    local itemName = nil
    if type(_G.GetMerchantItemInfo) == "function" and index then
        itemName = _G.GetMerchantItemInfo(index)
    end
    local zone, x, y = self:GetPlayerLocation()
    local npcName = self:GetRelevantNPCName(true) or self.lastVendorVisit.npc
    local label = "Sell junk / resupply"
    if type(itemName) == "string" and trim(itemName) ~= "" then
        local qty = tonumber(quantity) or 1
        if qty > 1 then
            label = string.format("Buy %dx %s", qty, trim(itemName))
        else
            label = "Buy " .. trim(itemName)
        end
    end

    -- If the active guide's last step already has a vendor action for this NPC, update its label
    local guide = self:GetOrCreateActiveGuide()
    if guide and guide.steps and #guide.steps > 0 then
        local lastCard = guide.steps[#guide.steps]
        if lastCard and type(lastCard.actions) == "table" then
            for i = #lastCard.actions, 1, -1 do
                local act = lastCard.actions[i]
                if act.type == "vendor" then
                    if itemName and trim(itemName) ~= "" then
                        act.text = label
                        if ns.FireCallback then
                            ns:FireCallback("GUIDE_UPDATED", guide)
                        end
                    end
                    return lastCard
                end
            end
        end
    end

    return self:CommitAction({
        type = "vendor",
        text = label,
        target = (npcName ~= "" and npcName) or nil,
        zone = zone,
        x = x,
        y = y,
    })
end

function Recorder:HandleBindHearthstone()
    if not self.isRecording then return nil end

    local now = getNow()
    local bindLoc = (type(_G.GetBindLocation) == "function" and trim(_G.GetBindLocation())) or ""
    if bindLoc == "" and type(_G.GetSubZoneText) == "function" then
        bindLoc = trim(_G.GetSubZoneText())
    end
    local zone, x, y = self:GetPlayerLocation()
    if bindLoc == "" then
        bindLoc = zone or "Inn"
    end

    if self.lastBinderRecord.loc == bindLoc and (now - self.lastBinderRecord.time) < 10.0 then
        return nil
    end
    self.lastBinderRecord = { loc = bindLoc, time = now }

    local npcName = self:GetRelevantNPCName(true)
    return self:CommitAction({
        type = "home",
        destination = bindLoc,
        text = "Set Hearthstone at " .. bindLoc,
        target = npcName,
        zone = zone,
        x = x,
        y = y,
    })
end

function Recorder:HandleSpellcastSucceeded(unitTarget, arg2, arg3, arg4, arg5)
    if not self.isRecording then return nil end
    if unitTarget ~= "player" then return nil end

    -- Support both (unit, castGUID, spellId) and legacy (unit, spellName, rank, lineId, spellId)
    local spellId = tonumber(arg3) or tonumber(arg5) or tonumber(arg2)
    if spellId == 8690 or spellId == 556 then
        local bindLoc = (type(_G.GetBindLocation) == "function" and trim(_G.GetBindLocation())) or "Inn"
        if bindLoc == "" then bindLoc = "Inn" end
        local zone, x, y = self:GetPlayerLocation()
        return self:CommitAction({
            type = "hs",
            destination = bindLoc,
            text = "Hearth to " .. bindLoc,
            zone = zone,
            x = x,
            y = y,
        })
    end
    return nil
end

function Recorder:RecordItemUse(itemId, itemName)
    if not self.isRecording then return nil end
    local id = tonumber(itemId)
    if not id or id <= 0 then return nil end

    local name = trim(itemName or "")
    if name == "" and type(_G.GetItemInfo) == "function" then
        local infoName = _G.GetItemInfo(id)
        if type(infoName) == "string" then
            name = trim(infoName)
        end
    end

    local zone, x, y = self:GetPlayerLocation()
    local npcName = self:GetRelevantNPCName(false)
    local label = "Use " .. (name ~= "" and name or ("Item #" .. tostring(id)))

    -- Attach to current card if in the same camp, otherwise create a card
    return self:CommitAction({
        type = "use",
        itemId = id,
        itemName = name ~= "" and name or nil,
        text = label,
        target = npcName,
        zone = zone,
        x = x,
        y = y,
    })
end

function Recorder:HandleTaxiMapOpened()
    if not self.isRecording then return nil end
    self.lastTaxiNPC = self:GetRelevantNPCName(true)
    local zone, x, y = self:GetPlayerLocation()

    -- Find current node name if available
    local currentNodeName = nil
    if type(_G.NumTaxiNodes) == "function" and type(_G.TaxiNodeGetType) == "function" and type(_G.TaxiNodeName) == "function" then
        local count = _G.NumTaxiNodes() or 0
        for i = 1, count do
            if _G.TaxiNodeGetType(i) == "CURRENT" then
                currentNodeName = _G.TaxiNodeName(i)
                break
            end
        end
    end

    if currentNodeName and trim(currentNodeName) ~= "" then
        self.lastTaxiNodeName = trim(currentNodeName)
    else
        self.lastTaxiNodeName = zone
    end
    return nil
end

function Recorder:OnTakeTaxiNode(slot)
    if not self.isRecording then return nil end
    local destName = nil
    if type(_G.TaxiNodeName) == "function" and slot then
        destName = _G.TaxiNodeName(slot)
    end
    destName = trim(destName or "")
    if destName == "" then
        destName = "Destination"
    end

    local zone, x, y = self:GetPlayerLocation()
    local npcName = self.lastTaxiNPC or self:GetRelevantNPCName(true)

    return self:CommitAction({
        type = "fly",
        destination = destName,
        text = "Fly to " .. destName,
        target = npcName,
        zone = zone,
        x = x,
        y = y,
    })
end

function Recorder:HandlePlayerDead()
    if not self.isRecording then return nil end
    local zone, x, y, mapID = self:GetPlayerLocation()
    self.deathState = {
        time = getNow(),
        zone = zone,
        x = x,
        y = y,
        mapID = mapID,
        recorded = false,
    }
    return nil
end

function Recorder:HandleSpiritHealerOrXPLoss()
    if not self.isRecording then return nil end
    if self.deathState and not self.deathState.recorded then
        self.deathState.recorded = true
        return self:CommitAction({
            type = "deathskip",
            text = "Die and resurrect at the Spirit Healer",
            zone = self.deathState.zone,
            x = self.deathState.x,
            y = self.deathState.y,
        }, {
            zone = self.deathState.zone,
            x = self.deathState.x,
            y = self.deathState.y,
        })
    end
    return nil
end

function Recorder:HandlePlayerResurrected()
    if not self.isRecording or not self.deathState then return nil end
    if self.deathState.recorded then
        self.deathState = nil
        return nil
    end

    -- Check if player is still a ghost (walking from graveyard); only evaluate when alive
    if type(_G.UnitIsGhost) == "function" and _G.UnitIsGhost("player") then
        return nil
    end
    if type(_G.UnitIsDeadOrGhost) == "function" and _G.UnitIsDeadOrGhost("player") then
        return nil
    end

    local zone, x, y = self:GetPlayerLocation()
    local distYards = 0
    if ns.AutoMerger and type(ns.AutoMerger.GetCoordDistanceYards) == "function" then
        distYards = ns.AutoMerger:GetCoordDistanceYards(self.deathState.zone, self.deathState.x, self.deathState.y, zone, x, y)
    end

    local card = nil
    if distYards >= self.DEATHSKIP_MIN_YARDS then
        self.deathState.recorded = true
        card = self:CommitAction({
            type = "deathskip",
            text = "Die and resurrect at the Spirit Healer",
            zone = self.deathState.zone,
            x = self.deathState.x,
            y = self.deathState.y,
        }, {
            zone = self.deathState.zone,
            x = self.deathState.x,
            y = self.deathState.y,
        })
    end

    self.deathState = nil
    return card
end

-- ============================================================================
-- 1-Click Quick-Action Triggers (Called by LiveHUD & Slash Commands)
-- ============================================================================

function Recorder:RecordQuickNote(noteText)
    local clean = trim(noteText)
    if clean == "" then return nil end

    local guide = self:GetOrCreateActiveGuide()
    if not guide then return nil end
    guide.steps = guide.steps or {}

    local zone, x, y = self:GetPlayerLocation()
    local lastCard = guide.steps[#guide.steps]

    if lastCard and (not lastCard.zone or not zone or lastCard.zone == zone) then
        if not lastCard.note or trim(lastCard.note) == "" then
            lastCard.note = clean
        else
            lastCard.note = lastCard.note .. "\n" .. clean
        end
        if ns.FireCallback then
            ns:FireCallback("STEP_RECORDED", lastCard, guide, #guide.steps, true)
            ns:FireCallback("GUIDE_UPDATED", guide)
        end
        return lastCard
    end

    return self:CommitAction({
        type = "note",
        text = clean,
        zone = zone,
        x = x,
        y = y,
    }, {
        zone = zone,
        x = x,
        y = y,
        note = clean,
    }, { disableAutoMerge = true })
end

function Recorder:RecordGrindXP(customTarget)
    local xpTarget = trim(customTarget)
    local label = nil

    if xpTarget == "" then
        local level = (type(_G.UnitLevel) == "function" and tonumber(_G.UnitLevel("player"))) or 1
        local xp = (type(_G.UnitXP) == "function" and tonumber(_G.UnitXP("player"))) or 0
        local maxXp = (type(_G.UnitXPMax) == "function" and tonumber(_G.UnitXPMax("player"))) or 1000
        if not maxXp or maxXp <= 0 then maxXp = 1000 end

        if xp > 0 then
            local pct = math.floor((xp / maxXp) * 100 + 0.5)
            xpTarget = string.format("%d+%d", level, xp)
            label = string.format("Grind to level %d+%d (%d%%)", level, xp, pct)
        else
            xpTarget = tostring(level + 1)
            label = string.format("Grind to level %d", level + 1)
        end
    else
        label = "Grind to " .. xpTarget
    end

    local zone, x, y = self:GetPlayerLocation()
    return self:CommitAction({
        type = "xp",
        xpTarget = xpTarget,
        text = label,
        zone = zone,
        x = x,
        y = y,
    }, {
        zone = zone,
        x = x,
        y = y,
    }, { disableAutoMerge = true })
end

function Recorder:RecordHearthOrBind(mode)
    local m = tostring(mode or "hs"):lower()
    local bindLoc = (type(_G.GetBindLocation) == "function" and trim(_G.GetBindLocation())) or ""
    if bindLoc == "" and type(_G.GetSubZoneText) == "function" then
        bindLoc = trim(_G.GetSubZoneText())
    end
    local zone, x, y = self:GetPlayerLocation()
    if bindLoc == "" then
        bindLoc = zone or "Inn"
    end

    if m == "home" or m == "bind" or m == "rightbutton" then
        local npcName = self:GetRelevantNPCName(true)
        return self:CommitAction({
            type = "home",
            destination = bindLoc,
            text = "Set Hearthstone at " .. bindLoc,
            target = npcName,
            zone = zone,
            x = x,
            y = y,
        })
    else
        return self:CommitAction({
            type = "hs",
            destination = bindLoc,
            text = "Hearth to " .. bindLoc,
            zone = zone,
            x = x,
            y = y,
        }, {
            zone = zone,
            x = x,
            y = y,
        }, { disableAutoMerge = true })
    end
end

function Recorder:RecordDeathskip(customText)
    local zone, x, y = self:GetPlayerLocation()
    if self.deathState and self.deathState.zone then
        zone = self.deathState.zone
        x = self.deathState.x
        y = self.deathState.y
        self.deathState.recorded = true
    end
    local label = trim(customText)
    if label == "" then
        label = "Die and resurrect at the Spirit Healer"
    end

    return self:CommitAction({
        type = "deathskip",
        text = label,
        zone = zone,
        x = x,
        y = y,
    }, {
        zone = zone,
        x = x,
        y = y,
    }, { disableAutoMerge = true })
end

function Recorder:RecordWaypointPin(label)
    local zone, x, y = self:GetPlayerLocation()
    local cleanLabel = trim(label)
    if cleanLabel == "" then
        if x and y then
            cleanLabel = string.format("Go to %s (%.1f, %.1f)", zone or "Waypoint", x, y)
        else
            cleanLabel = "Go to " .. tostring(zone or "Waypoint")
        end
    end

    return self:CommitAction({
        type = "goto",
        text = cleanLabel,
        zone = zone,
        x = x,
        y = y,
    }, {
        zone = zone,
        x = x,
        y = y,
    }, { disableAutoMerge = true })
end

-- ============================================================================
-- Unified Event Dispatcher & Hooks
-- ============================================================================

function Recorder:OnEvent(event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        return self:HandlePlayerEnteringWorld(...)
    elseif event == "QUEST_ACCEPTED" then
        return self:HandleQuestAccepted(...)
    elseif event == "QUEST_TURNED_IN" then
        return self:HandleQuestTurnedIn(...)
    elseif event == "QUEST_WATCH_UPDATE" then
        return self:HandleQuestWatchUpdate(...)
    elseif event == "QUEST_LOG_UPDATE" then
        return self:HandleQuestLogUpdate(...)
    elseif event == "UI_INFO_MESSAGE" then
        return self:HandleUIInfoMessage(...)
    elseif event == "TRAINER_SHOW" then
        return self:HandleTrainerShow(...)
    elseif event == "MERCHANT_SHOW" then
        return self:HandleMerchantShow(...)
    elseif event == "CONFIRM_BINDER" or event == "HEARTHSTONE_BOUND" then
        return self:HandleBindHearthstone(...)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        return self:HandleSpellcastSucceeded(...)
    elseif event == "TAXIMAP_OPENED" then
        return self:HandleTaxiMapOpened(...)
    elseif event == "PLAYER_DEAD" then
        return self:HandlePlayerDead(...)
    elseif event == "AREA_SPIRIT_HEALER_IN_RANGE" or event == "CONFIRM_XP_LOSS" then
        return self:HandleSpiritHealerOrXPLoss(...)
    elseif event == "PLAYER_UNGHOST" or event == "PLAYER_ALIVE" then
        return self:HandlePlayerResurrected(...)
    end
end

function Recorder:InstallHooks()
    if self.hooksInstalled then return end
    self.hooksInstalled = true

    local hooksecurefunc = _G.hooksecurefunc
    if type(hooksecurefunc) ~= "function" then return end

    if type(_G.TakeTaxiNode) == "function" then
        hooksecurefunc("TakeTaxiNode", function(slot)
            self:OnTakeTaxiNode(slot)
        end)
    end

    if type(_G.BuyMerchantItem) == "function" then
        hooksecurefunc("BuyMerchantItem", function(index, quantity)
            self:OnBuyMerchantItem(index, quantity)
        end)
    end

    if type(_G.AcceptXPLoss) == "function" then
        hooksecurefunc("AcceptXPLoss", function()
            self:HandleSpiritHealerOrXPLoss()
        end)
    end

    local function checkContainerQuestItem(bag, slot)
        if not self.isRecording then return end
        local C_Container = _G.C_Container
        if C_Container and type(C_Container.GetContainerItemQuestInfo) == "function" and type(C_Container.GetContainerItemID) == "function" then
            local qInfo = C_Container.GetContainerItemQuestInfo(bag, slot)
            local itemId = C_Container.GetContainerItemID(bag, slot)
            if itemId and qInfo and (qInfo.isQuestItem or qInfo.questID) then
                self:RecordItemUse(itemId)
            end
        elseif type(_G.GetContainerItemQuestInfo) == "function" and type(_G.GetContainerItemID) == "function" then
            local isQuestItem, questId = _G.GetContainerItemQuestInfo(bag, slot)
            local itemId = _G.GetContainerItemID(bag, slot)
            if itemId and (isQuestItem or questId) then
                self:RecordItemUse(itemId)
            end
        end
    end

    if type(_G.C_Container) == "table" and type(_G.C_Container.UseContainerItem) == "function" then
        hooksecurefunc(_G.C_Container, "UseContainerItem", checkContainerQuestItem)
    elseif type(_G.UseContainerItem) == "function" then
        hooksecurefunc("UseContainerItem", checkContainerQuestItem)
    end
end

function Recorder:Init()
    if type(_G.RXP_RecorderDB) == "table" and _G.RXP_RecorderDB.isRecording ~= nil then
        self.isRecording = _G.RXP_RecorderDB.isRecording and true or false
    end

    if not self.eventFrame and type(_G.CreateFrame) == "function" then
        local f = _G.CreateFrame("Frame")
        self.eventFrame = f
        local events = {
            "PLAYER_ENTERING_WORLD",
            "QUEST_ACCEPTED",
            "QUEST_TURNED_IN",
            "QUEST_WATCH_UPDATE",
            "QUEST_LOG_UPDATE",
            "UI_INFO_MESSAGE",
            "TRAINER_SHOW",
            "MERCHANT_SHOW",
            "CONFIRM_BINDER",
            "HEARTHSTONE_BOUND",
            "UNIT_SPELLCAST_SUCCEEDED",
            "TAXIMAP_OPENED",
            "PLAYER_DEAD",
            "AREA_SPIRIT_HEALER_IN_RANGE",
            "CONFIRM_XP_LOSS",
            "PLAYER_UNGHOST",
            "PLAYER_ALIVE",
        }
        for i = 1, #events do
            f:RegisterEvent(events[i])
        end
        f:SetScript("OnEvent", function(_, event, ...)
            self:OnEvent(event, ...)
        end)
    end

    self:InstallHooks()
    self:HandlePlayerEnteringWorld()
end
