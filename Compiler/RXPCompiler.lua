local addonName, ns = ...
_G.RXP_Studio = ns

ns.Core = ns.Core or {}
ns.Compiler = ns.Compiler or {}

local Compiler = ns.Compiler

local KNOWN_CLASSES = {
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

local KNOWN_RACES = {
    ORC       = "Orc",
    TROLL     = "Troll",
    TAUREN    = "Tauren",
    UNDEAD    = "Undead",
    SCOURGE   = "Undead",
    BLOODELF  = "BloodElf",
    HUMAN     = "Human",
    DWARF     = "Dwarf",
    GNOME     = "Gnome",
    NIGHTELF  = "NightElf",
    DRAENEI   = "Draenei",
    HIGHELF   = "HighElf",
}

local function trim(s)
    if not s then return "" end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function addUnique(list, val)
    if not val or val == "" then return end
    for i = 1, #list do
        if list[i] == val then
            return
        end
    end
    table.insert(list, val)
end

local function parseConditionTokens(condStr)
    local classes = {}
    local races = {}
    if not condStr or condStr == "" then
        return { classes = classes, races = races }
    end
    for token in condStr:gmatch("[%w!]+") do
        local clean = token:gsub("^!", ""):upper()
        if KNOWN_CLASSES[clean] then
            addUnique(classes, clean)
        elseif KNOWN_RACES[clean] then
            addUnique(races, KNOWN_RACES[clean])
        end
    end
    return { classes = classes, races = races }
end

local function formatConditionString(card)
    if card.conditions then
        local parts = {}
        local races = card.conditions.races or {}
        local classes = card.conditions.classes or {}
        if #races > 0 then
            table.insert(parts, table.concat(races, "/"))
        end
        if #classes > 0 then
            local prettyClasses = {}
            for i = 1, #classes do
                local c = tostring(classes[i]):upper()
                table.insert(prettyClasses, KNOWN_CLASSES[c] or classes[i])
            end
            table.insert(parts, table.concat(prettyClasses, "/"))
        end
        if #parts > 0 then
            return table.concat(parts, " ")
        end
    end
    if card.conditionText and trim(card.conditionText) ~= "" then
        return trim(card.conditionText)
    end
    return nil
end

function Compiler:ParseRawStep(stepString)
    if type(stepString) ~= "string" then
        return nil
    end

    local card
    if ns.Core and ns.Core.NewStepCard then
        card = ns.Core:NewStepCard()
    else
        card = {
            id = "card_" .. tostring(math.random(100000, 999999)),
            title = "",
            zone = nil,
            x = nil,
            y = nil,
            loopWaypoints = {},
            targets = {},
            mobs = {},
            sticky = false,
            completeWithNext = false,
            optional = false,
            hideWindow = false,
            loop = false,
            completeTogether = true,
            note = "",
            conditions = { classes = {}, races = {} },
            rawOverride = nil,
            actions = {},
            lintIssues = {},
        }
    end

    local hasPrimaryGoto = false

    for rawLine in (stepString .. "\n"):gmatch("([^\r\n]*)\r?\n") do
        local line = trim(rawLine)
        if line ~= "" then
            -- 1. Check for 'step' or 'step << Condition'
            if line:match("^step%f[%s%z]") then
                local cond = line:match("^step%s*<<%s*(.+)$")
                if cond then
                    card.conditionText = trim(cond)
                    card.conditions = parseConditionTokens(cond)
                end

            -- 2. Check for '#' step directives
            elseif line:sub(1, 1) == "#" then
                local lower = line:lower()
                if lower:match("^#sticky") then
                    card.sticky = true
                elseif lower:match("^#completewith%s+next") then
                    card.completeWithNext = true
                elseif lower:match("^#optional") then
                    card.optional = true
                elseif lower:match("^#hidewindow") then
                    card.hideWindow = true
                elseif lower:match("^#loop") then
                    card.loop = true
                elseif lower:match("^#label%s+") then
                    card.label = trim(line:match("^#[Ll]abel%s+(.+)$"))
                end

            -- 3. Check for '.complete' BEFORE stripping '--' comments (since RXP_Recorder uses --objText)
            elseif line:match("^%.complete%s+") then
                local body = line:match("^%.complete%s+(.+)$")
                if body then
                    local argsPart, textPart
                    local dashIdx = body:find("%-%-")
                    local arrowIdx = body:find(">>")
                    if dashIdx and (not arrowIdx or dashIdx < arrowIdx) then
                        argsPart = trim(body:sub(1, dashIdx - 1))
                        -- Preserve exact objective text (including unloaded spacing like "1/1   slain")
                        textPart = body:sub(dashIdx + 2):gsub("^ ?", ""):gsub("\r$", "")
                    elseif arrowIdx then
                        argsPart = trim(body:sub(1, arrowIdx - 1))
                        textPart = trim(body:sub(arrowIdx + 2):gsub("%s*%-%-.*$", ""))
                    else
                        argsPart = trim(body)
                        textPart = ""
                    end

                    local qidStr, objIdxStr, objMaxStr = argsPart:match("^(%d+)%s*,%s*(%d+)%s*,?%s*(%d*)$")
                    if not qidStr then
                        qidStr = argsPart:match("^(%d+)")
                        objIdxStr = "1"
                    end
                    local questId = tonumber(qidStr)
                    local objIndex = tonumber(objIdxStr) or 1
                    local objMax = tonumber(objMaxStr)
                    if not objMax and textPart ~= "" then
                        objMax = tonumber(textPart:match("^%d+/(%d+)"))
                    end

                    table.insert(card.actions, {
                        type     = "complete",
                        questId  = questId,
                        objIndex = objIndex,
                        objMax   = objMax,
                        objText  = textPart,
                        text     = textPart,
                    })
                end

            -- 4. Pure comment line '--...'
            elseif line:sub(1, 2) == "--" then
                -- Ignore pure comment lines

            else
                -- Strip trailing '--' comments for non-.complete lines
                local cleanLine = line:gsub("%s*%-%-.*$", "")

                -- 5. Standalone '>>' or '+' note line
                if cleanLine:sub(1, 2) == ">>" or cleanLine:sub(1, 1) == "+" then
                    local isPlus = (cleanLine:sub(1, 1) == "+")
                    local noteText = trim(isPlus and cleanLine:sub(2) or cleanLine:sub(3))
                    local isAutoTravel = (not isPlus) and (
                        noteText:match("^Travel to .+ %([%d%.]+, [%d%.]+%)$") ~= nil
                        or noteText == "Proceed to next step"
                    )
                    if noteText ~= "" and not isAutoTravel then
                        if not card.note or card.note == "" then
                            card.note = noteText
                        end
                        table.insert(card.actions, {
                            type   = "note",
                            text   = noteText,
                            prefix = isPlus and "+" or ">>",
                        })
                    end

                -- 6. Dot-commands (.goto, .accept, .turnin, .trainer, .vendor, .target, .mob, etc.)
                elseif cleanLine:sub(1, 1) == "." then
                    local cmd, rest = cleanLine:match("^%.([%w_]+)%s*(.*)$")
                    if cmd then
                        cmd = cmd:lower()
                        local argsPart, notePart = rest, nil
                        local arrowPos = rest:find(">>")
                        if arrowPos then
                            argsPart = trim(rest:sub(1, arrowPos - 1))
                            notePart = trim(rest:sub(arrowPos + 2))
                        else
                            argsPart = trim(rest)
                        end

                        if cmd == "goto" then
                            local zone, xStr, yStr, extra = argsPart:match("^([^,]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,?(.*)$")
                            if zone and xStr and yStr then
                                zone = trim(zone)
                                local x = tonumber(xStr)
                                local y = tonumber(yStr)
                                local radius = extra and tonumber(extra:match("^%s*([%d%.]+)")) or nil
                                if not hasPrimaryGoto then
                                    card.zone = zone
                                    card.x = x
                                    card.y = y
                                    hasPrimaryGoto = true
                                    if notePart and notePart ~= "" then
                                        if not card.note or card.note == "" then
                                            card.note = notePart
                                        end
                                        table.insert(card.actions, {
                                            type = "note",
                                            text = notePart,
                                        })
                                    end
                                else
                                    table.insert(card.loopWaypoints, {
                                        zone   = zone,
                                        x      = x,
                                        y      = y,
                                        radius = radius,
                                        text   = notePart,
                                    })
                                end
                            end

                        elseif cmd == "accept" then
                            local qid = tonumber(argsPart:match("^(%d+)"))
                            local qTitle = notePart and notePart:gsub("^[Aa]ccept%s+", "") or nil
                            if not qTitle or qTitle == "" then
                                qTitle = qid and ("Quest #" .. tostring(qid)) or "Quest"
                            end
                            table.insert(card.actions, {
                                type       = "accept",
                                questId    = qid,
                                questTitle = qTitle,
                                text       = notePart or ("Accept " .. qTitle),
                            })

                        elseif cmd == "turnin" then
                            local qid = tonumber(argsPart:match("^(%d+)"))
                            local qTitle = notePart and notePart:gsub("^[Tt]urn%s+[Ii]n%s+", "") or nil
                            if not qTitle or qTitle == "" then
                                qTitle = qid and ("Quest #" .. tostring(qid)) or "Quest"
                            end
                            table.insert(card.actions, {
                                type       = "turnin",
                                questId    = qid,
                                questTitle = qTitle,
                                text       = notePart or ("Turn in " .. qTitle),
                            })

                        elseif cmd == "trainer" then
                            table.insert(card.actions, {
                                type = "trainer",
                                text = (notePart and notePart ~= "") and notePart or "Train spells",
                            })

                        elseif cmd == "vendor" then
                            table.insert(card.actions, {
                                type = "vendor",
                                text = (notePart and notePart ~= "") and notePart or "Sell junk / resupply",
                            })

                        elseif cmd == "target" then
                            for npc in argsPart:gmatch("[^;]+") do
                                local cleanNpc = trim(npc):gsub("^%+%s*", "")
                                addUnique(card.targets, cleanNpc)
                                if #card.actions > 0 and not card.actions[#card.actions].target then
                                    card.actions[#card.actions].target = cleanNpc
                                end
                            end

                        elseif cmd == "mob" then
                            for mob in argsPart:gmatch("[^;]+") do
                                local cleanMob = trim(mob):gsub("^%+%s*", "")
                                addUnique(card.mobs, cleanMob)
                            end

                        elseif cmd == "hs" then
                            local dest = (argsPart ~= "" and argsPart) or (notePart and notePart:match("^[Hh]earth%s+to%s+(.+)$")) or nil
                            table.insert(card.actions, {
                                type        = "hs",
                                destination = dest,
                                text        = (notePart and notePart ~= "") and notePart or ("Hearth to " .. (dest or "Inn")),
                            })

                        elseif cmd == "home" then
                            local dest = (argsPart ~= "" and argsPart)
                                or (notePart and (notePart:match("^[Ss]et%s+[Hh]earthstone%s+at%s+(.+)$") or notePart:match("^[Ss]et%s+your%s+[Hh]earthstone%s+to%s+(.+)$")))
                                or nil
                            table.insert(card.actions, {
                                type        = "home",
                                destination = dest,
                                text        = (notePart and notePart ~= "") and notePart or ("Set Hearthstone at " .. (dest or "Inn")),
                            })

                        elseif cmd == "fly" then
                            local dest = (argsPart ~= "" and argsPart) or (notePart and notePart:match("^[Ff]ly%s+to%s+(.+)$")) or ""
                            table.insert(card.actions, {
                                type        = "fly",
                                destination = dest,
                                text        = (notePart and notePart ~= "") and notePart or ("Fly to " .. (dest ~= "" and dest or "destination")),
                            })

                        elseif cmd == "fp" then
                            local dest = (argsPart ~= "" and argsPart) or (notePart and notePart:match("^[Gg]et%s+the%s+(.-)%s+flight%s+path$")) or ""
                            table.insert(card.actions, {
                                type        = "fp",
                                destination = dest,
                                text        = (notePart and notePart ~= "") and notePart or ("Get the " .. dest .. " flight path"),
                            })

                        elseif cmd == "deathskip" then
                            table.insert(card.actions, {
                                type = "deathskip",
                                text = (notePart and notePart ~= "") and notePart or "Die and resurrect at the Spirit Healer",
                            })

                        elseif cmd == "xp" then
                            local xpTarget = argsPart ~= "" and argsPart or "level"
                            table.insert(card.actions, {
                                type     = "xp",
                                xpTarget = xpTarget,
                                text     = (notePart and notePart ~= "") and notePart or ("Grind to " .. xpTarget),
                            })

                        elseif cmd == "use" then
                            local itemId = tonumber(argsPart:match("^(%d+)"))
                            local itemName = notePart and notePart:match("^[Uu]se%s+(.+)$") or nil
                            table.insert(card.actions, {
                                type     = "use",
                                itemId   = itemId,
                                itemName = itemName,
                                text     = (notePart and notePart ~= "") and notePart or ("Use " .. tostring(itemName or itemId or "")),
                            })

                        elseif cmd == "collect" then
                            local idStr, qtyStr = argsPart:match("^(%d+)%s*,?%s*(%d*)")
                            local itemId = tonumber(idStr)
                            local qty = tonumber(qtyStr) or 1
                            local itemName = notePart and notePart:match("^[Cc]ollect%s+(.+)$") or nil
                            table.insert(card.actions, {
                                type     = "collect",
                                itemId   = itemId,
                                qty      = qty,
                                itemName = itemName,
                                text     = (notePart and notePart ~= "") and notePart or ("Collect " .. tostring(itemName or itemId or "")),
                            })
                        end
                    end
                end
            end
        end
    end

    return card
end

function Compiler:CompileStepCard(card)
    if not card then return "" end
    if type(card.rawOverride) == "string" and card.rawOverride:match("%S") then
        return card.rawOverride
    end

    local lines = {}

    -- 1. Step header & class/race condition
    local condStr = formatConditionString(card)
    if condStr and condStr ~= "" then
        table.insert(lines, "step << " .. condStr)
    else
        table.insert(lines, "step")
    end

    -- 2. Step directives (Note: never emit invalid '#loop' step tag; loopWaypoints emit multiple .goto lines)
    if card.sticky then
        table.insert(lines, "    #sticky")
    end
    if card.completeWithNext then
        table.insert(lines, "    #completewith next")
    end
    if card.optional then
        table.insert(lines, "    #optional")
    end
    if card.hideWindow then
        table.insert(lines, "    #hidewindow")
    end
    if card.label and trim(card.label) ~= "" then
        table.insert(lines, "    #label " .. trim(card.label))
    end

    -- 3. Emit card-level >> note BEFORE .goto (or fallback Travel to note for pure waypoint steps)
    local emittedNotes = {}
    if card.note and trim(card.note) ~= "" then
        local cleanNote = trim(card.note)
        emittedNotes[cleanNote] = true
        table.insert(lines, "    >>" .. cleanNote)
    else
        local hasVisibleAction = false
        for i = 1, #(card.actions or {}) do
            local act = card.actions[i]
            if act and act.type and act.type ~= "goto" then
                hasVisibleAction = true
                break
            elseif act and act.type == "goto" and act.text and trim(act.text) ~= "" then
                hasVisibleAction = true
                break
            end
        end
        if not hasVisibleAction then
            if card.zone and trim(card.zone) ~= "" and tonumber(card.x) and tonumber(card.y) then
                table.insert(lines, string.format("    >>Travel to %s (%.1f, %.1f)", trim(card.zone), tonumber(card.x), tonumber(card.y)))
            else
                table.insert(lines, "    >>Proceed to next step")
            end
        end
    end

    -- 4. Primary .goto and any loopWaypoints
    if card.zone and trim(card.zone) ~= "" and tonumber(card.x) and tonumber(card.y) then
        table.insert(lines, string.format("    .goto %s,%.2f,%.2f", trim(card.zone), tonumber(card.x), tonumber(card.y)))
    end
    if card.loopWaypoints then
        for i = 1, #card.loopWaypoints do
            local wp = card.loopWaypoints[i]
            local wpZone = (wp.zone and trim(wp.zone) ~= "") and trim(wp.zone) or (card.zone and trim(card.zone))
            if wpZone and tonumber(wp.x) and tonumber(wp.y) then
                if tonumber(wp.radius) then
                    table.insert(lines, string.format("    .goto %s,%.2f,%.2f,%d", wpZone, tonumber(wp.x), tonumber(wp.y), tonumber(wp.radius)))
                else
                    table.insert(lines, string.format("    .goto %s,%.2f,%.2f", wpZone, tonumber(wp.x), tonumber(wp.y)))
                end
            end
        end
    end

    -- 5. Actions
    local actionTargets = {}

    for i = 1, #(card.actions or {}) do
        local action = card.actions[i]
        local aType = action.type
        if action.target and trim(action.target) ~= "" then
            addUnique(actionTargets, trim(action.target))
        end

        if aType == "accept" then
            local qid = tonumber(action.questId) or 0
            local qTitle = action.questTitle
            if not qTitle or trim(qTitle) == "" then
                if action.text and trim(action.text) ~= "" then
                    qTitle = trim(action.text):gsub("^[Aa]ccept%s+", "")
                else
                    qTitle = "Quest #" .. tostring(qid)
                end
            end
            table.insert(lines, string.format("    .accept %d >>Accept %s", qid, qTitle))

        elseif aType == "turnin" then
            local qid = tonumber(action.questId) or 0
            local qTitle = action.questTitle
            if not qTitle or trim(qTitle) == "" then
                if action.text and trim(action.text) ~= "" then
                    qTitle = trim(action.text):gsub("^[Tt]urn%s+[Ii]n%s+", "")
                else
                    qTitle = "Quest #" .. tostring(qid)
                end
            end
            table.insert(lines, string.format("    .turnin %d >>Turn in %s", qid, qTitle))

        elseif aType == "complete" then
            local qid = tonumber(action.questId) or 0
            local objIdx = tonumber(action.objIndex) or 1
            local objText = action.objText or action.text or ""
            local safeArrowText = trim(objText):gsub("%%", "%%%%")
            if safeArrowText ~= "" then
                table.insert(lines, string.format("    .complete %d,%d >>%s --%s", qid, objIdx, safeArrowText, objText))
            else
                table.insert(lines, string.format("    .complete %d,%d --%s", qid, objIdx, objText))
            end

        elseif aType == "trainer" then
            local txt = (action.text and trim(action.text) ~= "") and trim(action.text) or "Train spells"
            table.insert(lines, "    .trainer >>" .. txt)

        elseif aType == "vendor" then
            local txt = (action.text and trim(action.text) ~= "") and trim(action.text) or "Sell junk / resupply"
            table.insert(lines, "    .vendor >>" .. txt)

        elseif aType == "hs" then
            local dest = action.destination and trim(action.destination) or ""
            local txt = (action.text and trim(action.text) ~= "") and trim(action.text)
                or ("Hearth to " .. (dest ~= "" and dest or "Inn"))
            table.insert(lines, "    .hs >>" .. txt)

        elseif aType == "home" then
            local dest = action.destination and trim(action.destination) or ""
            local txt = (action.text and trim(action.text) ~= "") and trim(action.text)
                or ("Set Hearthstone at " .. (dest ~= "" and dest or "Inn"))
            table.insert(lines, "    .home >>" .. txt)

        elseif aType == "fly" then
            local dest = action.destination and trim(action.destination) or ""
            local txt = (action.text and trim(action.text) ~= "") and trim(action.text)
                or ("Fly to " .. (dest ~= "" and dest or "destination"))
            if dest ~= "" then
                table.insert(lines, string.format("    .fly %s >>%s", dest, txt))
            else
                table.insert(lines, "    .fly  >>" .. txt)
            end

        elseif aType == "fp" then
            local dest = action.destination and trim(action.destination) or ""
            local txt = (action.text and trim(action.text) ~= "") and trim(action.text)
                or ("Get the " .. (dest ~= "" and (dest .. " ") or "") .. "flight path")
            if dest ~= "" then
                table.insert(lines, string.format("    .fp %s >>%s", dest, txt))
            else
                table.insert(lines, "    .fp  >>" .. txt)
            end

        elseif aType == "deathskip" then
            local txt = (action.text and trim(action.text) ~= "") and trim(action.text)
                or "Die and resurrect at the Spirit Healer"
            table.insert(lines, "    .deathskip >>" .. txt)

        elseif aType == "xp" then
            local xpTarget = (action.xpTarget and trim(tostring(action.xpTarget)) ~= "") and trim(tostring(action.xpTarget)) or "level"
            local txt = (action.text and trim(action.text) ~= "") and trim(action.text)
                or ("Grind to " .. xpTarget)
            table.insert(lines, string.format("    .xp %s >>%s", xpTarget, txt))

        elseif aType == "use" then
            local itemId = tonumber(action.itemId) or 0
            local txt = (action.text and trim(action.text) ~= "") and trim(action.text)
                or ("Use " .. tostring(action.itemName or itemId))
            table.insert(lines, string.format("    .use %d >>%s", itemId, txt))

        elseif aType == "collect" then
            local itemId = tonumber(action.itemId) or 0
            local qty = tonumber(action.qty) or 1
            local txt = (action.text and trim(action.text) ~= "") and trim(action.text)
                or ("Collect " .. tostring(action.itemName or itemId))
            table.insert(lines, string.format("    .collect %d,%d >>%s", itemId, qty, txt))

        elseif aType == "goto" then
            local gz = action.zone or card.zone
            if gz and tonumber(action.x) and tonumber(action.y) then
                if action.text and trim(action.text) ~= "" then
                    table.insert(lines, string.format("    .goto %s,%.2f,%.2f >>%s", gz, tonumber(action.x), tonumber(action.y), trim(action.text)))
                else
                    table.insert(lines, string.format("    .goto %s,%.2f,%.2f", gz, tonumber(action.x), tonumber(action.y)))
                end
            end

        elseif aType == "note" then
            local txt = action.text and trim(action.text) or ""
            if txt ~= "" and not emittedNotes[txt] then
                emittedNotes[txt] = true
                local prefix = (action.prefix == "+") and "+" or ">>"
                table.insert(lines, "    " .. prefix .. txt)
            end
        end
    end

    -- 5. Card-level note (if not already emitted via a 'note' action)
    if card.note and trim(card.note) ~= "" then
        local cleanNote = trim(card.note)
        if not emittedNotes[cleanNote] then
            table.insert(lines, "    >>" .. cleanNote)
        end
    end

    -- 6. Deduplicated .target and .mob lines at end of step
    local finalTargets = {}
    for i = 1, #(card.targets or {}) do
        addUnique(finalTargets, trim(card.targets[i]):gsub("^%+%s*", ""))
    end
    for i = 1, #actionTargets do
        addUnique(finalTargets, actionTargets[i]:gsub("^%+%s*", ""))
    end
    for i = 1, #finalTargets do
        table.insert(lines, "    .target " .. finalTargets[i])
    end

    local finalMobs = {}
    for i = 1, #(card.mobs or {}) do
        addUnique(finalMobs, trim(card.mobs[i]):gsub("^%+%s*", ""))
    end
    for i = 1, #finalMobs do
        table.insert(lines, "    .mob " .. finalMobs[i])
    end

    return table.concat(lines, "\n")
end

function Compiler:CompileGuide(guide, forRuntimeTest)
    if not guide then return "" end

    local lines = {}
    table.insert(lines, "#classic")
    table.insert(lines, "#forever")

    local group = (guide.group and trim(guide.group) ~= "") and trim(guide.group) or "My Recorded Guides"
    if not forRuntimeTest then
        local headerConds = {}
        if guide.faction and trim(guide.faction) ~= "" then
            table.insert(headerConds, trim(guide.faction))
        end
        if guide.races and #guide.races > 0 then
            table.insert(headerConds, table.concat(guide.races, "/"))
        end
        if guide.classes and #guide.classes > 0 then
            local pretty = {}
            for i = 1, #guide.classes do
                local c = tostring(guide.classes[i]):upper()
                table.insert(pretty, KNOWN_CLASSES[c] or guide.classes[i])
            end
            table.insert(headerConds, table.concat(pretty, "/"))
        end
        if #headerConds > 0 then
            table.insert(lines, "#group " .. group .. " << " .. table.concat(headerConds, " "))
        else
            table.insert(lines, "#group " .. group)
        end
    else
        table.insert(lines, "#group " .. group)
    end

    if guide.subgroup and trim(guide.subgroup) ~= "" then
        table.insert(lines, "#subgroup " .. trim(guide.subgroup))
    end

    local name = (guide.name and trim(guide.name) ~= "") and trim(guide.name) or "01-10 Recorded Route"
    local displayName = (guide.displayName and trim(guide.displayName) ~= "") and trim(guide.displayName) or name
    table.insert(lines, "#name " .. name)
    table.insert(lines, "#displayname " .. displayName)
    table.insert(lines, "#version " .. tostring(tonumber(guide.version) or 1))

    if guide.nextGuide and trim(guide.nextGuide) ~= "" then
        table.insert(lines, "#next " .. trim(guide.nextGuide))
    end

    table.insert(lines, "")

    local steps = guide.steps or {}
    if #steps == 0 and forRuntimeTest then
        table.insert(lines, "step\n    >>Guide has no recorded steps yet.")
    else
        for i = 1, #steps do
            local stepStr = self:CompileStepCard(steps[i])
            if stepStr and stepStr ~= "" then
                table.insert(lines, stepStr)
            end
        end
    end

    return table.concat(lines, "\n")
end

function Compiler:ParseGuideText(fullGuideText)
    if type(fullGuideText) ~= "string" then
        return nil
    end

    local metadata = {
        name        = "Imported Guide",
        displayName = nil,
        group       = "My Recorded Guides",
        subgroup    = "",
        version     = 1,
        faction     = "",
        classes     = {},
        races       = {},
        nextGuide   = nil,
        steps       = {},
    }

    local stepBlocks = {}
    local currentStepLines = nil

    for rawLine in (fullGuideText .. "\n"):gmatch("([^\r\n]*)\r?\n") do
        local line = trim(rawLine)
        if line:match("^step%f[%s%z]") then
            if currentStepLines and #currentStepLines > 0 then
                table.insert(stepBlocks, table.concat(currentStepLines, "\n"))
            end
            currentStepLines = { rawLine }
        elseif currentStepLines then
            table.insert(currentStepLines, rawLine)
        else
            -- Header directives before the first 'step'
            if line:sub(1, 1) == "#" then
                local tag, val = line:match("^#([%w_]+)%s*(.*)$")
                if tag then
                    tag = tag:lower()
                    local cleanVal, condPart = val, nil
                    local condPos = val:find("<<")
                    if condPos then
                        cleanVal = trim(val:sub(1, condPos - 1))
                        condPart = trim(val:sub(condPos + 2))
                    else
                        cleanVal = trim(val)
                    end

                    if condPart and condPart ~= "" then
                        if condPart:match("[Hh]orde") then metadata.faction = "Horde"
                        elseif condPart:match("[Aa]lliance") then metadata.faction = "Alliance" end
                        local parsedCond = parseConditionTokens(condPart)
                        if #parsedCond.classes > 0 then metadata.classes = parsedCond.classes end
                        if #parsedCond.races > 0 then metadata.races = parsedCond.races end
                    end

                    if tag == "group" and cleanVal ~= "" then
                        metadata.group = cleanVal
                    elseif tag == "subgroup" then
                        metadata.subgroup = cleanVal
                    elseif tag == "name" and cleanVal ~= "" then
                        metadata.name = cleanVal
                    elseif tag == "displayname" and cleanVal ~= "" then
                        metadata.displayName = cleanVal
                    elseif tag == "version" then
                        metadata.version = tonumber(cleanVal) or 1
                    elseif tag == "next" and cleanVal ~= "" then
                        metadata.nextGuide = cleanVal
                    end
                end
            end
        end
    end

    if currentStepLines and #currentStepLines > 0 then
        table.insert(stepBlocks, table.concat(currentStepLines, "\n"))
    end

    for i = 1, #stepBlocks do
        local card = self:ParseRawStep(stepBlocks[i])
        if card then
            table.insert(metadata.steps, card)
        end
    end

    metadata.displayName = metadata.displayName or metadata.name
    if ns.Core and ns.Core.NormalizeGuide then
        return ns.Core:NormalizeGuide(metadata, 1)
    end
    return metadata
end
