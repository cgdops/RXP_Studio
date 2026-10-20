local _, ns = ...
ns.UI = ns.UI or {}

local Theme = ns.UI.Theme
local CardInspector = {}
ns.UI.CardInspector = CardInspector

local WOW_CLASSES = {
    { token = "WARRIOR", code = "WA", color = { 0.78, 0.61, 0.43 }, coords = { 0.00, 0.25, 0.00, 0.25 } },
    { token = "PALADIN", code = "PA", color = { 0.96, 0.55, 0.73 }, coords = { 0.00, 0.25, 0.50, 0.75 } },
    { token = "HUNTER",  code = "HU", color = { 0.67, 0.83, 0.45 }, coords = { 0.00, 0.25, 0.25, 0.50 } },
    { token = "ROGUE",   code = "RO", color = { 1.00, 0.96, 0.41 }, coords = { 0.496, 0.742, 0.00, 0.25 } },
    { token = "PRIEST",  code = "PR", color = { 1.00, 1.00, 1.00 }, coords = { 0.496, 0.742, 0.25, 0.50 } },
    { token = "SHAMAN",  code = "SH", color = { 0.00, 0.44, 0.87 }, coords = { 0.25, 0.496, 0.25, 0.50 } },
    { token = "MAGE",    code = "MA", color = { 0.25, 0.78, 0.92 }, coords = { 0.25, 0.496, 0.00, 0.25 } },
    { token = "WARLOCK", code = "WL", color = { 0.53, 0.53, 0.93 }, coords = { 0.742, 0.988, 0.25, 0.50 } },
    { token = "DRUID",   code = "DR", color = { 1.00, 0.49, 0.04 }, coords = { 0.742, 0.988, 0.00, 0.25 } },
}

local function trim(s)
    return (tostring(s or "")):match("^%s*(.-)%s*$")
end

local function hasClassCondition(card, classToken)
    if not card or not card.conditions or not card.conditions.classes then
        return false
    end
    local classes = card.conditions.classes
    if classes[classToken] == true then
        return true
    end
    for i = 1, #classes do
        if tostring(classes[i]):upper() == classToken then
            return true
        end
    end
    return false
end

local function toggleClassCondition(card, classToken)
    if not card then
        return
    end
    card.conditions = card.conditions or {}
    card.conditions.classes = card.conditions.classes or {}
    local classes = card.conditions.classes

    -- Normalize to ordered array
    local normalized = {}
    local found = false
    for k, v in pairs(classes) do
        if type(k) == "number" and type(v) == "string" then
            local up = v:upper()
            if up == classToken then
                found = true
            else
                table.insert(normalized, up)
            end
        elseif type(k) == "string" and v == true then
            local up = k:upper()
            if up == classToken then
                found = true
            else
                table.insert(normalized, up)
            end
        end
    end

    if not found then
        table.insert(normalized, classToken)
    end
    card.conditions.classes = normalized
end

local function getActionPrimaryField(action)
    if not action then
        return ""
    end
    local aType = tostring(action.type or "note"):lower()
    if aType == "complete" then
        if action.questId then
            return string.format("%s,%s", tostring(action.questId), tostring(action.objIndex or 1))
        end
        return ""
    elseif aType == "accept" or aType == "turnin" then
        return action.questId and tostring(action.questId) or ""
    elseif aType == "use" or aType == "collect" then
        return action.itemId and tostring(action.itemId) or ""
    elseif aType == "xp" or aType == "grind" then
        return action.xpTarget and tostring(action.xpTarget) or ""
    elseif aType == "fly" or aType == "fp" or aType == "hs" or aType == "home" then
        return action.destination and tostring(action.destination) or ""
    end
    return action.questId and tostring(action.questId) or ""
end

local function setActionPrimaryField(action, val)
    if not action then
        return
    end
    val = trim(val)
    local aType = tostring(action.type or "note"):lower()
    if aType == "complete" then
        local qid, objIdx = val:match("^(%d+)%s*,%s*(%d+)$")
        if qid then
            action.questId = tonumber(qid)
            action.objIndex = tonumber(objIdx) or 1
        else
            action.questId = tonumber(val)
            action.objIndex = action.objIndex or 1
        end
    elseif aType == "accept" or aType == "turnin" then
        action.questId = tonumber(val)
    elseif aType == "use" or aType == "collect" then
        action.itemId = tonumber(val)
    elseif aType == "xp" or aType == "grind" then
        action.xpTarget = val
    elseif aType == "fly" or aType == "fp" or aType == "hs" or aType == "home" then
        action.destination = val
    else
        action.questId = tonumber(val)
    end
end

local function getActionSecondaryField(action)
    if not action then
        return ""
    end
    local aType = tostring(action.type or "note"):lower()
    if aType == "accept" or aType == "turnin" then
        return action.questTitle or action.text or ""
    elseif aType == "complete" then
        return action.objText or action.text or ""
    elseif aType == "use" or aType == "collect" then
        return action.itemName or action.text or ""
    end
    return action.text or action.questTitle or action.objText or ""
end

local function setActionSecondaryField(action, val)
    if not action then
        return
    end
    local aType = tostring(action.type or "note"):lower()
    if aType == "accept" or aType == "turnin" then
        action.questTitle = val
        action.text = val
    elseif aType == "complete" then
        action.objText = val
        action.text = val
    elseif aType == "use" or aType == "collect" then
        action.itemName = val
        action.text = val
    else
        action.text = val
    end
end

local function cycleActionType(currentType, reverse)
    local list = Theme.ActionTypesOrdered
    local cur = tostring(currentType or "accept"):lower()
    local idx = 1
    for i = 1, #list do
        if list[i] == cur then
            idx = i
            break
        end
    end
    if reverse then
        idx = idx - 1
        if idx < 1 then idx = #list end
    else
        idx = idx + 1
        if idx > #list then idx = 1 end
    end
    return list[idx]
end

function CardInspector:NotifyCardChanged()
    if self._isRefreshing then
        return
    end
    local guide = ns.Core and ns.Core:GetActiveGuide()
    if guide then
        if self.currentCard then
            self.currentCard.rawOverride = nil
        end
        ns:FireCallback("GUIDE_UPDATED", guide)
    end
end

function CardInspector:CreateActionRow(parent, rowIndex)
    local row = CreateFrame("Frame", nil, parent, Theme:GetBackdropTemplate())
    row:SetHeight(26)
    Theme:ApplyBackdrop(row, Theme.Colors.bgCard, Theme.Colors.borderDefault)

    local typeBtn = Theme:CreateTextButton(row, "[ACCEPT]", 78, 20, "subtle", function(_, mouseButton)
        local act = row.actionData
        if not act then return end
        act.type = cycleActionType(act.type, mouseButton == "RightButton")
        self:NotifyCardChanged()
        self:Refresh()
    end)
    typeBtn:SetPoint("LEFT", row, "LEFT", 3, 0)
    row.typeBtn = typeBtn

    local idBox = Theme:CreateEditBox(row, 54, 20, false, function(txt, userInput)
        if not userInput or self._isRefreshing then return end
        if row.actionData then
            setActionPrimaryField(row.actionData, txt)
            if self.currentCard then
                self.currentCard.rawOverride = nil
            end
        end
    end, function(txt)
        if self._isRefreshing then return end
        if row.actionData then
            setActionPrimaryField(row.actionData, txt)
            self:NotifyCardChanged()
        end
    end)
    idBox:SetPoint("LEFT", typeBtn, "RIGHT", 3, 0)
    row.idBox = idBox

    local delBtn = Theme:CreateTextButton(row, "[X]", 22, 20, "danger", function()
        if not self.currentCard or not self.currentCard.actions or not row.actionIndex then
            return
        end
        table.remove(self.currentCard.actions, row.actionIndex)
        self:NotifyCardChanged()
        self:Refresh()
    end)
    delBtn:SetPoint("RIGHT", row, "RIGHT", -3, 0)
    row.delBtn = delBtn

    local splitOutBtn = Theme:CreateTextButton(row, "[Split Out]", 60, 20, "gold", function()
        local guide = ns.Core and ns.Core:GetActiveGuide()
        if guide and self.currentStepIndex and row.actionIndex and ns.AutoMerger and ns.AutoMerger.SplitCard then
            ns.AutoMerger:SplitCard(guide, self.currentStepIndex, row.actionIndex)
            self:Refresh()
        end
    end)
    splitOutBtn:SetPoint("RIGHT", delBtn, "LEFT", -3, 0)
    row.splitOutBtn = splitOutBtn

    local descBox = Theme:CreateEditBox(row, 110, 20, false, function(txt, userInput)
        if not userInput or self._isRefreshing then return end
        if row.actionData then
            setActionSecondaryField(row.actionData, txt)
            if self.currentCard then
                self.currentCard.rawOverride = nil
            end
        end
    end, function(txt)
        if self._isRefreshing then return end
        if row.actionData then
            setActionSecondaryField(row.actionData, txt)
            self:NotifyCardChanged()
        end
    end)
    descBox:SetPoint("LEFT", idBox, "RIGHT", 3, 0)
    descBox:SetPoint("RIGHT", splitOutBtn, "LEFT", -3, 0)
    row.descBox = descBox

    row.rowIndex = rowIndex
    return row
end

function CardInspector:Create(parent)
    if not CreateFrame then
        return nil
    end

    local root = CreateFrame("Frame", nil, parent, Theme:GetBackdropTemplate())
    root:SetAllPoints(parent)
    Theme:ApplyBackdrop(root, Theme.Colors.bgSecondary, Theme.Colors.borderDefault)
    self.frame = root
    self.actionRows = {}

    -- Column Title Header
    local colHeader = CreateFrame("Frame", nil, root, Theme:GetBackdropTemplate())
    colHeader:SetPoint("TOPLEFT", root, "TOPLEFT", 4, -4)
    colHeader:SetPoint("TOPRIGHT", root, "TOPRIGHT", -4, -4)
    colHeader:SetHeight(26)
    Theme:ApplyBackdrop(colHeader, Theme.Colors.bgPrimary, Theme.Colors.borderDefault)

    local colTitle = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colTitle:SetPoint("LEFT", colHeader, "LEFT", 8, 0)
    colTitle:SetText("|cffF59E0BSTEP CARD INSPECTOR|r")
    self.colTitle = colTitle

    -- Visual Mode Container
    local visualPanel = CreateFrame("Frame", nil, root)
    visualPanel:SetPoint("TOPLEFT", colHeader, "BOTTOMLEFT", 0, -4)
    visualPanel:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -4, 4)
    self.visualPanel = visualPanel

    -- 1. Step Header Controls (Zone, X, Y + [Snap to MyPos], Target NPCs)
    local locSection = CreateFrame("Frame", nil, visualPanel, Theme:GetBackdropTemplate())
    locSection:SetPoint("TOPLEFT", visualPanel, "TOPLEFT", 0, 0)
    locSection:SetPoint("TOPRIGHT", visualPanel, "TOPRIGHT", 0, 0)
    locSection:SetHeight(64)
    Theme:ApplyBackdrop(locSection, Theme.Colors.bgPrimary, Theme.Colors.borderDefault)

    local zoneLabel = locSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneLabel:SetPoint("TOPLEFT", locSection, "TOPLEFT", 6, -8)
    zoneLabel:SetText("Zone:")

    local zoneBox = Theme:CreateEditBox(locSection, 108, 20, false, function(txt, userInput)
        if not userInput or self._isRefreshing or not self.currentCard then return end
        self.currentCard.zone = trim(txt)
        self.currentCard.rawOverride = nil
    end, function(txt)
        if self._isRefreshing or not self.currentCard then return end
        self.currentCard.zone = trim(txt)
        self:NotifyCardChanged()
    end)
    zoneBox:SetPoint("LEFT", zoneLabel, "RIGHT", 4, 0)
    self.zoneBox = zoneBox

    local xLabel = locSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    xLabel:SetPoint("LEFT", zoneBox, "RIGHT", 5, 0)
    xLabel:SetText("X:")

    local xBox = Theme:CreateEditBox(locSection, 42, 20, false, function(txt, userInput)
        if not userInput or self._isRefreshing or not self.currentCard then return end
        self.currentCard.x = tonumber(txt)
        self.currentCard.rawOverride = nil
    end, function(txt)
        if self._isRefreshing or not self.currentCard then return end
        self.currentCard.x = tonumber(txt)
        self:NotifyCardChanged()
    end)
    xBox:SetPoint("LEFT", xLabel, "RIGHT", 2, 0)
    self.xBox = xBox

    local yLabel = locSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    yLabel:SetPoint("LEFT", xBox, "RIGHT", 4, 0)
    yLabel:SetText("Y:")

    local yBox = Theme:CreateEditBox(locSection, 42, 20, false, function(txt, userInput)
        if not userInput or self._isRefreshing or not self.currentCard then return end
        self.currentCard.y = tonumber(txt)
        self.currentCard.rawOverride = nil
    end, function(txt)
        if self._isRefreshing or not self.currentCard then return end
        self.currentCard.y = tonumber(txt)
        self:NotifyCardChanged()
    end)
    yBox:SetPoint("LEFT", yLabel, "RIGHT", 2, 0)
    self.yBox = yBox

    local snapBtn = Theme:CreateTextButton(locSection, "[Snap to MyPos]", 88, 20, "primary", function()
        if not self.currentCard then return end
        if ns.Recorder and ns.Recorder.GetPlayerLocation then
            local z, px, py = ns.Recorder:GetPlayerLocation()
            if z then self.currentCard.zone = z end
            if px then self.currentCard.x = tonumber(string.format("%.2f", px)) end
            if py then self.currentCard.y = tonumber(string.format("%.2f", py)) end
            self:NotifyCardChanged()
            self:Refresh()
        end
    end)
    snapBtn:SetPoint("TOPRIGHT", locSection, "TOPRIGHT", -6, -5)
    self.snapBtn = snapBtn

    local npcLabel = locSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    npcLabel:SetPoint("TOPLEFT", locSection, "TOPLEFT", 6, -37)
    npcLabel:SetText("Target NPC(s):")

    local npcBox = Theme:CreateEditBox(locSection, 250, 20, false, function(txt, userInput)
        if not userInput or self._isRefreshing or not self.currentCard then return end
        local targets = {}
        for part in tostring(txt or ""):gmatch("[^;]+") do
            local clean = trim(part)
            if clean ~= "" then
                table.insert(targets, clean)
            end
        end
        self.currentCard.targets = targets
        self.currentCard.rawOverride = nil
    end, function(txt)
        if self._isRefreshing or not self.currentCard then return end
        local targets = {}
        for part in tostring(txt or ""):gmatch("[^;]+") do
            local clean = trim(part)
            if clean ~= "" then
                table.insert(targets, clean)
            end
        end
        self.currentCard.targets = targets
        self:NotifyCardChanged()
    end)
    npcBox:SetPoint("LEFT", npcLabel, "RIGHT", 6, 0)
    npcBox:SetPoint("RIGHT", locSection, "RIGHT", -6, 0)
    self.npcBox = npcBox

    -- 2. Action List Editor
    local actionsHeader = visualPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    actionsHeader:SetPoint("TOPLEFT", locSection, "BOTTOMLEFT", 4, -6)
    actionsHeader:SetText("ACTIONS (Click badge to cycle type | ID/Target | Title/Objective)")

    local addActionBtn = Theme:CreateTextButton(visualPanel, "[+ Add Action]", 92, 18, "success", function()
        if not self.currentCard then return end
        self.currentCard.actions = self.currentCard.actions or {}
        table.insert(self.currentCard.actions, {
            type = "accept",
            questId = nil,
            questTitle = "New Action",
            text = "New Action",
        })
        self:NotifyCardChanged()
        self:Refresh()
    end)
    addActionBtn:SetPoint("TOPRIGHT", locSection, "BOTTOMRIGHT", -2, -4)
    self.addActionBtn = addActionBtn

    local actionListScroll = Theme:CreateScrollList(visualPanel, 350, 175)
    actionListScroll:SetPoint("TOPLEFT", actionsHeader, "BOTTOMLEFT", -4, -4)
    actionListScroll:SetPoint("TOPRIGHT", visualPanel, "TOPRIGHT", 0, -24)
    actionListScroll:SetHeight(175)
    self.actionListScroll = actionListScroll

    -- 3. Plain-English Behavior Toggles (2x2 Grid)
    local behaviorHeader = visualPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    behaviorHeader:SetPoint("TOPLEFT", actionListScroll, "BOTTOMLEFT", 4, -6)
    behaviorHeader:SetText("STEP BEHAVIOR RULES")

    local toggleGrid = CreateFrame("Frame", nil, visualPanel)
    toggleGrid:SetPoint("TOPLEFT", behaviorHeader, "BOTTOMLEFT", -4, -3)
    toggleGrid:SetPoint("TOPRIGHT", visualPanel, "TOPRIGHT", 0, 0)
    toggleGrid:SetHeight(50)
    self.toggleGrid = toggleGrid

    self.pillCompleteTogether = Theme:CreateTogglePill(toggleGrid, "Complete Together", true, function(val)
        if self._isRefreshing or not self.currentCard then return end
        self.currentCard.completeTogether = val
        self:NotifyCardChanged()
    end)
    self.pillCompleteTogether:SetSize(172, 22)
    self.pillCompleteTogether:SetPoint("TOPLEFT", toggleGrid, "TOPLEFT", 0, 0)

    self.pillSticky = Theme:CreateTogglePill(toggleGrid, "Background / Sticky", false, function(val)
        if self._isRefreshing or not self.currentCard then return end
        self.currentCard.sticky = val
        self:NotifyCardChanged()
    end)
    self.pillSticky:SetSize(172, 22)
    self.pillSticky:SetPoint("TOPRIGHT", toggleGrid, "TOPRIGHT", 0, 0)

    self.pillCompleteWithNext = Theme:CreateTogglePill(toggleGrid, "Complete With Next", false, function(val)
        if self._isRefreshing or not self.currentCard then return end
        self.currentCard.completeWithNext = val
        self:NotifyCardChanged()
    end)
    self.pillCompleteWithNext:SetSize(172, 22)
    self.pillCompleteWithNext:SetPoint("BOTTOMLEFT", toggleGrid, "BOTTOMLEFT", 0, 0)

    self.pillOptional = Theme:CreateTogglePill(toggleGrid, "Optional Step", false, function(val)
        if self._isRefreshing or not self.currentCard then return end
        self.currentCard.optional = val
        self:NotifyCardChanged()
    end)
    self.pillOptional:SetSize(172, 22)
    self.pillOptional:SetPoint("BOTTOMRIGHT", toggleGrid, "BOTTOMRIGHT", 0, 0)

    -- 4. Guide Tip / Note Box
    local noteHeader = visualPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    noteHeader:SetPoint("TOPLEFT", toggleGrid, "BOTTOMLEFT", 4, -6)
    noteHeader:SetText("GUIDE TIP / STEP NOTE (Compiles to >> Tip)")

    local noteBox = Theme:CreateEditBox(visualPanel, 348, 66, true, function(txt, userInput)
        if not userInput or self._isRefreshing or not self.currentCard then return end
        self.currentCard.note = txt
        self.currentCard.rawOverride = nil
    end, function(txt)
        if self._isRefreshing or not self.currentCard then return end
        self.currentCard.note = txt
        self:NotifyCardChanged()
    end)
    noteBox:SetPoint("TOPLEFT", noteHeader, "BOTTOMLEFT", -4, -3)
    noteBox:SetPoint("TOPRIGHT", visualPanel, "TOPRIGHT", 0, 0)
    noteBox:SetHeight(66)
    self.noteBox = noteBox

    -- 5. Class Condition Filter Bar
    local classHeader = visualPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    classHeader:SetPoint("TOPLEFT", noteBox, "BOTTOMLEFT", 4, -6)
    classHeader:SetText("CLASS FILTER (Empty = All Classes | Highlighted = Restricted << Class)")

    local classBar = CreateFrame("Frame", nil, visualPanel, Theme:GetBackdropTemplate())
    classBar:SetPoint("TOPLEFT", classHeader, "BOTTOMLEFT", -4, -3)
    classBar:SetPoint("TOPRIGHT", visualPanel, "TOPRIGHT", 0, 0)
    classBar:SetHeight(34)
    Theme:ApplyBackdrop(classBar, Theme.Colors.bgPrimary, Theme.Colors.borderDefault)
    self.classBar = classBar
    self.classButtons = {}

    for i = 1, #WOW_CLASSES do
        local info = WOW_CLASSES[i]
        local cBtn = CreateFrame("Button", nil, classBar, Theme:GetBackdropTemplate())
        cBtn:SetSize(35, 26)
        cBtn:SetPoint("LEFT", classBar, "LEFT", 5 + ((i - 1) * 38), 0)
        Theme:ApplyBackdrop(cBtn, Theme.Colors.bgCard, Theme.Colors.borderDefault)

        local icon = cBtn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", cBtn, "LEFT", 2, 0)
        icon:SetTexture(Theme.CLASS_TEXTURE)
        local tcoords = (_G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[info.token]) or info.coords
        if tcoords and icon.SetTexCoord then
            icon:SetTexCoord(tcoords[1], tcoords[2], tcoords[3], tcoords[4])
        end
        cBtn.icon = icon

        local codeText = cBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        codeText:SetPoint("RIGHT", cBtn, "RIGHT", -2, 0)
        codeText:SetText(info.code)
        if codeText.SetTextColor then
            codeText:SetTextColor(info.color[1], info.color[2], info.color[3], 1)
        end
        cBtn.codeText = codeText
        cBtn.classInfo = info

        cBtn:SetScript("OnClick", function()
            if not self.currentCard then return end
            toggleClassCondition(self.currentCard, info.token)
            self:NotifyCardChanged()
            self:RefreshClassBar()
        end)

        self.classButtons[i] = cBtn
    end

    -- Raw Syntax Mode Container
    local rawPanel = CreateFrame("Frame", nil, root)
    rawPanel:SetPoint("TOPLEFT", colHeader, "BOTTOMLEFT", 0, -4)
    rawPanel:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -4, 4)
    rawPanel:Hide()
    self.rawPanel = rawPanel

    local rawHint = rawPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rawHint:SetPoint("TOPLEFT", rawPanel, "TOPLEFT", 4, -4)
    rawHint:SetText("RAW RXP SYNTAX EDITOR (Direct DSL inspection & override)")

    local rawBox = Theme:CreateEditBox(rawPanel, 348, 410, true)
    rawBox:SetPoint("TOPLEFT", rawHint, "BOTTOMLEFT", -4, -4)
    rawBox:SetPoint("BOTTOMRIGHT", rawPanel, "BOTTOMRIGHT", 0, 34)
    self.rawBox = rawBox

    local applyRawBtn = Theme:CreateTextButton(rawPanel, "[Apply Raw to Card]", 168, 24, "primary", function()
        if not self.currentCard then return end
        local rawTxt = self.rawBox:GetText()
        if ns.Compiler and ns.Compiler.ParseRawStep then
            local parsed = ns.Compiler:ParseRawStep(rawTxt)
            if parsed then
                parsed.id = self.currentCard.id
                for k in pairs(self.currentCard) do
                    self.currentCard[k] = nil
                end
                for k, v in pairs(parsed) do
                    self.currentCard[k] = v
                end
                self.currentCard.rawOverride = rawTxt
            else
                self.currentCard.rawOverride = rawTxt
            end
        else
            self.currentCard.rawOverride = rawTxt
        end
        local guide = ns.Core and ns.Core:GetActiveGuide()
        if guide then
            ns:FireCallback("GUIDE_UPDATED", guide)
        end
        self:Refresh()
    end)
    applyRawBtn:SetPoint("BOTTOMLEFT", rawPanel, "BOTTOMLEFT", 0, 2)

    local resetAstBtn = Theme:CreateTextButton(rawPanel, "[Reset to Visual AST]", 168, 24, "gold", function()
        if not self.currentCard then return end
        self.currentCard.rawOverride = nil
        local guide = ns.Core and ns.Core:GetActiveGuide()
        if guide then
            ns:FireCallback("GUIDE_UPDATED", guide)
        end
        self:Refresh()
    end)
    resetAstBtn:SetPoint("BOTTOMRIGHT", rawPanel, "BOTTOMRIGHT", 0, 2)

    return root
end

function CardInspector:RefreshClassBar()
    if not self.classButtons then
        return
    end
    for i = 1, #self.classButtons do
        local btn = self.classButtons[i]
        local active = hasClassCondition(self.currentCard, btn.classInfo.token)
        if active then
            Theme:ApplyBackdrop(btn, Theme.ButtonStyles.gold.bg, Theme.Colors.borderAccentGold)
            if btn.icon and btn.icon.SetAlpha then btn.icon:SetAlpha(1.0) end
        else
            Theme:ApplyBackdrop(btn, Theme.Colors.bgCard, Theme.Colors.borderDefault)
            if btn.icon and btn.icon.SetAlpha then btn.icon:SetAlpha(0.45) end
        end
    end
end

function CardInspector:SetCard(card, stepIndex)
    self.currentCard = card
    self.currentStepIndex = stepIndex
    self:Refresh()
end

function CardInspector:Refresh()
    if not self.frame then
        return
    end

    local isRawMode = RXP_StudioDB and RXP_StudioDB.settings and RXP_StudioDB.settings.rawSyntaxMode
    local card = self.currentCard
    local stepIdx = self.currentStepIndex or 1

    self._isRefreshing = true

    if not card then
        self.colTitle:SetText("|cffF59E0BSTEP CARD INSPECTOR|r |cff9CA3AF(No Step Selected)|r")
        self.visualPanel:Hide()
        self.rawPanel:Hide()
        self._isRefreshing = false
        return
    end

    self.colTitle:SetText(string.format("|cffF59E0BSTEP #%d INSPECTOR|r %s", stepIdx, card.rawOverride and "|cffA855F7[RAW OVERRIDE]|r" or ""))

    if isRawMode then
        self.visualPanel:Hide()
        self.rawPanel:Show()
        local compiled = ""
        if card.rawOverride and card.rawOverride ~= "" then
            compiled = card.rawOverride
        elseif ns.Compiler and ns.Compiler.CompileStepCard then
            compiled = ns.Compiler:CompileStepCard(card) or ""
        end
        if not self.rawBox:HasFocus() then
            self.rawBox:SetText(compiled)
        end
        self._isRefreshing = false
        return
    end

    self.rawPanel:Hide()
    self.visualPanel:Show()

    if not self.zoneBox:HasFocus() then
        self.zoneBox:SetText(card.zone or "")
    end
    if not self.xBox:HasFocus() then
        self.xBox:SetText(card.x and string.format("%.2f", tonumber(card.x) or 0) or "")
    end
    if not self.yBox:HasFocus() then
        self.yBox:SetText(card.y and string.format("%.2f", tonumber(card.y) or 0) or "")
    end
    if not self.npcBox:HasFocus() then
        self.npcBox:SetText(card.targets and table.concat(card.targets, "; ") or "")
    end

    self.pillCompleteTogether:SetValue(card.completeTogether ~= false, true)
    self.pillSticky:SetValue(card.sticky and true or false, true)
    self.pillCompleteWithNext:SetValue(card.completeWithNext and true or false, true)
    self.pillOptional:SetValue(card.optional and true or false, true)
    if not self.noteBox:HasFocus() then
        self.noteBox:SetText(card.note or "")
    end

    self:RefreshClassBar()

    local actions = card.actions or {}
    local content = self.actionListScroll.content
    for i = 1, #actions do
        local act = actions[i]
        local row = self.actionRows[i]
        if not row then
            row = self:CreateActionRow(content, i)
            self.actionRows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -2 - ((i - 1) * 28))
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", -2, -2 - ((i - 1) * 28))
        row.actionData = act
        row.actionIndex = i

        row.typeBtn:SetButtonText(Theme:GetActionBadge(act.type))
        if not row.idBox:HasFocus() then
            row.idBox:SetText(getActionPrimaryField(act))
        end
        if not row.descBox:HasFocus() then
            row.descBox:SetText(getActionSecondaryField(act))
        end

        if #actions > 1 then
            row.splitOutBtn:Show()
            row.descBox:SetPoint("RIGHT", row.splitOutBtn, "LEFT", -3, 0)
        else
            row.splitOutBtn:Hide()
            row.descBox:SetPoint("RIGHT", row.delBtn, "LEFT", -3, 0)
        end

        row:Show()
    end

    for i = #actions + 1, #self.actionRows do
        self.actionRows[i]:Hide()
    end

    self.actionListScroll:SetContentHeight(math.max(40, #actions * 28 + 6))
    self._isRefreshing = false
end
