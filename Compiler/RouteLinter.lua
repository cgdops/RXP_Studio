local addonName, ns = ...
_G.RXP_Studio = ns

ns.Core = ns.Core or {}
ns.Compiler = ns.Compiler or {}
ns.Linter = ns.Linter or {}

local Linter = ns.Linter

-- Known quests that have combat/loot/interaction objectives (used to detect MISSING_COMPLETE
-- when a quest is accepted and turned in with no .complete in between)
local KNOWN_OBJECTIVE_QUESTS = {
    -- Durotar
    [788]   = "10/10 Mottled Boar slain",
    [789]   = "10/10 Scorpid Worker Tail",
    [790]   = "1/1 Sarkoth's Mangled Claw",
    [792]   = "12/12 Vile Familiar slain",
    [794]   = "1/1 Burning Blade Medallion",
    [4402]  = "10/10 Cactus Apple",
    [5441]  = "5/5 Peons Awoken",
    [6394]  = "1/1 Thazz'ril's Pick",
    [1516]  = "2/2 Felstalker Hoof",
    [786]   = "1/1 Attack Plan: Valley of Trials destroyed",
    [791]   = "8/8 Canvas Scraps",
    -- Mulgore
    [747]   = "7/7 Plainstrider Meat",
    [750]   = "10/10 Mountain Cougar Pelt",
    [753]   = "1/1 Water Pitcher",
    [757]   = "12/12 Bristleback Belt",
    [780]   = "8/8 Battleboar Snout",
    [3376]  = "1/1 Chief Sharptusk Thornmantle's Head",
    [745]   = "10/10 Palemane Tanner slain",
    [746]   = "5/5 Broken Tools",
    [748]   = "6/6 Prairie Wolf Paw",
    [756]   = "6/6 Stalker Claws",
    [761]   = "8/8 Trophy Swoop Quill",
    [743]   = "8/8 Windfury Talon",
    [766]   = "1/1 Prairie Wolf Heart",
    [771]   = "2/2 Well Stone",
    [96130] = "1/1 Chakuyak's Pelt",
    [99108] = "3/3 Player Duels won or Novice Warriors defeated",
    [99411] = "1/1 Kyle Fed",
    -- Zephras Isle
    [92461] = "8/8 Juvenile Vuldren slain",
    [92462] = "8/8 Pesky Cirrusfly slain",
    [92463] = "1/1 Cirrusfly Queen slain",
    [92465] = "7/7 Al'Aketh Convert slain",
    [92466] = "1/1 Signet of Akir",
    [92470] = "8/8 Ursera Scavenger slain",
    [92473] = "6/6 Scrawny Ursera Claw",
    [92514] = "1/1 Speak with Illaya Amberwind",
    [92515] = "10/10 Prideclaw Pelt",
    [92516] = "8/8 Hippogryph Youth slain",
    [92517] = "10/10 Highlands Bandit slain",
    [92528] = "1/1 Learn about the cultists' plans",
    [92544] = "6/6 Al'Aketh Brute slain",
    [92550] = "6/6 Al'Aketh Stormcaller slain",
    [92551] = "10/10 Stolen Shen'dar Supplies",
    [92553] = "8/8 Strider Meat",
    [93318] = "1/1 Vulgara's Head",
    [93319] = "10/10 Pilfered Windstone",
    [93552] = "15/15 Windstone Cluster",
    [93927] = "1/1 Skypriest Aanders slain",
    [93949] = "8/8 Enchanted Skyhopper Exterminated",
    [93951] = "8/8 Hippogryph Down",
    [94411] = "6/6 High Order Apprentice defeated",
    [97244] = "1/1 Faladiel's Heart",
    -- Ashenvale / BFD
    [6561]  = "1/1 Head of Kelris",
    [6563]  = "20/20 Sapphire of Aku'Mai",
    [6921]  = "1/1 Fathom Core",
}

-- Known hostile mobs that are never quest-giving / turn-in NPCs (catches stale combat target bugs)
local KNOWN_HOSTILE_TARGETS = {
    ["Battleboar"]              = true,
    ["Prairie Stalker"]         = true,
    ["Mottled Boar"]            = true,
    ["Scorpid Worker"]          = true,
    ["Vile Familiar"]           = true,
    ["Felstalker"]              = true,
    ["Plainstrider"]            = true,
    ["Adult Plainstrider"]      = true,
    ["Mountain Cougar"]         = true,
    ["Flatland Cougar"]         = true,
    ["Prairie Wolf"]            = true,
    ["Prairie Wolf Alpha"]      = true,
    ["Bristleback Quilboar"]    = true,
    ["Bristleback Interloper"]  = true,
    ["Palemane Tanner"]         = true,
    ["Palemane Skinner"]        = true,
    ["Palemane Poacher"]        = true,
    ["Wiry Swoop"]              = true,
    ["Swoop"]                   = true,
    ["Windfury Harpy"]          = true,
    ["Juvenile Vuldren"]        = true,
    ["Pesky Cirrusfly"]         = true,
    ["Ursera Scavenger"]        = true,
    ["Al'Aketh Convert"]        = true,
    ["Al'Aketh Brute"]          = true,
    ["Al'Aketh Neophyte"]       = true,
    ["Al'Aketh Stormcaller"]    = true,
    ["Highlands Bandit"]        = true,
    ["Hippogryph Youth"]        = true,
    ["Hippogryph Protector"]    = true,
}

local COORD_REQUIRED_ACTIONS = {
    accept   = true,
    turnin   = true,
    complete = true,
    trainer  = true,
    vendor   = true,
    fp       = true,
    fly      = true,
    home     = true,
    collect  = true,
    use      = true,
    xp       = true,
}

local function safeFireCallback(event, ...)
    if ns.FireCallback then
        ns:FireCallback(event, ...)
    end
end

local function trim(s)
    if not s then return "" end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Extract mob/creature keywords from an objective string (e.g. "8/8 Battleboar Snout" -> "Battleboar")
local function matchesRecentCombatObjective(targetName, recentObjTexts, recentMobs)
    if not targetName or targetName == "" then return false end
    if KNOWN_HOSTILE_TARGETS[targetName] then
        return true
    end
    local lowerTarget = targetName:lower()
    for i = 1, #(recentMobs or {}) do
        if recentMobs[i]:lower() == lowerTarget then
            return true
        end
    end
    for i = 1, #(recentObjTexts or {}) do
        local obj = recentObjTexts[i]:lower()
        -- If the objective was "<N>/<N> <TargetName> slain"
        local slainCreature = obj:match("^%d+/%d+%s+(.+)%s+slain$") or obj:match("^%d+/%d+%s+(.+)%s+defeated$")
        if slainCreature and trim(slainCreature) == lowerTarget then
            return true
        end
        -- Or if the target is a multi-word creature or distinct word in a loot objective (e.g., "Battleboar", "Stalker")
        for word in lowerTarget:gmatch("%w+") do
            if #word >= 6 and obj:find(word, 1, true) and (obj:find("slain") or obj:find("claw") or obj:find("snout") or obj:find("flank") or obj:find("pelt")) then
                return true
            end
        end
    end
    return false
end

local function isLoginFlushStep(card, questTurnedInAnywhere)
    if not card or card.zone ~= "Kalimdor" then
        return false
    end
    local actions = card.actions or {}
    if #actions == 0 then return false end
    for i = 1, #actions do
        local a = actions[i]
        if a.type ~= "complete" then
            return false
        end
        local txt = a.objText or ""
        if txt:match("^%d+/%d+%s*$") or txt:match("^%d+/%d+%s%s+slain$") then
            return true
        end
        if a.questId and not questTurnedInAnywhere[a.questId] then
            return true
        end
    end
    return false
end

local function makeActionSignature(action, card)
    if not action then return nil end
    local t = action.type
    if t == "accept" or t == "turnin" then
        if not action.questId then return nil end
        return string.format("%s:%d", t, action.questId)
    elseif t == "complete" then
        if not action.questId then return nil end
        return string.format("complete:%d:%d", action.questId, tonumber(action.objIndex) or 1)
    elseif t == "trainer" or t == "vendor" then
        local npc = (card and card.targets and card.targets[1]) or action.target or ""
        return string.format("%s:%s", t, npc:lower())
    end
    return nil
end

function Linter:InspectGuide(guide)
    if not guide or type(guide.steps) ~= "table" then
        return {}
    end

    local issues = {}
    local steps = guide.steps

    -- Pre-scan guide to see where quests are accepted, completed, or turned in
    local firstAcceptStep = {}
    local firstCompleteStep = {}
    local lastCompleteStep = {}
    local firstTurninStep = {}
    local questTitles = {}
    local questObjectiveTexts = {}

    for stepIdx = 1, #steps do
        local card = steps[stepIdx]
        card.lintIssues = {}
        for _, action in ipairs(card.actions or {}) do
            local qid = action.questId
            if qid then
                if action.questTitle and action.questTitle ~= "" then
                    questTitles[qid] = action.questTitle
                end
                if action.type == "accept" then
                    if not firstAcceptStep[qid] then firstAcceptStep[qid] = stepIdx end
                elseif action.type == "complete" then
                    if not firstCompleteStep[qid] then firstCompleteStep[qid] = stepIdx end
                    lastCompleteStep[qid] = stepIdx
                    if action.objText and action.objText ~= "" then
                        questObjectiveTexts[qid] = action.objText
                    end
                elseif action.type == "turnin" then
                    if not firstTurninStep[qid] then firstTurninStep[qid] = stepIdx end
                end
            end
        end
    end

    local function addIssue(stepIdx, card, issueTable)
        issueTable.stepIndex = stepIdx
        issueTable.cardId = card and card.id or nil
        if card then
            card.lintIssues = card.lintIssues or {}
            table.insert(card.lintIssues, issueTable)
        end
        table.insert(issues, issueTable)
    end

    local acceptedSoFar = {}
    local completedSoFar = {}
    local recentCombatObjTexts = {}
    local recentCombatMobs = {}
    local prevCardSig = nil
    local prevCardStepIdx = nil

    for stepIdx = 1, #steps do
        local card = steps[stepIdx]
        local actions = card.actions or {}

        -- 4. Check MISSING_COORDS
        local needsCoords = false
        for i = 1, #actions do
            if COORD_REQUIRED_ACTIONS[actions[i].type] then
                needsCoords = true
                break
            end
        end
        local hasValidCoords = (card.zone and trim(card.zone) ~= "" and tonumber(card.x) ~= nil and tonumber(card.y) ~= nil)
        if needsCoords and not hasValidCoords then
            addIssue(stepIdx, card, {
                severity = "warning",
                code     = "MISSING_COORDS",
                message  = string.format("Step %d has quest/NPC actions but is missing .goto coordinates.", stepIdx),
                fixLabel = "Auto-Fix: Copy Coords from Neighbor Step",
                fixType  = "INTERPOLATE_COORDS",
                fixData  = { stepIndex = stepIdx },
            })
        end

        -- Track accepts first within the same step so same-step accept+complete+turnin is valid
        for i = 1, #actions do
            local a = actions[i]
            if a.type == "accept" and a.questId then
                acceptedSoFar[a.questId] = stepIdx
            end
        end
        for i = 1, #actions do
            local a = actions[i]
            if a.type == "complete" and a.questId then
                completedSoFar[a.questId] = stepIdx
            end
        end

        -- Check actions for ORPHAN_COMPLETE, ORPHAN_TURNIN, MISSING_COMPLETE, DUPLICATE_ACTION
        local seenActionInCard = {}
        local flushStepFlagged = false

        for aIdx = 1, #actions do
            local action = actions[aIdx]
            local qid = action.questId
            local sig = makeActionSignature(action, card)

            -- 5. Check DUPLICATE_ACTION (within the same card or immediately consecutive single-action step)
            if sig then
                if seenActionInCard[sig] then
                    addIssue(stepIdx, card, {
                        severity = "warning",
                        code     = "DUPLICATE_ACTION",
                        message  = string.format("Step %d repeats identical .%s action (%s).", stepIdx, action.type, sig),
                        questId  = qid,
                        objIndex = action.objIndex,
                        fixLabel = "Auto-Fix: Deduplicate Action",
                        fixType  = "DEDUPLICATE",
                        fixData  = { stepIndex = stepIdx, actionIndex = aIdx, signature = sig },
                    })
                elseif #actions == 1 and prevCardSig == sig and prevCardStepIdx == (stepIdx - 1) then
                    addIssue(stepIdx, card, {
                        severity = "warning",
                        code     = "DUPLICATE_ACTION",
                        message  = string.format("Step %d repeats identical .%s action from Step %d.", stepIdx, action.type, stepIdx - 1),
                        questId  = qid,
                        objIndex = action.objIndex,
                        fixLabel = "Auto-Fix: Deduplicate Action",
                        fixType  = "DEDUPLICATE",
                        fixData  = { stepIndex = stepIdx, actionIndex = aIdx, signature = sig, removeStep = true },
                    })
                end
                seenActionInCard[sig] = aIdx
            end

            -- 3. Check ORPHAN_COMPLETE
            if action.type == "complete" and qid and not acceptedSoFar[qid] then
                if isLoginFlushStep(card, firstTurninStep) then
                    if not flushStepFlagged then
                        flushStepFlagged = true
                        addIssue(stepIdx, card, {
                            severity = "warning",
                            code     = "ORPHAN_COMPLETE",
                            message  = string.format("Step %d in Kalimdor is a login quest-log flush for Quest #%d (%s).", stepIdx, qid, action.objText or "unloaded"),
                            questId  = qid,
                            objIndex = action.objIndex,
                            fixLabel = "Auto-Fix: Remove Login-Flush Step",
                            fixType  = "DELETE_STEP",
                            fixData  = { stepIndex = stepIdx, questId = qid },
                        })
                    end
                else
                    addIssue(stepIdx, card, {
                        severity = "warning",
                        code     = "ORPHAN_COMPLETE",
                        message  = string.format("Quest #%d objective (.complete %d,%d) recorded before .accept #%d.", qid, qid, tonumber(action.objIndex) or 1, qid),
                        questId  = qid,
                        objIndex = action.objIndex,
                        fixLabel = "Auto-Fix: Insert .accept #" .. tostring(qid),
                        fixType  = "INSERT_ACCEPT_BEFORE",
                        fixData  = {
                            stepIndex  = stepIdx,
                            questId    = qid,
                            questTitle = questTitles[qid] or ("Quest #" .. tostring(qid)),
                        },
                    })
                end
            end

            -- 1. Check ORPHAN_TURNIN & 2. Check MISSING_COMPLETE
            if action.type == "turnin" and qid then
                if not acceptedSoFar[qid] then
                    addIssue(stepIdx, card, {
                        severity = "error",
                        code     = "ORPHAN_TURNIN",
                        message  = string.format("Quest #%d (%s) is turned in at Step %d without a prior .accept #%d.", qid, action.questTitle or "Quest", stepIdx, qid),
                        questId  = qid,
                        fixLabel = "Auto-Fix: Insert .accept #" .. tostring(qid),
                        fixType  = "INSERT_ACCEPT_BEFORE",
                        fixData  = {
                            stepIndex  = stepIdx,
                            questId    = qid,
                            questTitle = action.questTitle or questTitles[qid] or ("Quest #" .. tostring(qid)),
                            target     = (card.targets and card.targets[1]) or action.target,
                        },
                    })
                else
                    -- Quest WAS accepted; check if it is missing .complete or if .complete occurs AFTER .turnin
                    local laterCompleteIdx = lastCompleteStep[qid]
                    local hasCompleteBefore = (completedSoFar[qid] ~= nil and completedSoFar[qid] <= stepIdx)
                    local knownObj = KNOWN_OBJECTIVE_QUESTS[qid] or questObjectiveTexts[qid] or (action.requiresComplete and "1/1 Objective Complete") or (card.requiresComplete and "1/1 Objective Complete")

                    if not hasCompleteBefore and (knownObj or (laterCompleteIdx and laterCompleteIdx > stepIdx)) then
                        addIssue(stepIdx, card, {
                            severity = "warning",
                            code     = "MISSING_COMPLETE",
                            message  = (laterCompleteIdx and laterCompleteIdx > stepIdx)
                                and string.format("Quest #%d (%s) is turned in at Step %d before its .complete at Step %d.", qid, action.questTitle or "Quest", stepIdx, laterCompleteIdx)
                                or string.format("Quest #%d (%s) is turned in at Step %d without recording .complete #%d.", qid, action.questTitle or "Quest", stepIdx, qid),
                            questId  = qid,
                            objIndex = 1,
                            fixLabel = "Auto-Fix: Insert .complete #" .. tostring(qid),
                            fixType  = "INSERT_COMPLETE_BEFORE",
                            fixData  = {
                                stepIndex      = stepIdx,
                                questId        = qid,
                                objIndex       = 1,
                                objText        = knownObj or "1/1 Objective Complete",
                                laterStepIndex = (laterCompleteIdx and laterCompleteIdx > stepIdx) and laterCompleteIdx or nil,
                            },
                        })
                    end
                end
            end
        end

        -- 6. Check STALE_COMBAT_TARGET
        local hasNPCInteraction = false
        local hasCombatAction = false
        for i = 1, #actions do
            local at = actions[i].type
            if at == "accept" or at == "turnin" or at == "trainer" or at == "vendor" then
                hasNPCInteraction = true
            elseif at == "complete" or at == "collect" then
                hasCombatAction = true
            end
        end
        if hasNPCInteraction and not hasCombatAction and card.targets and #card.targets > 0 then
            for tIdx = 1, #card.targets do
                local targetName = card.targets[tIdx]
                if matchesRecentCombatObjective(targetName, recentCombatObjTexts, recentCombatMobs) then
                    addIssue(stepIdx, card, {
                        severity = "warning",
                        code     = "STALE_COMBAT_TARGET",
                        message  = string.format("Step %d (.accept/.turnin) has stale hostile combat target '%s'.", stepIdx, targetName),
                        fixLabel = "Auto-Fix: Clear Stale Mob Target",
                        fixType  = "CLEAR_TARGET",
                        fixData  = { stepIndex = stepIdx, targetName = targetName },
                    })
                end
            end
        end

        -- Update recent combat state for next step's STALE_COMBAT_TARGET check
        local stepHadComplete = false
        local stepObjTexts = {}
        for i = 1, #actions do
            if actions[i].type == "complete" then
                stepHadComplete = true
                if actions[i].objText and actions[i].objText ~= "" then
                    table.insert(stepObjTexts, actions[i].objText)
                end
            end
        end
        if stepHadComplete then
            recentCombatObjTexts = stepObjTexts
            recentCombatMobs = card.mobs or {}
        end

        if #actions == 1 then
            prevCardSig = makeActionSignature(actions[1], card)
            prevCardStepIdx = stepIdx
        else
            prevCardSig = nil
            prevCardStepIdx = nil
        end
    end

    guide.lintIssues = issues
    safeFireCallback("GUIDE_LINT_UPDATED", guide, issues)
    return issues
end

function Linter:ApplyFix(guide, issue)
    if not guide or not guide.steps or not issue then
        return false
    end

    local steps = guide.steps
    local fixType = issue.fixType
    local fixData = issue.fixData or {}

    -- Locate the card by cardId first, falling back to stepIndex
    local stepIdx = issue.stepIndex or fixData.stepIndex
    local targetCard = nil
    if issue.cardId then
        for i = 1, #steps do
            if steps[i].id == issue.cardId then
                targetCard = steps[i]
                stepIdx = i
                break
            end
        end
    end
    if not targetCard and stepIdx and steps[stepIdx] then
        targetCard = steps[stepIdx]
    end
    if not targetCard then
        return false
    end

    local fixed = false

    if fixType == "INSERT_ACCEPT_BEFORE" then
        local qid = issue.questId or fixData.questId
        if qid then
            local qTitle = fixData.questTitle or ("Quest #" .. tostring(qid))
            local acceptAction = {
                type       = "accept",
                questId    = qid,
                questTitle = qTitle,
                text       = "Accept " .. qTitle,
                target     = fixData.target,
            }
            targetCard.actions = targetCard.actions or {}
            table.insert(targetCard.actions, 1, acceptAction)
            fixed = true
        end

    elseif fixType == "INSERT_COMPLETE_BEFORE" or fixType == "MOVE_COMPLETE_BEFORE_TURNIN" then
        local qid = issue.questId or fixData.questId
        if qid then
            -- If a later step had the out-of-order .complete, remove that action from the later step
            if fixData.laterStepIndex and steps[fixData.laterStepIndex] and fixData.laterStepIndex > stepIdx then
                local laterCard = steps[fixData.laterStepIndex]
                for i = #(laterCard.actions or {}), 1, -1 do
                    if laterCard.actions[i].type == "complete" and laterCard.actions[i].questId == qid then
                        table.remove(laterCard.actions, i)
                    end
                end
                if #(laterCard.actions or {}) == 0 then
                    table.remove(steps, fixData.laterStepIndex)
                end
            end

            local objText = fixData.objText or KNOWN_OBJECTIVE_QUESTS[qid] or "1/1 Objective Complete"
            local completeAction = {
                type     = "complete",
                questId  = qid,
                objIndex = tonumber(fixData.objIndex or issue.objIndex) or 1,
                objText  = objText,
                text     = objText,
            }

            targetCard.actions = targetCard.actions or {}
            local insertPos = 1
            for i = 1, #targetCard.actions do
                if targetCard.actions[i].type == "turnin" and targetCard.actions[i].questId == qid then
                    insertPos = i
                    break
                elseif targetCard.actions[i].type == "accept" and targetCard.actions[i].questId == qid then
                    insertPos = i + 1
                end
            end
            table.insert(targetCard.actions, insertPos, completeAction)
            fixed = true
        end

    elseif fixType == "DELETE_STEP" then
        if stepIdx and steps[stepIdx] then
            table.remove(steps, stepIdx)
            fixed = true
        end

    elseif fixType == "INTERPOLATE_COORDS" then
        local donorZone, donorX, donorY
        -- Search backward first, then forward for the closest step with valid coordinates
        for offset = 1, #steps do
            local prev = steps[stepIdx - offset]
            if prev and prev.zone and prev.zone ~= "" and tonumber(prev.x) and tonumber(prev.y) then
                donorZone, donorX, donorY = prev.zone, tonumber(prev.x), tonumber(prev.y)
                break
            end
            local nxt = steps[stepIdx + offset]
            if nxt and nxt.zone and nxt.zone ~= "" and tonumber(nxt.x) and tonumber(nxt.y) then
                donorZone, donorX, donorY = nxt.zone, tonumber(nxt.x), tonumber(nxt.y)
                break
            end
        end
        targetCard.zone = donorZone or (guide.subgroup ~= "" and guide.subgroup) or "Durotar"
        targetCard.x = donorX or 50.00
        targetCard.y = donorY or 50.00
        fixed = true

    elseif fixType == "DEDUPLICATE" then
        if fixData.removeStep and #steps > 1 then
            table.remove(steps, stepIdx)
            fixed = true
        elseif targetCard.actions then
            local sig = fixData.signature
            local seen = false
            for i = 1, #targetCard.actions do
                local s = makeActionSignature(targetCard.actions[i], targetCard)
                if s == sig then
                    if seen then
                        table.remove(targetCard.actions, i)
                        fixed = true
                        break
                    else
                        seen = true
                    end
                end
            end
            if not fixed and fixData.actionIndex and targetCard.actions[fixData.actionIndex] then
                table.remove(targetCard.actions, fixData.actionIndex)
                fixed = true
            end
            if fixed and #targetCard.actions == 0 and #steps > 1 then
                table.remove(steps, stepIdx)
            end
        end

    elseif fixType == "CLEAR_TARGET" then
        local badTarget = fixData.targetName
        if targetCard.targets then
            if badTarget then
                for i = #targetCard.targets, 1, -1 do
                    if targetCard.targets[i] == badTarget then
                        table.remove(targetCard.targets, i)
                        fixed = true
                    end
                end
            else
                targetCard.targets = {}
                fixed = true
            end
        end
        for _, a in ipairs(targetCard.actions or {}) do
            if not badTarget or a.target == badTarget then
                a.target = nil
                fixed = true
            end
        end
    end

    if fixed then
        self:InspectGuide(guide)
        safeFireCallback("GUIDE_UPDATED", guide)
    end
    return fixed
end

function Linter:ApplyAllFixes(guide)
    if not guide or not guide.steps then
        return false, 0
    end
    local appliedCount = 0
    local maxIterations = 500
    for _ = 1, maxIterations do
        local currentIssues = self:InspectGuide(guide)
        if not currentIssues or #currentIssues == 0 then
            break
        end
        local fixedAny = false
        for i = 1, #currentIssues do
            if currentIssues[i].fixType then
                if self:ApplyFix(guide, currentIssues[i]) then
                    appliedCount = appliedCount + 1
                    fixedAny = true
                    break
                end
            end
        end
        if not fixedAny then
            break
        end
    end
    local remaining = self:InspectGuide(guide)
    safeFireCallback("GUIDE_UPDATED", guide)
    return (#remaining == 0), appliedCount
end
