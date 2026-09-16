local _, PC = ...

PC.Sidebar = {}
local Sidebar = PC.Sidebar

local PeaversCommons = _G.PeaversCommons

local Style = PC.Style

local SIDEBAR_WIDTH = 180
local HEADER_HEIGHT = 40
-- One row height across the whole window, taken from the shared system rather
-- than restated here: a nav row and a list row inside a panel are the same
-- object and should not be two pixels different.
local ITEM_HEIGHT = Style.Row.height
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

    -- The rule separating the sidebar from the content pane. Chrome weight,
    -- because it is the window's own structure rather than a divider inside a
    -- panel, and vertical so it gets the same no-snap treatment every other
    -- hairline gets.
    local rightBorder = Style.Hairline(sidebarFrame, Style.Rule.chrome, true)
    rightBorder:SetPoint("TOPRIGHT", 0, 0)
    rightBorder:SetPoint("BOTTOMRIGHT", 0, 0)

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

    -- A section heading in the shared vocabulary: small, uppercase, muted. The
    -- indigo eyebrow this replaces spent the accent on a label that reads the
    -- same on every screen, which is what stops the accent meaning anything
    -- where it does carry state.
    local addonHeader = Style.Label(scrollChild, "ADDONS",
        Style.Size.section, Style.Alpha.muted)
    addonHeader:SetPoint("TOPLEFT", 12, yOffset)
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
    local sep = Style.Hairline(scrollChild, Style.Rule.section)
    sep:SetPoint("TOPLEFT", 12, yOffset)
    sep:SetPoint("TOPRIGHT", -12, yOffset)
    table.insert(decorations, sep)
    yOffset = yOffset - SECTION_SPACING

    -- Fixed section buttons
    local sections = {
        { key = "browse", label = "All Addons" },
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

    -- Hover and selection are both plain white overlays at different alphas, so
    -- they can never be mistaken for one another the way a pair of tinted fills
    -- can.
    local highlight = btn:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, Style.Row.hover)
    highlight:Hide()
    btn.highlight = highlight

    local selectedBg = btn:CreateTexture(nil, "BACKGROUND")
    selectedBg:SetAllPoints()
    selectedBg:SetColorTexture(1, 1, 1, Style.Row.selected)
    selectedBg:Hide()
    btn.selectedBg = selectedBg

    -- Selection is the accent bar down the left edge and nothing else - the same
    -- mark every list in the collection now uses.
    --
    -- This replaces an indigo dot, which was a deliberate choice here rather than
    -- an oversight: it matched peavers.io. It is going because one vocabulary
    -- across every window is worth more than a nod to the site in one of them.
    local accentBar = btn:CreateTexture(nil, "OVERLAY")
    accentBar:SetPoint("TOPLEFT", 0, 0)
    accentBar:SetPoint("BOTTOMLEFT", 0, 0)
    accentBar:SetWidth(Style.Row.bar)
    accentBar:SetColorTexture(Style.Accent[1], Style.Accent[2], Style.Accent[3], 1)
    if accentBar.SetSnapToPixelGrid then
        accentBar:SetSnapToPixelGrid(false)
        accentBar:SetTexelSnappingBias(0)
    end
    accentBar:Hide()
    btn.accentBar = accentBar

    -- Inset from the row's own edge, like every other row in the collection. The
    -- bar is drawn over the same edge rather than beside the text, so the label
    -- does not shift when the row is selected.
    local label = Style.Label(btn, text, Style.Size.label, Style.Alpha.secondary)
    label:SetPoint("LEFT", Style.Row.inset, 0)
    label:SetJustifyH("LEFT")
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

    -- The selected row brightens its label rather than recolouring it. Hierarchy
    -- is alpha: an accent-coloured label would be a second selection signal
    -- competing with the bar, which is the confusion the system exists to stop.
    for _, btn in pairs(buttons) do
        local isSelected = (btn.addonName and btn.addonName == selectedAddon)
            or (btn.sectionKey and btn.sectionKey == selectedSection)

        btn.isSelected = isSelected and true or false
        btn.selectedBg:SetShown(btn.isSelected)
        btn.accentBar:SetShown(btn.isSelected)
        Style.Text(btn.label, Style.Size.label,
            btn.isSelected and Style.Alpha.primary or Style.Alpha.secondary)
    end
end

function Sidebar:GetSelected()
    return selectedAddon or selectedSection
end

function Sidebar:GetFrame()
    return sidebarFrame
end

return Sidebar
