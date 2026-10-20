local addonName, ns = ...
ns = ns or _G.RXP_Studio or {}
_G.RXP_Studio = ns

ns.AutoMerger = ns.AutoMerger or {}
local AutoMerger = ns.AutoMerger

-- ============================================================================
-- Calibrated Spatial & Grouping Constants (First-Principles WoW Zone Scale)
-- ============================================================================
-- In standard World of Warcraft outdoor zones (0..100 coordinate percentage scale),
-- 1.0 coordinate unit corresponds to ~35 yards on average (~3,500 yards across a zone).
--   * 15-20 yards (same NPC / quest hub camp radius) ~= 0.45 - 0.55 coord units.
--   * 120-140 yards (co-located mob grind / loot objective camp) ~= 3.5 - 4.0 coord units.
--   * 17.5 yards (minimum separation to record an extra #loop waypoint) ~= 0.50 coord units.
AutoMerger.YARDS_PER_COORD_UNIT = 35.0
AutoMerger.NPC_CAMP_MAX_COORDS = 0.55
AutoMerger.SAME_NPC_MAX_COORDS = 5.00
AutoMerger.COMBAT_CAMP_MAX_COORDS = 4.00
AutoMerger.LOOP_WAYPOINT_MIN_COORDS = 0.50

local NPC_INTERACTION_TYPES = {
    accept  = true,
    turnin  = true,
    trainer = true,
    vendor  = true,
    home    = true,
    fp      = true,
}

local COMBAT_CAMP_TYPES = {
    complete = true,
    collect  = true,
}

local _splitCardIdSeq = 500000

local function nextCardId()
    if ns.Core and type(ns.Core.NextCardId) == "function" then
        return ns.Core:NextCardId()
    end
    if ns.Core and type(ns.Core.NextId) == "function" then
        return ns.Core:NextId()
    end
    _splitCardIdSeq = _splitCardIdSeq + 1
    return "card_" .. tostring(_splitCardIdSeq)
end

local function trim(s)
    if type(s) ~= "string" then return "" end
    return s:match("^%s*(.-)%s*$") or ""
end

local function normalizeTargetName(name)
    if type(name) ~= "string" then return nil end
    local clean = name:gsub("^%+%s*", ""):match("^%s*(.-)%s*$")
    if not clean or clean == "" then return nil end
    return clean
end

local function shallowCopyTable(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            local sub = {}
            for sk, sv in pairs(v) do
                sub[sk] = sv
            end
            copy[k] = sub
        else
            copy[k] = v
        end
    end
    return copy
end

local function appendUniqueString(list, value)
    local clean = normalizeTargetName(value)
    if not clean then return end
    for i = 1, #list do
        if list[i]:lower() == clean:lower() then
            return
        end
    end
    table.insert(list, clean)
end

local function collectCardTargets(card)
    local result = {}
    if not card then return result end
    if type(card.targets) == "table" then
        for i = 1, #card.targets do
            appendUniqueString(result, card.targets[i])
        end
    end
    if type(card.target) == "string" then
        appendUniqueString(result, card.target)
    end
    if type(card.actions) == "table" then
        for i = 1, #card.actions do
            local act = card.actions[i]
            if act and type(act.target) == "string" then
                appendUniqueString(result, act.target)
            end
        end
    end
    return result
end

local function cardsShareTarget(cardA, cardB)
    local targetsA = collectCardTargets(cardA)
    local targetsB = collectCardTargets(cardB)
    if #targetsA == 0 or #targetsB == 0 then
        return false
    end
    for i = 1, #targetsA do
        local a = targetsA[i]:lower()
        for j = 1, #targetsB do
            if a == targetsB[j]:lower() then
                return true
            end
        end
    end
    return false
end

local function isAllActionTypesInSet(card, allowedSet)
    if not card or type(card.actions) ~= "table" or #card.actions == 0 then
        return false
    end
    for i = 1, #card.actions do
        local act = card.actions[i]
        if not act or not act.type or not allowedSet[act.type] then
            return false
        end
    end
    return true
end

-- ============================================================================
-- Coordinate Distance Helpers
-- ============================================================================

function AutoMerger:GetCoordDistance(zone1, x1, y1, zone2, x2, y2)
    if not zone1 or not zone2 or zone1 == "" or zone2 == "" or zone1 ~= zone2 then
        return math.huge
    end
    local nx1, ny1 = tonumber(x1), tonumber(y1)
    local nx2, ny2 = tonumber(x2), tonumber(y2)
    if not nx1 or not ny1 or not nx2 or not ny2 then
        return math.huge
    end
    local dx = nx1 - nx2
    local dy = ny1 - ny2
    return math.sqrt(dx * dx + dy * dy)
end

function AutoMerger:GetCoordDistanceYards(zone1, x1, y1, zone2, x2, y2)
    local coordDist = self:GetCoordDistance(zone1, x1, y1, zone2, x2, y2)
    if coordDist == math.huge then
        return math.huge
    end
    return coordDist * self.YARDS_PER_COORD_UNIT
end

-- ============================================================================
-- Merge Eligibility Rules
-- ============================================================================

function AutoMerger:CanMergeCards(cardA, cardB, options)
    if not cardA or not cardB then
        return false, "INVALID_CARD"
    end
    if type(options) == "number" then
        options = { radiusYards = options }
    elseif type(options) ~= "table" then
        options = nil
    end

    -- Rule 1: Never auto-merge cards with rawOverride or lockedFromMerge
    if (cardA.rawOverride and trim(cardA.rawOverride) ~= "") or
       (cardB.rawOverride and trim(cardB.rawOverride) ~= "") then
        return false, "RAW_OVERRIDE"
    end

    local force = options and options.force
    if not force and (cardA.lockedFromMerge or cardB.lockedFromMerge) then
        return false, "LOCKED"
    end

    if type(cardA.actions) ~= "table" or #cardA.actions == 0 or
       type(cardB.actions) ~= "table" or #cardB.actions == 0 then
        return false, "EMPTY_ACTIONS"
    end

    -- Conflicting explicit zones cannot merge
    if cardA.zone and cardB.zone and cardA.zone ~= "" and cardB.zone ~= "" and cardA.zone ~= cardB.zone then
        return false, "DIFFERENT_ZONE"
    end

    local coordDist = self:GetCoordDistance(cardA.zone, cardA.x, cardA.y, cardB.zone, cardB.x, cardB.y)
    local npcMaxCoords = self.NPC_CAMP_MAX_COORDS
    if options and tonumber(options.npcMaxCoords) then
        npcMaxCoords = tonumber(options.npcMaxCoords)
    elseif options and tonumber(options.radiusYards) then
        npcMaxCoords = tonumber(options.radiusYards) / self.YARDS_PER_COORD_UNIT
    end

    local combatMaxCoords = (options and tonumber(options.combatMaxCoords)) or self.COMBAT_CAMP_MAX_COORDS

    -- Case 1: Same-NPC / Same-Camp Interaction Chain (accept, turnin, trainer, vendor, home, fp)
    if isAllActionTypesInSet(cardA, NPC_INTERACTION_TYPES) and isAllActionTypesInSet(cardB, NPC_INTERACTION_TYPES) then
        local sameNPC = cardsShareTarget(cardA, cardB)
        if sameNPC and (coordDist == math.huge or coordDist <= self.SAME_NPC_MAX_COORDS) then
            return true, "NPC_INTERACTION"
        end
        if coordDist <= npcMaxCoords then
            return true, "NPC_INTERACTION"
        end
    end

    -- Case 2: Co-located / Consecutive Combat & Loot Objectives (complete, collect)
    if isAllActionTypesInSet(cardA, COMBAT_CAMP_TYPES) and isAllActionTypesInSet(cardB, COMBAT_CAMP_TYPES) then
        -- Do not auto-merge continent-level Kalimdor login-flush bursts unless forced
        if cardA.zone == "Kalimdor" and not (options and options.mergeKalimdorFlushes) then
            return false, "KALIMDOR_FLUSH"
        end
        if coordDist <= combatMaxCoords then
            return true, "COMBAT_CAMP"
        end
    end

    return false, "NO_MATCH"
end

-- ============================================================================
-- Action Deduplication & Canonical NPC Ordering
-- ============================================================================

function AutoMerger:IsDuplicateAction(actA, actB)
    if not actA or not actB or actA.type ~= actB.type then
        return false
    end
    local t = actA.type
    if t == "accept" or t == "turnin" then
        return actA.questId ~= nil and tonumber(actA.questId) == tonumber(actB.questId)
    elseif t == "complete" then
        return actA.questId ~= nil
            and tonumber(actA.questId) == tonumber(actB.questId)
            and (tonumber(actA.objIndex) or 1) == (tonumber(actB.objIndex) or 1)
    elseif t == "trainer" or t == "vendor" then
        local targA = normalizeTargetName(actA.target)
        local targB = normalizeTargetName(actB.target)
        if targA and targB and targA:lower() ~= targB:lower() then
            return false
        end
        return true
    elseif t == "collect" or t == "use" then
        if actA.itemId and actB.itemId then
            return tonumber(actA.itemId) == tonumber(actB.itemId)
        end
        return trim(actA.text) ~= "" and trim(actA.text) == trim(actB.text)
    elseif t == "fp" or t == "fly" or t == "hs" or t == "home" then
        return trim(actA.destination or "") == trim(actB.destination or "")
            and trim(actA.text or "") == trim(actB.text or "")
    elseif t == "xp" then
        return trim(actA.xpTarget or "") == trim(actB.xpTarget or "")
    else
        return trim(actA.text or "") ~= "" and trim(actA.text or "") == trim(actB.text or "")
    end
end

local function stampActionOrigin(act, card)
    if not act or not card then return end
    if not act.zone and card.zone then act.zone = card.zone end
    if not act.x and card.x then act.x = card.x end
    if not act.y and card.y then act.y = card.y end
    if not act.target then
        if type(card.targets) == "table" and card.targets[1] then
            act.target = card.targets[1]
        elseif type(card.target) == "string" and card.target ~= "" then
            act.target = card.target
        end
    end
end

local function sortNPCActions(actions)
    if not actions or #actions <= 1 then return actions end

    -- Track first appearance index of .accept and .turnin per questId
    -- so instant-dialogue quests (where .accept Q occurs BEFORE .turnin Q in the same card,
    -- such as 94414 The Anchors of Zephras) preserve their .accept -> .turnin order!
    local firstAcceptIdx = {}
    local firstTurninIdx = {}
    for i = 1, #actions do
        local act = actions[i]
        local qid = act and tonumber(act.questId)
        if qid then
            if act.type == "accept" and not firstAcceptIdx[qid] then
                firstAcceptIdx[qid] = i
            elseif act.type == "turnin" and not firstTurninIdx[qid] then
                firstTurninIdx[qid] = i
            end
        end
    end

    local instantChainQuest = {}
    for qid, accIdx in pairs(firstAcceptIdx) do
        local turnIdx = firstTurninIdx[qid]
        if turnIdx and accIdx < turnIdx then
            instantChainQuest[qid] = true
        end
    end

    local normalTurnins = {}
    local acceptsAndInstantTurnins = {}
    local instantTurninLookup = {}
    local services = {} -- home, fp, fly
    local trainersAndVendors = {} -- trainer, vendor
    local others = {}

    for i = 1, #actions do
        local act = actions[i]
        local qid = act and tonumber(act.questId)
        if act.type == "turnin" and qid and instantChainQuest[qid] then
            instantTurninLookup[qid] = instantTurninLookup[qid] or {}
            table.insert(instantTurninLookup[qid], act)
        end
    end

    for i = 1, #actions do
        local act = actions[i]
        local t = act and act.type
        local qid = act and tonumber(act.questId)
        if t == "turnin" then
            if not (qid and instantChainQuest[qid]) then
                table.insert(normalTurnins, act)
            end
        elseif t == "accept" then
            table.insert(acceptsAndInstantTurnins, act)
            if qid and instantTurninLookup[qid] then
                for _, turnAct in ipairs(instantTurninLookup[qid]) do
                    table.insert(acceptsAndInstantTurnins, turnAct)
                end
                instantTurninLookup[qid] = nil
            end
        elseif t == "home" or t == "fp" or t == "fly" then
            table.insert(services, act)
        elseif t == "trainer" or t == "vendor" then
            table.insert(trainersAndVendors, act)
        else
            table.insert(others, act)
        end
    end

    local ordered = {}
    for _, list in ipairs({ normalTurnins, acceptsAndInstantTurnins, services, trainersAndVendors, others }) do
        for i = 1, #list do
            table.insert(ordered, list[i])
        end
    end
    return ordered
end

-- ============================================================================
-- Merging & Splitting Operations
-- ============================================================================

function AutoMerger:MergeTwoCards(cardA, cardB)
    if not cardA or not cardB then return cardA end

    cardA.actions = cardA.actions or {}
    cardB.actions = cardB.actions or {}
    cardA.targets = collectCardTargets(cardA)
    cardA.mobs = cardA.mobs or {}

    -- Stamp origin coords/targets onto existing actions in cardA so SplitCard is 100% lossless
    for i = 1, #cardA.actions do
        stampActionOrigin(cardA.actions[i], cardA)
    end

    -- Deduplicate existing actions in cardA first
    local mergedActions = {}
    for i = 1, #cardA.actions do
        local candidate = cardA.actions[i]
        local isDup = false
        for j = 1, #mergedActions do
            if self:IsDuplicateAction(mergedActions[j], candidate) then
                isDup = true
                break
            end
        end
        if not isDup then
            table.insert(mergedActions, candidate)
        end
    end

    -- Stamp and merge cardB's actions with deduplication
    for i = 1, #cardB.actions do
        local candidate = shallowCopyTable(cardB.actions[i])
        stampActionOrigin(candidate, cardB)
        local isDup = false
        for j = 1, #mergedActions do
            if self:IsDuplicateAction(mergedActions[j], candidate) then
                isDup = true
                break
            end
        end
        if not isDup then
            table.insert(mergedActions, candidate)
        end
    end

    cardA.actions = mergedActions

    -- Apply canonical NPC interaction ordering if this is an NPC interaction card
    if isAllActionTypesInSet(cardA, NPC_INTERACTION_TYPES) then
        cardA.actions = sortNPCActions(cardA.actions)
    end

    -- Inherit zone/coordinates if cardA lacked them
    if (not cardA.zone or cardA.zone == "") and cardB.zone and cardB.zone ~= "" then
        cardA.zone = cardB.zone
    end
    if (not cardA.x or not cardA.y) and cardB.x and cardB.y then
        cardA.x = cardB.x
        cardA.y = cardB.y
    end

    -- Preserve distinct combat/loot coordinates in cardA.loopWaypoints
    local dist = self:GetCoordDistance(cardA.zone, cardA.x, cardA.y, cardB.zone, cardB.x, cardB.y)
    if dist ~= math.huge and dist > self.LOOP_WAYPOINT_MIN_COORDS and isAllActionTypesInSet(cardA, COMBAT_CAMP_TYPES) then
        cardA.loopWaypoints = cardA.loopWaypoints or {}
        local alreadyHasWaypoint = false
        for i = 1, #cardA.loopWaypoints do
            local wp = cardA.loopWaypoints[i]
            if self:GetCoordDistance(cardA.zone, wp.x, wp.y, cardB.zone, cardB.x, cardB.y) <= 0.25 then
                alreadyHasWaypoint = true
                break
            end
        end
        if not alreadyHasWaypoint then
            table.insert(cardA.loopWaypoints, {
                zone = cardB.zone or cardA.zone,
                x = cardB.x,
                y = cardB.y,
            })
        end
    end

    if type(cardB.loopWaypoints) == "table" then
        cardA.loopWaypoints = cardA.loopWaypoints or {}
        for i = 1, #cardB.loopWaypoints do
            local wp = cardB.loopWaypoints[i]
            if wp and wp.x and wp.y then
                local exists = false
                for j = 1, #cardA.loopWaypoints do
                    local existing = cardA.loopWaypoints[j]
                    if self:GetCoordDistance(cardA.zone, existing.x, existing.y, wp.zone or cardA.zone, wp.x, wp.y) <= 0.25 then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(cardA.loopWaypoints, shallowCopyTable(wp))
                end
            end
        end
    end

    -- Merge targets and mobs (deduplicated)
    local targetsB = collectCardTargets(cardB)
    for i = 1, #targetsB do
        appendUniqueString(cardA.targets, targetsB[i])
    end

    if type(cardB.mobs) == "table" then
        for i = 1, #cardB.mobs do
            appendUniqueString(cardA.mobs, cardB.mobs[i])
        end
    end

    -- Merge notes if non-empty
    local noteB = trim(cardB.note)
    if noteB ~= "" then
        local noteA = trim(cardA.note)
        if noteA == "" then
            cardA.note = noteB
        elseif not noteA:find(noteB, 1, true) then
            cardA.note = noteA .. "\n" .. noteB
        end
    end

    -- Merge boolean step directives
    cardA.sticky = (cardA.sticky or cardB.sticky) and true or false
    cardA.completeWithNext = (cardA.completeWithNext or cardB.completeWithNext) and true or false
    cardA.optional = (cardA.optional or cardB.optional) and true or false
    cardA.hideWindow = (cardA.hideWindow or cardB.hideWindow) and true or false
    cardA.loop = (cardA.loop or cardB.loop) and true or false

    return cardA
end

local function buildSingleActionCard(parentCard, action, keepNote)
    local actCopy = shallowCopyTable(action)
    local zone = actCopy.zone or parentCard.zone
    local x = actCopy.x or parentCard.x
    local y = actCopy.y or parentCard.y

    local targets = {}
    if actCopy.target and trim(actCopy.target) ~= "" then
        appendUniqueString(targets, actCopy.target)
    elseif type(parentCard.targets) == "table" then
        for i = 1, #parentCard.targets do
            appendUniqueString(targets, parentCard.targets[i])
        end
    end

    local mobs = {}
    if (actCopy.type == "complete" or actCopy.type == "collect") and type(parentCard.mobs) == "table" then
        for i = 1, #parentCard.mobs do
            appendUniqueString(mobs, parentCard.mobs[i])
        end
    end

    local conditions = { classes = {}, races = {} }
    if type(parentCard.conditions) == "table" then
        if type(parentCard.conditions.classes) == "table" then
            for i = 1, #parentCard.conditions.classes do
                conditions.classes[i] = parentCard.conditions.classes[i]
            end
        end
        if type(parentCard.conditions.races) == "table" then
            for i = 1, #parentCard.conditions.races do
                conditions.races[i] = parentCard.conditions.races[i]
            end
        end
    end

    return {
        id = nextCardId(),
        title = "",
        zone = zone,
        x = x,
        y = y,
        loopWaypoints = {},
        targets = targets,
        mobs = mobs,
        sticky = parentCard.sticky or false,
        completeWithNext = parentCard.completeWithNext or false,
        optional = parentCard.optional or false,
        hideWindow = parentCard.hideWindow or false,
        loop = false,
        completeTogether = parentCard.completeTogether ~= false,
        note = keepNote and (parentCard.note or "") or "",
        conditions = conditions,
        rawOverride = nil,
        actions = { actCopy },
        lintIssues = {},
    }
end

function AutoMerger:SplitCard(guide, stepIndex, actionIndex)
    if not guide or type(guide.steps) ~= "table" then
        return nil
    end
    local card = guide.steps[stepIndex]
    if not card or type(card.actions) ~= "table" or #card.actions <= 1 then
        return nil
    end

    -- Case A: Split a single specified actionIndex out into stepIndex + 1
    if actionIndex ~= nil then
        local idx = tonumber(actionIndex)
        if not idx or idx < 1 or idx > #card.actions then
            return nil
        end
        local extractedAction = table.remove(card.actions, idx)
        local newCard = buildSingleActionCard(card, extractedAction, false)

        -- Refresh parent card's primary coords and targets from its remaining actions
        local firstRemaining = card.actions[1]
        if firstRemaining then
            if firstRemaining.zone then card.zone = firstRemaining.zone end
            if firstRemaining.x then card.x = firstRemaining.x end
            if firstRemaining.y then card.y = firstRemaining.y end
        end
        local remainingTargets = {}
        for i = 1, #card.actions do
            if card.actions[i].target then
                appendUniqueString(remainingTargets, card.actions[i].target)
            end
        end
        if #remainingTargets > 0 then
            card.targets = remainingTargets
        end
        card.rawOverride = nil

        table.insert(guide.steps, stepIndex + 1, newCard)
        if ns.FireCallback then
            ns:FireCallback("GUIDE_UPDATED", guide)
        end
        return { card, newCard }
    end

    -- Case B: 1-Click [Split] on a merged card -> split all actions into individual StepCards
    local splitCards = {}
    for i = 1, #card.actions do
        local singleCard = buildSingleActionCard(card, card.actions[i], i == 1)
        table.insert(splitCards, singleCard)
    end

    table.remove(guide.steps, stepIndex)
    for i = #splitCards, 1, -1 do
        table.insert(guide.steps, stepIndex, splitCards[i])
    end

    if ns.FireCallback then
        ns:FireCallback("GUIDE_UPDATED", guide)
    end
    return splitCards
end

function AutoMerger:MergeAdjacentCards(guide, stepIndexA, stepIndexB)
    if not guide or type(guide.steps) ~= "table" then
        return nil
    end
    local idxA = tonumber(stepIndexA)
    local idxB = tonumber(stepIndexB) or (idxA and (idxA + 1))
    if not idxA or not idxB or idxA == idxB then
        return nil
    end
    if idxA > idxB then
        idxA, idxB = idxB, idxA
    end
    local cardA = guide.steps[idxA]
    local cardB = guide.steps[idxB]
    if not cardA or not cardB then
        return nil
    end

    self:MergeTwoCards(cardA, cardB)
    cardA.rawOverride = nil
    table.remove(guide.steps, idxB)

    if ns.FireCallback then
        ns:FireCallback("GUIDE_UPDATED", guide)
    end
    return cardA
end

function AutoMerger:MergeGuideSteps(guide, options)
    if not guide or type(guide.steps) ~= "table" or #guide.steps < 2 then
        return 0
    end
    if type(options) == "number" then
        options = { radiusYards = options }
    elseif type(options) ~= "table" then
        options = nil
    end

    local mergedCount = 0
    local i = 1
    while i < #guide.steps do
        local cardA = guide.steps[i]
        local cardB = guide.steps[i + 1]
        local canMerge = self:CanMergeCards(cardA, cardB, options)
        if canMerge then
            self:MergeTwoCards(cardA, cardB)
            table.remove(guide.steps, i + 1)
            mergedCount = mergedCount + 1
        else
            i = i + 1
        end
    end

    if mergedCount > 0 and ns.FireCallback then
        ns:FireCallback("GUIDE_UPDATED", guide)
    end
    return mergedCount
end

function AutoMerger:AppendOrMergeCard(guide, newCard, options)
    if not guide or not newCard then
        return nil, false
    end
    guide.steps = guide.steps or {}

    local autoMergeEnabled = true
    if options and options.disableAutoMerge then
        autoMergeEnabled = false
    elseif _G.RXP_StudioDB and _G.RXP_StudioDB.settings and _G.RXP_StudioDB.settings.autoMerge == false then
        autoMergeEnabled = false
    end

    local stepCount = #guide.steps
    if autoMergeEnabled and stepCount > 0 then
        local lastCard = guide.steps[stepCount]
        local canMerge, mergeReason = self:CanMergeCards(lastCard, newCard, options)
        if canMerge then
            self:MergeTwoCards(lastCard, newCard)
            if ns.FireCallback then
                ns:FireCallback("STEP_RECORDED", lastCard, guide, stepCount, true)
                ns:FireCallback("GUIDE_UPDATED", guide)
            end
            return lastCard, true, stepCount, mergeReason
        end
    end

    if ns.Core and type(ns.Core.AddStepCard) == "function" then
        ns.Core:AddStepCard(guide, newCard)
    else
        table.insert(guide.steps, newCard)
    end

    local newIndex = #guide.steps
    if ns.FireCallback then
        ns:FireCallback("STEP_RECORDED", newCard, guide, newIndex, false)
        ns:FireCallback("GUIDE_UPDATED", guide)
    end
    return newCard, false, newIndex, nil
end
