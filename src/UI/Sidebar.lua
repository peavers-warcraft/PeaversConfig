local _, PC = ...

PC.Sidebar = {}
local Sidebar = PC.Sidebar

local PeaversCommons = _G.PeaversCommons

local SIDEBAR_WIDTH = 180
local HEADER_HEIGHT = 40
local ITEM_HEIGHT = 28
local SECTION_SPACING = 10

local sidebarFrame = nil
local selectedAddon = nil
local selectedSection = nil
local buttons = {}
local decorations = {}

function Sidebar:Create(parent)
    local W = PC.Widgets
    local C = W.Colors

    sidebarFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    sidebarFrame:SetPoint("TOPLEFT", 2, -(HEADER_HEIGHT + 2))
    sidebarFrame:SetPoint("BOTTOMLEFT", 2, 2)
    sidebarFrame:SetWidth(SIDEBAR_WIDTH)
    sidebarFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    sidebarFrame:SetBackdropColor(C.bgNested[1], C.bgNested[2], C.bgNested[3], 1)

    -- Right border
    local rightBorder = sidebarFrame:CreateTexture(nil, "ARTWORK")
    rightBorder:SetPoint("TOPRIGHT", 0, 0)
    rightBorder:SetPoint("BOTTOMRIGHT", 0, 0)
    rightBorder:SetWidth(1)
    rightBorder:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

    self.frame = sidebarFrame
    self:Refresh()

    return sidebarFrame
end

function Sidebar:Refresh()
    local W = PC.Widgets
    local C = W.Colors

    for _, btn in pairs(buttons) do
        btn:Hide()
        btn:SetParent(nil)
    end
    buttons = {}

    for _, deco in ipairs(decorations) do
        deco:Hide()
    end
    decorations = {}

    if not sidebarFrame then return end

    local yOffset = -10
    local addons = PeaversCommons.ConfigRegistry:GetSortedAddons()

    -- Addon section header
    local addonHeader = sidebarFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    addonHeader:SetPoint("TOPLEFT", 12, yOffset)
    addonHeader:SetText("ADDONS")
    addonHeader:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    table.insert(decorations, addonHeader)
    yOffset = yOffset - 18

    -- Addon buttons
    for _, info in ipairs(addons) do
        local btn = self:CreateButton(sidebarFrame, info.displayName, yOffset, function()
            self:Select(info.name)
        end)
        btn.addonName = info.name
        buttons[info.name] = btn
        yOffset = yOffset - ITEM_HEIGHT
    end

    -- Separator
    yOffset = yOffset - SECTION_SPACING
    local sep = sidebarFrame:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 12, yOffset)
    sep:SetPoint("TOPRIGHT", -12, yOffset)
    sep:SetHeight(1)
    sep:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.5)
    table.insert(decorations, sep)
    yOffset = yOffset - SECTION_SPACING

    -- Fixed section buttons
    local sections = {
        { key = "profiles", label = "Profiles" },
        { key = "appearance", label = "Global Appearance" },
        { key = "changelog", label = "What's New" },
        { key = "about", label = "About" },
    }

    for _, sec in ipairs(sections) do
        local btn = self:CreateButton(sidebarFrame, sec.label, yOffset, function()
            self:SelectSection(sec.key)
        end)
        btn.sectionKey = sec.key
        buttons["_section_" .. sec.key] = btn
        yOffset = yOffset - ITEM_HEIGHT
    end

    self:UpdateSelection()
end

function Sidebar:CreateButton(parent, text, yOffset, onClick)
    local W = PC.Widgets
    local C = W.Colors

    local btn = CreateFrame("Button", nil, parent)
    btn:SetPoint("TOPLEFT", 4, yOffset)
    btn:SetPoint("TOPRIGHT", -4, yOffset)
    btn:SetHeight(ITEM_HEIGHT)

    local highlight = btn:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints()
    highlight:SetColorTexture(C.highlight[1], C.highlight[2], C.highlight[3], C.highlight[4])
    highlight:Hide()
    btn.highlight = highlight

    local selectedBg = btn:CreateTexture(nil, "BACKGROUND")
    selectedBg:SetAllPoints()
    selectedBg:SetColorTexture(C.selected[1], C.selected[2], C.selected[3], C.selected[4])
    selectedBg:Hide()
    btn.selectedBg = selectedBg

    -- Left accent bar for selected state
    local accentBar = btn:CreateTexture(nil, "OVERLAY")
    accentBar:SetPoint("TOPLEFT", 0, 0)
    accentBar:SetPoint("BOTTOMLEFT", 0, 0)
    accentBar:SetWidth(3)
    accentBar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    accentBar:Hide()
    btn.accentBar = accentBar

    local label = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", 12, 0)
    label:SetText(text)
    label:SetJustifyH("LEFT")
    label:SetTextColor(C.textSec[1], C.textSec[2], C.textSec[3])
    btn.label = label

    btn:SetScript("OnEnter", function(self)
        if not self.isSelected then
            self.highlight:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        self.highlight:Hide()
    end)
    btn:SetScript("OnClick", onClick)

    return btn
end

function Sidebar:Select(addonName)
    selectedAddon = addonName
    selectedSection = nil
    self:UpdateSelection()

    if PC.ContentArea then
        PC.ContentArea:ShowAddon(addonName)
    end

    PC.WindowState:Set("lastAddon", addonName)
end

function Sidebar:SelectSection(sectionKey)
    selectedSection = sectionKey
    selectedAddon = nil
    self:UpdateSelection()

    if PC.ContentArea then
        PC.ContentArea:ShowSection(sectionKey)
    end
end

function Sidebar:UpdateSelection()
    local W = PC.Widgets
    local C = W.Colors

    for key, btn in pairs(buttons) do
        if btn.addonName and btn.addonName == selectedAddon then
            btn.isSelected = true
            btn.selectedBg:Show()
            btn.accentBar:Show()
            btn.label:SetTextColor(C.accentLight[1], C.accentLight[2], C.accentLight[3])
        elseif btn.sectionKey and btn.sectionKey == selectedSection then
            btn.isSelected = true
            btn.selectedBg:Show()
            btn.accentBar:Show()
            btn.label:SetTextColor(C.accentLight[1], C.accentLight[2], C.accentLight[3])
        else
            btn.isSelected = false
            btn.selectedBg:Hide()
            btn.accentBar:Hide()
            btn.label:SetTextColor(C.textSec[1], C.textSec[2], C.textSec[3])
        end
    end
end

function Sidebar:GetSelected()
    return selectedAddon or selectedSection
end

function Sidebar:GetFrame()
    return sidebarFrame
end

return Sidebar
