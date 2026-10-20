local _, ns = ...
ns.UI = ns.UI or {}

local Theme = ns.UI.Theme
local MapPreview = {}
ns.UI.MapPreview = MapPreview

-- Classic & Beta Zone Name -> uiMapID Lookup Table
MapPreview.ZoneToMapID = {
    ["Durotar"]               = 1411,
    ["Mulgore"]               = 1412,
    ["The Barrens"]           = 1413,
    ["Kalimdor"]              = 1414,
    ["Eastern Kingdoms"]      = 1415,
    ["Alterac Mountains"]     = 1416,
    ["Arathi Highlands"]      = 1417,
    ["Badlands"]              = 1418,
    ["Blasted Lands"]         = 1419,
    ["Tirisfal Glades"]       = 1420,
    ["Silverpine Forest"]     = 1421,
    ["Western Plaguelands"]   = 1422,
    ["Eastern Plaguelands"]   = 1423,
    ["Hillsbrad Foothills"]   = 1424,
    ["The Hinterlands"]       = 1425,
    ["Dun Morogh"]            = 1426,
    ["Searing Gorge"]         = 1427,
    ["Burning Steppes"]       = 1428,
    ["Elwynn Forest"]         = 1429,
    ["Deadwind Pass"]         = 1430,
    ["Duskwood"]              = 1431,
    ["Loch Modan"]            = 1432,
    ["Redridge Mountains"]    = 1433,
    ["Stranglethorn Vale"]    = 1434,
    ["Swamp of Sorrows"]      = 1435,
    ["Westfall"]              = 1436,
    ["Wetlands"]              = 1437,
    ["Teldrassil"]            = 1438,
    ["Darkshore"]             = 1439,
    ["Ashenvale"]             = 1440,
    ["Thousand Needles"]      = 1441,
    ["Stonetalon Mountains"]  = 1442,
    ["Desolace"]              = 1443,
    ["Feralas"]               = 1444,
    ["Dustwallow Marsh"]      = 1445,
    ["Tanaris"]               = 1446,
    ["Azshara"]               = 1447,
    ["Felwood"]               = 1448,
    ["Un'Goro Crater"]        = 1449,
    ["Moonglade"]             = 1450,
    ["Silithus"]              = 1451,
    ["Winterspring"]          = 1452,
    ["Stormwind City"]        = 1453,
    ["Orgrimmar"]             = 1454,
    ["Ironforge"]             = 1455,
    ["Thunder Bluff"]         = 1456,
    ["Darnassus"]             = 1457,
    ["Undercity"]             = 1458,
}

function MapPreview:ResolveMapID(zoneName)
    if not zoneName or zoneName == "" then
        return nil
    end
    if self.ZoneToMapID[zoneName] then
        return self.ZoneToMapID[zoneName]
    end

    local lower = zoneName:lower()
    for name, id in pairs(self.ZoneToMapID) do
        if name:lower() == lower then
            return id
        end
    end

    if _G.C_Map and _G.C_Map.GetBestMapForUnit and _G.C_Map.GetMapInfo then
        local playerMap = _G.C_Map.GetBestMapForUnit("player")
        if playerMap then
            local info = _G.C_Map.GetMapInfo(playerMap)
            if info and info.name and info.name:lower() == lower then
                self.ZoneToMapID[zoneName] = playerMap
                return playerMap
            end
        end
        for mapID = 1400, 2600 do
            local info = _G.C_Map.GetMapInfo(mapID)
            if info and info.name and info.name:lower() == lower then
                self.ZoneToMapID[zoneName] = mapID
                return mapID
            end
        end
    end
    return nil
end

function MapPreview:RenderMapArt(uiMapID)
    if not self.canvas then
        return
    end
    self.tileTextures = self.tileTextures or {}
    for i = 1, #self.tileTextures do
        self.tileTextures[i]:Hide()
    end

    local hasTiles = false
    if uiMapID and _G.C_Map and _G.C_Map.GetMapArtLayers and _G.C_Map.GetMapArtLayerTextures then
        local layers = _G.C_Map.GetMapArtLayers(uiMapID)
        local textures = _G.C_Map.GetMapArtLayerTextures(uiMapID, 1)
        if layers and layers[1] and textures and #textures > 0 then
            local layer = layers[1]
            local layerW = layer.layerWidth or 1002
            local layerH = layer.layerHeight or 668
            local tileW = layer.tileWidth or 256
            local tileH = layer.tileHeight or 256
            local numCols = math.ceil(layerW / tileW)
            local numRows = math.ceil(layerH / tileH)

            local canvasW = self.canvas:GetWidth() or 280
            local canvasH = self.canvas:GetHeight() or 200
            local scaleX = canvasW / layerW
            local scaleY = canvasH / layerH

            local texIdx = 1
            for r = 1, numRows do
                for c = 1, numCols do
                    local fileDataID = textures[texIdx]
                    if fileDataID then
                        local tile = self.tileTextures[texIdx]
                        if not tile then
                            tile = self.canvas:CreateTexture(nil, "BACKGROUND", nil, 1)
                            self.tileTextures[texIdx] = tile
                        end
                        local xOffset = (c - 1) * tileW * scaleX
                        local yOffset = -((r - 1) * tileH * scaleY)
                        tile:ClearAllPoints()
                        tile:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", xOffset, yOffset)
                        tile:SetSize(tileW * scaleX, tileH * scaleY)
                        tile:SetTexture(fileDataID)
                        tile:SetAlpha(0.78)
                        tile:Show()
                        hasTiles = true
                    end
                    texIdx = texIdx + 1
                end
            end
        end
    end

    if self.gridGroup then
        for i = 1, #self.gridGroup do
            self.gridGroup[i]:SetAlpha(hasTiles and 0.15 or 0.45)
        end
    end
end

function MapPreview:AcquirePin(index)
    self.pins = self.pins or {}
    local pin = self.pins[index]
    if not pin then
        pin = CreateFrame("Button", nil, self.canvas, Theme:GetBackdropTemplate())
        pin:SetSize(30, 16)
        pin:SetFrameLevel(self.canvas:GetFrameLevel() + 8)
        local fs = pin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("CENTER", pin, "CENTER", 0, 0)
        pin.label = fs
        self.pins[index] = pin
    end
    return pin
end

function MapPreview:DrawSegment(segIdx, x1, y1, x2, y2, color)
    self.segments = self.segments or {}
    local canvasW = self.canvas:GetWidth() or 280
    local canvasH = self.canvas:GetHeight() or 200

    local px1 = (x1 / 100) * canvasW
    local py1 = -((y1 / 100) * canvasH)
    local px2 = (x2 / 100) * canvasW
    local py2 = -((y2 / 100) * canvasH)

    local seg = self.segments[segIdx]
    if not seg then
        if self.canvas.CreateLine then
            local line = self.canvas:CreateLine(nil, "ARTWORK")
            line:SetThickness(2)
            seg = { isLine = true, line = line }
        else
            local dots = {}
            for d = 1, 9 do
                local dot = self.canvas:CreateTexture(nil, "ARTWORK")
                dot:SetSize(3, 3)
                dots[d] = dot
            end
            seg = { isLine = false, dots = dots }
        end
        self.segments[segIdx] = seg
    end

    local r, g, b, a = color[1], color[2], color[3], color[4] or 0.85
    if seg.isLine then
        seg.line:SetColorTexture(r, g, b, a)
        seg.line:SetStartPoint("TOPLEFT", self.canvas, px1, py1)
        seg.line:SetEndPoint("TOPLEFT", self.canvas, px2, py2)
        seg.line:Show()
    else
        local count = #seg.dots
        for d = 1, count do
            local t = d / (count + 1)
            local dx = px1 + (px2 - px1) * t
            local dy = py1 + (py2 - py1) * t
            local dot = seg.dots[d]
            dot:ClearAllPoints()
            dot:SetPoint("CENTER", self.canvas, "TOPLEFT", dx, dy)
            dot:SetColorTexture(r, g, b, a)
            dot:Show()
        end
    end
end

function MapPreview:HideUnusedGraphics(usedPins, usedSegments)
    if usedPins == 0 then
        if self.selectBracket and type(self.selectBracket.Hide) == "function" then
            self.selectBracket:Hide()
        end
        if self.tooltipFrame and type(self.tooltipFrame.Hide) == "function" then
            self.tooltipFrame:Hide()
        end
    end
    if self.pins then
        for i = usedPins + 1, #self.pins do
            self.pins[i]:Hide()
        end
    end
    if self.segments then
        for i = usedSegments + 1, #self.segments do
            local seg = self.segments[i]
            if seg.isLine then
                seg.line:Hide()
            else
                for d = 1, #seg.dots do
                    seg.dots[d]:Hide()
                end
            end
        end
    end
end

function MapPreview:ScreenToMapCoords(cursorX, cursorY)
    if not self.canvas then
        return 50, 50
    end
    local scale = self.canvas:GetEffectiveScale() or 1
    local left = (self.canvas:GetLeft() or 0) * scale
    local top = (self.canvas:GetTop() or 0) * scale
    local w = (self.canvas:GetWidth() or 280) * scale
    local h = (self.canvas:GetHeight() or 200) * scale

    if w <= 0 or h <= 0 then
        return 50, 50
    end

    local rx = ((cursorX - left) / w) * 100
    local ry = ((top - cursorY) / h) * 100
    rx = math.max(0, math.min(100, rx))
    ry = math.max(0, math.min(100, ry))
    return tonumber(string.format("%.2f", rx)), tonumber(string.format("%.2f", ry))
end

function MapPreview:ApplyCoordClick(mouseButton, isDrag)
    local card = self.currentCard
    if not card or not GetCursorPosition then
        return
    end
    local cx, cy = GetCursorPosition()
    local mx, my = self:ScreenToMapCoords(cx, cy)

    local isLoopClick = (mouseButton == "RightButton") or (self.drawLoopMode and not isDrag)
    if isLoopClick then
        card.loopWaypoints = card.loopWaypoints or {}
        table.insert(card.loopWaypoints, { x = mx, y = my })
        card.loop = true
    else
        card.x = mx
        card.y = my
        if not card.zone or card.zone == "" then
            if ns.Recorder and ns.Recorder.GetPlayerLocation then
                local z = ns.Recorder:GetPlayerLocation()
                card.zone = z or "Durotar"
            else
                card.zone = "Durotar"
            end
        end
    end

    card.rawOverride = nil
    local guide = ns.Core and ns.Core:GetActiveGuide()
    if guide then
        ns:FireCallback("GUIDE_UPDATED", guide)
    end
    self:Refresh()
end

function MapPreview:Create(parent)
    if not CreateFrame then
        return nil
    end

    local root = CreateFrame("Frame", nil, parent, Theme:GetBackdropTemplate())
    root:SetAllPoints(parent)
    Theme:ApplyBackdrop(root, Theme.Colors.bgSecondary, Theme.Colors.borderDefault)
    self.frame = root
    self.drawLoopMode = false

    -- Column Header
    local colHeader = CreateFrame("Frame", nil, root, Theme:GetBackdropTemplate())
    colHeader:SetPoint("TOPLEFT", root, "TOPLEFT", 4, -4)
    colHeader:SetPoint("TOPRIGHT", root, "TOPRIGHT", -4, -4)
    colHeader:SetHeight(26)
    Theme:ApplyBackdrop(colHeader, Theme.Colors.bgPrimary, Theme.Colors.borderDefault)

    local colTitle = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colTitle:SetPoint("LEFT", colHeader, "LEFT", 8, 0)
    colTitle:SetText("|cff3B82F6ZONE MAP & WAYPOINT PREVIEW|r")
    self.colTitle = colTitle

    -- Zone & Coords Status Banner
    local statusBanner = CreateFrame("Frame", nil, root, Theme:GetBackdropTemplate())
    statusBanner:SetPoint("TOPLEFT", colHeader, "BOTTOMLEFT", 0, -4)
    statusBanner:SetPoint("TOPRIGHT", colHeader, "BOTTOMRIGHT", 0, -4)
    statusBanner:SetHeight(24)
    Theme:ApplyBackdrop(statusBanner, Theme.Colors.bgPrimary, Theme.Colors.borderDefault)

    local zoneReadout = statusBanner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneReadout:SetPoint("LEFT", statusBanner, "LEFT", 6, 0)
    zoneReadout:SetText("Zone: None")
    self.zoneReadout = zoneReadout

    -- Interactive Map Canvas (3:2 aspect ratio: 288 x 192)
    local canvas = CreateFrame("Button", nil, root, Theme:GetBackdropTemplate())
    canvas:SetPoint("TOPLEFT", statusBanner, "BOTTOMLEFT", 0, -4)
    canvas:SetPoint("TOPRIGHT", statusBanner, "BOTTOMRIGHT", 0, -4)
    canvas:SetHeight(210)
    canvas:EnableMouse(true)
    if canvas.RegisterForClicks then
        canvas:RegisterForClicks("LeftButtonDown", "RightButtonDown")
    end
    Theme:ApplyBackdrop(canvas, Theme.Colors.bgInput, Theme.Colors.borderAccentBlue)
    self.canvas = canvas

    -- Tactical Coordinate Grid Fallback Lines
    self.gridGroup = {}
    for g = 1, 3 do
        local pct = g * 0.25
        local vLine = canvas:CreateTexture(nil, "BACKGROUND", nil, 2)
        vLine:SetWidth(1)
        vLine:SetPoint("TOP", canvas, "TOPLEFT", 288 * pct, -1)
        vLine:SetPoint("BOTTOM", canvas, "BOTTOMLEFT", 288 * pct, 1)
        vLine:SetColorTexture(0.28, 0.34, 0.46, 0.35)
        table.insert(self.gridGroup, vLine)

        local hLine = canvas:CreateTexture(nil, "BACKGROUND", nil, 2)
        hLine:SetHeight(1)
        hLine:SetPoint("LEFT", canvas, "TOPLEFT", 1, -(210 * pct))
        hLine:SetPoint("RIGHT", canvas, "TOPRIGHT", -1, -(210 * pct))
        hLine:SetColorTexture(0.28, 0.34, 0.46, 0.35)
        table.insert(self.gridGroup, hLine)
    end

    canvas:SetScript("OnMouseDown", function(_, mouseButton)
        if mouseButton == "LeftButton" and not self.drawLoopMode then
            self._isDraggingPin = true
        end
        self:ApplyCoordClick(mouseButton, false)
    end)

    canvas:SetScript("OnMouseUp", function()
        self._isDraggingPin = false
    end)

    canvas:SetScript("OnUpdate", function()
        if self._isDraggingPin and IsMouseButtonDown and IsMouseButtonDown("LeftButton") then
            self:ApplyCoordClick("LeftButton", true)
        elseif self._isDraggingPin then
            self._isDraggingPin = false
        end
    end)

    -- Instructions & Neighbor Route Legend
    local legendBox = CreateFrame("Frame", nil, root, Theme:GetBackdropTemplate())
    legendBox:SetPoint("TOPLEFT", canvas, "BOTTOMLEFT", 0, -4)
    legendBox:SetPoint("TOPRIGHT", canvas, "BOTTOMRIGHT", 0, -4)
    legendBox:SetHeight(98)
    Theme:ApplyBackdrop(legendBox, Theme.Colors.bgPrimary, Theme.Colors.borderDefault)

    local legendText = legendBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    legendText:SetPoint("TOPLEFT", legendBox, "TOPLEFT", 6, -6)
    legendText:SetPoint("BOTTOMRIGHT", legendBox, "BOTTOMRIGHT", -6, 6)
    legendText:SetJustifyH("LEFT")
    legendText:SetJustifyV("TOP")
    self.legendText = legendText

    -- Bottom Map Controls
    local controlsFrame = CreateFrame("Frame", nil, root, Theme:GetBackdropTemplate())
    controlsFrame:SetPoint("TOPLEFT", legendBox, "BOTTOMLEFT", 0, -4)
    controlsFrame:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -4, 4)
    Theme:ApplyBackdrop(controlsFrame, Theme.Colors.bgPrimary, Theme.Colors.borderDefault)

    local modeBtn = Theme:CreateTextButton(controlsFrame, "[Drag Pin Mode]", 180, 22, "primary", function(btn)
        self.drawLoopMode = not self.drawLoopMode
        if self.drawLoopMode then
            btn:SetButtonText("[Draw Loop Mode: ON]")
            btn:SetButtonStyle("gold")
        else
            btn:SetButtonText("[Drag Pin Mode]")
            btn:SetButtonStyle("primary")
        end
    end)
    modeBtn:SetPoint("TOPLEFT", controlsFrame, "TOPLEFT", 6, -6)
    self.modeBtn = modeBtn

    local clearLoopBtn = Theme:CreateTextButton(controlsFrame, "[Clear Loop]", 96, 22, "danger", function()
        if not self.currentCard then return end
        self.currentCard.loopWaypoints = nil
        self.currentCard.loop = false
        self.currentCard.rawOverride = nil
        local guide = ns.Core and ns.Core:GetActiveGuide()
        if guide then
            ns:FireCallback("GUIDE_UPDATED", guide)
        end
        self:Refresh()
    end)
    clearLoopBtn:SetPoint("TOPRIGHT", controlsFrame, "TOPRIGHT", -6, -6)
    self.clearLoopBtn = clearLoopBtn

    local snapPosBtn = Theme:CreateTextButton(controlsFrame, "[Snap to My Position]", 280, 24, "success", function()
        if not self.currentCard then return end
        if ns.Recorder and ns.Recorder.GetPlayerLocation then
            local z, px, py = ns.Recorder:GetPlayerLocation()
            if z then self.currentCard.zone = z end
            if px then self.currentCard.x = tonumber(string.format("%.2f", px)) end
            if py then self.currentCard.y = tonumber(string.format("%.2f", py)) end
            self.currentCard.rawOverride = nil
            local guide = ns.Core and ns.Core:GetActiveGuide()
            if guide then
                ns:FireCallback("GUIDE_UPDATED", guide)
            end
            self:Refresh()
        end
    end)
    snapPosBtn:SetPoint("TOPLEFT", modeBtn, "BOTTOMLEFT", 0, -6)
    snapPosBtn:SetPoint("TOPRIGHT", clearLoopBtn, "BOTTOMRIGHT", 0, -6)
    self.snapPosBtn = snapPosBtn

    return root
end

function MapPreview:SetCard(card, stepIndex, guide)
    self.currentCard = card
    self.currentStepIndex = stepIndex
    self.currentGuide = guide
    self:Refresh()
end

function MapPreview:PlacePinOnCanvas(pinIdx, x, y, text, bgColor, borderColor)
    local pin = self:AcquirePin(pinIdx)
    local canvasW = self.canvas:GetWidth() or 280
    local canvasH = self.canvas:GetHeight() or 210
    local px = (x / 100) * canvasW
    local py = -((y / 100) * canvasH)

    pin:ClearAllPoints()
    pin:SetPoint("CENTER", self.canvas, "TOPLEFT", px, py)
    Theme:ApplyBackdrop(pin, bgColor, borderColor)
    pin.label:SetText(text)
    pin:SetWidth(math.max(28, (string.len(text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) * 6) + 8))
    pin:Show()
end

function MapPreview:Refresh()
    if not self.frame or not self.canvas then
        return
    end

    local card = self.currentCard
    local guide = self.currentGuide or (ns.Core and ns.Core:GetActiveGuide())
    local stepIdx = self.currentStepIndex or 1

    if not card then
        self.zoneReadout:SetText("|cff9CA3AFNo Step Selected|r")
        self.legendText:SetText("Select a step card on the left timeline to view or drag its map waypoint.")
        self:HideUnusedGraphics(0, 0)
        return
    end

    local zone = card.zone or "Unknown Zone"
    local mapID = self:ResolveMapID(zone)
    self:RenderMapArt(mapID)

    local cx = tonumber(card.x)
    local cy = tonumber(card.y)

    if cx and cy then
        self.zoneReadout:SetText(string.format("|cffF59E0B%s|r  |cff10B981(%.2f, %.2f)|r %s",
            zone, cx, cy, mapID and ("|cff9CA3AF[MapID " .. mapID .. "]|r") or "|cff9CA3AF[Grid Mode]|r"))
    else
        self.zoneReadout:SetText(string.format("|cffF59E0B%s|r  |cffEF4444(No Coordinates)|r", zone))
    end

    local usedPins = 0
    local usedSegs = 0
    local steps = (guide and guide.steps) or {}

    -- Plot previous and next steps in the same zone
    local prevCard = steps[stepIdx - 1]
    local nextCard = steps[stepIdx + 1]

    if prevCard and prevCard.zone == card.zone and prevCard.x and prevCard.y then
        local px, py = tonumber(prevCard.x), tonumber(prevCard.y)
        if px and py then
            if cx and cy then
                usedSegs = usedSegs + 1
                self:DrawSegment(usedSegs, px, py, cx, cy, { 0.45, 0.55, 0.70, 0.75 })
            end
            usedPins = usedPins + 1
            self:PlacePinOnCanvas(usedPins, px, py, string.format("|cff9CA3AF[%d]|r", stepIdx - 1),
                Theme.Colors.bgSecondary, Theme.Colors.borderDefault)
        end
    end

    if nextCard and nextCard.zone == card.zone and nextCard.x and nextCard.y then
        local nx, ny = tonumber(nextCard.x), tonumber(nextCard.y)
        if nx and ny then
            if cx and cy then
                usedSegs = usedSegs + 1
                self:DrawSegment(usedSegs, cx, cy, nx, ny, { 0.23, 0.51, 0.96, 0.85 })
            end
            usedPins = usedPins + 1
            self:PlacePinOnCanvas(usedPins, nx, ny, string.format("|cff3B82F6[%d]|r", stepIdx + 1),
                Theme.Colors.bgCard, Theme.Colors.borderAccentBlue)
        end
    end

    -- Plot loop waypoints if present
    local loops = card.loopWaypoints or {}
    if #loops > 0 then
        local lastX = cx or tonumber(loops[1].x)
        local lastY = cy or tonumber(loops[1].y)
        for i = 1, #loops do
            local lx = tonumber(loops[i].x)
            local ly = tonumber(loops[i].y)
            if lx and ly then
                if lastX and lastY then
                    usedSegs = usedSegs + 1
                    self:DrawSegment(usedSegs, lastX, lastY, lx, ly, { 0.96, 0.62, 0.04, 0.90 })
                end
                usedPins = usedPins + 1
                self:PlacePinOnCanvas(usedPins, lx, ly, string.format("|cffEAB308[L%d]|r", i),
                    Theme.ButtonStyles.gold.bg, Theme.Colors.borderAccentGold)
                lastX, lastY = lx, ly
            end
        end
        if #loops > 1 and cx and cy and lastX and lastY then
            usedSegs = usedSegs + 1
            self:DrawSegment(usedSegs, lastX, lastY, cx, cy, { 0.96, 0.62, 0.04, 0.65 })
        end
    end

    -- Plot current step pin on top
    if cx and cy then
        usedPins = usedPins + 1
        self:PlacePinOnCanvas(usedPins, cx, cy, string.format("|cffF59E0B[%d]|r", stepIdx),
            Theme.ButtonStyles.gold.bg, Theme.Colors.borderAccentGold)
    end

    self:HideUnusedGraphics(usedPins, usedSegs)

    local loopCount = #loops
    local summaryLines = {
        string.format("|cffF59E0BActive Pin:|r [%d] %s", stepIdx, cx and string.format("(%.2f, %.2f)", cx, cy) or "Click canvas to set"),
        string.format("|cffEAB308Grind Loop Nodes:|r %d %s", loopCount, loopCount > 0 and "(#loop enabled)" or "(Right-click canvas to add)"),
        "|cff9CA3AFLeft-Click / Drag:|r Move step waypoint in real time",
        "|cff9CA3AFRight-Click:|r Append grind loop node [L1..Ln]",
    }
    self.legendText:SetText(table.concat(summaryLines, "\n"))
end
