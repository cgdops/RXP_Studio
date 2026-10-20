local _, ns = ...
ns.UI = ns.UI or {}

local Theme = ns.UI.Theme
local StudioFrame = {}
ns.UI.StudioFrame = StudioFrame

local STUDIO_WIDTH = 980
local STUDIO_HEIGHT = 640
local LEFT_COL_WIDTH = 300
local CENTER_COL_WIDTH = 360
local RIGHT_COL_WIDTH = 300
local TIMELINE_CARD_HEIGHT = 86

function StudioFrame:GetSelectedStepIndex(guide)
    guide = guide or (ns.Core and ns.Core:GetActiveGuide())
    local steps = (guide and guide.steps) or {}
    if #steps == 0 then
        if ns.Core then ns.Core.selectedStepIndex = nil end
        return nil
    end
    local idx = (ns.Core and ns.Core.selectedStepIndex) or 1
    if idx < 1 then idx = 1 end
    if idx > #steps then idx = #steps end
    if ns.Core then ns.Core.selectedStepIndex = idx end
    return idx
end

function StudioFrame:SelectStep(stepIndex)
    local guide = ns.Core and ns.Core:GetActiveGuide()
    local steps = (guide and guide.steps) or {}
    if #steps == 0 then
        if ns.Core then ns.Core.selectedStepIndex = nil end
    else
        stepIndex = math.max(1, math.min(#steps, tonumber(stepIndex) or 1))
        if ns.Core then ns.Core.selectedStepIndex = stepIndex end
    end
    self:Refresh()
end

function StudioFrame:CycleActiveGuide(reverse)
    if not ns.Core or not ns.Core.GetGuideList then
        return
    end
    local list = ns.Core:GetGuideList()
    if not list or #list == 0 then
        return
    end
    local active = ns.Core:GetActiveGuide()
    local curIdx = 1
    for i = 1, #list do
        if active and list[i].id == active.id then
            curIdx = i
            break
        end
    end
    if reverse then
        curIdx = curIdx - 1
        if curIdx < 1 then curIdx = #list end
    else
        curIdx = curIdx + 1
        if curIdx > #list then curIdx = 1 end
    end
    local nextGuide = list[curIdx]
    if nextGuide and ns.Core.SetActiveGuide then
        ns.Core:SetActiveGuide(nextGuide.id)
        ns.Core.selectedStepIndex = 1
        self:Refresh()
        if ns.UI.LiveHUD then
            ns.UI.LiveHUD:Refresh()
        end
    end
end

function StudioFrame:CreateGuideDropdownMenu(parent)
    local menu = CreateFrame("Frame", nil, parent, Theme:GetBackdropTemplate())
    menu:SetWidth(260)
    menu:SetHeight(180)
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(parent:GetFrameLevel() + 30)
    Theme:ApplyBackdrop(menu, Theme.Colors.bgPrimary, Theme.Colors.borderAccentBlue)
    menu:Hide()
    menu.rows = {}

    function menu:Populate()
        local list = (ns.Core and ns.Core.GetGuideList and ns.Core:GetGuideList()) or {}
        local active = ns.Core and ns.Core:GetActiveGuide()
        local rowH = 22
        local count = #list
        self:SetHeight(math.max(36, count * (rowH + 2) + 8))

        for i = 1, count do
            local g = list[i]
            local btn = self.rows[i]
            if not btn then
                btn = Theme:CreateTextButton(self, "", 250, rowH, "subtle")
                btn.label:ClearAllPoints()
                btn.label:SetPoint("LEFT", btn, "LEFT", 6, 0)
                btn.label:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
                btn.label:SetJustifyH("LEFT")
                self.rows[i] = btn
            end
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", self, "TOPLEFT", 4, -4 - ((i - 1) * (rowH + 2)))
            local stepCount = (g.steps and #g.steps) or 0
            local isCur = active and (g.id == active.id)
            btn:SetButtonStyle(isCur and "primary" or "subtle")
            btn:SetButtonText(string.format("%s%s |cff9CA3AF(%d steps)|r",
                isCur and "|cff10B981[ACTIVE]|r " or "",
                tostring(g.name or g.id),
                stepCount))
            btn:SetScript("OnClick", function()
                if ns.Core and ns.Core.SetActiveGuide then
                    ns.Core:SetActiveGuide(g.id)
                    ns.Core.selectedStepIndex = 1
                end
                self:Hide()
                StudioFrame:Refresh()
                if ns.UI.LiveHUD then
                    ns.UI.LiveHUD:Refresh()
                end
            end)
            btn:Show()
        end

        for i = count + 1, #self.rows do
            self.rows[i]:Hide()
        end
    end

    return menu
end

function StudioFrame:CreateExportModal(parent)
    local modal = CreateFrame("Frame", nil, parent, Theme:GetBackdropTemplate())
    modal:SetSize(680, 480)
    modal:SetPoint("CENTER", parent, "CENTER", 0, 0)
    modal:SetFrameStrata("DIALOG")
    modal:SetFrameLevel(parent:GetFrameLevel() + 40)
    modal:EnableMouse(true)
    Theme:ApplyBackdrop(modal, Theme.Colors.bgPrimary, Theme.Colors.borderAccentGold)
    modal:Hide()

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", modal, "TOPLEFT", 12, -10)
    title:SetText("|cffF59E0BEXPORT / IMPORT RXP GUIDE SCRIPT|r")

    local closeBtn = Theme:CreateTextButton(modal, "[Close]", 64, 22, "danger", function()
        modal:Hide()
    end)
    closeBtn:SetPoint("TOPRIGHT", modal, "TOPRIGHT", -10, -8)

    local subText = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    subText:SetText("Copy compiled RXPGuides.RegisterGuide([[...]]) Lua code below, or paste an existing RXP guide script to import into visual cards.")

    local codeBox = Theme:CreateEditBox(modal, 656, 376, true)
    codeBox:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -8)
    codeBox:SetPoint("BOTTOMRIGHT", modal, "BOTTOMRIGHT", -12, 42)
    modal.codeBox = codeBox

    local selectAllBtn = Theme:CreateTextButton(modal, "[Highlight All for Copy]", 164, 24, "primary", function()
        if codeBox.editBox then
            codeBox.editBox:SetFocus()
            if codeBox.editBox.HighlightText then
                codeBox.editBox:HighlightText()
            end
        end
    end)
    selectAllBtn:SetPoint("BOTTOMLEFT", modal, "BOTTOMLEFT", 12, 10)

    local importOverwriteBtn = Theme:CreateTextButton(modal, "[Import Text as New Guide]", 188, 24, "success", function()
        local raw = codeBox:GetText()
        if not raw or not raw:match("%S") then
            return
        end
        -- Strip outer RegisterGuide wrapper if pasted directly from a guide .lua file
        local inner = raw:match("RegisterGuide%(%s*%[=*%[(.-)%]=*%]") or raw
        if ns.Compiler and ns.Compiler.ParseGuideText then
            local parsedGuide = ns.Compiler:ParseGuideText(inner)
            if parsedGuide and ns.Core then
                local createdGuide = parsedGuide
                if type(ns.Core.CreateGuide) == "function" then
                    createdGuide = ns.Core:CreateGuide(parsedGuide)
                elseif RXP_StudioDB and type(RXP_StudioDB.guides) == "table" then
                    table.insert(RXP_StudioDB.guides, parsedGuide)
                end
                if createdGuide and createdGuide.id and ns.Core.SetActiveGuide then
                    ns.Core:SetActiveGuide(createdGuide.id)
                end
                ns.Core.selectedStepIndex = 1
                ns:FireCallback("GUIDE_UPDATED", createdGuide)
                modal:Hide()
                self:Refresh()
            end
        end
    end)
    importOverwriteBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 8, 0)

    function modal:OpenWithGuide(guide)
        local body = ""
        if guide and ns.Compiler and ns.Compiler.CompileGuide then
            local rawGuide = ns.Compiler:CompileGuide(guide, false) or ""
            body = "local RXPGuides = _G.RXPGuides\nif not RXPGuides then return end\n\nRXPGuides.RegisterGuide([[\n" .. rawGuide .. "\n]])"
        end
        self.codeBox:SetText(body)
        self:Show()
        if self.codeBox.editBox then
            self.codeBox.editBox:SetFocus()
            if self.codeBox.editBox.HighlightText then
                self.codeBox.editBox:HighlightText()
            end
        end
    end

    return modal
end

function StudioFrame:CreateTimelineCardRow(parent, rowIdx)
    local row = CreateFrame("Button", nil, parent, Theme:GetBackdropTemplate())
    row:SetHeight(TIMELINE_CARD_HEIGHT)
    Theme:ApplyBackdrop(row, Theme.Colors.bgCard, Theme.Colors.borderDefault)

    local stepHeader = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stepHeader:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -5)
    stepHeader:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    stepHeader:SetJustifyH("LEFT")
    stepHeader:SetWordWrap(false)
    row.stepHeader = stepHeader

    local actionLine1 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    actionLine1:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -19)
    actionLine1:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    actionLine1:SetJustifyH("LEFT")
    actionLine1:SetWordWrap(false)
    row.actionLine1 = actionLine1

    local actionLine2 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    actionLine2:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -31)
    actionLine2:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    actionLine2:SetJustifyH("LEFT")
    actionLine2:SetWordWrap(false)
    row.actionLine2 = actionLine2

    local warnLine = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    warnLine:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -45)
    warnLine:SetPoint("RIGHT", row, "RIGHT", -68, 0)
    warnLine:SetJustifyH("LEFT")
    warnLine:SetWordWrap(false)
    row.warnLine = warnLine

    local fixBtn = Theme:CreateTextButton(row, "[Auto-Fix]", 58, 16, "gold", function()
        local guide = ns.Core and ns.Core:GetActiveGuide()
        local card = row.cardData
        if guide and card and card.lintIssues and card.lintIssues[1] and ns.Linter and ns.Linter.ApplyFix then
            ns.Linter:ApplyFix(guide, card.lintIssues[1])
            ns:FireCallback("GUIDE_UPDATED", guide)
            self:Refresh()
        end
    end)
    fixBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -43)
    row.fixBtn = fixBtn

    -- Row Bottom Action Controls: [Up] [Down] [Merge Down] [Split] [Del]
    local btnUp = Theme:CreateTextButton(row, "[Up]", 32, 16, "subtle", function()
        local guide = ns.Core and ns.Core:GetActiveGuide()
        local idx = row.stepIndex
        if guide and idx and idx > 1 and ns.Core and ns.Core.MoveStepCard then
            ns.Core:MoveStepCard(guide, idx, idx - 1)
            self:SelectStep(idx - 1)
        end
    end)
    btnUp:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 4, 4)
    row.btnUp = btnUp

    local btnDown = Theme:CreateTextButton(row, "[Down]", 42, 16, "subtle", function()
        local guide = ns.Core and ns.Core:GetActiveGuide()
        local idx = row.stepIndex
        if guide and guide.steps and idx and idx < #guide.steps and ns.Core and ns.Core.MoveStepCard then
            ns.Core:MoveStepCard(guide, idx, idx + 1)
            self:SelectStep(idx + 1)
        end
    end)
    btnDown:SetPoint("LEFT", btnUp, "RIGHT", 3, 0)
    row.btnDown = btnDown

    local btnMerge = Theme:CreateTextButton(row, "[Merge Down]", 74, 16, "primary", function()
        local guide = ns.Core and ns.Core:GetActiveGuide()
        local idx = row.stepIndex
        if guide and guide.steps and idx and idx < #guide.steps and ns.AutoMerger and ns.AutoMerger.MergeAdjacentCards then
            ns.AutoMerger:MergeAdjacentCards(guide, idx, idx + 1)
            self:SelectStep(idx)
        end
    end)
    btnMerge:SetPoint("LEFT", btnDown, "RIGHT", 3, 0)
    row.btnMerge = btnMerge

    local btnSplit = Theme:CreateTextButton(row, "[Split]", 42, 16, "gold", function()
        local guide = ns.Core and ns.Core:GetActiveGuide()
        local idx = row.stepIndex
        if guide and idx and ns.AutoMerger and ns.AutoMerger.SplitCard then
            ns.AutoMerger:SplitCard(guide, idx)
            self:Refresh()
        end
    end)
    btnSplit:SetPoint("LEFT", btnMerge, "RIGHT", 3, 0)
    row.btnSplit = btnSplit

    local btnDel = Theme:CreateTextButton(row, "[Del]", 36, 16, "danger", function()
        local guide = ns.Core and ns.Core:GetActiveGuide()
        local idx = row.stepIndex
        if guide and idx and ns.Core and ns.Core.RemoveStepCard then
            ns.Core:RemoveStepCard(guide, idx)
            self:SelectStep(math.max(1, idx - 1))
        end
    end)
    btnDel:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 4)
    row.btnDel = btnDel

    row:SetScript("OnClick", function(btn)
        if btn.stepIndex then
            self:SelectStep(btn.stepIndex)
        end
    end)

    row.rowIdx = rowIdx
    return row
end

function StudioFrame:Init()
    if self.frame or not CreateFrame then
        return self.frame
    end

    local f = CreateFrame("Frame", "RXPStudioMainFrame", UIParent, Theme:GetBackdropTemplate())
    f:SetSize(STUDIO_WIDTH, STUDIO_HEIGHT)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(frame)
        frame:StartMoving()
    end)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
    end)
    f:Hide()

    if _G.UISpecialFrames then
        local found = false
        for i = 1, #_G.UISpecialFrames do
            if _G.UISpecialFrames[i] == "RXPStudioMainFrame" then
                found = true
                break
            end
        end
        if not found then
            table.insert(_G.UISpecialFrames, "RXPStudioMainFrame")
        end
    end

    Theme:ApplyBackdrop(f, Theme.Colors.bgPrimary, Theme.Colors.borderDefault)
    self.frame = f
    self.timelineRows = {}

    -- =========================================================================
    -- TOP HEADER BAR (Row 1: Title, Guide Selector, New/Import, Route Health)
    -- =========================================================================
    local topBar = CreateFrame("Frame", nil, f, Theme:GetBackdropTemplate())
    topBar:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
    topBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    topBar:SetHeight(64)
    Theme:ApplyBackdrop(topBar, Theme.Colors.bgSecondary, Theme.Colors.borderDefault)
    f.topBar = topBar

    local brandIcon = topBar:CreateTexture(nil, "ARTWORK")
    brandIcon:SetSize(22, 22)
    brandIcon:SetPoint("TOPLEFT", topBar, "TOPLEFT", 10, -6)
    if brandIcon.SetTexture then
        brandIcon:SetTexture(Theme.STUDIO_ICON)
    end
    self.brandIcon = brandIcon

    local brandTitle = topBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    brandTitle:SetPoint("LEFT", brandIcon, "RIGHT", 6, 0)
    brandTitle:SetText("|cff3B82F6RXP GUIDE STUDIO|r")

    local guideDropdownBtn = Theme:CreateTextButton(topBar, "[Guide: Select]", 210, 22, "subtle", function(_, mouseButton)
        if mouseButton == "RightButton" then
            self:CycleActiveGuide(false)
            return
        end
        if self.guideMenu:IsShown() then
            self.guideMenu:Hide()
        else
            self.guideMenu:Populate()
            self.guideMenu:Show()
        end
    end)
    guideDropdownBtn:SetPoint("LEFT", brandTitle, "RIGHT", 12, 0)
    self.guideDropdownBtn = guideDropdownBtn

    local newGuideBtn = Theme:CreateTextButton(topBar, "[+ New Guide]", 90, 22, "subtle", function()
        if ns.Core and ns.Core.CreateGuide then
            local g = ns.Core:CreateGuide({
                name = "New Speedrun Guide",
                group = "My Recorded Guides",
            })
            if g and ns.Core.SetActiveGuide then
                ns.Core:SetActiveGuide(g.id)
                ns.Core.selectedStepIndex = 1
            end
            self:Refresh()
        end
    end)
    newGuideBtn:SetPoint("LEFT", guideDropdownBtn, "RIGHT", 4, 0)

    local importLegacyBtn = Theme:CreateTextButton(topBar, "[Import RXP_RecorderDB]", 146, 22, "subtle", function()
        if ns.Core and ns.Core.ImportLegacyRecorderDB then
            local count = ns.Core:ImportLegacyRecorderDB()
            ns:Print("Imported " .. tostring(count or 0) .. " guide run(s) from RXP_RecorderDB.")
            self:Refresh()
        end
    end)
    importLegacyBtn:SetPoint("LEFT", newGuideBtn, "RIGHT", 4, 0)

    local closeWinBtn = Theme:CreateTextButton(topBar, "[X]", 26, 22, "danger", function()
        f:Hide()
    end)
    closeWinBtn:SetPoint("TOPRIGHT", topBar, "TOPRIGHT", -6, -6)

    -- Route Health Pill + [Auto-Fix All]
    local autoFixHeaderBtn = Theme:CreateTextButton(topBar, "[Auto-Fix All]", 86, 22, "gold", function()
        local guide = ns.Core and ns.Core:GetActiveGuide()
        if guide and ns.Linter and ns.Linter.ApplyAllFixes then
            ns.Linter:ApplyAllFixes(guide)
            ns:FireCallback("GUIDE_UPDATED", guide)
            self:Refresh()
        end
    end)
    autoFixHeaderBtn:SetPoint("RIGHT", closeWinBtn, "LEFT", -6, 0)
    self.autoFixHeaderBtn = autoFixHeaderBtn

    local healthPill = Theme:CreateTextButton(topBar, "|cff10B981[OK: 0 Steps Validated]|r", 174, 22, "subtle", function()
        local guide = ns.Core and ns.Core:GetActiveGuide()
        if not guide or not ns.Linter or not ns.Linter.InspectGuide then return end
        local issues = ns.Linter:InspectGuide(guide)
        if issues and #issues > 0 and issues[1].stepIndex then
            self:SelectStep(issues[1].stepIndex)
        end
    end)
    healthPill:SetPoint("RIGHT", autoFixHeaderBtn, "LEFT", -4, 0)
    self.healthPill = healthPill

    -- Top Header Row 2: Editable Guide Name & Group + Primary Action Bar
    local nameLabel = topBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameLabel:SetPoint("BOTTOMLEFT", topBar, "BOTTOMLEFT", 10, 10)
    nameLabel:SetText("Guide Name:")

    local guideNameBox = Theme:CreateEditBox(topBar, 195, 20, false, function(txt, userInput)
        if not userInput or self._isRefreshing then return end
        local guide = ns.Core and ns.Core:GetActiveGuide()
        if guide then
            guide.name = txt
            guide.displayName = txt
            self.guideDropdownBtn:SetButtonText("[Guide: " .. tostring(guide.name or "Untitled") .. "]")
        end
    end, function(txt)
        if self._isRefreshing then return end
        local guide = ns.Core and ns.Core:GetActiveGuide()
        if guide then
            guide.name = txt
            guide.displayName = txt
            ns:FireCallback("GUIDE_UPDATED", guide)
        end
    end)
    guideNameBox:SetPoint("LEFT", nameLabel, "RIGHT", 6, 0)
    self.guideNameBox = guideNameBox

    local groupLabel = topBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    groupLabel:SetPoint("LEFT", guideNameBox, "RIGHT", 10, 0)
    groupLabel:SetText("Group:")

    local guideGroupBox = Theme:CreateEditBox(topBar, 150, 20, false, function(txt, userInput)
        if not userInput or self._isRefreshing then return end
        local guide = ns.Core and ns.Core:GetActiveGuide()
        if guide then
            guide.group = txt
        end
    end, function(txt)
        if self._isRefreshing then return end
        local guide = ns.Core and ns.Core:GetActiveGuide()
        if guide then
            guide.group = txt
            ns:FireCallback("GUIDE_UPDATED", guide)
        end
    end)
    guideGroupBox:SetPoint("LEFT", groupLabel, "RIGHT", 6, 0)
    self.guideGroupBox = guideGroupBox

    -- Primary Action Buttons on Row 2 Right
    local exportImportBtn = Theme:CreateTextButton(topBar, "[Export / Import]", 116, 22, "subtle", function()
        local guide = ns.Core and ns.Core:GetActiveGuide()
        self.exportModal:OpenWithGuide(guide)
    end)
    exportImportBtn:SetPoint("BOTTOMRIGHT", topBar, "BOTTOMRIGHT", -6, 6)
    self.exportImportBtn = exportImportBtn

    local rawSyntaxBtn = Theme:CreateTextButton(topBar, "[Raw Syntax: OFF]", 122, 22, "subtle", function(btn)
        if RXP_StudioDB and RXP_StudioDB.settings then
            RXP_StudioDB.settings.rawSyntaxMode = not RXP_StudioDB.settings.rawSyntaxMode
            if RXP_StudioDB.settings.rawSyntaxMode then
                btn:SetButtonText("[Raw Syntax: |cff10B981ON|r]")
                btn:SetButtonStyle("gold")
            else
                btn:SetButtonText("[Raw Syntax: |cff9CA3AFOFF|r]")
                btn:SetButtonStyle("subtle")
            end
        end
        if ns.UI.CardInspector then
            ns.UI.CardInspector:Refresh()
        end
    end)
    rawSyntaxBtn:SetPoint("RIGHT", exportImportBtn, "LEFT", -6, 0)
    self.rawSyntaxBtn = rawSyntaxBtn

    local testLiveBtn = Theme:CreateTextButton(topBar, "[Test Live in RXP]", 134, 22, "success", function()
        local guide = ns.Core and ns.Core:GetActiveGuide()
        if not guide then return end
        local stepIdx = self:GetSelectedStepIndex(guide) or 1
        if ns.Bridge and ns.Bridge.SyncGuideToRXP then
            local ok, res = ns.Bridge:SyncGuideToRXP(guide, stepIdx)
            if ok then
                ns:Print(string.format("Synced '%s' to RXPGuides at Step #%d.", tostring(guide.name), stepIdx))
            else
                ns:Print("|cffEF4444Sync failed:|r " .. tostring(res))
            end
        end
    end)
    testLiveBtn:SetPoint("RIGHT", rawSyntaxBtn, "LEFT", -6, 0)
    self.testLiveBtn = testLiveBtn

    -- =========================================================================
    -- 3-COLUMN WORKSPACE LAYOUT
    -- =========================================================================
    -- Left Column (300px wide): Visual Step Timeline
    local leftCol = CreateFrame("Frame", nil, f, Theme:GetBackdropTemplate())
    leftCol:SetPoint("TOPLEFT", topBar, "BOTTOMLEFT", 0, -6)
    leftCol:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 6, 6)
    leftCol:SetWidth(LEFT_COL_WIDTH)
    Theme:ApplyBackdrop(leftCol, Theme.Colors.bgSecondary, Theme.Colors.borderDefault)
    self.leftCol = leftCol

    local timelineHeader = CreateFrame("Frame", nil, leftCol, Theme:GetBackdropTemplate())
    timelineHeader:SetPoint("TOPLEFT", leftCol, "TOPLEFT", 4, -4)
    timelineHeader:SetPoint("TOPRIGHT", leftCol, "TOPRIGHT", -4, -4)
    timelineHeader:SetHeight(26)
    Theme:ApplyBackdrop(timelineHeader, Theme.Colors.bgPrimary, Theme.Colors.borderDefault)

    local timelineTitle = timelineHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timelineTitle:SetPoint("LEFT", timelineHeader, "LEFT", 8, 0)
    timelineTitle:SetText("|cff10B981VISUAL STEP TIMELINE|r")
    self.timelineTitle = timelineTitle

    local timelineScroll = Theme:CreateScrollList(leftCol, LEFT_COL_WIDTH - 8, 480)
    timelineScroll:SetPoint("TOPLEFT", timelineHeader, "BOTTOMLEFT", 0, -4)
    timelineScroll:SetPoint("BOTTOMRIGHT", leftCol, "BOTTOMRIGHT", -4, 34)
    self.timelineScroll = timelineScroll

    -- Bottom Timeline Bar: [+ Add Step], [Auto-Merge All], [Auto-Fix All Issues]
    local timelineBottomBar = CreateFrame("Frame", nil, leftCol)
    timelineBottomBar:SetPoint("BOTTOMLEFT", leftCol, "BOTTOMLEFT", 4, 4)
    timelineBottomBar:SetPoint("BOTTOMRIGHT", leftCol, "BOTTOMRIGHT", -4, 4)
    timelineBottomBar:SetHeight(26)

    local addStepBtn = Theme:CreateTextButton(timelineBottomBar, "[+ Add Step]", 82, 22, "success", function()
        local guide = ns.Core and ns.Core:GetActiveGuide()
        if not guide or not ns.Core or not ns.Core.AddStepCard then return end
        local z, px, py = "Durotar", 50.0, 50.0
        if ns.Recorder and ns.Recorder.GetPlayerLocation then
            local rz, rx, ry = ns.Recorder:GetPlayerLocation()
            if rz then z = rz end
            if rx then px = tonumber(string.format("%.2f", rx)) end
            if ry then py = tonumber(string.format("%.2f", ry)) end
        end
        local insertIdx = (self:GetSelectedStepIndex(guide) or #guide.steps) + 1
        ns.Core:AddStepCard(guide, {
            zone = z,
            x = px,
            y = py,
            targets = {},
            actions = {
                { type = "note", text = "New step objective" },
            },
        }, insertIdx)
        self:SelectStep(insertIdx)
    end)
    addStepBtn:SetPoint("LEFT", timelineBottomBar, "LEFT", 0, 0)

    local autoMergeAllBtn = Theme:CreateTextButton(timelineBottomBar, "[Auto-Merge All]", 98, 22, "primary", function()
        local guide = ns.Core and ns.Core:GetActiveGuide()
        if guide and ns.AutoMerger and ns.AutoMerger.MergeGuideSteps then
            local merged = ns.AutoMerger:MergeGuideSteps(guide)
            ns:Print("Auto-merged " .. tostring(merged or 0) .. " adjacent step card(s).")
            ns:FireCallback("GUIDE_UPDATED", guide)
            self:Refresh()
        end
    end)
    autoMergeAllBtn:SetPoint("LEFT", addStepBtn, "RIGHT", 4, 0)

    local autoFixBottomBtn = Theme:CreateTextButton(timelineBottomBar, "[Auto-Fix All Issues]", 104, 22, "gold", function()
        local guide = ns.Core and ns.Core:GetActiveGuide()
        if guide and ns.Linter and ns.Linter.ApplyAllFixes then
            ns.Linter:ApplyAllFixes(guide)
            ns:FireCallback("GUIDE_UPDATED", guide)
            self:Refresh()
        end
    end)
    autoFixBottomBtn:SetPoint("RIGHT", timelineBottomBar, "RIGHT", 0, 0)

    -- Center Column (360px wide): Card Inspector
    local centerCol = CreateFrame("Frame", nil, f)
    centerCol:SetPoint("TOPLEFT", leftCol, "TOPRIGHT", 6, 0)
    centerCol:SetPoint("BOTTOMLEFT", leftCol, "BOTTOMRIGHT", 6, 0)
    centerCol:SetWidth(CENTER_COL_WIDTH)
    self.centerCol = centerCol

    if ns.UI.CardInspector and ns.UI.CardInspector.Create then
        ns.UI.CardInspector:Create(centerCol)
    end

    -- Right Column (300px wide): Map Preview
    local rightCol = CreateFrame("Frame", nil, f)
    rightCol:SetPoint("TOPLEFT", centerCol, "TOPRIGHT", 6, 0)
    rightCol:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)
    rightCol:SetWidth(RIGHT_COL_WIDTH)
    self.rightCol = rightCol

    if ns.UI.MapPreview and ns.UI.MapPreview.Create then
        ns.UI.MapPreview:Create(rightCol)
    end

    -- Guide Selector Dropdown & Export/Import Modal
    self.guideMenu = self:CreateGuideDropdownMenu(topBar)
    self.guideMenu:SetPoint("TOPLEFT", guideDropdownBtn, "BOTTOMLEFT", 0, -2)

    self.exportModal = self:CreateExportModal(f)

    self:Refresh()
    return f
end

function StudioFrame:RefreshTimeline(guide, selectedIdx)
    if not self.timelineScroll then
        return
    end
    local steps = (guide and guide.steps) or {}
    local content = self.timelineScroll.content

    for i = 1, #steps do
        local card = steps[i]
        local row = self.timelineRows[i]
        if not row then
            row = self:CreateTimelineCardRow(content, i)
            self.timelineRows[i] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -2 - ((i - 1) * (TIMELINE_CARD_HEIGHT + 4)))
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", -2, -2 - ((i - 1) * (TIMELINE_CARD_HEIGHT + 4)))
        row.stepIndex = i
        row.cardData = card

        local isSelected = (i == selectedIdx)
        local hasIssues = card.lintIssues and #card.lintIssues > 0

        if isSelected then
            Theme:ApplyBackdrop(row, Theme.Colors.bgCardActive, Theme.Colors.borderAccentGold)
        elseif hasIssues then
            Theme:ApplyBackdrop(row, Theme.Colors.bgCard, Theme.Colors.borderWarning)
        else
            Theme:ApplyBackdrop(row, Theme.Colors.bgCard, Theme.Colors.borderDefault)
        end

        local locStr = card.zone or "No Zone"
        if card.x and card.y then
            locStr = string.format("%s %.1f, %.1f", locStr, tonumber(card.x) or 0, tonumber(card.y) or 0)
        end
        local npcStr = (card.targets and #card.targets > 0) and (" |cff60A5FA@" .. card.targets[1] .. "|r") or ""
        local flagsStr = ""
        if card.sticky then flagsStr = flagsStr .. " |cff10B981[STICKY]|r" end
        if card.loop then flagsStr = flagsStr .. " |cffEAB308[LOOP]|r" end

        row.stepHeader:SetText(string.format("|cffF59E0B#%d|r |cffF3F4F6%s|r%s%s", i, locStr, npcStr, flagsStr))

        local actions = card.actions or {}
        if actions[1] then
            row.actionLine1:SetText(Theme:FormatActionLine(actions[1]))
        elseif card.note and card.note ~= "" then
            row.actionLine1:SetText(Theme:GetActionBadge("note") .. " " .. tostring(card.note))
        else
            row.actionLine1:SetText("|cff9CA3AF[WAYPOINT] Travel / Pin|r")
        end

        if actions[2] then
            local suffix = (#actions > 2) and string.format(" |cff9CA3AF(+%d more)|r", #actions - 2) or ""
            row.actionLine2:SetText(Theme:FormatActionLine(actions[2]) .. suffix)
            row.actionLine2:Show()
        else
            row.actionLine2:SetText("")
            row.actionLine2:Hide()
        end

        if hasIssues then
            local firstIssue = card.lintIssues[1]
            row.warnLine:SetText(Theme:GetStatusBadge("WARN") .. " |cffF59E0B" .. tostring(firstIssue.message or firstIssue.code or "Route issue") .. "|r")
            row.warnLine:Show()
            row.fixBtn:Show()
        else
            row.warnLine:SetText("")
            row.warnLine:Hide()
            row.fixBtn:Hide()
        end

        if #actions > 1 then
            row.btnSplit:Show()
        else
            row.btnSplit:Hide()
        end

        if i < #steps then
            row.btnMerge:Show()
        else
            row.btnMerge:Hide()
        end

        row:Show()
    end

    for i = #steps + 1, #self.timelineRows do
        self.timelineRows[i]:Hide()
    end

    self.timelineScroll:SetContentHeight(math.max(60, #steps * (TIMELINE_CARD_HEIGHT + 4) + 8))
end

function StudioFrame:Refresh()
    if not self.frame then
        return
    end

    local guide = ns.Core and ns.Core:GetActiveGuide()
    local issues = {}
    if guide and ns.Linter and ns.Linter.InspectGuide then
        issues = ns.Linter:InspectGuide(guide) or {}
    end

    self._isRefreshing = true
    if guide then
        self.guideDropdownBtn:SetButtonText("[Guide: " .. tostring(guide.name or "Untitled") .. "]")
        if not self.guideNameBox:HasFocus() then
            self.guideNameBox:SetText(guide.name or "")
        end
        if not self.guideGroupBox:HasFocus() then
            self.guideGroupBox:SetText(guide.group or "My Recorded Guides")
        end
    else
        self.guideDropdownBtn:SetButtonText("[Guide: None]")
        if not self.guideNameBox:HasFocus() then
            self.guideNameBox:SetText("")
        end
        if not self.guideGroupBox:HasFocus() then
            self.guideGroupBox:SetText("")
        end
    end
    self._isRefreshing = false

    local stepCount = (guide and guide.steps and #guide.steps) or 0
    self.timelineTitle:SetText(string.format("|cff10B981VISUAL STEP TIMELINE|r |cff9CA3AF(%d Steps)|r", stepCount))

    if #issues == 0 then
        self.healthPill:SetButtonText(string.format("|cff10B981[OK: %d Steps Validated]|r", stepCount))
        self.healthPill:SetButtonStyle("success")
        self.autoFixHeaderBtn:Hide()
    else
        self.healthPill:SetButtonText(string.format("|cffF59E0B[WARN: %d Issue(s)]|r", #issues))
        self.healthPill:SetButtonStyle("gold")
        self.autoFixHeaderBtn:Show()
    end

    local isRaw = RXP_StudioDB and RXP_StudioDB.settings and RXP_StudioDB.settings.rawSyntaxMode
    if isRaw then
        self.rawSyntaxBtn:SetButtonText("[Raw Syntax: |cff10B981ON|r]")
        self.rawSyntaxBtn:SetButtonStyle("gold")
    else
        self.rawSyntaxBtn:SetButtonText("[Raw Syntax: |cff9CA3AFOFF|r]")
        self.rawSyntaxBtn:SetButtonStyle("subtle")
    end

    local selectedIdx = self:GetSelectedStepIndex(guide)
    local selectedCard = (guide and guide.steps and selectedIdx) and guide.steps[selectedIdx] or nil

    self:RefreshTimeline(guide, selectedIdx)

    if ns.UI.CardInspector then
        ns.UI.CardInspector:SetCard(selectedCard, selectedIdx)
    end
    if ns.UI.MapPreview then
        ns.UI.MapPreview:SetCard(selectedCard, selectedIdx, guide)
    end
end

function StudioFrame:Toggle()
    if not self.frame then
        self:Init()
    end
    if not self.frame then
        return
    end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
        self:Refresh()
    end
end

-- =============================================================================
-- Top-Level ns.UI Controller & Callback Subscriptions
-- =============================================================================
function ns.UI:Init()
    if self._initialized then
        return
    end
    self._initialized = true

    if self.LiveHUD and self.LiveHUD.Init then
        self.LiveHUD:Init()
    end
    if self.StudioFrame and self.StudioFrame.Init then
        self.StudioFrame:Init()
    end

    ns:RegisterCallback("GUIDE_UPDATED", function()
        ns.UI:RefreshAll()
    end)

    ns:RegisterCallback("STEP_RECORDED", function(arg1, arg2, stepIndex)
        local guide = (type(arg1) == "table" and arg1.steps and arg1)
            or (type(arg2) == "table" and arg2.steps and arg2)
        if stepIndex and ns.Core then
            ns.Core.selectedStepIndex = stepIndex
        elseif guide and guide.steps and ns.Core then
            ns.Core.selectedStepIndex = #guide.steps
        end
        ns.UI:RefreshAll()
    end)

    ns:RegisterCallback("GUIDE_SYNCED_TO_RXP", function()
        if ns.UI.LiveHUD and ns.UI.LiveHUD.Refresh then
            ns.UI.LiveHUD:Refresh()
        end
    end)
end

function ns.UI:RefreshAll()
    if self.LiveHUD and self.LiveHUD.Refresh then
        self.LiveHUD:Refresh()
    end
    if self.StudioFrame and self.StudioFrame.frame and self.StudioFrame.frame:IsShown() then
        self.StudioFrame:Refresh()
    end
end

function ns.UI:ToggleStudio()
    if self.StudioFrame and self.StudioFrame.Toggle then
        self.StudioFrame:Toggle()
    end
end

function ns.UI:ToggleHUD()
    if self.LiveHUD and self.LiveHUD.Toggle then
        self.LiveHUD:Toggle()
    end
end
