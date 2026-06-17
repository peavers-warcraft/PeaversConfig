local _, PC = ...

PC.AppearancePanel = {}
local AppearancePanel = PC.AppearancePanel

local PeaversCommons = _G.PeaversCommons

local panel = nil
local elements = {}

local SYNC_KEYS = {
    "barHeight", "barSpacing", "barAlpha", "barBgAlpha", "textAlpha", "barTexture",
    "fontFace", "fontSize", "fontOutline", "fontShadow",
    "bgAlpha", "bgColor", "showTitleBar",
}

function AppearancePanel:GetOrCreatePanel(parent)
    if panel then
        panel:Show()
        self:Refresh()
        return panel
    end

    panel = CreateFrame("Frame", nil, parent)
    panel:SetWidth(parent:GetWidth())
    panel:SetHeight(800)

    self:RegisterPopups()
    self:Refresh()

    return panel
end

function AppearancePanel:RegisterPopups()
    StaticPopupDialogs["PEAVERSCONFIG_SYNC_APPEARANCE"] = {
        text = "Sync appearance from '%s' to all other addons?\n\nThis will copy font, bar texture, sizes, and background settings.",
        button1 = "Sync",
        button2 = "Cancel",
        OnAccept = function(_, data)
            AppearancePanel:SyncFromAddon(data)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

function AppearancePanel:SyncFromAddon(sourceAddonName)
    local registry = PeaversCommons.ConfigRegistry
    if not registry then return end

    local sourceInfo = registry:GetAddon(sourceAddonName)
    if not sourceInfo or not sourceInfo.config then return end

    local sourceConfig = sourceInfo.config
    local addons = registry:GetRegisteredAddons()

    for addonName, info in pairs(addons) do
        if addonName ~= sourceAddonName and info.config then
            self:CopyAppearance(sourceConfig, info.config)
        end
    end

    print("|cff00ff00PeaversConfig:|r Synced appearance from " .. (sourceInfo.displayName or sourceAddonName) .. " to all addons.")
    self:Refresh()
end

function AppearancePanel:CopyAppearance(sourceConfig, targetConfig)
    for _, key in ipairs(SYNC_KEYS) do
        local value = sourceConfig[key]
        if value ~= nil then
            if type(value) == "table" then
                targetConfig[key] = self:DeepCopy(value)
            else
                targetConfig[key] = value
            end
        end
    end
    if targetConfig.Save then
        targetConfig:Save()
    end
end

function AppearancePanel:DeepCopy(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = self:DeepCopy(v)
    end
    return copy
end

function AppearancePanel:GetAddonAppearanceSummary(config)
    if not config then return "N/A" end
    local parts = {}
    if config.fontFace then
        local fontName = config.fontFace:match("([^\\]+)%.[Tt][Tt][Ff]$") or config.fontFace:match("([^\\]+)$") or "Default"
        table.insert(parts, fontName)
    end
    if config.fontSize then
        table.insert(parts, config.fontSize .. "pt")
    end
    if config.barHeight then
        table.insert(parts, "bar:" .. config.barHeight .. "px")
    end
    return table.concat(parts, ", ")
end

function AppearancePanel:Refresh()
    if not panel then return end

    for _, el in ipairs(elements) do
        if el.Hide then el:Hide() end
        if el.SetParent then el:SetParent(nil) end
    end
    elements = {}

    local W = PC.Widgets
    local C = W.Colors
    local registry = PeaversCommons.ConfigRegistry
    if not registry then return end

    local addons = registry:GetSortedAddons()
    local yPos = -20
    local leftX = 25

    -- ========================================
    -- Title
    -- ========================================

    local title = W:CreateLabel(panel, "Global Appearance", { color = C.gold, size = 20, outline = "OUTLINE" })
    title:SetPoint("TOPLEFT", leftX, yPos)
    table.insert(elements, title)
    yPos = yPos - 28

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    desc:SetPoint("TOPLEFT", leftX, yPos)
    desc:SetPoint("TOPRIGHT", -25, yPos)
    desc:SetJustifyH("LEFT")
    desc:SetText("Copy appearance settings (fonts, bar textures, sizes, backgrounds) from one addon to all others.")
    desc:SetTextColor(C.textSec[1], C.textSec[2], C.textSec[3])
    table.insert(elements, desc)
    yPos = yPos - 35

    -- ========================================
    -- Sync to All section
    -- ========================================

    local _, syncHeaderY = W:CreateSectionHeader(panel, "SYNC SOURCE", leftX, yPos)
    yPos = syncHeaderY - 5
    table.insert(elements, _)

    local syncDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    syncDesc:SetPoint("TOPLEFT", leftX, yPos)
    syncDesc:SetText("Pick a source — its appearance will be copied to every other addon.")
    syncDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    table.insert(elements, syncDesc)
    yPos = yPos - 22

    for _, addonInfo in ipairs(addons) do
        if addonInfo.config then
            local row = W:CreatePanel(panel, { bg = C.bgNested })
            row:SetPoint("TOPLEFT", leftX, yPos)
            row:SetPoint("TOPRIGHT", -25, yPos)
            row:SetHeight(36)
            table.insert(elements, row)

            local nameText = W:CreateLabel(row, addonInfo.displayName or addonInfo.name, { color = C.text })
            nameText:SetPoint("LEFT", 12, 0)

            local summary = W:CreateLabel(row, self:GetAddonAppearanceSummary(addonInfo.config), {
                color = C.textMuted,
                font = "GameFontNormalSmall",
            })
            summary:SetPoint("LEFT", nameText, "RIGHT", 12, 0)

            local addonName = addonInfo.name
            local displayName = addonInfo.displayName or addonInfo.name
            local syncBtn = W:CreateButton(row, "Sync to All", {
                variant = "primary",
                width = 90,
                height = 22,
                onClick = function()
                    local dialog = StaticPopup_Show("PEAVERSCONFIG_SYNC_APPEARANCE", displayName)
                    if dialog then
                        dialog.data = addonName
                    end
                end,
            })
            syncBtn:SetPoint("RIGHT", -8, 0)

            yPos = yPos - 40
        end
    end

    yPos = yPos - 15

    -- ========================================
    -- What gets synced
    -- ========================================

    local _, infoHeaderY = W:CreateSectionHeader(panel, "WHAT GETS SYNCED", leftX, yPos)
    yPos = infoHeaderY - 8
    table.insert(elements, _)

    local syncItems = {
        "Font face, size, and outline style",
        "Bar height, spacing, and opacity",
        "Background color and transparency",
        "Bar texture",
        "Title bar visibility",
    }

    for _, item in ipairs(syncItems) do
        local bullet = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        bullet:SetPoint("TOPLEFT", leftX + 10, yPos)
        bullet:SetText("|cff" .. string.format("%02x%02x%02x",
            C.accent[1] * 255, C.accent[2] * 255, C.accent[3] * 255) .. "•|r  " .. item)
        bullet:SetTextColor(C.textSec[1], C.textSec[2], C.textSec[3])
        table.insert(elements, bullet)
        yPos = yPos - 18
    end

    yPos = yPos - 10
    panel:SetHeight(math.abs(yPos) + 50)
end

return AppearancePanel
