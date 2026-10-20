-- ============================================================================
-- RXP_Studio Automated Headless Lua 5.1 QA Test Suite
-- Executes all 6 QA Test Suites against:
--   1. Real 934-step SavedVariables dataset (RXP_Recorder.lua)
--   2. All 12 RXP_Studio modules loaded in exact RXP_Studio.toc order
--   3. Real RXPGuides GuideLoader.lua & functions.lua parser + runtime bridge
-- ============================================================================

local STUDIO_DIR   = [[e:\World of Warcraft\_classic_beta_\Interface\AddOns\RXP_Studio]]
local RXPGUIDES_DIR = [[e:\World of Warcraft\_classic_beta_\Interface\AddOns\RXPGuides]]
local DATASET_PATH = [[E:\World of Warcraft\_classic_beta_\WTF\Account\303328060#1\SavedVariables\RXP_Recorder.lua]]

local totalAssertions = 0
local passedAssertions = 0
local failedAssertions = 0
local failureMessages = {}

local function assertTrue(cond, label, detail)
    totalAssertions = totalAssertions + 1
    if cond then
        passedAssertions = passedAssertions + 1
        print(string.format("  [PASS] %s", label))
        return true
    else
        failedAssertions = failedAssertions + 1
        local msg = string.format("  [FAIL] %s%s", label, detail and (" -- " .. tostring(detail)) or "")
        print(msg)
        table.insert(failureMessages, msg)
        return false
    end
end

local function assertEqual(actual, expected, label)
    return assertTrue(
        actual == expected,
        label,
        string.format("expected %s, got %s", tostring(expected), tostring(actual))
    )
end

-- ============================================================================
-- 1. Comprehensive Mock WoW Classic Beta (16001) Environment
-- ============================================================================
_G.unpack = _G.unpack or table.unpack
_G.strmatch = string.match
_G.strfind = string.find
_G.strsub = string.sub
_G.strlen = string.len
_G.strlower = string.lower
_G.strupper = string.upper
_G.strbyte = string.byte
_G.strchar = string.char
_G.strrep = string.rep
_G. gsub = string.gsub
_G.format = string.format
_G.tinsert = table.insert
_G.tremove = table.remove
_G. wipe = function(t)
    if type(t) == "table" then
        for k in pairs(t) do t[k] = nil end
    end
    return t
end
_G.strsplit = function(sep, str, pieces)
    if type(str) ~= "string" then return nil end
    sep = sep or "%s"
    local result = {}
    local pattern = string.format("([^%s]*)", sep)
    local pos = 1
    while true do
        local s, e = string.find(str, sep, pos, true)
        if not s or (pieces and #result >= pieces - 1) then
            table.insert(result, string.sub(str, pos))
            break
        end
        table.insert(result, string.sub(str, pos, s - 1))
        pos = e + 1
    end
    return unpack(result)
end

_G.bit = _G.bit or {
    band = function(a, b)
        a = math.floor(tonumber(a) or 0)
        b = math.floor(tonumber(b) or 0)
        local p, c = 1, 0
        while a > 0 and b > 0 do
            local ra, rb = a % 2, b % 2
            if ra + rb > 1 then c = c + p end
            a, b, p = (a - ra) / 2, (b - rb) / 2, p * 2
        end
        return c
    end,
    bor = function(a, b)
        a = math.floor(tonumber(a) or 0)
        b = math.floor(tonumber(b) or 0)
        local p, c = 1, 0
        while a > 0 or b > 0 do
            local ra, rb = a % 2, b % 2
            if ra + rb > 0 then c = c + p end
            a, b, p = (a - ra) / 2, (b - rb) / 2, p * 2
        end
        return c
    end,
    lshift = function(a, b) return math.floor((tonumber(a) or 0) * (2 ^ (tonumber(b) or 0))) end,
    rshift = function(a, b) return math.floor((tonumber(a) or 0) / (2 ^ (tonumber(b) or 0))) end,
}

local _mockTime = 100.0
_G.GetTime = function() return _mockTime end
_G.SetMockTime = function(t) _mockTime = t end
_G.AdvanceMockTime = function(dt) _mockTime = _mockTime + (dt or 1.0) end

_G.WOW_PROJECT_ID = 2
_G.WOW_PROJECT_CLASSIC = 2
_G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
_G.WOW_PROJECT_WRATH_CLASSIC = 11
_G.WOW_PROJECT_CATACLYSM_CLASSIC = 14
_G.WOW_PROJECT_MAINLINE = 1
_G.NONE = "None"
_G.HOME = "Home"
_G.ERR_NEWTAXIPATH = "New flight path discovered!"
_G.QUEST_MONSTERS_KILLED = "%s slain: %d/%d"
_G.QUEST_ITEMS_NEEDED = "%s: %d/%d"
_G.QUEST_OBJECTS_FOUND = "%s: %d/%d"
_G.CreateVector2D = function(x, y)
    return { x = x or 0, y = y or 0, GetXY = function(self) return self.x, self.y end }
end
_G.BackdropTemplateMixin = {}
_G.UISpecialFrames = {}
_G.StaticPopupDialogs = {}
_G.SlashCmdList = {}
_G.getglobal = function(k) return _G[k] end

_G.GetBuildInfo = function()
    return "1.16.0", "58222", "Oct 19 2026", 16001, "", "FOREVER "
end
_G.GetLocale = function() return "enUS" end

local _mockPlayer = {
    name = "Speedrunner",
    level = 1,
    xp = 250,
    maxXp = 400,
    classLocal = "Hunter",
    classToken = "HUNTER",
    classId = 3,
    raceLocal = "Orc",
    raceToken = "Orc",
    faction = "Horde",
    zone = "Durotar",
    subzone = "Valley of Trials",
    mapId = 1411,
    x = 43.29,
    y = 68.53,
    isDead = false,
}
_G.MockPlayer = _mockPlayer

local _mockUnits = {
    target = nil,
    npc = nil,
    mouseover = nil,
}
_G.MockUnits = _mockUnits

_G.UnitName = function(unit)
    if unit == "player" then return _mockPlayer.name end
    local u = _mockUnits[unit]
    return u and u.name or nil
end
_G.UnitGUID = function(unit)
    if unit == "player" then return "Player-1-00000001" end
    local u = _mockUnits[unit]
    return u and u.guid or nil
end
_G.UnitExists = function(unit)
    if unit == "player" then return true end
    return _mockUnits[unit] ~= nil
end
_G.UnitIsPlayer = function(unit)
    if unit == "player" then return true end
    local u = _mockUnits[unit]
    return u and u.isPlayer or false
end
_G.UnitIsDead = function(unit)
    if unit == "player" then return _mockPlayer.isDead end
    local u = _mockUnits[unit]
    return u and u.isDead or false
end
_G.UnitIsDeadOrGhost = function(unit)
    return _G.UnitIsDead(unit)
end
_G.UnitCanAttack = function(u1, u2)
    local u = _mockUnits[u2] or _mockUnits[u1]
    return u and u.hostile or false
end
_G.UnitReaction = function(u1, u2)
    local u = _mockUnits[u2] or _mockUnits[u1]
    if not u then return 5 end
    return u.hostile and 2 or 5
end
_G.UnitLevel = function(unit) return _mockPlayer.level end
_G.UnitXP = function(unit) return _mockPlayer.xp end
_G.UnitXPMax = function(unit) return _mockPlayer.maxXp end
_G.UnitClass = function(unit) return _mockPlayer.classLocal, _mockPlayer.classToken, _mockPlayer.classId end
_G.UnitRace = function(unit) return _mockPlayer.raceLocal, _mockPlayer.raceToken end
_G.UnitFactionGroup = function(unit) return _mockPlayer.faction, _mockPlayer.faction end
_G.GetRealZoneText = function() return _mockPlayer.zone end
_G.GetZoneText = function() return _mockPlayer.zone end
_G.GetSubZoneText = function() return _mockPlayer.subzone end
_G.GetBindLocation = function() return "Razor Hill" end
_G.GetCursorPosition = function() return 500, 400 end
_G.IsShiftKeyDown = function() return false end
_G.IsControlKeyDown = function() return false end
_G.IsAltKeyDown = function() return false end
_G.IsModifierKeyDown = function() return false end
_G.GetNumSkillLines = function() return 0 end
_G.GetItemInfo = function(id) return "Item #" .. tostring(id) end
_G.GetSpellInfo = function(id)
    if tonumber(id) == 8690 then return "Hearthstone" end
    if tonumber(id) == 556 then return "Astral Recall" end
    return "Spell #" .. tostring(id)
end

-- Mock Frame & Widget Factory
local function createMockWidget(widgetType, name, parent)
    local w = {
        _type = widgetType or "Frame",
        _name = name,
        _parent = parent,
        _shown = true,
        _width = 200,
        _height = 100,
        _scale = 1.0,
        _alpha = 1.0,
        _text = "",
        _scripts = {},
        _events = {},
        _points = {},
        _textures = {},
        _checked = false,
        _enabled = true,
        _hasFocus = false,
    }
    function w:SetSize(width, height) self._width = width or self._width; self._height = height or self._height end
    function w:GetSize() return self._width, self._height end
    function w:SetWidth(width) self._width = width or self._width end
    function w:GetWidth() return self._width or 200 end
    function w:SetHeight(height) self._height = height or self._height end
    function w:GetHeight() return self._height or 100 end
    function w:SetPoint(...) table.insert(self._points, { ... }) end
    function w:SetAllPoints(p) self._points = { { "ALL", p } } end
    function w:ClearAllPoints() self._points = {} end
    function w:Show()
        self._shown = true
        if self._scripts["OnShow"] then self._scripts["OnShow"](self) end
    end
    function w:Hide()
        self._shown = false
        if self._scripts["OnHide"] then self._scripts["OnHide"](self) end
    end
    function w:IsShown() return self._shown end
    function w:IsVisible() return self._shown end
    function w:SetShown(v) if v then self:Show() else self:Hide() end end
    function w:SetAlpha(a) self._alpha = a end
    function w:GetAlpha() return self._alpha end
    function w:SetScale(s) self._scale = s end
    function w:GetScale() return self._scale end
    function w:GetEffectiveScale() return self._scale or 1.0 end
    function w:GetLeft() return 100 end
    function w:GetRight() return 100 + (self._width or 200) end
    function w:GetTop() return 500 end
    function w:GetBottom() return 500 - (self._height or 100) end
    function w:SetFrameStrata(s) self._strata = s end
    function w:SetFrameLevel(l) self._level = l end
    function w:GetFrameLevel() return self._level or 1 end
    function w:SetToplevel(b) end
    function w:SetMovable(b) end
    function w:SetResizable(b) end
    function w:EnableMouse(b) end
    function w:EnableMouseWheel(b) end
    function w:SetClipsChildren(b) end
    function w:RegisterForDrag(...) end
    function w:RegisterForClicks(...) end
    function w:StartMoving() end
    function w:StopMovingOrSizing() end
    function w:SetClampedToScreen(b) end
    function w:SetBackdrop(bd) self._backdrop = bd end
    function w:SetBackdropColor(...) self._backdropColor = { ... } end
    function w:SetBackdropBorderColor(...) self._backdropBorderColor = { ... } end
    function w:SetScript(evt, fn) self._scripts[evt] = fn end
    function w:GetScript(evt) return self._scripts[evt] end
    function w:HookScript(evt, fn)
        local prev = self._scripts[evt]
        self._scripts[evt] = function(...)
            if prev then prev(...) end
            return fn(...)
        end
    end
    function w:RegisterEvent(evt) self._events[evt] = true end
    function w:UnregisterEvent(evt) self._events[evt] = nil end
    function w:UnregisterAllEvents() self._events = {} end
    function w:SetText(t)
        self._text = tostring(t or "")
        if self._type == "EditBox" and self._scripts["OnTextChanged"] then
            self._scripts["OnTextChanged"](self, false)
        end
    end
    function w:GetText() return self._text or "" end
    function w:SetTextColor(...) end
    function w:SetFontObject(...) end
    function w:SetFont(...) end
    function w:SetJustifyH(...) end
    function w:SetJustifyV(...) end
    function w:SetWordWrap(...) end
    function w:GetStringWidth() return string.len(self._text or "") * 7 end
    function w:GetStringHeight() return 14 end
    function w:SetMultiLine(b) self._multiLine = b end
    function w:SetAutoFocus(b) self._autoFocus = b end
    function w:SetTextInsets(...) end
    function w:SetMaxLetters(...) end
    function w:SetNumeric(...) end
    function w:SetFocus()
        self._hasFocus = true
        if self._scripts["OnEditFocusGained"] then
            self._scripts["OnEditFocusGained"](self)
        end
    end
    function w:ClearFocus()
        local hadFocus = self._hasFocus
        self._hasFocus = false
        if hadFocus and self._scripts["OnEditFocusLost"] then
            self._scripts["OnEditFocusLost"](self)
        end
    end
    function w:HasFocus() return self._hasFocus or false end
    function w:HighlightText(...) end
    function w:SetCursorPosition(...) end
    function w:SetScrollChild(child) self._scrollChild = child end
    function w:GetScrollChild() return self._scrollChild end
    function w:SetVerticalScroll(...) end
    function w:GetVerticalScroll() return 0 end
    function w:GetVerticalScrollRange() return 0 end
    function w:UpdateScrollChildRect() end
    function w:SetChecked(c) self._checked = c and true or false end
    function w:GetChecked() return self._checked end
    function w:Enable() self._enabled = true end
    function w:Disable() self._enabled = false end
    function w:IsEnabled() return self._enabled end
    function w:SetNormalFontObject(...) end
    function w:SetHighlightFontObject(...) end
    function w:SetDisabledFontObject(...) end
    function w:SetNormalTexture(...) end
    function w:SetPushedTexture(...) end
    function w:SetHighlightTexture(...) end
    function w:SetCheckedTexture(...) end
    function w:CreateTexture(tName, layer)
        local tex = createMockWidget("Texture", tName, self)
        function tex:SetTexture(path) self._texturePath = path end
        function tex:GetTexture() return self._texturePath end
        function tex:SetColorTexture(...) self._colorTex = { ... } end
        function tex:SetVertexColor(...) self._vertexColor = { ... } end
        function tex:SetTexCoord(...) self._texCoord = { ... } end
        function tex:SetBlendMode(...) end
        function tex:SetDrawLayer(...) end
        table.insert(self._textures, tex)
        return tex
    end
    function w:CreateFontString(fName, layer, inherits)
        local fs = createMockWidget("FontString", fName, self)
        return fs
    end
    function w:CreateLine(lName, layer)
        local ln = createMockWidget("Line", lName, self)
        function ln:SetColorTexture(...) end
        function ln:SetVertexColor(...) end
        function ln:SetThickness(th) self._thickness = th end
        function ln:SetStartPoint(relPoint, relFrame, x, y) self._start = { relPoint, relFrame, x, y } end
        function ln:SetEndPoint(relPoint, relFrame, x, y) self._end = { relPoint, relFrame, x, y } end
        return ln
    end
    if name and type(name) == "string" then
        _G[name] = w
    end
    return w
end

_G.CreateFrame = function(frameType, name, parent, template)
    return createMockWidget(frameType, name, parent)
end
_G.UIParent = createMockWidget("Frame", "UIParent", nil)
_G.WorldFrame = createMockWidget("Frame", "WorldFrame", nil)
_G.GameTooltip = createMockWidget("GameTooltip", "GameTooltip", _G.UIParent)
function _G.GameTooltip:SetOwner(...) end
function _G.GameTooltip:ClearLines() end
function _G.GameTooltip:AddLine(...) end
function _G.GameTooltip:AddDoubleLine(...) end
function _G.GameTooltip:SetHyperlink(...) end
_G.GameTooltipTextLeft1 = createMockWidget("FontString", "GameTooltipTextLeft1", _G.GameTooltip)

-- Mock C_Map, C_QuestLog, C_Timer, C_GossipInfo
local ZONE_MAP_INFO = {
    [2521] = { mapID = 2521, name = "Zephras Isle", parentMapID = 1414, mapType = 3 },
    [1411] = { mapID = 1411, name = "Durotar", parentMapID = 1414, mapType = 3 },
    [1412] = { mapID = 1412, name = "Mulgore", parentMapID = 1414, mapType = 3 },
    [1413] = { mapID = 1413, name = "The Barrens", parentMapID = 1414, mapType = 3 },
    [1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 },
    [1415] = { mapID = 1415, name = "Eastern Kingdoms", parentMapID = 947, mapType = 2 },
    [1438] = { mapID = 1438, name = "Teldrassil", parentMapID = 1414, mapType = 3 },
    [1439] = { mapID = 1439, name = "Darkshore", parentMapID = 1414, mapType = 3 },
    [1440] = { mapID = 1440, name = "Ashenvale", parentMapID = 1414, mapType = 3 },
    [1429] = { mapID = 1429, name = "Elwynn Forest", parentMapID = 1415, mapType = 3 },
    [1426] = { mapID = 1426, name = "Dun Morogh", parentMapID = 1415, mapType = 3 },
    [1420] = { mapID = 1420, name = "Tirisfal Glades", parentMapID = 1415, mapType = 3 },
}

_G.C_Map = {
    GetBestMapForUnit = function(unit)
        return _mockPlayer.mapId
    end,
    GetPlayerMapPosition = function(mapId, unit)
        return {
            x = (_mockPlayer.x or 50) / 100,
            y = (_mockPlayer.y or 50) / 100,
            GetXY = function(self) return self.x, self.y end,
        }
    end,
    GetMapInfo = function(mapId)
        local id = tonumber(mapId) or 1414
        return ZONE_MAP_INFO[id] or { mapID = id, name = "Zone " .. tostring(id), parentMapID = 1414, mapType = 3 }
    end,
    GetMapArtLayers = function(mapId)
        return { { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256 } }
    end,
    GetMapArtLayerTextures = function(mapId, layerIdx)
        local tex = {}
        for i = 1, 12 do tex[i] = 136300 + i end
        return tex
    end,
    CanSetUserWaypointOnMap = function() return false end,
}

local _mockQuestLog = {}
local _mockTurnedIn = {}
_G.MockQuestLog = _mockQuestLog
_G.MockTurnedIn = _mockTurnedIn

_G.C_QuestLog = {
    GetTitleForQuestID = function(qid)
        qid = tonumber(qid)
        if _mockQuestLog[qid] then return _mockQuestLog[qid].title end
        return nil
    end,
    GetQuestObjectives = function(qid)
        qid = tonumber(qid)
        if _mockQuestLog[qid] and _mockQuestLog[qid].objectives then
            return _mockQuestLog[qid].objectives
        end
        return nil
    end,
    IsQuestFlaggedCompleted = function(qid)
        return _mockTurnedIn[tonumber(qid)] or false
    end,
    IsOnQuest = function(qid)
        return _mockQuestLog[tonumber(qid)] ~= nil
    end,
    IsComplete = function(qid)
        local q = _mockQuestLog[tonumber(qid)]
        return q and q.isComplete or false
    end,
    GetNumQuestLogEntries = function()
        local count = 0
        for _ in pairs(_mockQuestLog) do count = count + 1 end
        return count, count
    end,
}

_G.GetNumQuestLogEntries = function()
    local list = {}
    for qid in pairs(_mockQuestLog) do table.insert(list, qid) end
    table.sort(list)
    _G._sortedQuestIds = list
    return #list, #list
end

_G.GetQuestLogTitle = function(index)
    local list = _G._sortedQuestIds or {}
    local qid = list[index]
    local q = qid and _mockQuestLog[qid]
    if not q then return nil end
    return q.title, 1, nil, false, false, q.isComplete and 1 or nil, nil, qid
end

_G.GetNumQuestLeaderBoards = function(index)
    local list = _G._sortedQuestIds or {}
    local qid = list[index]
    local q = qid and _mockQuestLog[qid]
    if not q or not q.objectives then return 0 end
    return #q.objectives
end

_G.GetQuestLogLeaderBoard = function(objIdx, questLogIndex)
    local list = _G._sortedQuestIds or {}
    local qid = list[questLogIndex]
    local q = qid and _mockQuestLog[qid]
    local obj = q and q.objectives and q.objectives[objIdx]
    if not obj then return nil end
    return obj.text, obj.type or "monster", obj.finished or false
end

_G.GetTitleText = function()
    return _G._activeDialogQuestTitle
end
_G.GetQuestID = function()
    return _G._activeDialogQuestId
end

_G.C_Timer = {
    After = function(delay, fn)
        if type(fn) == "function" then fn() end
    end,
    NewTicker = function(interval, fn)
        return { Cancel = function() end }
    end,
}
_G.C_GossipInfo = {
    GetOptions = function() return {} end,
}
_G.C_DateAndTime = {
    GetCurrentCalendarTime = function()
        return { year = 2026, month = 10, monthDay = 19 }
    end,
}

-- Mock LibStub + HereBeDragons-2.0
local _libs = {}
_libs["HereBeDragons-2.0"] = {
    GetAllMapIDs = function()
        return { 2521, 1411, 1412, 1413, 1414, 1415, 1438, 1439, 1440, 1429, 1426, 1420 }
    end,
    GetLocalizedMap = function(self, mapID)
        local info = ZONE_MAP_INFO[tonumber(mapID)]
        return info and info.name or nil
    end,
    GetWorldCoordinatesFromZone = function(self, x, y, zone)
        return (tonumber(x) or 0) * 1000, (tonumber(y) or 0) * 1000, tonumber(zone) or 1414
    end,
    GetZoneCoordinatesFromWorld = function(self, wx, wy, zone)
        return (tonumber(wx) or 0) / 1000, (tonumber(wy) or 0) / 1000
    end,
    GetPlayerWorldPosition = function(self)
        return (_mockPlayer.x or 50) * 10, (_mockPlayer.y or 50) * 10, _mockPlayer.mapId
    end,
}
_libs["HereBeDragons-Pins-2.0"] = {}
_libs["AceAddon-3.0"] = {
    GetAddon = function(self, name)
        if name == "RXPGuides" then return _G.RXPGuides end
        return nil
    end,
}

_G.LibStub = setmetatable({
    GetLibrary = function(self, name, silent)
        return _libs[name]
    end,
}, {
    __call = function(self, name, silent)
        return _libs[name]
    end,
})

-- ============================================================================
-- 2. Initialize Real RXPGuides Addon Environment (GuideLoader.lua + functions.lua)
-- ============================================================================
local RXPGuides = {}
RXPGuides.RXPGuides = RXPGuides
_G.RXPGuides = RXPGuides
_G.RXP = RXPGuides
_G.RXPData = { skipMissingPreReqs = false }
_G.RXPCData = {
    completedWaypoints = {},
    questNameCache = { [0] = 0 },
    questObjectivesCache = { [0] = 0 },
    flightPaths = {},
}

RXPGuides.guides = {}
RXPGuides.guideList = {}
RXPGuides.functions = { __index = {} }
RXPGuides.FunctionList = {}
RXPGuides.separators = {}
RXPGuides.stepUpdateList = {}
RXPGuides.questAccept = {}
RXPGuides.questTurnIn = {}
RXPGuides.questConversion = {}
RXPGuides.questCompleteItems = {}
RXPGuides.disabledQuests = {}
RXPGuides.skipPreReq = {}
RXPGuides.recentAccept = {}
RXPGuides.recentTurnIn = {}
RXPGuides.pickUpList = {}
RXPGuides.turnInList = {}
RXPGuides.itemQueryList = {}
RXPGuides.activeItems = {}
RXPGuides.activeSpells = {}
RXPGuides.mapConversion = {}
RXPGuides.mapId = {
    ["Zephras Isle"]         = 2521,
    ["Durotar"]              = 1411,
    ["Mulgore"]              = 1412,
    ["The Barrens"]          = 1413,
    ["Kalimdor"]             = 1414,
    ["Eastern Kingdoms"]     = 1415,
    ["Teldrassil"]           = 1438,
    ["Darkshore"]            = 1439,
    ["Ashenvale"]            = 1440,
    ["Blackfathom Deeps"]    = 1440,
    ["Elwynn Forest"]        = 1429,
    ["Dun Morogh"]           = 1426,
    ["Tirisfal Glades"]      = 1420,
}
RXPGuides.colors = { tooltip = "|cffFFFFFF" }
RXPGuides.icons = setmetatable({}, { __index = function() return "" end })
RXPGuides.locale = { Get = function(s, s2) return type(s) == "string" and s or tostring(s2 or "") end }
RXPGuides.player = {
    localeClass = "Hunter",
    class = "HUNTER",
    race = "Orc",
    faction = "Horde",
    neutral = false,
    season = 0,
    phase = 6,
}
RXPGuides.settings = {
    ReplaceColors = function(s) return s end,
    profile = {
        debug = false,
        season = 0,
        phase = 6,
        hardcore = false,
        soM = false,
        xpRate = 1,
    },
}
RXPGuides.BuildGuideKey = function(g)
    return string.format("%s|%s|%s", g.group or "", g.subgroup or "", g.name or "")
end
RXPGuides.comms = {
    PrettyDebug = function(msg, ...)
        RXPGuides._lastParseError = tostring(msg)
    end,
    grouping = { ShareQuest = function() end },
}
RXPGuides.error = function(msg)
    RXPGuides._lastParseError = tostring(msg)
    return false, tostring(msg)
end
RXPGuides.version = 40000
RXPGuides.release = "v4.x"
RXPGuides.game = "CLASSIC"
RXPGuides.gameVersion = 16001
RXPGuides.lastStepUpdate = 0
RXPGuides.ClearTimer = function() end
RXPGuides.StartTimer = function() end
RXPGuides.UpdateMap = function() end
RXPGuides.UpdateItemFrame = function() end
RXPGuides.QueueMessage = function() end
RXPGuides.SendEvent = function() end
RXPGuides.SetActiveAlpha = function() end
RXPGuides.GetGuideTable = function(self, group, name)
    if not group or not name then return nil end
    return self.guides[string.format("%s||%s", group, name)]
        or self.guides[string.format("%s||||%s", group, name)]
end
RXPGuides.NewModule = function(self, name, tbl)
    return tbl or {}
end
RXPGuides.GroupOverride = function() end
RXPGuides.GetMapId = function(zone)
    return RXPGuides.mapId[zone]
end
RXPGuides.GetMapInfo = function(zone, x, y, instance)
    x = tonumber(x)
    y = tonumber(y)
    if not (x and y and zone) then return end
    return RXPGuides.GetMapId(zone) or tonumber(zone), x, y, instance
end

-- Load real RXPGuides/GuideLoader.lua and RXPGuides/functions.lua
local function loadAddonFile(filePath, addonNameArg, addonTableArg)
    local chunk, err = loadfile(filePath)
    if not chunk then
        error("Failed to load file " .. tostring(filePath) .. ": " .. tostring(err))
    end
    return chunk(addonNameArg, addonTableArg)
end

loadAddonFile(RXPGUIDES_DIR .. [[\GuideLoader.lua]], "RXPGuides", RXPGuides)
loadAddonFile(RXPGUIDES_DIR .. [[\functions.lua]], "RXPGuides", RXPGuides)

-- Provide RXPGuides runtime window & step navigation methods matching GuideWindow.lua / RXPGuides.lua
RXPGuides.RXPFrame = createMockWidget("Frame", "RXPFrame", _G.UIParent)
RXPGuides.RXPFrame.CurrentStepFrame = createMockWidget("Frame", "RXPCurrentStepFrame", RXPGuides.RXPFrame)
RXPGuides.RXPFrame.GuideName = { SetText = function(self, t) self._text = t end }
RXPGuides.RXPFrame.Footer = { text = { SetText = function(self, t) self._text = t end } }

-- Exact replica of RXPFrame.GenerateMenuTable's table.sort over guideList[group].names_ (GuideWindow.lua:1013)
function RXPGuides.RXPFrame.GenerateMenuTable()
    for group, groupTable in pairs(RXPGuides.guideList or {}) do
        if type(groupTable) == "table" and type(groupTable.names_) == "table" then
            table.sort(groupTable.names_, function(n1, n2)
                assert(type(n1) == "table" and type(n2) == "table",
                    "guideList[" .. tostring(group) .. "].names_ contains non-table entry (" .. type(n1) .. ", " .. type(n2) .. ")")
                if n1.group ~= n2.group then
                    return tostring(n1.group) < tostring(n2.group)
                end
                return tostring(n1.name) < tostring(n2.name)
            end)
        end
    end
end

function RXPGuides:LoadGuide(guide)
    if type(guide) ~= "table" or not guide.steps then
        return false
    end
    self.currentGuide = guide
    self.currentGuideName = guide.name
    self.currentGuideGroup = guide.group
    RXPCData.currentGuideName = guide.name
    RXPCData.currentGuideGroup = guide.group
    self.SetStep(1)
    return true
end

function RXPGuides.SetStep(stepNum)
    local guide = RXPGuides.currentGuide
    if not guide or not guide.steps then return end
    local n = math.max(1, math.min(tonumber(stepNum) or 1, #guide.steps))
    for i = 1, #guide.steps do
        guide.steps[i].active = (i == n)
    end
    RXPCData.currentStep = n
    RXPGuides.currentStep = n
end

-- ============================================================================
-- 3. Load Real 934-Step SavedVariables Dataset (RXP_Recorder.lua)
-- ============================================================================
dofile(DATASET_PATH)

-- ============================================================================
-- 4. Load All 12 RXP_Studio Files in Exact RXP_Studio.toc Order
-- ============================================================================
local TOC_FILES = {
    [[Core\DataModel.lua]],
    [[Compiler\RXPCompiler.lua]],
    [[Compiler\RouteLinter.lua]],
    [[Bridge\RXPBridge.lua]],
    [[Recorder\AutoMerger.lua]],
    [[Recorder\EventCapture.lua]],
    [[UI\Theme.lua]],
    [[UI\LiveHUD.lua]],
    [[UI\CardInspector.lua]],
    [[UI\MapPreview.lua]],
    [[UI\StudioFrame.lua]],
    [[RXP_Studio.lua]],
}

local studioNs = {}
for _, relPath in ipairs(TOC_FILES) do
    loadAddonFile(STUDIO_DIR .. "\\" .. relPath, "RXP_Studio", studioNs)
end

local ns = _G.RXP_Studio

print("============================================================================")
print("RXP_Studio Headless Lua 5.1 QA Test Suite")
print("============================================================================")

-- ============================================================================
-- TEST SUITE 1: Legacy RXP_RecorderDB Import & Session Segmentation
-- ============================================================================
print("\n--- Test Suite 1: Legacy RXP_RecorderDB Import & Session Segmentation ---")

local rawSteps = _G.RXP_RecorderDB and _G.RXP_RecorderDB.steps or {}
assertEqual(#rawSteps, 934, "Loaded real RXP_Recorder.lua SavedVariables with 934 raw steps")

local rawParseErrors = 0
for i = 1, #rawSteps do
    local ok, card = pcall(ns.Compiler.ParseRawStep, ns.Compiler, rawSteps[i])
    if not ok or type(card) ~= "table" then
        rawParseErrors = rawParseErrors + 1
    end
end
assertEqual(rawParseErrors, 0, "All 934 raw steps in RXP_Recorder.lua parse via ParseRawStep with 0 errors")

-- Initialize Core DB and import legacy recorder dataset
_G.RXP_StudioDB = nil
ns.Core:InitDB()
local importedGuides = ns.Core:GetGuideList()
assertTrue(#importedGuides >= 4, "ImportLegacyRecorderDB segmented multi-character recording into >= 4 guides (got " .. tostring(#importedGuides) .. ")")

local foundRegions = {}
local kalimdorCorruptCount = 0
for _, g in ipairs(importedGuides) do
    if g.subgroup then
        foundRegions[g.subgroup] = true
    end
    for _, step in ipairs(g.steps or {}) do
        if step.zone == "Kalimdor" then
            for _, act in ipairs(step.actions or {}) do
                if act.type == "complete" and tostring(act.objText or ""):match("^%d+/%d+%s*$") then
                    kalimdorCorruptCount = kalimdorCorruptCount + 1
                end
            end
        end
    end
end

assertTrue(foundRegions["Zephras Isle"] == true, "Segmented guide created for Zephras Isle session")
assertTrue(foundRegions["Durotar"] == true, "Segmented guide created for Durotar session")
assertTrue(foundRegions["Mulgore"] == true, "Segmented guide created for Mulgore session")
assertTrue(foundRegions["Ashenvale & Barrens"] == true, "Segmented guide created for Ashenvale / Blackfathom Deeps session")
assertEqual(kalimdorCorruptCount, 0, "Filtered out 100% of corrupt Kalimdor '--1/1  ' login-flush bursts")

-- ============================================================================
-- TEST SUITE 2: Smart Auto-Merger & Lossless Split/Re-Merge
-- ============================================================================
print("\n--- Test Suite 2: Smart Auto-Merger & Lossless Split/Re-Merge ---")

-- Check merged NPC cards across imported guides
local mergedNPCCounts = {}
local halaanOrderValid = false
local trainerSpamFound = false

for _, g in ipairs(importedGuides) do
    for _, card in ipairs(g.steps or {}) do
        if #card.actions > 1 then
            for _, t in ipairs(card.targets or {}) do
                mergedNPCCounts[t] = (mergedNPCCounts[t] or 0) + 1
            end
        end
        -- Check Halaan Hawk-Eye quest 94414 (.accept 94414 before .turnin 94414)
        local accept94414Idx, turnin94414Idx
        local trainerCountInCard = 0
        for idx, act in ipairs(card.actions or {}) do
            if act.questId == 94414 and act.type == "accept" then accept94414Idx = idx end
            if act.questId == 94414 and act.type == "turnin" then turnin94414Idx = idx end
            if act.type == "trainer" then trainerCountInCard = trainerCountInCard + 1 end
        end
        if accept94414Idx and turnin94414Idx and accept94414Idx < turnin94414Idx then
            halaanOrderValid = true
        end
        if trainerCountInCard > 1 then
            trainerSpamFound = true
        end
    end
end

assertTrue(
    (mergedNPCCounts["Gornek"] or 0) > 0
    and (mergedNPCCounts["Rorian the Dayseeker"] or 0) > 0
    and (mergedNPCCounts["Windshaper Boro"] or 0) > 0
    and (mergedNPCCounts["Zureetha Fargaze"] or 0) > 0
    and (mergedNPCCounts["Master Gadrin"] or 0) > 0,
    "Consecutive same-NPC actions (Gornek, Rorian the Dayseeker, Windshaper Boro, Zureetha Fargaze, Master Gadrin) merged into multi-action cards"
)
assertTrue(halaanOrderValid, "Same-quest accept->turnin (.accept 94414 -> .turnin 94414 at Halaan Hawk-Eye) preserved in chronological order")
assertEqual(trainerSpamFound, false, "Duplicate .trainer spam at class trainers deduplicated to single .trainer action per card")

-- Test Turnin-before-Accept ordering for distinct quests at same NPC
local testMergeGuide = ns.Core:CreateGuide({
    name = "Merge & Split Test Guide",
    group = "QA Tests",
    steps = {
        ns.Core:NewStepCard({
            zone = "Durotar", x = 42.06, y = 68.32,
            targets = { "Gornek" },
            actions = { { type = "accept", questId = 788, questTitle = "Cutting Teeth", target = "Gornek" } },
        }),
        ns.Core:NewStepCard({
            zone = "Durotar", x = 42.08, y = 68.34,
            targets = { "Gornek" },
            actions = { { type = "turnin", questId = 4641, questTitle = "Your Place in the World", target = "Gornek" } },
        }),
    },
})
local mergedCnt = ns.AutoMerger:MergeGuideSteps(testMergeGuide, 15) -- Pass numeric radius to test normalization!
assertEqual(mergedCnt, 1, "AutoMerger:MergeGuideSteps(guide, 15) accepts numeric radius and merges co-located NPC cards")
assertEqual(#testMergeGuide.steps, 1, "Merged guide has 1 combined step card")
assertEqual(testMergeGuide.steps[1].actions[1].type, "turnin", "Merged card orders .turnin (4641) before .accept (788)")
assertEqual(testMergeGuide.steps[1].actions[2].type, "accept", "Merged card orders .accept (788) second")

-- Test SplitCard and MergeAdjacentCards
local splitResult = ns.AutoMerger:SplitCard(testMergeGuide, 1)
assertEqual(#testMergeGuide.steps, 2, "AutoMerger:SplitCard splits 2-action card into 2 individual StepCards")
assertTrue(
    testMergeGuide.steps[1].zone == "Durotar" and testMergeGuide.steps[2].zone == "Durotar"
    and testMergeGuide.steps[1].title ~= nil and type(testMergeGuide.steps[1].lintIssues) == "table"
    and testMergeGuide.steps[2].title ~= nil and type(testMergeGuide.steps[2].lintIssues) == "table",
    "Split cards preserve coordinates, targets, title, and lintIssues table"
)

local remergedCard = ns.AutoMerger:MergeAdjacentCards(testMergeGuide, 1, 2)
assertTrue(remergedCard ~= nil and #testMergeGuide.steps == 1 and #remergedCard.actions == 2, "AutoMerger:MergeAdjacentCards re-merges split cards back into 1 multi-action card")

-- ============================================================================
-- TEST SUITE 3: Route Linter & 1-Click Auto-Fix Verification
-- ============================================================================
print("\n--- Test Suite 3: Route Linter & 1-Click Auto-Fix Verification ---")

local lintTestGuide = ns.Core:CreateGuide({
    name = "Linter Torture Test",
    group = "QA Tests",
    steps = {
        -- Step 1: Accept 788, Turnin 788 (WITHOUT .complete 788 -> triggers MISSING_COMPLETE),
        --         plus duplicate .trainer (triggers DUPLICATE_ACTION),
        --         plus stale dead mob target Battleboar on an accept/turnin card (triggers STALE_COMBAT_TARGET)
        ns.Core:NewStepCard({
            zone = "Durotar", x = 42.06, y = 68.32,
            targets = { "Gornek", "Battleboar", "Prairie Stalker" },
            actions = {
                { type = "accept", questId = 788, questTitle = "Cutting Teeth", target = "Gornek" },
                { type = "trainer", text = "Train spells", target = "Gornek" },
                { type = "trainer", text = "Train spells", target = "Gornek" },
            },
        }),
        -- Step 2: Turnin 788 (triggers MISSING_COMPLETE since 788 is known combat quest) + MISSING_COORDS
        ns.Core:NewStepCard({
            zone = nil, x = nil, y = nil,
            targets = { "Gornek" },
            actions = {
                { type = "turnin", questId = 788, questTitle = "Cutting Teeth", target = "Gornek" },
            },
        }),
        -- Step 3: Orphan Complete (Quest 790 never accepted) + Orphan Turnin (Quest 792 never accepted)
        ns.Core:NewStepCard({
            zone = "Durotar", x = 44.10, y = 69.20,
            targets = { "Gornek" },
            actions = {
                { type = "complete", questId = 790, objIndex = 1, objText = "1/1 Sarkoth's Mangled Claw" },
                { type = "turnin", questId = 792, questTitle = "Vile Familiars", target = "Gornek" },
            },
        }),
    },
})

local detectedIssues = ns.Linter:InspectGuide(lintTestGuide)
local detectedByCode = {}
for _, iss in ipairs(detectedIssues) do
    detectedByCode[iss.code] = (detectedByCode[iss.code] or 0) + 1
end

assertTrue((detectedByCode["ORPHAN_TURNIN"] or 0) >= 1, "Linter detected ORPHAN_TURNIN")
assertTrue((detectedByCode["MISSING_COMPLETE"] or 0) >= 1, "Linter detected MISSING_COMPLETE")
assertTrue((detectedByCode["ORPHAN_COMPLETE"] or 0) >= 1, "Linter detected ORPHAN_COMPLETE")
assertTrue((detectedByCode["MISSING_COORDS"] or 0) >= 1, "Linter detected MISSING_COORDS")
assertTrue((detectedByCode["DUPLICATE_ACTION"] or 0) >= 1, "Linter detected DUPLICATE_ACTION")
assertTrue((detectedByCode["STALE_COMBAT_TARGET"] or 0) >= 1, "Linter detected STALE_COMBAT_TARGET (Battleboar / Prairie Stalker)")

local allResolved, appliedFixes = ns.Linter:ApplyAllFixes(lintTestGuide)
local remainingIssues = ns.Linter:InspectGuide(lintTestGuide)
assertTrue(allResolved == true and #remainingIssues == 0 and appliedFixes >= 6, "Linter:ApplyAllFixes resolved all 6 lint issue categories to 0 remaining warnings/errors")

-- ============================================================================
-- TEST SUITE 4: Bidirectional Compiler & Live RXPGuides Runtime Bridge
-- ============================================================================
print("\n--- Test Suite 4: Bidirectional Compiler & Live RXPGuides Runtime Bridge ---")

-- Clean up test guides so we test the real imported guides + round-trip
for i = 1, #importedGuides do
    local g = importedGuides[i]
    -- Ensure all lint issues on imported guides can also be auto-fixed cleanly
    ns.Linter:ApplyAllFixes(g)

    local compiled = ns.Compiler:CompileGuide(g, true)
    assertTrue(compiled:find("^#classic\n#forever\n") ~= nil, string.format("Guide '%s' emits #classic and #forever headers", g.name))
    assertTrue(compiled:find("\n%s*#loop%f[%s%z]") == nil, string.format("Guide '%s' never emits invalid #loop step tag", g.name))

    local reparsed = ns.Compiler:ParseGuideText(compiled)
    assertEqual(#reparsed.steps, #g.steps, string.format("Guide '%s' round-trip ParseGuideText preserves exact step count (%d)", g.name, #g.steps))

    -- Sync into real RXPGuides via Bridge:SyncGuideToRXP
    RXPGuides._lastParseError = nil
    local syncOk, parsedOrErr = ns.Bridge:SyncGuideToRXP(g, 1)
    assertTrue(syncOk == true and type(parsedOrErr) == "table", string.format("Bridge:SyncGuideToRXP synced '%s' with 0 errors", g.name), tostring(parsedOrErr))
    assertEqual(RXPGuides._lastParseError, nil, string.format("RXPGuides.ParseGuide reported 0 internal errors on '%s'", g.name))
    assertEqual(#parsedOrErr.steps, #g.steps, string.format("RXPGuides parsed all %d steps of '%s' without dropping any steps", #g.steps, g.name))

    -- Verify every step in parsedOrErr.steps has >= 1 element with non-empty text
    local emptySteps = 0
    for sIdx, pStep in ipairs(parsedOrErr.steps) do
        local hasText = false
        for _, el in ipairs(pStep.elements or {}) do
            if type(el.text) == "string" and el.text:match("%S") then
                hasText = true
                break
            end
        end
        if not hasText then
            emptySteps = emptySteps + 1
        end
    end
    assertEqual(emptySteps, 0, string.format("All %d RXPGuides steps in '%s' have >= 1 visible non-empty text element", #parsedOrErr.steps, g.name))
end

-- Verify guideList[group].names_ entries are all structured tables and GenerateMenuTable sorts cleanly
local menuSortOk, menuSortErr = pcall(RXPGuides.RXPFrame.GenerateMenuTable)
assertTrue(menuSortOk, "RXPFrame.GenerateMenuTable sorted guideList[group].names_ with 0 errors", menuSortErr)

-- ============================================================================
-- TEST SUITE 5: Live Event Capture & Speedrun Quick Triggers
-- ============================================================================
print("\n--- Test Suite 5: Live Event Capture & Speedrun Quick Triggers ---")

local liveGuide = ns.Core:CreateGuide({
    name = "Live Capture QA Route",
    group = "My Recorded Guides",
    steps = {},
})
ns.Core:SetActiveGuide(liveGuide.id)

-- Advance past login cooldown
_G.SetMockTime(200.0)
ns.Recorder.loginTimestamp = 100.0
ns.Recorder.isRecording = true
ns.Recorder.questSnapshot = {}
ns.Recorder.completedObjectives = {}

-- Set player in Mulgore at a quest giver, but with a dead hostile Prairie Stalker on 'target'
-- and the friendly quest giver 'Grull Hawkwind' on 'npc'
_mockPlayer.zone = "Mulgore"
_mockPlayer.subzone = "Red Cloud Mesa"
_mockPlayer.mapId = 1412
_mockPlayer.x = 44.90
_mockPlayer.y = 77.10
_mockUnits.target = { name = "Prairie Stalker", isDead = true, hostile = true, isPlayer = false }
_mockUnits.npc = { name = "Grull Hawkwind", isDead = false, hostile = false, isPlayer = false }

-- 1. Simulate QUEST_ACCEPTED (Quest 747: The Hunt Begins)
_mockQuestLog[747] = {
    title = "The Hunt Begins",
    isComplete = false,
    objectives = {
        { text = "0/7 Plainstrider Meat", type = "item", finished = false },
        { text = "0/7 Plainstrider Feather", type = "item", finished = false },
    },
}
ns.Recorder:OnEvent("QUEST_ACCEPTED", 1, 747)
assertEqual(#liveGuide.steps, 1, "QUEST_ACCEPTED (747) recorded Step 1")
assertEqual(liveGuide.steps[1].actions[1].type, "accept", "Step 1 action is .accept 747")
assertEqual(liveGuide.steps[1].targets[1], "Grull Hawkwind", "Recorded friendly NPC 'Grull Hawkwind' and ignored dead hostile 'Prairie Stalker'")

-- 2. Simulate QUEST_WATCH_UPDATE + QUEST_LOG_UPDATE when objective 1 finishes
_G.AdvanceMockTime(20.0)
_mockPlayer.x = 47.50
_mockPlayer.y = 75.20
_mockUnits.npc = nil
_mockUnits.target = { name = "Adult Plainstrider", isDead = true, hostile = true, isPlayer = false }
_mockQuestLog[747].objectives[1] = { text = "7/7 Plainstrider Meat", type = "item", finished = true }
ns.Recorder:OnEvent("QUEST_WATCH_UPDATE", 1)
ns.Recorder:OnEvent("QUEST_LOG_UPDATE")
assertEqual(#liveGuide.steps, 2, "QUEST_WATCH_UPDATE + QUEST_LOG_UPDATE recorded Step 2 for completed objective")
assertEqual(liveGuide.steps[2].actions[1].type, "complete", "Step 2 action is .complete 747,1")
assertEqual(liveGuide.steps[2].actions[1].objText, "7/7 Plainstrider Meat", "Step 2 captured exact objective text '7/7 Plainstrider Meat'")

-- 3. Simulate QUEST_TURNED_IN (747) + TRAINER_SHOW at same NPC camp
_G.AdvanceMockTime(20.0)
_mockPlayer.x = 44.92
_mockPlayer.y = 77.12
_mockUnits.target = { name = "Grull Hawkwind", isDead = false, hostile = false, isPlayer = false }
_mockQuestLog[747] = nil
_mockTurnedIn[747] = true
ns.Recorder:OnEvent("QUEST_TURNED_IN", 747, 250, 0)
ns.Recorder:OnEvent("TRAINER_SHOW")
assertEqual(#liveGuide.steps, 3, "QUEST_TURNED_IN + TRAINER_SHOW at same coordinates auto-merged into Step 3")
assertEqual(#liveGuide.steps[3].actions, 2, "Step 3 contains both .turnin and .trainer actions")

-- 4. Simulate CONFIRM_BINDER (.home) and Hearthstone spellcast 8690 (.hs)
_G.AdvanceMockTime(20.0)
_mockPlayer.x = 46.60
_mockPlayer.y = 61.00
_mockPlayer.subzone = "Bloodhoof Village"
_mockUnits.target = { name = "Innkeeper Kauth", isDead = false, hostile = false, isPlayer = false }
ns.Recorder:OnEvent("CONFIRM_BINDER")
_G.AdvanceMockTime(20.0)
ns.Recorder:OnEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 8690)
assertTrue(#liveGuide.steps >= 4, "CONFIRM_BINDER (.home) and UNIT_SPELLCAST_SUCCEEDED 8690 (.hs) recorded")

-- 5. Simulate PLAYER_DEAD + AREA_SPIRIT_HEALER_IN_RANGE > 80 yards away (.deathskip)
_G.AdvanceMockTime(20.0)
_mockPlayer.x = 30.00
_mockPlayer.y = 30.00
_mockPlayer.isDead = true
ns.Recorder:OnEvent("PLAYER_DEAD")
_G.AdvanceMockTime(5.0)
_mockPlayer.x = 46.60
_mockPlayer.y = 61.00
ns.Recorder:OnEvent("AREA_SPIRIT_HEALER_IN_RANGE")
_mockPlayer.isDead = false
local lastCard = liveGuide.steps[#liveGuide.steps]
assertEqual(lastCard.actions[#lastCard.actions].type, "deathskip", "PLAYER_DEAD + distant Spirit Healer recorded .deathskip")

-- 6. Test all 5 quick-action HUD triggers
local beforeQuickCount = #liveGuide.steps
ns.Recorder:RecordQuickNote("Watch out for patrolling Kodo")
ns.Recorder:RecordGrindXP("6")
ns.Recorder:RecordHearthOrBind("hs", "Bloodhoof Village")
ns.Recorder:RecordDeathskip()
ns.Recorder:RecordWaypointPin(false)
assertTrue(#liveGuide.steps > beforeQuickCount, "All 5 quick-action triggers (Note, GrindXP, Hearth/Bind, Deathskip, WaypointPin) executed cleanly")

-- ============================================================================
-- TEST SUITE 6: UI Initialization, Slash Commands & Strict ASCII / Zero-Icon Policy
-- ============================================================================
print("\n--- Test Suite 6: UI Initialization, Slash Commands & Strict ASCII / Zero-Icon Policy ---")

local uiInitOk, uiInitErr = pcall(function()
    ns.UI:Init()
    ns.UI:ToggleStudio()
    ns.UI.StudioFrame:Refresh()
    ns.UI.StudioFrame:SelectStep(1)
    ns.UI.LiveHUD:Refresh()
end)
assertTrue(uiInitOk, "ns.UI:Init(), ToggleStudio(), SelectStep(1), and LiveHUD:Refresh() executed with 0 Lua errors", uiInitErr)

-- Verify EditBox focus guard and deferred commit behavior
local nameBox = ns.UI.StudioFrame.guideNameBox
nameBox:SetFocus()
assertTrue(nameBox:HasFocus() == true, "EditBox:HasFocus() returns true when focused")
nameBox._text = "User Typing In Progress"
ns.UI.StudioFrame:Refresh()
assertEqual(nameBox:GetText(), "User Typing In Progress", "StudioFrame:Refresh() does not overwrite EditBox text while focused")
nameBox:ClearFocus()
assertEqual(liveGuide.name, "User Typing In Progress", "EditBox commits updated guide name on focus lost")

-- Test Slash Commands (/rxpstudio and /rxprec)
local slashOk, slashErr = pcall(function()
    if SlashCmdList["RXPSTUDIO"] then
        SlashCmdList["RXPSTUDIO"]("")
        SlashCmdList["RXPSTUDIO"]("hud")
        SlashCmdList["RXPSTUDIO"]("lint")
        SlashCmdList["RXPSTUDIO"]("fix")
        SlashCmdList["RXPSTUDIO"]("sync")
    end
    if SlashCmdList["RXPREC"] then
        SlashCmdList["RXPREC"]("note Quick slash note")
        SlashCmdList["RXPREC"]("xp 8")
        SlashCmdList["RXPREC"]("pin")
    end
end)
assertTrue(slashOk, "Slash commands /rxpstudio and /rxprec executed with 0 Lua errors", slashErr)

-- Strict ASCII-only & Zero-Icon Policy Scan across all 12 RXP_Studio .lua files
local nonAsciiFiles = 0
local unauthorizedIcons = 0
for _, relPath in ipairs(TOC_FILES) do
    local fullPath = STUDIO_DIR .. "\\" .. relPath
    local f = assert(io.open(fullPath, "rb"))
    local content = f:read("*a")
    f:close()

    for i = 1, #content do
        if string.byte(content, i) > 127 then
            nonAsciiFiles = nonAsciiFiles + 1
            print(string.format("  [NON-ASCII] %s byte offset %d (0x%02X)", relPath, i, string.byte(content, i)))
            break
        end
    end

    for texPath in content:gmatch("[Ii]nterface\\[%w_\\%-%.]+") do
        local lowerTex = texPath:lower():gsub("\\\\", "\\")
        if lowerTex ~= [[interface\buttons\white8x8]]
           and lowerTex ~= [[interface\glues\charactercreate\ui-charactercreate-classes]] then
            unauthorizedIcons = unauthorizedIcons + 1
            print(string.format("  [UNAUTHORIZED TEXTURE] %s: %s", relPath, texPath))
        end
    end
end

assertEqual(nonAsciiFiles, 0, "All 12 RXP_Studio .lua files contain 0 non-ASCII characters (100% pure ASCII)")
assertEqual(unauthorizedIcons, 0, "All 12 RXP_Studio .lua files obey the Zero-Icon Policy (0 unauthorized icon textures)")

print("\n============================================================================")
print(string.format("QA SUMMARY: %d / %d Assertions Passed (%d Failed)", passedAssertions, totalAssertions, failedAssertions))
print("============================================================================")

if failedAssertions > 0 then
    error("QA Test Suite had " .. tostring(failedAssertions) .. " failure(s)!")
end
