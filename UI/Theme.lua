local _, ns = ...
ns.UI = ns.UI or {}

local Theme = {}
ns.UI.Theme = Theme

Theme.WHITE8X8 = "Interface\\Buttons\\WHITE8X8"
Theme.CLASS_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes"
Theme.STUDIO_ICON = "Interface\\AddOns\\RXP_Studio\\RXP_Studio_Icon"

Theme.Colors = {
    bgPrimary        = { 0.07, 0.08, 0.12, 0.96 }, -- #12151E
    bgSecondary      = { 0.11, 0.13, 0.17, 0.95 }, -- #1B202C
    bgCard           = { 0.13, 0.15, 0.21, 0.95 }, -- #212736
    bgCardActive     = { 0.15, 0.19, 0.28, 0.98 },
    bgInput          = { 0.05, 0.06, 0.09, 0.98 },
    bgHover          = { 0.18, 0.23, 0.32, 0.98 },
    borderDefault    = { 0.18, 0.21, 0.27, 1.00 }, -- #2E3646
    borderAccentGold = { 0.96, 0.62, 0.04, 1.00 }, -- #F59E0B
    borderAccentBlue = { 0.23, 0.51, 0.96, 1.00 }, -- #3B82F6
    borderWarning    = { 0.96, 0.62, 0.04, 1.00 },
    borderError      = { 0.94, 0.27, 0.27, 1.00 }, -- #EF4444
    borderSuccess    = { 0.06, 0.73, 0.51, 1.00 }, -- #10B981
    textPrimary      = { 0.95, 0.96, 0.98, 1.00 },
    textSecondary    = { 0.68, 0.73, 0.81, 1.00 },
    textMuted        = { 0.45, 0.50, 0.58, 1.00 },
}

Theme.Hex = {
    blue    = "3B82F6",
    green   = "10B981",
    gold    = "F59E0B",
    yellow  = "EAB308",
    red     = "EF4444",
    purple  = "A855F7",
    pink    = "EC4899",
    rose    = "F472B6",
    cyan    = "06B6D4",
    teal    = "14B8A6",
    sky     = "38BDF8",
    orange  = "FB923C",
    slate   = "94A3B8",
    light   = "CBD5E1",
    muted   = "9CA3AF",
    white   = "F3F4F6",
}

Theme.ActionBadges = {
    accept    = "|cff3B82F6[ACCEPT]|r",
    turnin    = "|cff10B981[TURN IN]|r",
    complete  = "|cffF59E0B[COMPLETE]|r",
    trainer   = "|cff06B6D4[TRAINER]|r",
    vendor    = "|cff14B8A6[VENDOR]|r",
    hs        = "|cffEC4899[HEARTH]|r",
    hearth    = "|cffEC4899[HEARTH]|r",
    home      = "|cffF472B6[SET HS]|r",
    fly       = "|cff38BDF8[FLY]|r",
    fp        = "|cff60A5FA[FP]|r",
    deathskip = "|cffA855F7[DEATHSKIP]|r",
    xp        = "|cffEAB308[GRIND XP]|r",
    grind     = "|cffEAB308[GRIND XP]|r",
    use       = "|cffFB923C[USE ITEM]|r",
    collect   = "|cffF59E0B[USE ITEM]|r",
    goto      = "|cff94A3B8[WAYPOINT]|r",
    waypoint  = "|cff94A3B8[WAYPOINT]|r",
    note      = "|cffCBD5E1[NOTE]|r",
}

Theme.StatusBadges = {
    REC    = "|cffEF4444[REC]|r",
    PAUSED = "|cff9CA3AF[PAUSED]|r",
    OK     = "|cff10B981[OK]|r",
    WARN   = "|cffF59E0B[WARN]|r",
    ACTIVE = "|cff3B82F6[ACTIVE]|r",
    DONE   = "|cff10B981[DONE]|r",
}

Theme.ActionTypesOrdered = {
    "accept",
    "turnin",
    "complete",
    "trainer",
    "vendor",
    "hs",
    "home",
    "fly",
    "fp",
    "deathskip",
    "xp",
    "use",
    "note",
}

Theme.ButtonStyles = {
    primary = {
        bg          = { 0.14, 0.29, 0.56, 0.95 },
        bgHover     = { 0.20, 0.38, 0.72, 1.00 },
        border      = { 0.23, 0.51, 0.96, 1.00 },
        borderHover = { 0.45, 0.68, 1.00, 1.00 },
        text        = { 0.96, 0.98, 1.00, 1.00 },
    },
    gold = {
        bg          = { 0.32, 0.21, 0.04, 0.95 },
        bgHover     = { 0.45, 0.30, 0.06, 1.00 },
        border      = { 0.96, 0.62, 0.04, 1.00 },
        borderHover = { 1.00, 0.78, 0.25, 1.00 },
        text        = { 1.00, 0.92, 0.70, 1.00 },
    },
    success = {
        bg          = { 0.05, 0.28, 0.20, 0.95 },
        bgHover     = { 0.08, 0.38, 0.28, 1.00 },
        border      = { 0.06, 0.73, 0.51, 1.00 },
        borderHover = { 0.20, 0.88, 0.64, 1.00 },
        text        = { 0.88, 1.00, 0.95, 1.00 },
    },
    danger = {
        bg          = { 0.32, 0.10, 0.12, 0.95 },
        bgHover     = { 0.45, 0.14, 0.16, 1.00 },
        border      = { 0.94, 0.27, 0.27, 1.00 },
        borderHover = { 1.00, 0.45, 0.45, 1.00 },
        text        = { 1.00, 0.90, 0.90, 1.00 },
    },
    subtle = {
        bg          = { 0.12, 0.15, 0.21, 0.95 },
        bgHover     = { 0.18, 0.22, 0.30, 1.00 },
        border      = { 0.22, 0.26, 0.34, 1.00 },
        borderHover = { 0.36, 0.42, 0.54, 1.00 },
        text        = { 0.85, 0.88, 0.94, 1.00 },
    },
}

Theme.BackdropInfo = {
    bgFile   = Theme.WHITE8X8,
    edgeFile = Theme.WHITE8X8,
    tile     = false,
    tileSize = 0,
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

function Theme:GetBackdropTemplate()
    return BackdropTemplateMixin and "BackdropTemplate" or nil
end

function Theme:GetActionBadge(actionType)
    local key = tostring(actionType or "note"):lower()
    return self.ActionBadges[key] or ("|cffCBD5E1[" .. key:upper() .. "]|r")
end

function Theme:GetStatusBadge(statusKey)
    local key = tostring(statusKey or "OK"):upper()
    return self.StatusBadges[key] or ("|cffCBD5E1[" .. key .. "]|r")
end

function Theme:FormatActionDescription(action)
    if not action then
        return ""
    end
    local aType = tostring(action.type or "note"):lower()
    if aType == "accept" or aType == "turnin" then
        local title = action.questTitle or action.text
        if title and title ~= "" then
            title = title:gsub("^Accept%s+", ""):gsub("^Turn in%s+", "")
            if action.questId then
                return string.format("%s (#%s)", title, tostring(action.questId))
            end
            return title
        elseif action.questId then
            return "Quest #" .. tostring(action.questId)
        end
        return "Quest"
    elseif aType == "complete" then
        local obj = action.objText or action.text or action.questTitle
        if obj and obj ~= "" then
            if action.questId then
                return string.format("%s (#%s)", obj, tostring(action.questId))
            end
            return obj
        elseif action.questId then
            return string.format("Quest #%s (Obj %s)", tostring(action.questId), tostring(action.objIndex or 1))
        end
        return "Objective"
    elseif aType == "xp" or aType == "grind" then
        local target = action.xpTarget or action.text or "target XP"
        return "To " .. tostring(target)
    elseif aType == "use" or aType == "collect" then
        local name = action.itemName or action.text
        if name and name ~= "" then
            return name
        elseif action.itemId then
            return "Item #" .. tostring(action.itemId)
        end
        return "Item"
    elseif aType == "fly" or aType == "fp" or aType == "hs" or aType == "home" then
        if action.destination and action.destination ~= "" then
            return action.destination
        elseif action.text and action.text ~= "" then
            return action.text
        end
        if aType == "hs" then return "Hearthstone" end
        if aType == "home" then return "Bind Hearthstone" end
        if aType == "fly" then return "Flight Destination" end
        if aType == "fp" then return "Flight Path" end
    elseif aType == "trainer" then
        return (action.text and action.text ~= "") and action.text or "Train class spells"
    elseif aType == "vendor" then
        return (action.text and action.text ~= "") and action.text or "Vendor & resupply"
    elseif aType == "deathskip" then
        return (action.text and action.text ~= "") and action.text or "Spirit Healer resurrect"
    elseif aType == "goto" or aType == "waypoint" then
        if action.text and action.text ~= "" then
            return action.text
        elseif action.zone and action.x and action.y then
            return string.format("%s (%.1f, %.1f)", tostring(action.zone), tonumber(action.x) or 0, tonumber(action.y) or 0)
        end
        return "Pin location"
    end
    return action.text or action.questTitle or action.objText or ""
end

function Theme:FormatActionLine(action)
    if not action then
        return ""
    end
    local badge = self:GetActionBadge(action.type)
    local desc = self:FormatActionDescription(action)
    if desc and desc ~= "" then
        return badge .. " " .. desc
    end
    return badge
end

function Theme:ApplyBackdrop(frame, bgColor, borderColor)
    if not frame then
        return
    end
    local bg = bgColor or self.Colors.bgPrimary
    local border = borderColor or self.Colors.borderDefault

    if not frame.SetBackdrop and BackdropTemplateMixin and Mixin then
        pcall(Mixin, frame, BackdropTemplateMixin)
    end

    if frame.SetBackdrop then
        frame:SetBackdrop(self.BackdropInfo)
        frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
        frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
    else
        if not frame._rxpBgTex and frame.CreateTexture then
            local tex = frame:CreateTexture(nil, "BACKGROUND")
            tex:SetAllPoints(frame)
            frame._rxpBgTex = tex
        end
        if frame._rxpBgTex and frame._rxpBgTex.SetColorTexture then
            frame._rxpBgTex:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1)
        end
    end
end

function Theme:CreateTextButton(parent, text, width, height, style, onClick)
    if not CreateFrame then
        return nil
    end
    local btn = CreateFrame("Button", nil, parent, self:GetBackdropTemplate())
    btn:SetSize(width or 90, height or 22)
    if btn.RegisterForClicks then
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end

    local styleName = style or "subtle"
    local palette = self.ButtonStyles[styleName] or self.ButtonStyles.subtle
    btn._stylePalette = palette

    self:ApplyBackdrop(btn, palette.bg, palette.border)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    label:SetJustifyH("CENTER")
    label:SetText(text or "")
    if label.SetTextColor and palette.text then
        label:SetTextColor(palette.text[1], palette.text[2], palette.text[3], palette.text[4] or 1)
    end
    btn.label = label

    function btn:SetButtonText(newText)
        if self.label then
            self.label:SetText(newText or "")
        end
    end

    function btn:SetButtonStyle(newStyle)
        local p = Theme.ButtonStyles[newStyle] or Theme.ButtonStyles.subtle
        self._stylePalette = p
        Theme:ApplyBackdrop(self, p.bg, p.border)
        if self.label and self.label.SetTextColor and p.text then
            self.label:SetTextColor(p.text[1], p.text[2], p.text[3], p.text[4] or 1)
        end
    end

    btn:SetScript("OnEnter", function(self)
        local p = self._stylePalette or palette
        Theme:ApplyBackdrop(self, p.bgHover, p.borderHover)
    end)

    btn:SetScript("OnLeave", function(self)
        local p = self._stylePalette or palette
        Theme:ApplyBackdrop(self, p.bg, p.border)
    end)

    if onClick then
        btn:SetScript("OnClick", function(self, mouseButton)
            onClick(self, mouseButton)
        end)
    end

    return btn
end

function Theme:CreateTogglePill(parent, label, initialValue, onChange)
    if not CreateFrame then
        return nil
    end

    local pill = CreateFrame("Button", nil, parent, self:GetBackdropTemplate())
    pill:SetSize(140, 22)
    pill._value = initialValue and true or false
    pill._label = label or "Toggle"
    pill._onChange = onChange

    local fs = pill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("CENTER", pill, "CENTER", 0, 0)
    fs:SetJustifyH("CENTER")
    pill.text = fs

    function pill:UpdateVisual()
        if self._value then
            Theme:ApplyBackdrop(self, Theme.ButtonStyles.success.bg, Theme.Colors.borderSuccess)
            self.text:SetText(string.format("[%s: |cff10B981ON|r]", self._label))
        else
            Theme:ApplyBackdrop(self, Theme.Colors.bgSecondary, Theme.Colors.borderDefault)
            self.text:SetText(string.format("[%s: |cff9CA3AFOFF|r]", self._label))
        end
    end

    function pill:SetValue(val, silent)
        self._value = val and true or false
        self:UpdateVisual()
        if not silent and self._onChange then
            self._onChange(self._value, self)
        end
    end

    function pill:GetValue()
        return self._value
    end

    pill:SetScript("OnEnter", function(self)
        if self._value then
            Theme:ApplyBackdrop(self, Theme.ButtonStyles.success.bgHover, Theme.Colors.borderSuccess)
        else
            Theme:ApplyBackdrop(self, Theme.Colors.bgHover, Theme.Colors.borderAccentBlue)
        end
    end)

    pill:SetScript("OnLeave", function(self)
        self:UpdateVisual()
    end)

    pill:SetScript("OnClick", function(self)
        self:SetValue(not self._value, false)
    end)

    pill:UpdateVisual()
    return pill
end

function Theme:CreateEditBox(parent, width, height, isMultiLine, onTextChanged, onCommit)
    if not CreateFrame then
        return nil
    end

    local w = width or 140
    local h = height or 22

    if isMultiLine then
        local container = CreateFrame("Frame", nil, parent, self:GetBackdropTemplate())
        container:SetSize(w, h)
        self:ApplyBackdrop(container, self.Colors.bgInput, self.Colors.borderDefault)

        local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 6, -6)
        scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -24, 6)

        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetWidth(math.max(40, w - 34))
        editBox:SetTextInsets(2, 2, 2, 2)
        scrollFrame:SetScrollChild(editBox)

        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)

        editBox:SetScript("OnEditFocusGained", function(self)
            self._hasFocus = true
            Theme:ApplyBackdrop(container, Theme.Colors.bgInput, Theme.Colors.borderAccentBlue)
        end)

        editBox:SetScript("OnEditFocusLost", function(self)
            self._hasFocus = false
            Theme:ApplyBackdrop(container, Theme.Colors.bgInput, Theme.Colors.borderDefault)
            if onCommit then
                onCommit(self:GetText(), self)
            end
        end)

        editBox:SetScript("OnTextChanged", function(self, userInput)
            if onTextChanged then
                onTextChanged(self:GetText(), userInput, self)
            end
        end)

        container:SetScript("OnMouseDown", function()
            editBox:SetFocus()
        end)

        container.editBox = editBox
        container.scrollFrame = scrollFrame

        function container:GetText()
            return self.editBox:GetText()
        end

        function container:SetText(txt)
            self.editBox:SetText(txt or "")
        end

        function container:ClearFocus()
            self.editBox._hasFocus = false
            self.editBox:ClearFocus()
        end

        function container:HasFocus()
            if self.editBox and type(self.editBox.HasFocus) == "function" then
                return self.editBox:HasFocus()
            end
            return (self.editBox and self.editBox._hasFocus) or false
        end

        return container
    else
        local editBox = CreateFrame("EditBox", nil, parent, self:GetBackdropTemplate())
        editBox:SetSize(w, h)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetTextInsets(6, 6, 2, 2)
        self:ApplyBackdrop(editBox, self.Colors.bgInput, self.Colors.borderDefault)

        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)

        editBox:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            if onCommit then
                onCommit(self:GetText(), self)
            end
        end)

        editBox:SetScript("OnEditFocusGained", function(self)
            self._hasFocus = true
            Theme:ApplyBackdrop(self, Theme.Colors.bgInput, Theme.Colors.borderAccentBlue)
        end)

        editBox:SetScript("OnEditFocusLost", function(self)
            self._hasFocus = false
            Theme:ApplyBackdrop(self, Theme.Colors.bgInput, Theme.Colors.borderDefault)
            if onCommit then
                onCommit(self:GetText(), self)
            end
        end)

        editBox:SetScript("OnTextChanged", function(self, userInput)
            if onTextChanged then
                onTextChanged(self:GetText(), userInput, self)
            end
        end)

        if type(editBox.HasFocus) ~= "function" then
            function editBox:HasFocus()
                return self._hasFocus or false
            end
        end

        return editBox
    end
end

function Theme:CreateScrollList(parent, width, height)
    if not CreateFrame then
        return nil
    end

    local container = CreateFrame("Frame", nil, parent, self:GetBackdropTemplate())
    container:SetSize(width or 280, height or 400)
    self:ApplyBackdrop(container, self.Colors.bgSecondary, self.Colors.borderDefault)

    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -24, 4)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(math.max(40, (width or 280) - 28), 10)
    scrollFrame:SetScrollChild(content)

    container.scrollFrame = scrollFrame
    container.content = content

    function container:SetContentHeight(h)
        self.content:SetHeight(math.max(10, h or 10))
    end

    return container
end
