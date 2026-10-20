local _, ns = ...
ns.UI = ns.UI or {}

local Theme = ns.UI.Theme
local LiveHUD = {}
ns.UI.LiveHUD = LiveHUD

local HUD_WIDTH = 360
local HUD_HEIGHT = 290
local MAX_FEED_CARDS = 3
local MAX_ACTION_LINES = 4

function LiveHUD:IsRecorderActive()
    if ns.Recorder then
        if type(ns.Recorder.IsRecording) == "function" then
            return ns.Recorder:IsRecording()
        end
        if ns.Recorder.isRecording ~= nil then
            return ns.Recorder.isRecording
        end
    end
    return true
end

function LiveHUD:ToggleRecording()
    local nextState = not self:IsRecorderActive()
    if ns.Recorder then
        if type(ns.Recorder.SetRecording) == "function" then
            ns.Recorder:SetRecording(nextState)
        else
            ns.Recorder.isRecording = nextState
        end
    end
    self:Refresh()
end

function LiveHUD:AnchorDefaultPosition()
    if not self.frame then
        return
    end
    self.frame:ClearAllPoints()
    local rxpFrame = _G.RXPFrame
    if rxpFrame and rxpFrame.IsShown and rxpFrame:IsShown() then
        self.frame:SetPoint("TOPLEFT", rxpFrame, "TOPRIGHT", 8, 0)
    else
        self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24, -140)
    end
end

function LiveHUD:CreateCardSlot(parent, slotIndex)
    local cardFrame = CreateFrame("Button", nil, parent, Theme:GetBackdropTemplate())
    cardFrame:SetHeight(64)
    Theme:ApplyBackdrop(cardFrame, Theme.Colors.bgCard, Theme.Colors.borderDefault)

    local headerText = cardFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerText:SetPoint("TOPLEFT", cardFrame, "TOPLEFT", 6, -5)
    headerText:SetPoint("RIGHT", cardFrame, "RIGHT", -124, 0)
    headerText:SetJustifyH("LEFT")
    headerText:SetWordWrap(false)
    cardFrame.headerText = headerText

    local stickyBtn = Theme:CreateTextButton(cardFrame, "[Sticky: OFF]", 74, 16, "subtle", function()
        local guide = ns.Core and ns.Core:GetActiveGuide()
        local idx = cardFrame.stepIndex
        if guide and guide.steps and idx and guide.steps[idx] then
            local c = guide.steps[idx]
            c.sticky = not c.sticky
            ns:FireCallback("GUIDE_UPDATED", guide)
        end
    end)
    stickyBtn:SetPoint("TOPRIGHT", cardFrame, "TOPRIGHT", -4, -3)
    cardFrame.stickyBtn = stickyBtn

    local splitBtn = Theme:CreateTextButton(cardFrame, "[Split]", 44, 16, "gold", function()
        local guide = ns.Core and ns.Core:GetActiveGuide()
        local idx = cardFrame.stepIndex
        if guide and idx and ns.AutoMerger and ns.AutoMerger.SplitCard then
            ns.AutoMerger:SplitCard(guide, idx)
            self:Refresh()
        end
    end)
    splitBtn:SetPoint("RIGHT", stickyBtn, "LEFT", -3, 0)
    cardFrame.splitBtn = splitBtn

    cardFrame.actionLines = {}
    for i = 1, MAX_ACTION_LINES do
        local line = cardFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        line:SetPoint("TOPLEFT", cardFrame, "TOPLEFT", 8, -19 - ((i - 1) * 11))
        line:SetPoint("RIGHT", cardFrame, "RIGHT", -6, 0)
        line:SetJustifyH("LEFT")
        line:SetWordWrap(false)
        cardFrame.actionLines[i] = line
    end

    cardFrame:SetScript("OnClick", function(btn)
        if btn.stepIndex and ns.Core then
            ns.Core.selectedStepIndex = btn.stepIndex
            if ns.UI and ns.UI.StudioFrame and ns.UI.StudioFrame.SelectStep then
                ns.UI.StudioFrame:SelectStep(btn.stepIndex)
            end
        end
    end)

    cardFrame.slotIndex = slotIndex
    return cardFrame
end

function LiveHUD:Init()
    if self.frame or not CreateFrame then
        return self.frame
    end

    local f = CreateFrame("Frame", "RXPStudioLiveHUD", UIParent, Theme:GetBackdropTemplate())
    f:SetSize(HUD_WIDTH, HUD_HEIGHT)
    f:SetFrameStrata("MEDIUM")
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

    Theme:ApplyBackdrop(f, Theme.Colors.bgPrimary, Theme.Colors.borderDefault)
    self.frame = f
    self:AnchorDefaultPosition()

    -- Top Header Bar
    local headerBar = CreateFrame("Frame", nil, f, Theme:GetBackdropTemplate())
    headerBar:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    headerBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    headerBar:SetHeight(28)
    Theme:ApplyBackdrop(headerBar, Theme.Colors.bgSecondary, Theme.Colors.borderDefault)
    f.headerBar = headerBar

    local hudIcon = headerBar:CreateTexture(nil, "ARTWORK")
    hudIcon:SetSize(20, 20)
    hudIcon:SetPoint("LEFT", headerBar, "LEFT", 4, 0)
    if hudIcon.SetTexture then
        hudIcon:SetTexture(Theme.STUDIO_ICON)
    end
    f.hudIcon = hudIcon

    local statusPill = Theme:CreateTextButton(headerBar, "|cffEF4444[REC]|r Guide", 168, 20, "subtle", function()
        self:ToggleRecording()
    end)
    statusPill:SetPoint("LEFT", hudIcon, "RIGHT", 4, 0)
    statusPill.label:ClearAllPoints()
    statusPill.label:SetPoint("LEFT", statusPill, "LEFT", 6, 0)
    statusPill.label:SetPoint("RIGHT", statusPill, "RIGHT", -4, 0)
    statusPill.label:SetJustifyH("LEFT")
    f.statusPill = statusPill

    local openStudioBtn = Theme:CreateTextButton(headerBar, "[Open Studio]", 86, 20, "primary", function()
        if ns.UI and ns.UI.ToggleStudio then
            ns.UI:ToggleStudio()
        end
    end)
    openStudioBtn:SetPoint("RIGHT", headerBar, "RIGHT", -4, 0)
    f.openStudioBtn = openStudioBtn

    local pauseBtn = Theme:CreateTextButton(headerBar, "[Pause]", 62, 20, "gold", function()
        self:ToggleRecording()
    end)
    pauseBtn:SetPoint("RIGHT", openStudioBtn, "LEFT", -4, 0)
    f.pauseBtn = pauseBtn

    -- Center Live Card Feed
    local feedContainer = CreateFrame("Frame", nil, f, Theme:GetBackdropTemplate())
    feedContainer:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -4)
    feedContainer:SetPoint("TOPRIGHT", headerBar, "BOTTOMRIGHT", 0, -4)
    feedContainer:SetHeight(216)
    Theme:ApplyBackdrop(feedContainer, Theme.Colors.bgSecondary, Theme.Colors.borderDefault)
    f.feedContainer = feedContainer

    local emptyText = feedContainer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("CENTER", feedContainer, "CENTER", 0, 0)
    emptyText:SetText("No steps recorded yet.\nAccept or complete a quest in-game to capture steps.")
    f.emptyText = emptyText

    f.cardSlots = {}
    for i = 1, MAX_FEED_CARDS do
        local slot = self:CreateCardSlot(feedContainer, i)
        slot:SetPoint("TOPLEFT", feedContainer, "TOPLEFT", 4, -4 - ((i - 1) * 69))
        slot:SetPoint("TOPRIGHT", feedContainer, "TOPRIGHT", -4, -4 - ((i - 1) * 69))
        f.cardSlots[i] = slot
    end

    -- Inline Note Input Overlay (shown when [+Note] is clicked)
    local noteBar = CreateFrame("Frame", nil, feedContainer, Theme:GetBackdropTemplate())
    noteBar:SetPoint("BOTTOMLEFT", feedContainer, "BOTTOMLEFT", 4, 4)
    noteBar:SetPoint("BOTTOMRIGHT", feedContainer, "BOTTOMRIGHT", -4, 4)
    noteBar:SetHeight(28)
    noteBar:SetFrameLevel(feedContainer:GetFrameLevel() + 10)
    Theme:ApplyBackdrop(noteBar, Theme.Colors.bgPrimary, Theme.Colors.borderAccentBlue)
    noteBar:Hide()
    f.noteBar = noteBar

    local noteInput = Theme:CreateEditBox(noteBar, 240, 20, false)
    noteInput:SetPoint("LEFT", noteBar, "LEFT", 4, 0)
    f.noteInput = noteInput

    local function submitQuickNote()
        local txt = noteInput:GetText()
        if txt and txt:match("%S") then
            if ns.Recorder and ns.Recorder.RecordQuickNote then
                ns.Recorder:RecordQuickNote(txt)
            else
                local guide = ns.Core and ns.Core:GetActiveGuide()
                if guide and guide.steps and #guide.steps > 0 then
                    guide.steps[#guide.steps].note = txt
                    ns:FireCallback("GUIDE_UPDATED", guide)
                end
            end
        end
        noteInput:SetText("")
        noteInput:ClearFocus()
        noteBar:Hide()
        self:Refresh()
    end

    noteInput:SetScript("OnEnterPressed", submitQuickNote)

    local saveNoteBtn = Theme:CreateTextButton(noteBar, "[Save]", 48, 20, "success", submitQuickNote)
    saveNoteBtn:SetPoint("LEFT", noteInput, "RIGHT", 4, 0)

    local cancelNoteBtn = Theme:CreateTextButton(noteBar, "[X]", 26, 20, "danger", function()
        noteInput:SetText("")
        noteInput:ClearFocus()
        noteBar:Hide()
    end)
    cancelNoteBtn:SetPoint("LEFT", saveNoteBtn, "RIGHT", 3, 0)

    -- Bottom Quick-Action Bar (5 crisp text buttons)
    local actionBar = CreateFrame("Frame", nil, f, Theme:GetBackdropTemplate())
    actionBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 4, 4)
    actionBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    actionBar:SetHeight(30)
    Theme:ApplyBackdrop(actionBar, Theme.Colors.bgSecondary, Theme.Colors.borderDefault)
    f.actionBar = actionBar

    local btnNote = Theme:CreateTextButton(actionBar, "[+Note]", 58, 22, "subtle", function()
        if noteBar:IsShown() then
            noteBar:Hide()
        else
            noteBar:Show()
            noteInput:SetFocus()
        end
    end)
    btnNote:SetPoint("LEFT", actionBar, "LEFT", 4, 0)

    local btnGrind = Theme:CreateTextButton(actionBar, "[Grind XP]", 68, 22, "subtle", function()
        if ns.Recorder and ns.Recorder.RecordGrindXP then
            ns.Recorder:RecordGrindXP()
        end
        self:Refresh()
    end)
    btnGrind:SetPoint("LEFT", btnNote, "RIGHT", 4, 0)

    local btnHearth = Theme:CreateTextButton(actionBar, "[Hearth/Bind]", 84, 22, "subtle", function(_, mouseButton)
        local mode = (mouseButton == "RightButton") and "home" or "hs"
        if ns.Recorder then
            if ns.Recorder.RecordHearthOrBind then
                ns.Recorder:RecordHearthOrBind(mode)
            elseif mode == "home" and ns.Recorder.RecordBind then
                ns.Recorder:RecordBind()
            elseif ns.Recorder.RecordHearth then
                ns.Recorder:RecordHearth()
            end
        end
        self:Refresh()
    end)
    btnHearth:SetPoint("LEFT", btnGrind, "RIGHT", 4, 0)

    local btnDeathskip = Theme:CreateTextButton(actionBar, "[Deathskip]", 68, 22, "subtle", function()
        if ns.Recorder and ns.Recorder.RecordDeathskip then
            ns.Recorder:RecordDeathskip()
        end
        self:Refresh()
    end)
    btnDeathskip:SetPoint("LEFT", btnHearth, "RIGHT", 4, 0)

    local btnPinPos = Theme:CreateTextButton(actionBar, "[Pin Pos]", 56, 22, "subtle", function()
        if ns.Recorder and ns.Recorder.RecordWaypointPin then
            ns.Recorder:RecordWaypointPin()
        end
        self:Refresh()
    end)
    btnPinPos:SetPoint("LEFT", btnDeathskip, "RIGHT", 4, 0)

    if RXP_StudioDB and RXP_StudioDB.settings and RXP_StudioDB.settings.showHUD == false then
        f:Hide()
    else
        f:Show()
    end

    self:Refresh()
    return f
end

function LiveHUD:Refresh()
    if not self.frame then
        return
    end
    local f = self.frame
    local guide = ns.Core and ns.Core:GetActiveGuide()
    local guideName = (guide and guide.name) or "Untitled Guide"
    local isRec = self:IsRecorderActive()

    if isRec then
        f.statusPill:SetButtonText("|cffEF4444[REC]|r " .. guideName)
        f.pauseBtn:SetButtonText("[Pause]")
        f.pauseBtn:SetButtonStyle("gold")
    else
        f.statusPill:SetButtonText("|cff9CA3AF[PAUSED]|r " .. guideName)
        f.pauseBtn:SetButtonText("[Resume]")
        f.pauseBtn:SetButtonStyle("success")
    end

    local steps = (guide and guide.steps) or {}
    local total = #steps

    if total == 0 then
        f.emptyText:Show()
        for i = 1, MAX_FEED_CARDS do
            f.cardSlots[i]:Hide()
        end
        return
    end

    f.emptyText:Hide()
    local startIdx = math.max(1, total - MAX_FEED_CARDS + 1)
    local slotIdx = 1

    for stepIdx = startIdx, total do
        local card = steps[stepIdx]
        local slot = f.cardSlots[slotIdx]
        if slot and card then
            slot.stepIndex = stepIdx
            slot:Show()

            local isLatest = (stepIdx == total)
            if isLatest then
                Theme:ApplyBackdrop(slot, Theme.Colors.bgCardActive, Theme.Colors.borderAccentBlue)
            else
                Theme:ApplyBackdrop(slot, Theme.Colors.bgCard, Theme.Colors.borderDefault)
            end

            local locStr = ""
            if card.zone and card.zone ~= "" then
                if card.x and card.y then
                    locStr = string.format("%s (%.1f, %.1f)", card.zone, tonumber(card.x) or 0, tonumber(card.y) or 0)
                else
                    locStr = card.zone
                end
            end

            local npcStr = ""
            if card.targets and #card.targets > 0 then
                npcStr = " - " .. table.concat(card.targets, ", ")
            end

            slot.headerText:SetText(string.format("|cffF59E0BStep #%d|r |cffCBD5E1%s%s|r", stepIdx, locStr, npcStr))

            if card.sticky then
                slot.stickyBtn:SetButtonText("[Sticky: |cff10B981ON|r]")
            else
                slot.stickyBtn:SetButtonText("[Sticky: |cff9CA3AFOFF|r]")
            end

            local actions = card.actions or {}
            if #actions > 1 then
                slot.splitBtn:Show()
            else
                slot.splitBtn:Hide()
            end

            for lineIdx = 1, MAX_ACTION_LINES do
                local lineFs = slot.actionLines[lineIdx]
                local act = actions[lineIdx]
                if act then
                    if lineIdx == MAX_ACTION_LINES and #actions > MAX_ACTION_LINES then
                        local extra = #actions - MAX_ACTION_LINES + 1
                        lineFs:SetText(string.format("|cff9CA3AF+%d more action(s)...|r", extra))
                    else
                        lineFs:SetText(Theme:FormatActionLine(act))
                    end
                    lineFs:Show()
                elseif lineIdx == 1 and card.note and card.note ~= "" then
                    lineFs:SetText(Theme:GetActionBadge("note") .. " " .. tostring(card.note))
                    lineFs:Show()
                else
                    lineFs:SetText("")
                    lineFs:Hide()
                end
            end

            slotIdx = slotIdx + 1
        end
    end

    for i = slotIdx, MAX_FEED_CARDS do
        if f.cardSlots[i] then
            f.cardSlots[i]:Hide()
        end
    end
end

function LiveHUD:Toggle()
    if not self.frame then
        self:Init()
    end
    if not self.frame then
        return
    end
    if self.frame:IsShown() then
        self.frame:Hide()
        if RXP_StudioDB and RXP_StudioDB.settings then
            RXP_StudioDB.settings.showHUD = false
        end
    else
        self.frame:Show()
        if RXP_StudioDB and RXP_StudioDB.settings then
            RXP_StudioDB.settings.showHUD = true
        end
        self:Refresh()
    end
end
