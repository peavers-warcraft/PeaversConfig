local _, PC = ...

PC.AppearancePanel = {}
local AppearancePanel = PC.AppearancePanel

local PeaversCommons = _G.PeaversCommons
local Style = PC.Style

local panel = nil
local content = nil

local INSET = Style.Pad.content

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

    -- One container per build, dropped whole rather than walked. See the note in
    -- SupportPanel: it replaces a hand-kept table of every region made, and gives
    -- the row banding a parent of its own to count against.
    if content then
        content:Hide()
        content:SetParent(nil)
    end

    local registry = PeaversCommons.ConfigRegistry
    if not registry then return end

    content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", INSET, -INSET)
    content:SetPoint("TOPRIGHT", -INSET, -INSET)
    content:SetHeight(1)

    local width = (panel:GetWidth() or 0) - (INSET * 2)
    if width < 100 then width = 360 end

    local addons = registry:GetSortedAddons()
    local y = 0

    local title = Style.Label(content, "Global Appearance", Style.Size.hero, Style.Alpha.primary)
    title:SetPoint("TOPLEFT", 0, y)
    y = y - Style.Size.hero - Style.Pad.gap

    local desc, descHeight = Style.Paragraph(content,
        "Copy appearance settings - fonts, bar textures, sizes, backgrounds - from one " ..
        "addon to all the others.", width)
    desc:SetPoint("TOPLEFT", 0, y)
    y = y - descHeight - Style.Pad.gap

    y = Style.Section(content, "Sync source", y, width)

    local intro, introHeight = Style.Paragraph(content,
        "Pick a source. Its appearance is copied to every other addon.",
        width, Style.Alpha.muted)
    intro:SetPoint("TOPLEFT", 0, y)
    y = y - introHeight - Style.Pad.gap

    -- A banded row per addon rather than a hairline-ruled one. Both are lists on
    -- flat paper; the banding is what makes a run of them read as a table rather
    -- than as separate strips, and it costs no extra chrome.
    for _, addonInfo in ipairs(addons) do
        if addonInfo.config then
            local row, nextY = Style.MakeRow(content, y, width, { height = Style.Row.tall })

            local nameText = Style.Label(row, addonInfo.displayName or addonInfo.name,
                Style.Size.label, Style.Alpha.primary)
            nameText:SetPoint("LEFT", Style.Row.inset, 0)

            local summary = Style.Label(row, self:GetAddonAppearanceSummary(addonInfo.config),
                Style.Size.value, Style.Alpha.muted)
            summary:SetPoint("LEFT", nameText, "RIGHT", 12, 0)

            local addonName = addonInfo.name
            local displayName = addonInfo.displayName or addonInfo.name
            -- Secondary, not primary: the accent marks one main action, never a
            -- control repeated down every row of a list.
            local syncBtn = Style.Button(row, "Sync to All", {
                variant = "secondary",
                width = 96,
                height = 24,
                size = Style.Size.value,
                onClick = function()
                    local dialog = StaticPopup_Show("PEAVERSCONFIG_SYNC_APPEARANCE", displayName)
                    if dialog then
                        dialog.data = addonName
                    end
                end,
            })
            syncBtn:SetPoint("RIGHT", -Style.Row.inset, 0)

            y = nextY
        end
    end

    y = Style.Section(content, "What gets synced", y, width)

    local syncItems = {
        "Font face, size and outline style",
        "Bar height, spacing and opacity",
        "Background colour and transparency",
        "Bar texture",
        "Title bar visibility",
    }

    for _, item in ipairs(syncItems) do
        local row, nextY = Style.MakeRow(content, y, width)
        local label = Style.Label(row, item, Style.Size.value, Style.Alpha.secondary)
        label:SetPoint("LEFT", Style.Row.inset, 0)
        y = nextY
    end

    panel:SetHeight(INSET + math.abs(y) + INSET)
end

return AppearancePanel
