local _, PC = ...

PC.AddonsPanel = {}
local AddonsPanel = PC.AddonsPanel

local PeaversCommons = _G.PeaversCommons
local Theme = PeaversCommons.Theme

local panel = nil
local elements = {}

-- Folder names of every addon physically present, loaded or not. Installation
-- can't change mid-session, but enable state can, so this stays a function.
local function GetInstalledFolders()
    local installed = {}
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        if name then
            installed[name] = true
        end
    end
    return installed
end

function AddonsPanel:GetOrCreatePanel(parent)
    if panel then
        panel:Show()
        self:Refresh()
        return panel
    end

    panel = CreateFrame("Frame", nil, parent)
    panel:SetWidth(parent:GetWidth())
    panel:SetHeight(400)

    self:Refresh()

    return panel
end

function AddonsPanel:Refresh()
    if not panel then return end

    for _, el in ipairs(elements) do
        if el.Hide then el:Hide() end
        if el.SetParent then el:SetParent(nil) end
    end
    elements = {}

    local W = PC.Widgets
    local C = W.Colors
    local leftX = 25
    local yPos = -20
    local accentHex = Theme.Hex(C.accent)

    local catalog = (PC.AddonCatalog and PC.AddonCatalog.addons) or {}
    local installed = GetInstalledFolders()

    local missing, have = {}, {}
    for _, addon in ipairs(catalog) do
        if installed[addon.folder] then
            table.insert(have, addon)
        else
            table.insert(missing, addon)
        end
    end
    local byName = function(a, b) return a.name < b.name end
    table.sort(missing, byName)
    table.sort(have, byName)

    local title = W:CreateLabel(panel, "All |cff" .. accentHex .. "Peavers|r Addons", {
        color = C.text,
        size = 20,
    })
    title:SetPoint("TOPLEFT", leftX, yPos)
    table.insert(elements, title)
    yPos = yPos - 28

    local summaryText
    if #catalog == 0 then
        summaryText = "No catalog data available. This build is missing its bundled addon catalog."
    elseif #missing == 0 then
        summaryText = "You have all " .. #catalog .. " Peavers addons installed. Thank you!"
    else
        summaryText = "You have " .. #have .. " of " .. #catalog .. " Peavers addons installed."
    end
    local summary = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    summary:SetPoint("TOPLEFT", leftX, yPos)
    summary:SetPoint("TOPRIGHT", -leftX, yPos)
    summary:SetJustifyH("LEFT")
    summary:SetText(summaryText)
    summary:SetTextColor(C.textSec[1], C.textSec[2], C.textSec[3])
    table.insert(elements, summary)
    yPos = yPos - (summary:GetStringHeight() + 25)

    local function AddRow(addon, isInstalled)
        local dot = panel:CreateTexture(nil, "ARTWORK")
        dot:SetPoint("TOPLEFT", leftX + 2, yPos - 5)
        Theme.Dot(dot, 5, isInstalled and C.statusLive or C.amber)
        table.insert(elements, dot)

        local name = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        name:SetPoint("TOPLEFT", leftX + 14, yPos)
        name:SetText(addon.name)
        local nameColor = isInstalled and C.textSec or C.text
        name:SetTextColor(nameColor[1], nameColor[2], nameColor[3])
        table.insert(elements, name)
        yPos = yPos - 16

        local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        desc:SetPoint("TOPLEFT", leftX + 14, yPos)
        desc:SetPoint("TOPRIGHT", -leftX, yPos)
        desc:SetJustifyH("LEFT")
        desc:SetText(addon.description or "")
        local descColor = isInstalled and C.textMuted or C.textSec
        desc:SetTextColor(descColor[1], descColor[2], descColor[3])
        table.insert(elements, desc)
        yPos = yPos - (desc:GetStringHeight() + 12)
    end

    if #missing > 0 then
        local header, headerY = W:CreateSectionHeader(panel, "NOT INSTALLED (" .. #missing .. ")", leftX, yPos)
        table.insert(elements, header)
        yPos = headerY - 8

        for _, addon in ipairs(missing) do
            AddRow(addon, false)
        end

        local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", leftX, yPos)
        hint:SetPoint("TOPRIGHT", -leftX, yPos)
        hint:SetJustifyH("LEFT")
        hint:SetText("Get these with the Peavers Updater app or from CurseForge — |cff" .. accentHex .. "addons.peavers.io|r")
        hint:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
        table.insert(elements, hint)
        yPos = yPos - (hint:GetStringHeight() + 25)
    end

    if #have > 0 then
        local header, headerY = W:CreateSectionHeader(panel, "INSTALLED (" .. #have .. ")", leftX, yPos)
        table.insert(elements, header)
        yPos = headerY - 8

        for _, addon in ipairs(have) do
            AddRow(addon, true)
        end
    end

    panel:SetHeight(math.abs(yPos) + 20)
end

return AddonsPanel
