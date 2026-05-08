local addonName, PC = ...

local PeaversCommons = _G.PeaversCommons
if not PeaversCommons then
    print("|cffff0000PeaversConfig:|r PeaversCommons is required but not loaded.")
    return
end

PC.name = addonName
PC.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "1.0.0"

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        PC.WindowState:Initialize()
        PC.EcosystemProfiles:Initialize()

    elseif event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")

        C_Timer.After(1, function()
            PC.MainFrame:Initialize()
        end)
    end
end)

SLASH_PEAVERSCONFIG1 = "/pconfig"
SLASH_PEAVERSCONFIG2 = "/peavers"
SlashCmdList["PEAVERSCONFIG"] = function(msg)
    msg = msg and msg:trim():lower() or ""

    if msg == "" then
        PC.MainFrame:Toggle()
    elseif msg == "profiles" then
        PC.MainFrame:Show()
        PC.MainFrame:SelectSection("profiles")
    else
        PC.MainFrame:Show()
        local registry = PeaversCommons.ConfigRegistry
        for name, _ in pairs(registry:GetRegisteredAddons()) do
            if name:lower():find(msg) or (registry:GetAddon(name).displayName or ""):lower():find(msg) then
                PC.MainFrame:SelectAddon(name)
                return
            end
        end
    end
end

_G.PeaversConfig = PC
