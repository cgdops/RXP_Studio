local addonName, ns = ...
_G.RXP_Studio = ns

ns.version = "1.0.0"
ns.Core = ns.Core or {}
ns.Compiler = ns.Compiler or {}
ns.Linter = ns.Linter or {}
ns.Bridge = ns.Bridge or {}
ns.Recorder = ns.Recorder or {}
ns.AutoMerger = ns.AutoMerger or {}
ns.UI = ns.UI or {}
ns.callbacks = ns.callbacks or {}

function ns:RegisterCallback(event, fn)
    if not self.callbacks[event] then
        self.callbacks[event] = {}
    end
    table.insert(self.callbacks[event], fn)
end

function ns:FireCallback(event, ...)
    local list = self.callbacks[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffEF4444[RXP Studio Error]|r " .. tostring(err))
        end
    end
end

function ns:Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff3B82F6[RXP Studio]|r " .. tostring(msg))
    end
end

local bootFrame = CreateFrame and CreateFrame("Frame")
if bootFrame then
    bootFrame:RegisterEvent("ADDON_LOADED")
    bootFrame:RegisterEvent("PLAYER_LOGIN")
    bootFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == addonName then
            if ns.Core and ns.Core.InitDB then
                ns.Core:InitDB()
            end
        elseif event == "PLAYER_LOGIN" then
            if ns.Recorder and ns.Recorder.Init then
                ns.Recorder:Init()
            end
            if ns.UI and ns.UI.Init then
                ns.UI:Init()
            end
            if ns.Bridge and ns.Bridge.RegisterAllSavedGuides then
                ns.Bridge:RegisterAllSavedGuides()
            end
            ns:Print("Loaded v" .. ns.version .. ". Type |cffF59E0B/rxpstudio|r to open the Guide Studio or |cffF59E0B/rxprec|r to toggle the Live Recorder HUD.")
        end
    end)
end

SLASH_RXPSTUDIO1 = "/rxpstudio"
SLASH_RXPSTUDIO2 = "/rxps"
SlashCmdList["RXPSTUDIO"] = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$"):lower()
    if msg == "import" or msg == "migrate" then
        if ns.Core and ns.Core.ImportLegacyRecorderDB then
            local count = ns.Core:ImportLegacyRecorderDB()
            ns:Print("Imported " .. tostring(count or 0) .. " guide run(s) from RXP_RecorderDB.")
            if ns.UI and ns.UI.RefreshAll then ns.UI:RefreshAll() end
        end
    elseif msg == "test" then
        if ns.Bridge and ns.Bridge.SyncGuideToRXP and ns.Core then
            local g = ns.Core:GetActiveGuide()
            if g then
                ns.Bridge:SyncGuideToRXP(g, ns.Core.selectedStepIndex or 1)
            end
        end
    else
        if ns.UI and ns.UI.ToggleStudio then
            ns.UI:ToggleStudio()
        end
    end
end

SLASH_RXPREC1 = "/rxprec"
SLASH_RXPREC2 = "/rxprecorder"
SlashCmdList["RXPREC"] = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$"):lower()
    if msg == "start" then
        if ns.Recorder and ns.Recorder.SetRecording then
            ns.Recorder:SetRecording(true)
        end
    elseif msg == "stop" or msg == "pause" then
        if ns.Recorder and ns.Recorder.SetRecording then
            ns.Recorder:SetRecording(false)
        end
    else
        if ns.UI and ns.UI.ToggleHUD then
            ns.UI:ToggleHUD()
        end
    end
end
