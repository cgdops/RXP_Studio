local addonName, ns = ...
_G.RXP_Studio = ns

ns.Core = ns.Core or {}
ns.Compiler = ns.Compiler or {}
ns.Bridge = ns.Bridge or {}

local Bridge = ns.Bridge

local function safeFireCallback(event, ...)
    if ns.FireCallback then
        ns:FireCallback(event, ...)
    end
end

function Bridge:GetRXPAddon()
    if _G.RXP and (_G.RXP.ParseGuide or _G.RXP.LoadGuide) then
        return _G.RXP
    end
    if LibStub then
        local aceAddon = LibStub("AceAddon-3.0", true)
        if aceAddon and aceAddon.GetAddon then
            local rxp = aceAddon:GetAddon("RXPGuides", true)
            if rxp then
                return rxp
            end
        end
    end
    if _G.RXPGuides and (_G.RXPGuides.ParseGuide or _G.RXPGuides.LoadGuide) then
        return _G.RXPGuides
    end
    return nil
end

local DEFAULT_ZONE_MAP_IDS = {
    ["Zephras Isle"]             = 2521,
    ["Kalimdor"]                 = 1414,
    ["Eastern Kingdoms"]         = 1415,
    ["Durotar"]                  = 1411,
    ["Mulgore"]                  = 1412,
    ["The Barrens"]              = 1413,
    ["Teldrassil"]               = 1438,
    ["Darkshore"]                = 1439,
    ["Ashenvale"]                = 1440,
    ["Thousand Needles"]         = 1441,
    ["Stonetalon Mountains"]     = 1442,
    ["Desolace"]                 = 1443,
    ["Feralas"]                  = 1444,
    ["Dustwallow Marsh"]         = 1445,
    ["Tanaris"]                  = 1446,
    ["Azshara"]                  = 1447,
    ["Felwood"]                  = 1448,
    ["Un'Goro Crater"]           = 1449,
    ["Moonglade"]                = 1450,
    ["Silithus"]                 = 1451,
    ["Winterspring"]             = 1452,
    ["Orgrimmar"]                = 1454,
    ["Thunder Bluff"]            = 1456,
    ["Darnassus"]                = 1457,
    ["Elwynn Forest"]            = 1429,
    ["Westfall"]                 = 1436,
    ["Redridge Mountains"]       = 1433,
    ["Duskwood"]                 = 1431,
    ["Stranglethorn Vale"]       = 1434,
    ["Dun Morogh"]               = 1426,
    ["Loch Modan"]               = 1432,
    ["Wetlands"]                 = 1437,
    ["Tirisfal Glades"]          = 1420,
    ["Silverpine Forest"]        = 1421,
    ["Hillsbrad Foothills"]      = 1424,
    ["Arathi Highlands"]         = 1417,
    ["The Hinterlands"]          = 1425,
    ["Badlands"]                 = 1418,
    ["Searing Gorge"]            = 1427,
    ["Burning Steppes"]          = 1428,
    ["Swamp of Sorrows"]         = 1435,
    ["Blasted Lands"]            = 1419,
    ["Western Plaguelands"]      = 1422,
    ["Eastern Plaguelands"]      = 1423,
    ["Deadwind Pass"]            = 1430,
    ["Alterac Mountains"]        = 1416,
    ["Stormwind City"]           = 1453,
    ["Ironforge"]                = 1455,
    ["Undercity"]                = 1458,
    ["Blackfathom Deeps"]        = 1440,
    ["The Deadmines"]            = 1436,
    ["Wailing Caverns"]          = 1413,
    ["Ragefire Chasm"]           = 1454,
    ["Shadowfang Keep"]          = 1421,
    ["The Stockade"]             = 1453,
    ["Gnomeregan"]               = 1426,
    ["Razorfen Kraul"]           = 1413,
    ["Scarlet Monastery"]        = 1420,
    ["Razorfen Downs"]           = 1413,
    ["Uldaman"]                  = 1418,
    ["Zul'Farrak"]               = 1446,
    ["Maraudon"]                 = 1443,
}

local function resolveZoneMapId(zoneName)
    if type(zoneName) ~= "string" or zoneName == "" then
        return 1414
    end
    if DEFAULT_ZONE_MAP_IDS[zoneName] then
        return DEFAULT_ZONE_MAP_IDS[zoneName]
    end
    if ns.UI and ns.UI.MapPreview and type(ns.UI.MapPreview.ResolveMapID) == "function" then
        local resolved = ns.UI.MapPreview:ResolveMapID(zoneName)
        if tonumber(resolved) then
            return tonumber(resolved)
        end
    end
    if zoneName:lower():find("zephras") then
        return 2521
    end
    return 1414
end

local function preRegisterGuideZonesAndObjectives(rxpAddon, guide)
    if not rxpAddon or type(guide) ~= "table" then
        return
    end
    rxpAddon.mapId = rxpAddon.mapId or {}
    rxpAddon.questConversion = rxpAddon.questConversion or {}
    for zName, mId in pairs(DEFAULT_ZONE_MAP_IDS) do
        if not rxpAddon.mapId[zName] then
            rxpAddon.mapId[zName] = mId
        end
    end
    if type(rxpAddon.GetMapId) ~= "function" then
        rxpAddon.GetMapId = function(zone)
            return rxpAddon.mapId and rxpAddon.mapId[zone]
        end
    end
    if type(rxpAddon.GetMapInfo) ~= "function" then
        rxpAddon.GetMapInfo = function(zone, x, y, instance)
            x = tonumber(x)
            y = tonumber(y)
            if not (x and y and zone) then return end
            return rxpAddon.GetMapId(zone) or tonumber(zone), x, y, instance
        end
    end
    rxpAddon.settings = rxpAddon.settings or {}
    if type(rxpAddon.settings.ReplaceColors) ~= "function" then
        rxpAddon.settings.ReplaceColors = function(s) return s end
    end
    if type(rxpAddon.BuildGuideKey) ~= "function" then
        rxpAddon.BuildGuideKey = function(g)
            return string.format("%s|%s|%s", g.group or "", g.subgroup or "", g.name or "")
        end
    end

    _G.RXPCData = _G.RXPCData or {}
    _G.RXPCData.questObjectivesCache = _G.RXPCData.questObjectivesCache or { [0] = 0 }
    local objCache = _G.RXPCData.questObjectivesCache

    local function registerZone(z)
        if type(z) == "string" and z ~= "" and not rxpAddon.mapId[z] then
            rxpAddon.mapId[z] = resolveZoneMapId(z)
        end
    end

    for _, card in ipairs(guide.steps or {}) do
        registerZone(card.zone)
        for _, wp in ipairs(card.loopWaypoints or {}) do
            registerZone(wp.zone)
        end
        for _, act in ipairs(card.actions or {}) do
            registerZone(act.zone)
            if act.type == "complete" and tonumber(act.questId) then
                local qid = tonumber(act.questId)
                local objIdx = tonumber(act.objIndex) or 1
                local rawObjText = act.objText or act.text or ("Quest #" .. tostring(qid) .. " Objective " .. tostring(objIdx))
                local objMax = tonumber(act.objMax)
                    or tonumber(tostring(rawObjText):match("^%s*%d+%s*/%s*(%d+)"))
                    or tonumber(tostring(rawObjText):match(":%s*%d+%s*/%s*(%d+)%s*$"))
                    or 1

                -- Normalize cached preview text to "0/N Objective" (or "Objective: 0/N") so
                -- unaccepted quests never display a baked-in "7/7" or "10/10" completion count
                local cleanObjDesc = tostring(rawObjText)
                    :gsub("^%s*%d+%s*/%s*%d+%s*", "")
                    :gsub("%s*:%s*%d+%s*/%s*%d+%s*$", "")
                cleanObjDesc = cleanObjDesc:match("^%s*(.-)%s*$") or ""
                local previewText
                if cleanObjDesc ~= "" then
                    previewText = string.format("%s: 0/%d", cleanObjDesc, objMax)
                else
                    previewText = rawObjText
                end

                if type(objCache[qid]) ~= "table" then
                    objCache[qid] = {}
                    objCache[0] = (tonumber(objCache[0]) or 0) + 1
                end
                local existingObj = objCache[qid][objIdx]
                if not existingObj or (type(existingObj.text) == "string" and existingObj.text:match("^%s*[1-9]%d*%s*/%s*%d+")) then
                    objCache[qid][objIdx] = {
                        text         = previewText,
                        type         = "monster",
                        numRequired  = objMax,
                        numFulfilled = 0,
                        finished     = false,
                    }
                end
            end
        end
    end
end

local function populateParsedStepTextFallbacks(parsedGuide, sourceGuide)
    if type(parsedGuide) ~= "table" or type(parsedGuide.steps) ~= "table" then
        return
    end
    local objCache = _G.RXPCData and _G.RXPCData.questObjectivesCache
    for idx, step in ipairs(parsedGuide.steps) do
        step.elements = step.elements or {}
        local hasNonEmptyText = false
        for _, el in ipairs(step.elements) do
            if type(el.text) == "string" and el.text:match("%S") then
                hasNonEmptyText = true
            elseif el.tag == "complete" then
                local qid = tonumber(el.questId)
                local objIdx = tonumber(el.obj) or 1
                local cachedEntry = qid and objCache and objCache[qid] and objCache[qid][objIdx]
                local fallback = (type(el.rawtext) == "string" and el.rawtext:match("%S") and el.rawtext)
                    or (cachedEntry and type(cachedEntry.text) == "string" and cachedEntry.text:match("%S") and cachedEntry.text)
                    or (qid and string.format("Complete Quest #%d (Objective %d)", qid, objIdx))
                    or "Complete quest objective"
                el.text = fallback
                hasNonEmptyText = true
            end
        end
        if not hasNonEmptyText then
            table.insert(step.elements, 1, {
                text     = string.format("Step %d", idx),
                textOnly = true,
                step     = step,
            })
        end
    end
end

local function registerParsedGuideInRXP(rxpAddon, parsedGuide)
    if not rxpAddon or type(parsedGuide) ~= "table" then
        return
    end
    local group = parsedGuide.group or "My Recorded Guides"
    local cleanGroup = tostring(group):gsub("^%*", "")
    local name = parsedGuide.name or parsedGuide.displayname or "Recorded Guide"
    local indexKey = parsedGuide.key or string.format("%s||%s||%s", group, parsedGuide.subgroup or "", name)
    parsedGuide.key = indexKey

    rxpAddon.guides = rxpAddon.guides or {}
    rxpAddon.guideList = rxpAddon.guideList or {}

    local alreadyExists = (rxpAddon.guides[indexKey] ~= nil)
    if type(rxpAddon.AddGuide) == "function" and not alreadyExists then
        pcall(rxpAddon.AddGuide, parsedGuide)
    end

    rxpAddon.guides[indexKey] = parsedGuide
    rxpAddon.guides[string.format("%s||%s", group, name)] = parsedGuide

    -- Ensure rxpAddon.guideList[group].names_ only ever contains structured { name = ..., group = ... } tables
    rxpAddon.guideList[group] = rxpAddon.guideList[group] or {}
    rxpAddon.guideList[group].names_ = rxpAddon.guideList[group].names_ or {}
    local namesList = rxpAddon.guideList[group].names_
    local foundEntry = false
    for i = #namesList, 1, -1 do
        local entry = namesList[i]
        if type(entry) == "string" then
            if entry == name then
                namesList[i] = { name = name, group = cleanGroup }
                foundEntry = true
            else
                namesList[i] = { name = entry, group = cleanGroup }
            end
        elseif type(entry) == "table" then
            entry.group = entry.group or cleanGroup
            entry.name = entry.name or name
            if entry.name == name and entry.group == cleanGroup then
                if foundEntry then
                    table.remove(namesList, i)
                else
                    foundEntry = true
                end
            end
        end
    end
    if not foundEntry then
        table.insert(namesList, { name = name, group = cleanGroup })
    end
end

function Bridge:SyncGuideToRXP(guide, targetStepIndex)
    if not guide then
        if ns.Core and ns.Core.GetActiveGuide then
            guide = ns.Core:GetActiveGuide()
        end
    end
    if not guide then
        return false, "No active guide to sync."
    end

    local rxpAddon = self:GetRXPAddon()
    if not rxpAddon or type(rxpAddon.ParseGuide) ~= "function" then
        return false, "RXPGuides addon is not loaded or available."
    end

    if not ns.Compiler or type(ns.Compiler.CompileGuide) ~= "function" then
        return false, "RXP Studio Compiler is not initialized."
    end

    preRegisterGuideZonesAndObjectives(rxpAddon, guide)

    local compiledText = ns.Compiler:CompileGuide(guide, true)
    if not compiledText or compiledText == "" then
        return false, "Compiled guide text is empty."
    end

    local ok, parsedGuide, parseErr = pcall(rxpAddon.ParseGuide, compiledText)
    if not ok or type(parsedGuide) ~= "table" or (parseErr and parseErr ~= "") or not parsedGuide.steps or #parsedGuide.steps == 0 then
        local errMsg = tostring(parseErr or parsedGuide or "RXPGuides.ParseGuide failed to parse guide.")
        return false, errMsg
    end

    populateParsedStepTextFallbacks(parsedGuide)
    registerParsedGuideInRXP(rxpAddon, parsedGuide)

    -- Refresh RXP menu dropdown table if available
    if rxpAddon.RXPFrame and type(rxpAddon.RXPFrame.GenerateMenuTable) == "function" then
        pcall(rxpAddon.RXPFrame.GenerateMenuTable)
    end

    -- Load the guide into RXPGuides active window
    if type(rxpAddon.LoadGuide) == "function" then
        pcall(rxpAddon.LoadGuide, rxpAddon, parsedGuide)
    end

    -- Jump to the requested step index if provided
    local clampedStep = nil
    if targetStepIndex and type(rxpAddon.SetStep) == "function" then
        local totalSteps = (type(parsedGuide.steps) == "table" and #parsedGuide.steps) or 1
        if totalSteps < 1 then totalSteps = 1 end
        clampedStep = math.max(1, math.min(tonumber(targetStepIndex) or 1, totalSteps))
        pcall(rxpAddon.SetStep, clampedStep)
    end

    -- Ensure RXPFrame is visible
    if rxpAddon.RXPFrame and type(rxpAddon.RXPFrame.Show) == "function" then
        if not rxpAddon.RXPFrame.IsShown or not rxpAddon.RXPFrame:IsShown() then
            pcall(rxpAddon.RXPFrame.Show, rxpAddon.RXPFrame)
        end
    end

    safeFireCallback("GUIDE_SYNCED_TO_RXP", guide, parsedGuide, clampedStep or targetStepIndex)
    return true, parsedGuide
end

function Bridge:RegisterAllSavedGuides()
    local rxpAddon = self:GetRXPAddon()
    if not rxpAddon or type(rxpAddon.ParseGuide) ~= "function" then
        return 0
    end
    if not ns.Compiler or type(ns.Compiler.CompileGuide) ~= "function" then
        return 0
    end

    local guides = (ns.Core and ns.Core.GetGuideList and ns.Core:GetGuideList())
        or (_G.RXP_StudioDB and _G.RXP_StudioDB.guides)
        or {}

    local registeredCount = 0
    for i = 1, #guides do
        local guide = guides[i]
        if type(guide) == "table" and guide.steps and #guide.steps > 0 then
            preRegisterGuideZonesAndObjectives(rxpAddon, guide)
            local compiledText = ns.Compiler:CompileGuide(guide, true)
            if compiledText and compiledText ~= "" then
                local ok, parsedGuide, parseErr = pcall(rxpAddon.ParseGuide, compiledText)
                if ok and type(parsedGuide) == "table" and (not parseErr or parseErr == "") and parsedGuide.steps and #parsedGuide.steps > 0 then
                    populateParsedStepTextFallbacks(parsedGuide)
                    registerParsedGuideInRXP(rxpAddon, parsedGuide)
                    registeredCount = registeredCount + 1
                end
            end
        end
    end

    if registeredCount > 0 and rxpAddon.RXPFrame and type(rxpAddon.RXPFrame.GenerateMenuTable) == "function" then
        pcall(rxpAddon.RXPFrame.GenerateMenuTable)
    end

    return registeredCount
end
