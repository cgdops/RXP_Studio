local addonName, ns = ...
_G.RXP_Studio = ns

ns.Core = ns.Core or {}
ns.Compiler = ns.Compiler or {}
ns.Linter = ns.Linter or {}
ns.Bridge = ns.Bridge or {}
ns.Recorder = ns.Recorder or {}
ns.AutoMerger = ns.AutoMerger or {}
ns.UI = ns.UI or {}
ns.callbacks = ns.callbacks or {}

local Core = ns.Core

Core.selectedStepIndex = Core.selectedStepIndex or 1
local nextCardUid = 1

local DEFAULT_SETTINGS = {
    autoMerge = true,
    autoMergeRadius = 15,
    showHUD = true,
    rawSyntaxMode = false,
}

-- Known starter quests that signal a fresh character/run when re-accepted after progression
local STARTER_QUEST_RESETS = {
    [92460] = "Zephras Isle", -- Coming of Age (High Elf / Zephras Isle)
    [92461] = "Zephras Isle", -- Harmony in Balance
    [4641]  = "Durotar",      -- Your Place in the World (Orc / Troll)
    [788]   = "Durotar",      -- Cutting Teeth
    [747]   = "Mulgore",      -- The Hunt Begins (Tauren)
    [752]   = "Mulgore",      -- A Humble Task
    [380]   = "Tirisfal Glades", -- Night Web's Hollow (Undead)
    [363]   = "Tirisfal Glades", -- Rude Awakening
    [783]   = "Elwynn Forest",   -- A Threat Within (Human)
    [179]   = "Dun Morogh",      -- Dwarven Outfitters (Dwarf / Gnome)
    [456]   = "Teldrassil",      -- The Balance of Nature (Night Elf)
}

-- Known class-specific quests used to infer the class/spec of a recorded session
local CLASS_QUEST_HINTS = {
    [92484] = "SHAMAN",  -- Embracing the Elements (Zephras Isle)
    [92466] = "SHAMAN",  -- Call of Earth (Zephras Isle)
    [97243] = "SHAMAN",  -- Call of Fire (Zephras Isle)
    [1516]  = "SHAMAN",  -- Call of Earth (Durotar)
    [3089]  = "SHAMAN",  -- Rune-Inscribed Parchment (Durotar)
    [92485] = "DRUID",   -- A Student of Nature (Zephras Isle)
    [3094]  = "DRUID",   -- Verdant Note (Mulgore)
    [5928]  = "DRUID",   -- Heeding the Call (Mulgore)
    [92481] = "MAGE",    -- A Student of the Arcane (Zephras Isle)
    [3085]  = "PRIEST",  -- Hallowed Tablet (Durotar)
    [3065]  = "WARRIOR", -- Simple Tablet (Durotar)
}

local CLASS_DISPLAY_NAMES = {
    WARRIOR = "Warrior",
    PALADIN = "Paladin",
    HUNTER  = "Hunter",
    ROGUE   = "Rogue",
    PRIEST  = "Priest",
    SHAMAN  = "Shaman",
    MAGE    = "Mage",
    WARLOCK = "Warlock",
    DRUID   = "Druid",
}

local ZONE_FACTION_HINTS = {
    ["Zephras Isle"]        = "Alliance",
    ["Durotar"]             = "Horde",
    ["Mulgore"]             = "Horde",
    ["Tirisfal Glades"]     = "Horde",
    ["Stonetalon Mountains"]= "Horde",
    ["Thunder Bluff"]       = "Horde",
    ["Ashenvale"]           = "Horde",
}

local function safeFireCallback(event, ...)
    if ns.FireCallback then
        ns:FireCallback(event, ...)
    end
end

local function generateCardId()
    local id = "card_" .. tostring(nextCardUid)
    nextCardUid = nextCardUid + 1
    return id
end

function Core:NextCardId()
    return generateCardId()
end

function Core:NextId()
    return generateCardId()
end

local function deepCopy(orig)
    if type(orig) ~= "table" then
        return orig
    end
    local copy = {}
    for k, v in pairs(orig) do
        copy[deepCopy(k)] = deepCopy(v)
    end
    return copy
end

function Core:NewAction(fields)
    fields = fields or {}
    return {
        type        = fields.type or "note",
        questId     = fields.questId and tonumber(fields.questId) or nil,
        questTitle  = fields.questTitle or nil,
        objIndex    = fields.objIndex and tonumber(fields.objIndex) or (fields.type == "complete" and 1 or nil),
        objText     = fields.objText or nil,
        objMax      = fields.objMax and tonumber(fields.objMax) or nil,
        itemId      = fields.itemId and tonumber(fields.itemId) or nil,
        itemName    = fields.itemName or nil,
        qty         = fields.qty and tonumber(fields.qty) or nil,
        xpTarget    = fields.xpTarget or nil,
        destination = fields.destination or nil,
        text        = fields.text or nil,
        target      = fields.target or nil,
        zone        = fields.zone or nil,
        x           = fields.x and tonumber(fields.x) or nil,
        y           = fields.y and tonumber(fields.y) or nil,
    }
end

function Core:NewStepCard(fields)
    fields = fields or {}
    local conditions = fields.conditions or {}
    local card = {
        id               = fields.id or generateCardId(),
        title            = fields.title or "",
        zone             = fields.zone or nil,
        x                = fields.x and tonumber(fields.x) or nil,
        y                = fields.y and tonumber(fields.y) or nil,
        loopWaypoints    = fields.loopWaypoints or {},
        targets          = fields.targets or {},
        mobs             = fields.mobs or {},
        sticky           = fields.sticky and true or false,
        completeWithNext = fields.completeWithNext and true or false,
        optional         = fields.optional and true or false,
        hideWindow       = fields.hideWindow and true or false,
        loop             = fields.loop and true or false,
        completeTogether = (fields.completeTogether == nil) and true or (fields.completeTogether and true or false),
        note             = fields.note or "",
        conditions       = {
            classes = conditions.classes or {},
            races   = conditions.races or {},
        },
        conditionText    = fields.conditionText or nil,
        label            = fields.label or nil,
        rawOverride      = fields.rawOverride or nil,
        actions          = {},
        lintIssues       = fields.lintIssues or {},
    }
    if fields.actions then
        for i = 1, #fields.actions do
            card.actions[i] = self:NewAction(fields.actions[i])
        end
    end
    return card
end

function Core:GetCardSummary(card)
    if not card then return "Empty Step" end
    if card.title and card.title ~= "" then
        return card.title
    end
    if card.rawOverride and card.rawOverride ~= "" then
        local firstLine = card.rawOverride:match("[^\r\n]+") or "Custom Step"
        return "[Raw] " .. firstLine
    end
    local actions = card.actions or {}
    if #actions > 0 then
        local first = actions[1]
        local suffix = (#actions > 1) and string.format(" (+%d more)", #actions - 1) or ""
        if first.type == "accept" then
            return string.format("Accept: %s%s", first.questTitle or ("#" .. tostring(first.questId or "?")), suffix)
        elseif first.type == "turnin" then
            return string.format("Turn In: %s%s", first.questTitle or ("#" .. tostring(first.questId or "?")), suffix)
        elseif first.type == "complete" then
            return string.format("Complete: %s%s", first.objText or ("#" .. tostring(first.questId or "?")), suffix)
        elseif first.type == "trainer" then
            local npc = (card.targets and card.targets[1]) or first.target
            return (npc and ("Train: " .. npc) or (first.text or "Train Spells")) .. suffix
        elseif first.type == "vendor" then
            local npc = (card.targets and card.targets[1]) or first.target
            return (npc and ("Vendor: " .. npc) or (first.text or "Vendor / Resupply")) .. suffix
        elseif first.type == "hs" then
            return ("Hearth: " .. (first.destination or first.text or "Inn")) .. suffix
        elseif first.type == "home" then
            return ("Set Hearth: " .. (first.destination or first.text or "Inn")) .. suffix
        elseif first.type == "fp" then
            return ("Flight Path: " .. (first.destination or first.text or "Discover")) .. suffix
        elseif first.type == "fly" then
            return ("Fly: " .. (first.destination or first.text or "Destination")) .. suffix
        elseif first.type == "deathskip" then
            return (first.text or "Deathskip") .. suffix
        elseif first.type == "xp" then
            return ("Grind XP: " .. tostring(first.xpTarget or "")) .. suffix
        elseif first.type == "use" then
            return ("Use: " .. tostring(first.itemName or first.text or first.itemId or "Item")) .. suffix
        elseif first.type == "collect" then
            return ("Collect: " .. tostring(first.itemName or first.text or first.itemId or "Item")) .. suffix
        elseif first.type == "note" then
            return (first.text or "Step Note") .. suffix
        end
    end
    if card.note and card.note ~= "" then
        return card.note
    end
    if card.zone and card.x and card.y then
        return string.format("Travel to %s (%.1f, %.1f)", card.zone, card.x, card.y)
    end
    return "Empty Step"
end

function Core:NormalizeGuide(guide, fallbackIndex)
    if type(guide) ~= "table" then return nil end
    local idx = fallbackIndex or 1
    guide.id          = tostring(guide.id or ("guide_" .. tostring(idx)))
    guide.name        = guide.name or ("01-10 Recorded Route " .. tostring(idx))
    guide.displayName = guide.displayName or guide.name
    guide.group       = (guide.group and guide.group ~= "") and guide.group or "My Recorded Guides"
    guide.subgroup    = guide.subgroup or ""
    guide.version     = tonumber(guide.version) or 1
    guide.faction     = guide.faction or ""
    guide.classes     = guide.classes or {}
    guide.races       = guide.races or {}
    guide.nextGuide   = guide.nextGuide or nil
    guide.steps       = guide.steps or {}
    for i = 1, #guide.steps do
        guide.steps[i] = self:NewStepCard(guide.steps[i])
    end
    return guide
end

function Core:InitDB()
    if type(_G.RXP_StudioDB) ~= "table" then
        _G.RXP_StudioDB = {}
    end
    local db = _G.RXP_StudioDB
    db.version = db.version or 1
    db.activeGuideId = db.activeGuideId or "default"
    if type(db.guides) ~= "table" then
        db.guides = {}
    end
    if type(db.settings) ~= "table" then
        db.settings = {}
    end
    for k, v in pairs(DEFAULT_SETTINGS) do
        if db.settings[k] == nil then
            db.settings[k] = v
        end
    end

    -- Normalize any existing guides into an ordered array while preserving lookup
    local ordered = {}
    local seenIds = {}
    for i = 1, #db.guides do
        local g = self:NormalizeGuide(db.guides[i], i)
        if g and not seenIds[g.id] then
            seenIds[g.id] = true
            table.insert(ordered, g)
        end
    end
    for k, v in pairs(db.guides) do
        if type(k) == "string" and type(v) == "table" then
            v.id = v.id or k
            local g = self:NormalizeGuide(v, #ordered + 1)
            if g and not seenIds[g.id] then
                seenIds[g.id] = true
                table.insert(ordered, g)
            end
        end
    end
    db.guides = ordered

    -- Automatically import RXP_RecorderDB on first run if present
    if _G.RXP_RecorderDB and type(_G.RXP_RecorderDB.steps) == "table" and #_G.RXP_RecorderDB.steps > 0 and not db.legacyImported then
        self:ImportLegacyRecorderDB(_G.RXP_RecorderDB.steps)
        db.legacyImported = true
    end

    -- Ensure at least one active guide exists
    if #db.guides == 0 then
        self:CreateGuide({
            id = "default",
            name = "01-10 Starter Speedrun",
            group = "My Recorded Guides",
            subgroup = "",
            version = 1,
            faction = "",
        })
    end

    -- Validate activeGuideId
    if not self:GetGuide(db.activeGuideId) then
        db.activeGuideId = db.guides[1].id
    end

    self.selectedStepIndex = 1
    local active = self:GetActiveGuide()
    if active and ns.Linter and ns.Linter.InspectGuide then
        ns.Linter:InspectGuide(active)
    end

    safeFireCallback("DB_INITIALIZED", db)
    return db
end

function Core:GetGuideList()
    if not _G.RXP_StudioDB or type(_G.RXP_StudioDB.guides) ~= "table" then
        return {}
    end
    local list = {}
    local seen = {}
    for i = 1, #_G.RXP_StudioDB.guides do
        local g = _G.RXP_StudioDB.guides[i]
        if type(g) == "table" and g.id and not seen[g.id] then
            seen[g.id] = true
            table.insert(list, g)
        end
    end
    for k, g in pairs(_G.RXP_StudioDB.guides) do
        if type(k) == "string" and type(g) == "table" then
            g.id = g.id or k
            if not seen[g.id] then
                seen[g.id] = true
                table.insert(list, g)
            end
        end
    end
    return list
end

function Core:GetGuide(guideId)
    if not guideId or not _G.RXP_StudioDB or not _G.RXP_StudioDB.guides then
        return nil
    end
    local guides = _G.RXP_StudioDB.guides
    if type(guides[guideId]) == "table" then
        return guides[guideId]
    end
    for i = 1, #guides do
        local g = guides[i]
        if type(g) == "table" and (g.id == guideId or g.name == guideId) then
            return g
        end
    end
    for k, g in pairs(guides) do
        if type(g) == "table" and (g.id == guideId or g.name == guideId or k == guideId) then
            return g
        end
    end
    return nil
end

function Core:CreateGuide(metadata)
    if not _G.RXP_StudioDB then
        self:InitDB()
    end
    metadata = metadata or {}
    local guides = _G.RXP_StudioDB.guides

    local baseId = metadata.id
    if not baseId or baseId == "" then
        local slug = (metadata.name or "guide"):lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
        if slug == "" then slug = "guide" end
        baseId = slug
    end

    local uniqueId = baseId
    local suffix = 2
    while self:GetGuide(uniqueId) do
        uniqueId = baseId .. "_" .. tostring(suffix)
        suffix = suffix + 1
    end

    local guide = self:NormalizeGuide({
        id          = uniqueId,
        name        = metadata.name or ("New Guide " .. tostring(#guides + 1)),
        displayName = metadata.displayName or metadata.name,
        group       = metadata.group or "My Recorded Guides",
        subgroup    = metadata.subgroup or "",
        version     = metadata.version or 1,
        faction     = metadata.faction or "",
        classes     = metadata.classes and deepCopy(metadata.classes) or {},
        races       = metadata.races and deepCopy(metadata.races) or {},
        nextGuide   = metadata.nextGuide or nil,
        steps       = metadata.steps or {},
    }, #guides + 1)

    table.insert(guides, guide)
    _G.RXP_StudioDB.activeGuideId = guide.id
    self.selectedStepIndex = math.max(1, #guide.steps > 0 and 1 or 1)

    if ns.Linter and ns.Linter.InspectGuide then
        ns.Linter:InspectGuide(guide)
    end

    safeFireCallback("GUIDE_CREATED", guide)
    safeFireCallback("ACTIVE_GUIDE_CHANGED", guide)
    return guide
end

function Core:GetActiveGuide()
    if not _G.RXP_StudioDB then
        self:InitDB()
    end
    local g = self:GetGuide(_G.RXP_StudioDB.activeGuideId)
    if not g and #_G.RXP_StudioDB.guides > 0 then
        g = _G.RXP_StudioDB.guides[1]
        _G.RXP_StudioDB.activeGuideId = g.id
    end
    return g
end

function Core:SetActiveGuide(guideId)
    if not _G.RXP_StudioDB then
        self:InitDB()
    end
    local g = self:GetGuide(guideId)
    if not g then
        return nil
    end
    _G.RXP_StudioDB.activeGuideId = g.id
    self.selectedStepIndex = 1
    if ns.Linter and ns.Linter.InspectGuide then
        ns.Linter:InspectGuide(g)
    end
    safeFireCallback("ACTIVE_GUIDE_CHANGED", g)
    return g
end

function Core:DeleteGuide(guideId)
    if not _G.RXP_StudioDB or not _G.RXP_StudioDB.guides then
        return false
    end
    local guides = _G.RXP_StudioDB.guides
    local removed = false
    for i = #guides, 1, -1 do
        if guides[i] and guides[i].id == guideId then
            table.remove(guides, i)
            removed = true
        end
    end
    if guides[guideId] then
        guides[guideId] = nil
        removed = true
    end
    if not removed then
        return false
    end
    if #guides == 0 then
        self:CreateGuide({
            id = "default",
            name = "01-10 Starter Speedrun",
            group = "My Recorded Guides",
        })
    elseif _G.RXP_StudioDB.activeGuideId == guideId then
        self:SetActiveGuide(guides[1].id)
    end
    safeFireCallback("GUIDE_DELETED", guideId)
    return true
end

function Core:DuplicateGuide(guideId)
    local src = self:GetGuide(guideId or (_G.RXP_StudioDB and _G.RXP_StudioDB.activeGuideId))
    if not src then return nil end
    local copy = deepCopy(src)
    copy.id = nil
    copy.name = src.name .. " (Copy)"
    copy.displayName = copy.name
    return self:CreateGuide(copy)
end

function Core:SetSelectedStepIndex(index)
    local guide = self:GetActiveGuide()
    local maxSteps = guide and #guide.steps or 1
    if maxSteps < 1 then maxSteps = 1 end
    self.selectedStepIndex = math.max(1, math.min(tonumber(index) or 1, maxSteps))
    local card = guide and guide.steps[self.selectedStepIndex] or nil
    safeFireCallback("STEP_SELECTED", self.selectedStepIndex, card, guide)
    return self.selectedStepIndex, card
end

function Core:GetSelectedStepCard()
    local guide = self:GetActiveGuide()
    if not guide or not guide.steps then return nil, nil end
    local idx = math.max(1, math.min(self.selectedStepIndex or 1, #guide.steps))
    return guide.steps[idx], idx
end

function Core:AddStepCard(guideOrCard, cardOrIndex, maybeIndex)
    local guide, card, index
    -- Support both AddStepCard(guide, card, index) and AddStepCard(card, index)
    if type(guideOrCard) == "table" and guideOrCard.steps then
        guide = guideOrCard
        card = cardOrIndex
        index = maybeIndex
    else
        guide = self:GetActiveGuide()
        card = guideOrCard
        index = cardOrIndex
    end
    if not guide then return nil end
    local newCard = self:NewStepCard(card)
    if index and type(index) == "number" and index >= 1 and index <= (#guide.steps + 1) then
        table.insert(guide.steps, index, newCard)
        self.selectedStepIndex = index
    else
        table.insert(guide.steps, newCard)
        self.selectedStepIndex = #guide.steps
    end

    if ns.Linter and ns.Linter.InspectGuide then
        ns.Linter:InspectGuide(guide)
    end
    safeFireCallback("STEP_ADDED", guide, newCard, self.selectedStepIndex)
    safeFireCallback("GUIDE_UPDATED", guide)
    return newCard, self.selectedStepIndex
end

function Core:RemoveStepCard(guideOrIndex, maybeIndex)
    local guide, index
    if type(guideOrIndex) == "table" and guideOrIndex.steps then
        guide = guideOrIndex
        index = maybeIndex
    else
        guide = self:GetActiveGuide()
        index = guideOrIndex
    end
    if not guide or not guide.steps then return nil end
    index = tonumber(index) or self.selectedStepIndex
    if not index or index < 1 or index > #guide.steps then
        return nil
    end
    local removed = table.remove(guide.steps, index)
    if self.selectedStepIndex > #guide.steps then
        self.selectedStepIndex = math.max(1, #guide.steps)
    end
    if ns.Linter and ns.Linter.InspectGuide then
        ns.Linter:InspectGuide(guide)
    end
    safeFireCallback("STEP_REMOVED", guide, removed, index)
    safeFireCallback("GUIDE_UPDATED", guide)
    return removed
end

function Core:MoveStepCard(guideOrFrom, fromOrTo, maybeTo)
    local guide, fromIndex, toIndex
    if type(guideOrFrom) == "table" and guideOrFrom.steps then
        guide = guideOrFrom
        fromIndex = fromOrTo
        toIndex = maybeTo
    else
        guide = self:GetActiveGuide()
        fromIndex = guideOrFrom
        toIndex = fromOrTo
    end
    if not guide or not guide.steps then return false end
    fromIndex = tonumber(fromIndex)
    toIndex = tonumber(toIndex)
    if not fromIndex or not toIndex then return false end
    if fromIndex < 1 or fromIndex > #guide.steps then return false end
    toIndex = math.max(1, math.min(toIndex, #guide.steps))
    if fromIndex == toIndex then return false end

    local card = table.remove(guide.steps, fromIndex)
    table.insert(guide.steps, toIndex, card)
    self.selectedStepIndex = toIndex

    if ns.Linter and ns.Linter.InspectGuide then
        ns.Linter:InspectGuide(guide)
    end
    safeFireCallback("STEP_MOVED", guide, card, fromIndex, toIndex)
    safeFireCallback("GUIDE_UPDATED", guide)
    return true
end

-- Built-in fallback step merger when Recorder/AutoMerger.lua is not yet loaded
local function cardsCanMergeFallback(prevCard, nextCard, radiusYards)
    if not prevCard or not nextCard then return false end
    if prevCard.rawOverride or nextCard.rawOverride then return false end
    if prevCard.zone ~= nextCard.zone or not prevCard.zone then return false end

    local prevTarget = prevCard.targets and prevCard.targets[1]
    local nextTarget = nextCard.targets and nextCard.targets[1]

    -- Check distance in map percentage units (~1.5 map units is ~15 yards in typical zones)
    local distMap = 999
    if prevCard.x and prevCard.y and nextCard.x and nextCard.y then
        local dx = prevCard.x - nextCard.x
        local dy = prevCard.y - nextCard.y
        distMap = math.sqrt(dx * dx + dy * dy)
    end
    local maxMapDist = (tonumber(radiusYards) or 15) * 0.12

    -- Case 1: Consecutive NPC interactions with the same NPC nearby
    if prevTarget and nextTarget and prevTarget == nextTarget and distMap <= math.max(maxMapDist, 1.5) then
        -- Do not merge if either step is a combat/loot .complete objective out in the field,
        -- unless it's an instant dialogue objective at the exact same NPC
        local prevHasFieldComplete = false
        for _, a in ipairs(prevCard.actions or {}) do
            if a.type == "complete" and distMap > 0.35 then
                prevHasFieldComplete = true
            end
        end
        local nextHasFieldComplete = false
        for _, a in ipairs(nextCard.actions or {}) do
            if a.type == "complete" and distMap > 0.35 then
                nextHasFieldComplete = true
            end
        end
        if not prevHasFieldComplete and not nextHasFieldComplete then
            return true
        end
    end

    -- Case 2: Consecutive .complete objectives for the SAME quest (or very close cluster) with no NPC target
    if not prevTarget and not nextTarget and distMap <= math.max(maxMapDist, 2.5) then
        local allCompletePrev = #(prevCard.actions or {}) > 0
        local allCompleteNext = #(nextCard.actions or {}) > 0
        for _, a in ipairs(prevCard.actions or {}) do
            if a.type ~= "complete" then allCompletePrev = false end
        end
        for _, a in ipairs(nextCard.actions or {}) do
            if a.type ~= "complete" then allCompleteNext = false end
        end
        if allCompletePrev and allCompleteNext then
            local qPrev = prevCard.actions[1].questId
            local qNext = nextCard.actions[1].questId
            if qPrev == qNext or distMap <= 1.2 then
                return true
            end
        end
    end

    return false
end

local function mergeCardIntoPrevFallback(prevCard, nextCard)
    for _, action in ipairs(nextCard.actions or {}) do
        -- Deduplicate identical consecutive actions during merge
        local isDup = false
        for _, existing in ipairs(prevCard.actions) do
            if existing.type == action.type and existing.questId == action.questId and existing.objIndex == action.objIndex then
                if action.type == "trainer" or action.type == "vendor" or action.questId ~= nil then
                    isDup = true
                    break
                end
            end
        end
        if not isDup then
            local copied = deepCopy(action)
            copied.zone = copied.zone or nextCard.zone
            copied.x = copied.x or nextCard.x
            copied.y = copied.y or nextCard.y
            table.insert(prevCard.actions, copied)
        end
    end

    local seenTargets = {}
    for _, t in ipairs(prevCard.targets or {}) do seenTargets[t] = true end
    for _, t in ipairs(nextCard.targets or {}) do
        if not seenTargets[t] then
            seenTargets[t] = true
            table.insert(prevCard.targets, t)
        end
    end

    local seenMobs = {}
    for _, m in ipairs(prevCard.mobs or {}) do seenMobs[m] = true end
    for _, m in ipairs(nextCard.mobs or {}) do
        if not seenMobs[m] then
            seenMobs[m] = true
            table.insert(prevCard.mobs, m)
        end
    end

    if (not prevCard.note or prevCard.note == "") and nextCard.note and nextCard.note ~= "" then
        prevCard.note = nextCard.note
    end
end

function Core:FallbackMergeGuideSteps(guide, radiusYards)
    if not guide or not guide.steps or #guide.steps < 2 then
        return guide
    end
    local merged = { guide.steps[1] }
    for i = 2, #guide.steps do
        local prev = merged[#merged]
        local curr = guide.steps[i]
        if cardsCanMergeFallback(prev, curr, radiusYards) then
            mergeCardIntoPrevFallback(prev, curr)
        else
            table.insert(merged, curr)
        end
    end
    guide.steps = merged
    return guide
end

-- Helper to classify the primary region of a step card
local function getRegionGroup(zone)
    if not zone or zone == "" then return nil end
    if zone == "Zephras Isle" then return "Zephras Isle" end
    if zone == "Durotar" or zone == "Orgrimmar" then return "Durotar" end
    if zone == "Mulgore" then return "Mulgore" end
    if zone == "Ashenvale" or zone == "Stonetalon Mountains" or zone == "Thunder Bluff" or zone == "The Barrens" then
        return "Ashenvale & Barrens"
    end
    if zone == "Kalimdor" or zone == "Eastern Kingdoms" then
        return nil -- Continent-level fallback (instance or login flush)
    end
    return zone
end

-- Check if a Kalimdor step is a login quest-log flush rather than a real in-session objective
local function isKalimdorLoginFlush(card, acceptedInSession)
    if not card or card.zone ~= "Kalimdor" then
        return false
    end
    if not card.actions or #card.actions == 0 then
        return false
    end
    for _, action in ipairs(card.actions) do
        if action.type ~= "complete" then
            return false
        end
        local objText = action.objText or ""
        -- Blank/unloaded client cache strings like "1/1  " or "1/1   slain"
        if objText:match("^%d+/%d+%s*$") or objText:match("^%d+/%d+%s%s+slain$") then
            return true
        end
        -- Complete event in continent "Kalimdor" for a quest never accepted in this session
        if action.questId and not acceptedInSession[action.questId] then
            return true
        end
    end
    return false
end

function Core:ImportLegacyRecorderDB(rawStepsTable)
    rawStepsTable = rawStepsTable or (_G.RXP_RecorderDB and _G.RXP_RecorderDB.steps)
    if type(rawStepsTable) ~= "table" or #rawStepsTable == 0 then
        return 0, {}
    end
    if not ns.Compiler or not ns.Compiler.ParseRawStep then
        return 0, {}
    end

    -- Step 1: Parse all raw step strings into StepCards
    local parsedCards = {}
    for i = 1, #rawStepsTable do
        local rawStr = rawStepsTable[i]
        if type(rawStr) == "string" and rawStr:match("%S") then
            local card = ns.Compiler:ParseRawStep(rawStr)
            if card then
                table.insert(parsedCards, card)
            end
        end
    end

    if #parsedCards == 0 then
        return 0, {}
    end

    -- Step 2: Smart Session Segmenter
    local rawSegments = {}
    local currentSegment = {
        region = nil,
        cards = {},
        acceptedQuests = {},
        turnedInQuests = {},
        classHint = nil,
    }

    local function pushSegment()
        if #currentSegment.cards > 0 then
            table.insert(rawSegments, currentSegment)
        end
        currentSegment = {
            region = nil,
            cards = {},
            acceptedQuests = {},
            turnedInQuests = {},
            classHint = nil,
        }
    end

    for i = 1, #parsedCards do
        local card = parsedCards[i]
        local cardRegion = getRegionGroup(card.zone)

        -- Check if this card is a starter quest reset or major region switch
        local isStarterReset = false
        for _, action in ipairs(card.actions or {}) do
            local qid = action.questId
            if qid and STARTER_QUEST_RESETS[qid] then
                if action.type == "accept" then
                    -- If we already progressed in this session (or already accepted/completed quests)
                    -- and are not just double-clicking the exact same starter quest on step 1
                    if #currentSegment.cards > 2 or (currentSegment.acceptedQuests[qid] and #currentSegment.cards > 1) then
                        isStarterReset = true
                        break
                    end
                end
            end
        end

        local isRegionSwitch = false
        if cardRegion and currentSegment.region and cardRegion ~= currentSegment.region then
            isRegionSwitch = true
        end

        if (isStarterReset or isRegionSwitch) and #currentSegment.cards > 0 then
            pushSegment()
        end

        -- Filter out continent-level Kalimdor login-flush bursts from clean segments
        -- (unless the entire input is only Kalimdor steps)
        if not isKalimdorLoginFlush(card, currentSegment.acceptedQuests) then
            if cardRegion and not currentSegment.region then
                currentSegment.region = cardRegion
            end
            for _, action in ipairs(card.actions or {}) do
                if action.questId then
                    if action.type == "accept" then
                        currentSegment.acceptedQuests[action.questId] = true
                    elseif action.type == "turnin" then
                        currentSegment.turnedInQuests[action.questId] = true
                    end
                    if CLASS_QUEST_HINTS[action.questId] and not currentSegment.classHint then
                        currentSegment.classHint = CLASS_QUEST_HINTS[action.questId]
                    end
                end
            end
            table.insert(currentSegment.cards, card)
        end
    end
    pushSegment()

    -- Fallback: if all steps were Kalimdor login-flush steps (e.g., synthetic test), keep them in one segment
    if #rawSegments == 0 and #parsedCards > 0 then
        table.insert(rawSegments, {
            region = parsedCards[1].zone or "Kalimdor",
            cards = parsedCards,
            acceptedQuests = {},
            turnedInQuests = {},
        })
    end

    -- Step 3: Filter out tiny 1-4 step accidental restarts ONLY when there are multiple full segments
    local finalSegments = {}
    if #rawSegments <= 1 then
        finalSegments = rawSegments
    else
        for i = 1, #rawSegments do
            local seg = rawSegments[i]
            local nextSeg = rawSegments[i + 1]
            local isTinyFalseStart = (#seg.cards <= 5) and (nextSeg and nextSeg.region == seg.region and #nextSeg.cards > #seg.cards)
            local isTrailingStub = (#seg.cards <= 4) and (#rawSegments > 3)
            if not isTinyFalseStart and not isTrailingStub then
                table.insert(finalSegments, seg)
            end
        end
        if #finalSegments == 0 then
            finalSegments = rawSegments
        end
    end

    -- Step 4: Build Guide objects, apply AutoMerger, and register in RXP_StudioDB
    local createdGuides = {}
    local regionCounters = {}

    for i = 1, #finalSegments do
        local seg = finalSegments[i]
        local regionName = seg.region or "Recorded Zone"
        regionCounters[regionName] = (regionCounters[regionName] or 0) + 1
        local runNum = regionCounters[regionName]

        local classTag = seg.classHint and CLASS_DISPLAY_NAMES[seg.classHint] or nil
        local levelRange = "01-10"
        if regionName == "Ashenvale & Barrens" then
            levelRange = "20-25"
        elseif #seg.cards < 35 then
            levelRange = "01-06"
        end

        local guideTitle
        if classTag then
            guideTitle = string.format("%s %s (%s Run %d)", levelRange, regionName, classTag, runNum)
        else
            guideTitle = string.format("%s %s (Run %d)", levelRange, regionName, runNum)
        end

        local classesTable = seg.classHint and { seg.classHint } or {}
        local faction = ZONE_FACTION_HINTS[regionName] or ""

        local guide = self:CreateGuide({
            name        = guideTitle,
            displayName = guideTitle,
            group       = "My Recorded Guides",
            subgroup    = regionName,
            version     = 1,
            faction     = faction,
            classes     = classesTable,
            steps       = seg.cards,
        })

        -- Apply AutoMerger if enabled/loaded, or fallback merger
        local radius = (_G.RXP_StudioDB and _G.RXP_StudioDB.settings and _G.RXP_StudioDB.settings.autoMergeRadius) or 15
        if ns.AutoMerger and ns.AutoMerger.MergeGuideSteps then
            ns.AutoMerger:MergeGuideSteps(guide, { radiusYards = radius })
        else
            self:FallbackMergeGuideSteps(guide, radius)
        end

        if ns.Linter and ns.Linter.InspectGuide then
            ns.Linter:InspectGuide(guide)
        end

        table.insert(createdGuides, guide)
    end

    -- Select the richest guide as the active default
    if #createdGuides > 0 then
        local bestGuide = createdGuides[1]
        for i = 2, #createdGuides do
            if #createdGuides[i].steps > #bestGuide.steps then
                bestGuide = createdGuides[i]
            end
        end
        self:SetActiveGuide(bestGuide.id)
    end

    safeFireCallback("LEGACY_DB_IMPORTED", #createdGuides, createdGuides)
    return #createdGuides, createdGuides
end
