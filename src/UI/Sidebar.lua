local _, PC = ...

PC.Sidebar = {}
local Sidebar = PC.Sidebar

local PeaversCommons = _G.PeaversCommons
local Theme = PeaversCommons.Theme

local SIDEBAR_WIDTH = 180
local HEADER_HEIGHT = 40
local ITEM_HEIGHT = 28
local SECTION_SPACING = 10
local SCROLL_WIDTH = 6
local SCROLL_STEP = 30

local sidebarFrame = nil
local scrollFrame = nil ---@type ScrollFrame
local scrollChild = nil ---@type Frame
local scrollTrack = nil ---@type Frame
local scrollThumb = nil
local selectedAddon = nil
local selectedSection = nil
local buttons = {}
local decorations = {}

local function UpdateScrollThumb()
    if not scrollTrack or not scrollThumb then return end

    local contentHeight = scrollChild:GetHeight() or 1
    local frameHeight = scrollFrame:GetHeight() or 1
    local trackHeight = scrollTrack:GetHeight() or 1

    if contentHeight <= frameHeight then
        scrollThumb:Hide()
        scrollTrack:Hide()
        return
    end

    scrollTrack:Show()
    scrollThumb:Show()

    local thumbHeight = math.max(20, (frameHeight / contentHeight) * trackHeight)
    scrollThumb:SetHeight(thumbHeight)

    local maxScroll = contentHeight - frameHeight
    local scrollPercent = scrollFrame:GetVerticalScroll() / maxScroll
    local thumbOffset = scrollPercent * (trackHeight - thumbHeight)

    scrollThumb:ClearAllPoints()
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -thumbOffset)
end

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
    -- Flat paper, same as the content area; the right hairline is what separates
    -- them. This is the site's structural device rather than a tinted panel.
    sidebarFrame:SetBackdropColor(C.bgBase[1], C.bgBase[2], C.bgBase[3], 1)

    -- Right border
    local rightBorder = sidebarFrame:CreateTexture(nil, "ARTWORK")
    rightBorder:SetPoint("TOPRIGHT", 0, 0)
    rightBorder:SetPoint("BOTTOMRIGHT", 0, 0)
    rightBorder:SetWidth(1)
    rightBorder:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

    scrollFrame = CreateFrame("ScrollFrame", nil, sidebarFrame)
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", -1, 0)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:SetScript("OnSizeChanged", function(_, width)
        scrollChild:SetWidth(width)
        UpdateScrollThumb()
    end)

    scrollFrame:SetScript("OnScrollRangeChanged", function()
        UpdateScrollThumb()
    end)

    -- Custom scroll track and thumb, matching the content area's.
    scrollTrack = CreateFrame("Frame", nil, sidebarFrame, "BackdropTemplate") --[[@as Frame]]
    scrollTrack:SetWidth(SCROLL_WIDTH)
    scrollTrack:SetPoint("TOPRIGHT", sidebarFrame, "TOPRIGHT", -3, -4)
    scrollTrack:SetPoint("BOTTOMRIGHT", sidebarFrame, "BOTTOMRIGHT", -3, 4)
    scrollTrack:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    })
    scrollTrack:SetBackdropColor(0, 0, 0, 0)
    -- Above the buttons inside the scroll child, so the thumb stays visible
    -- and clickable over them.
    scrollTrack:SetFrameLevel(sidebarFrame:GetFrameLevel() + 10)

    scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
    scrollThumb:SetWidth(SCROLL_WIDTH)
    scrollThumb:SetHeight(40)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    })
    scrollThumb:SetBackdropColor(unpack(C.scrollThumb))
    scrollThumb:EnableMouse(true)

    scrollThumb:SetScript("OnEnter", function(thumb)
        thumb:SetBackdropColor(1, 1, 1, 0.30)
    end)
    scrollThumb:SetScript("OnLeave", function(thumb)
        thumb:SetBackdropColor(unpack(C.scrollThumb))
    end)

    sidebarFrame:EnableMouseWheel(true)
    sidebarFrame:SetScript("OnMouseWheel", function(_, delta)
        local maxScroll = scrollFrame:GetVerticalScrollRange()
        local currentScroll = scrollFrame:GetVerticalScroll()
        local newScroll = math.max(0, math.min(maxScroll, currentScroll - (delta * SCROLL_STEP)))
        scrollFrame:SetVerticalScroll(newScroll)
        UpdateScrollThumb()
    end)

    -- Thumb dragging — fullscreen overlay captures the mouse even when the
    -- cursor leaves the thumb mid-drag.
    local isDragging = false
    local dragStartY = 0
    local dragStartScroll = 0

    local dragOverlay = CreateFrame("Frame", nil, UIParent)
    dragOverlay:SetAllPoints(UIParent)
    dragOverlay:SetFrameStrata("TOOLTIP")
    dragOverlay:EnableMouse(true)
    dragOverlay:Hide()

    dragOverlay:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            isDragging = false
            dragOverlay:Hide()
        end
    end)

    dragOverlay:SetScript("OnUpdate", function()
        if not isDragging then return end
        local currentY = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
        local deltaY = dragStartY - currentY

        local contentHeight = scrollChild:GetHeight() or 1
        local frameHeight = scrollFrame:GetHeight() or 1
        local trackHeight = scrollTrack:GetHeight() or 1
        local maxScroll = math.max(0, contentHeight - frameHeight)

        local scrollRatio = maxScroll / math.max(1, trackHeight - scrollThumb:GetHeight())
        local newScroll = math.max(0, math.min(maxScroll, dragStartScroll + (deltaY * scrollRatio)))
        scrollFrame:SetVerticalScroll(newScroll)
        UpdateScrollThumb()
    end)

    scrollThumb:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            isDragging = true
            dragStartY = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
            dragStartScroll = scrollFrame:GetVerticalScroll()
            dragOverlay:Show()
        end
    end)

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

    -- Addon section header, as an indigo eyebrow matching the content panes.
    local addonHeader
    if Theme.UsesCustomFonts() then
        addonHeader = Theme.TrackedLabel(scrollChild, "ADDONS", 10, C.eyebrow)
        addonHeader:SetPoint("TOPLEFT", 12, yOffset)
    else
        addonHeader = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        addonHeader:SetPoint("TOPLEFT", 12, yOffset)
        addonHeader:SetText("ADDONS")
        addonHeader:SetTextColor(unpack(C.eyebrow))
    end
    table.insert(decorations, addonHeader)
    yOffset = yOffset - 18

    -- Addon buttons
    for _, info in ipairs(addons) do
        local btn = self:CreateButton(scrollChild, info.displayName, yOffset, function()
            self:Select(info.name)
        end)
        btn.addonName = info.name
        buttons[info.name] = btn
        yOffset = yOffset - ITEM_HEIGHT
    end

    -- Separator
    yOffset = yOffset - SECTION_SPACING
    local sep = scrollChild:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 12, yOffset)
    sep:SetPoint("TOPRIGHT", -12, yOffset)
    sep:SetHeight(1)
    sep:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    table.insert(decorations, sep)
    yOffset = yOffset - SECTION_SPACING

    -- Fixed section buttons
    local sections = {
        { key = "profiles", label = "Profiles" },
        { key = "appearance", label = "Global Appearance" },
        { key = "support", label = "Support" },
        { key = "changelog", label = "What's New" },
        { key = "about", label = "About" },
    }

    for _, sec in ipairs(sections) do
        local btn = self:CreateButton(scrollChild, sec.label, yOffset, function()
            self:SelectSection(sec.key)
        end)
        btn.sectionKey = sec.key
        buttons["_section_" .. sec.key] = btn
        yOffset = yOffset - ITEM_HEIGHT
    end

    scrollChild:SetHeight(-yOffset + 10)

    -- Clamp in case the list shrank while scrolled down.
    local maxScroll = scrollFrame:GetVerticalScrollRange()
    if scrollFrame:GetVerticalScroll() > maxScroll then
        scrollFrame:SetVerticalScroll(maxScroll)
    end
    UpdateScrollThumb()

    self:UpdateSelection()
end

function Sidebar.CreateButton(_, parent, text, yOffset, onClick)
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

    -- Active marker: the site's indigo dot, replacing the 3px left accent bar.
    local accentBar = btn:CreateTexture(nil, "OVERLAY")
    accentBar:SetPoint("LEFT", 8, 0)
    Theme.Dot(accentBar, 5, C.accent)
    accentBar:Hide()
    btn.accentBar = accentBar

    local label = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    -- Indented past the dot so the label does not shift on selection.
    label:SetPoint("LEFT", 20, 0)
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
