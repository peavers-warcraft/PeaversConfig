local _, PC = ...

PC.ContentArea = {}
local ContentArea = PC.ContentArea

local PeaversCommons = _G.PeaversCommons
local Style = PC.Style

local INSET = Style.Pad.content

local SIDEBAR_WIDTH = 180
local HEADER_HEIGHT = 40
local TAB_BAR_HEIGHT = 30
local SCROLL_WIDTH = 6
local SCROLL_STEP = 30

local contentFrame = nil
local scrollFrame = nil ---@type ScrollFrame
local scrollChild = nil ---@type Frame
local scrollTrack = nil ---@type Frame
local scrollThumb = nil
local cachedPanels = {}
local cachedTabData = {}
local currentPanel = nil
local currentTabBar = nil
local currentAddonName = nil
local resizeTimer = nil

local function UpdateScrollThumb()
    if not scrollTrack or not scrollThumb then return end

    local activeChild = scrollFrame:GetScrollChild()
    if not activeChild then return end

    local contentHeight = activeChild:GetHeight() or 1
    local frameHeight = scrollFrame:GetHeight() or 1
    local trackHeight = scrollTrack:GetHeight() or 1

    if contentHeight <= frameHeight then
        scrollThumb:Hide()
        scrollTrack:Hide()
        scrollFrame:SetPoint("BOTTOMRIGHT", -4, 4)
        return
    end

    scrollTrack:Show()
    scrollThumb:Show()
    scrollFrame:SetPoint("BOTTOMRIGHT", -(SCROLL_WIDTH + 8), 4)

    local thumbHeight = math.max(20, (frameHeight / contentHeight) * trackHeight)
    scrollThumb:SetHeight(thumbHeight)

    local maxScroll = contentHeight - frameHeight
    local currentScroll = scrollFrame:GetVerticalScroll()
    local scrollPercent = currentScroll / maxScroll
    local maxThumbOffset = trackHeight - thumbHeight
    local thumbOffset = scrollPercent * maxThumbOffset

    scrollThumb:ClearAllPoints()
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -thumbOffset)
end

function ContentArea:Create(parent)
    local W = PC.Widgets
    local C = W.Colors

    contentFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    contentFrame:SetPoint("TOPLEFT", SIDEBAR_WIDTH + 3, -(HEADER_HEIGHT + 2))
    contentFrame:SetPoint("BOTTOMRIGHT", -2, 2)
    contentFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    -- Fully opaque: content sits on flat paper, not a tinted wash over the window.
    contentFrame:SetBackdropColor(C.bgBase[1], C.bgBase[2], C.bgBase[3], 1)

    scrollFrame = CreateFrame("ScrollFrame", "PeaversConfigScrollFrame", contentFrame)
    scrollFrame:SetPoint("TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", -(SCROLL_WIDTH + 8), 4)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:SetScript("OnSizeChanged", function(_, width, height)
        scrollChild:SetWidth(width)
    end)

    scrollFrame:SetScript("OnScrollRangeChanged", function()
        UpdateScrollThumb()
    end)

    -- Custom scroll track
    scrollTrack = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate") --[[@as Frame]]
    scrollTrack:SetWidth(SCROLL_WIDTH)
    scrollTrack:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", -4, -4)
    scrollTrack:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -4, 4)
    scrollTrack:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    })
    -- Transparent track, as on the site; only the thumb is visible.
    scrollTrack:SetBackdropColor(0, 0, 0, 0)

    -- Custom scroll thumb
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

    -- Mouse wheel scrolling
    contentFrame:EnableMouseWheel(true)
    contentFrame:SetScript("OnMouseWheel", function(_, delta)
        local maxScroll = scrollFrame:GetVerticalScrollRange()
        local currentScroll = scrollFrame:GetVerticalScroll()
        local newScroll = math.max(0, math.min(maxScroll, currentScroll - (delta * SCROLL_STEP)))
        scrollFrame:SetVerticalScroll(newScroll)
        UpdateScrollThumb()
    end)

    -- Thumb dragging — use a fullscreen overlay to capture mouse even when cursor leaves the thumb
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

        local activeChild = scrollFrame:GetScrollChild()
        if not activeChild then return end

        local contentHeight = activeChild:GetHeight() or 1
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

    -- Track click to jump
    scrollTrack:EnableMouse(true)
    scrollTrack:SetScript("OnMouseDown", function(track, button)
        if button == "LeftButton" then
            local activeChild = scrollFrame:GetScrollChild()
            if not activeChild then return end

            local _, cursorY = GetCursorPosition()
            cursorY = cursorY / UIParent:GetEffectiveScale()
            local trackTop = track:GetTop()
            local clickOffset = trackTop - cursorY

            local contentHeight = activeChild:GetHeight() or 1
            local frameHeight = scrollFrame:GetHeight() or 1
            local trackHeight = track:GetHeight() or 1
            local maxScroll = math.max(0, contentHeight - frameHeight)

            local scrollPercent = clickOffset / trackHeight
            local newScroll = math.max(0, math.min(maxScroll, scrollPercent * maxScroll))
            scrollFrame:SetVerticalScroll(newScroll)
            UpdateScrollThumb()
        end
    end)

    self.frame = contentFrame
    self.scrollFrame = scrollFrame
    self.scrollChild = scrollChild

    return contentFrame
end

function ContentArea:ShowAddon(addonName)
    self:HideCurrentPanel()
    self:HideTabBar()
    currentAddonName = addonName

    local info = PeaversCommons.ConfigRegistry:GetAddon(addonName)
    if not info then
        self:ShowMessage("Addon '" .. addonName .. "' not found in registry.")
        return
    end

    if info.pages then
        self:ShowTabbedAddon(addonName, info)
        return
    end

    if cachedPanels[addonName] then
        cachedPanels[addonName]:Show()
        currentPanel = cachedPanels[addonName]
        scrollFrame:SetScrollChild(currentPanel)
        return
    end

    if info.buildPanel then
        local panel = CreateFrame("Frame", nil, scrollFrame)
        panel:SetWidth(scrollChild:GetWidth())
        panel:SetHeight(1)

        local success, err = pcall(info.buildPanel, panel)
        if success then
            cachedPanels[addonName] = panel
            currentPanel = panel
            scrollFrame:SetScrollChild(panel)
        else
            panel:Hide()
            self:ShowMessage("Error loading settings for " .. (info.displayName or addonName) .. ":\n" .. tostring(err))
        end
    else
        self:ShowMessage("No settings panel available for " .. (info.displayName or addonName))
    end
end

function ContentArea:ShowTabbedAddon(addonName, info)
    local W = PC.Widgets

    if not cachedTabData[addonName] then
        cachedTabData[addonName] = { pages = {}, selectedKey = info.pages[1].key }
    end

    local tabData = cachedTabData[addonName]

    local tabBar = W:CreateTabBar(contentFrame, info.pages, {
        height = TAB_BAR_HEIGHT,
        onChange = function(key)
            self:ShowTabPage(addonName, info, key)
        end,
    })
    tabBar:SetPoint("TOPLEFT", 4, -4)
    tabBar:SetPoint("TOPRIGHT", -(SCROLL_WIDTH + 8), -4)
    currentTabBar = tabBar

    scrollFrame:SetPoint("TOPLEFT", 4, -(TAB_BAR_HEIGHT + 5))
    scrollTrack:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", -4, -(TAB_BAR_HEIGHT + 5))

    if tabData.selectedKey then
        tabBar:Select(tabData.selectedKey)
    end

    self:ShowTabPage(addonName, info, tabData.selectedKey or info.pages[1].key)
end

function ContentArea:ShowTabPage(addonName, info, pageKey)
    local tabData = cachedTabData[addonName]
    tabData.selectedKey = pageKey

    if currentPanel then
        currentPanel:Hide()
        currentPanel = nil
    end

    if tabData.pages[pageKey] then
        tabData.pages[pageKey]:Show()
        currentPanel = tabData.pages[pageKey]
        scrollFrame:SetScrollChild(currentPanel)
        scrollFrame:SetVerticalScroll(0)
        return
    end

    local page = nil
    for _, p in ipairs(info.pages) do
        if p.key == pageKey then
            page = p
            break
        end
    end

    if not page or not page.builder then return end

    local panel = CreateFrame("Frame", nil, scrollFrame)
    panel:SetWidth(scrollChild:GetWidth())
    panel:SetHeight(1)

    local success, err = pcall(page.builder, panel)
    if success then
        tabData.pages[pageKey] = panel
        currentPanel = panel
        scrollFrame:SetScrollChild(panel)
        scrollFrame:SetVerticalScroll(0)
    else
        panel:Hide()
        self:ShowMessage("Error loading page '" .. (page.label or pageKey) .. "':\n" .. tostring(err))
    end
end

function ContentArea:HideTabBar()
    if currentTabBar then
        currentTabBar:Hide()
        currentTabBar = nil
        scrollFrame:SetPoint("TOPLEFT", 4, -4)
        scrollTrack:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", -4, -4)
    end
end

function ContentArea:ShowSection(sectionKey)
    self:HideCurrentPanel()
    self:HideTabBar()
    currentAddonName = nil

    if sectionKey == "profiles" then
        if PC.ProfilePanel then
            local panel = PC.ProfilePanel:GetOrCreatePanel(scrollFrame)
            currentPanel = panel
            scrollFrame:SetScrollChild(panel)
        end
    elseif sectionKey == "browse" then
        self:ShowBrowse()
    elseif sectionKey == "appearance" then
        self:ShowGlobalAppearance()
    elseif sectionKey == "support" then
        self:ShowSupport()
    elseif sectionKey == "changelog" then
        self:ShowChangelog()
    elseif sectionKey == "about" then
        self:ShowAbout()
    end
end

function ContentArea:ShowGlobalAppearance()
    if cachedPanels["_appearance"] then
        cachedPanels["_appearance"]:Hide()
        cachedPanels["_appearance"] = nil
    end

    if PC.AppearancePanel then
        local panel = PC.AppearancePanel:GetOrCreatePanel(scrollFrame)
        cachedPanels["_appearance"] = panel
        currentPanel = panel
        scrollFrame:SetScrollChild(panel)
    end
end

function ContentArea:ShowChangelog()
    if cachedPanels["_changelog"] then
        cachedPanels["_changelog"]:Show()
        currentPanel = cachedPanels["_changelog"]
        scrollFrame:SetScrollChild(currentPanel)
        return
    end

    local panel = CreateFrame("Frame", nil, scrollFrame)
    panel:SetWidth(scrollChild:GetWidth())
    panel:SetHeight(600)

    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", INSET, -INSET)
    content:SetPoint("TOPRIGHT", -INSET, -INSET)
    content:SetHeight(1)

    local width = (panel:GetWidth() or 0) - (INSET * 2)
    if width < 100 then width = 360 end

    local y = 0

    local title = Style.Label(content, "What's New", Style.Size.hero, Style.Alpha.primary)
    title:SetPoint("TOPLEFT", 0, y)
    y = y - Style.Size.hero - Style.Pad.gap

    local changelogs = _G.PeaversChangelogs
    local sortedAddons = {}
    if changelogs then
        for name, data in pairs(changelogs) do
            if data.entries and #data.entries > 0 then
                table.insert(sortedAddons, { name = name, data = data })
            end
        end
        table.sort(sortedAddons, function(a, b) return a.name < b.name end)
    end

    if #sortedAddons == 0 then
        local text = (changelogs and next(changelogs))
            and "All addons are up to date - no recent changes to show."
            or "No changelog data yet. Entries appear here after your next addon update."
        local empty, emptyHeight = Style.Paragraph(content, text, width, Style.Alpha.muted)
        empty:SetPoint("TOPLEFT", 0, y)
        y = y - emptyHeight
    else
        for _, addon in ipairs(sortedAddons) do
            y = Style.Section(content,
                addon.name:gsub("^Peavers", "") .. "  v" .. (addon.data.version or ""),
                y, width)

            -- NEW or FIX marked by alpha rather than by two colours. It is a
            -- category, not a state, and the accent is spent on state alone.
            -- The row grows to hold the entry instead of clipping it: a
            -- changelog line is a sentence, not a label.
            for _, entry in ipairs(addon.data.entries) do
                local isFeature = (entry.type == "feature")
                local row = Style.MakeRow(content, y, width)

                local marker = Style.Label(row, isFeature and "NEW" or "FIX",
                    Style.Size.meta,
                    isFeature and Style.Alpha.primary or Style.Alpha.muted)
                marker:SetPoint("TOPRIGHT", -Style.Row.inset, -10)

                local text, textHeight = Style.Paragraph(row, entry.text,
                    width - (Style.Row.inset * 2) - 44, Style.Alpha.secondary)
                text:SetPoint("TOPLEFT", Style.Row.inset, -9)

                local height = math.max(Style.Row.height, textHeight + 18)
                row:SetHeight(height)
                y = y - height
            end
        end
    end

    panel:SetHeight(INSET + math.abs(y) + INSET)

    cachedPanels["_changelog"] = panel
    currentPanel = panel
    scrollFrame:SetScrollChild(panel)
end

function ContentArea:ShowAbout()
    if cachedPanels["_about"] then
        cachedPanels["_about"]:Show()
        currentPanel = cachedPanels["_about"]
        scrollFrame:SetScrollChild(currentPanel)
        return
    end

    local panel = CreateFrame("Frame", nil, scrollFrame)
    panel:SetWidth(scrollChild:GetWidth())
    panel:SetHeight(600)

    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", INSET, -INSET)
    content:SetPoint("TOPRIGHT", -INSET, -INSET)
    content:SetHeight(1)

    local width = (panel:GetWidth() or 0) - (INSET * 2)
    if width < 100 then width = 360 end

    local y = 0

    local title = Style.Label(content, "Peavers Addons", Style.Size.hero, Style.Alpha.primary)
    title:SetPoint("TOPLEFT", 0, y)
    y = y - Style.Size.hero - Style.Pad.gap

    local desc, descHeight = Style.Paragraph(content,
        "Centralized configuration for all Peavers addons. If you enjoy them and want " ..
        "to support their development, or you need help, stop by the website.", width)
    desc:SetPoint("TOPLEFT", 0, y)
    y = y - descHeight - Style.Pad.gap

    -- Label on the left, value on the right: exactly the shape Style.RowText is
    -- for, and the reason these stop being hand-spaced strings with colour
    -- escapes baked into them.
    y = Style.Section(content, "Info", y, width)

    local addonCount = PeaversCommons.ConfigRegistry:GetAddonCount()
    local infoRows = {
        { "Version", PC.version or "1.0.0" },
        { "Website", "peavers.io" },
        { "Registered addons", tostring(addonCount) },
    }
    for _, pair in ipairs(infoRows) do
        local row, nextY = Style.MakeRow(content, y, width)
        Style.RowText(row, pair[1], pair[2])
        y = nextY
    end

    y = Style.Section(content, "parses.gg", y, width)
    do
        local row, nextY = Style.MakeRow(content, y, width)
        Style.RowText(row, "Open combat logs, free to download", "parses.gg",
            { valueAlpha = Style.Alpha.primary })
        y = nextY
    end

    y = Style.Section(content, "UI Vault", y, width)
    do
        local row, nextY = Style.MakeRow(content, y, width)
        Style.RowText(row, "Backup and restore every WoW addon", "vault.peavers.io",
            { valueAlpha = Style.Alpha.primary })
        y = nextY
    end

    -- Patron names keep their own colours: those are earned marks rather than
    -- this window's palette, so the system does not get a vote.
    local Patrons = PeaversCommons.Patrons
    if Patrons and Patrons.GetSorted then
        local allPatrons = Patrons:GetSorted()
        if #allPatrons > 0 then
            y = Style.Section(content, "Patrons", y, width)

            local patronLines = {}
            for _, patron in ipairs(allPatrons) do
                table.insert(patronLines, Patrons:GetColoredName(patron))
            end

            local patronList = Style.Label(content, table.concat(patronLines, "\n"),
                Style.Size.value, Style.Alpha.primary, { width = width, wrap = true })
            patronList:SetSpacing(4)
            patronList:SetPoint("TOPLEFT", 0, y)
            y = y - ((patronList:GetStringHeight() or 0) + Style.Pad.gap)
        end
    end

    y = y - Style.Pad.section

    local thanks = Style.Label(content, "Thank you for using Peavers addons.",
        Style.Size.value, Style.Alpha.muted)
    thanks:SetPoint("TOPLEFT", 0, y)
    y = y - Style.Size.value - Style.Pad.gap

    panel:SetHeight(INSET + math.abs(y) + INSET)

    cachedPanels["_about"] = panel
    currentPanel = panel
    scrollFrame:SetScrollChild(panel)
end

function ContentArea:ShowBrowse()
    if cachedPanels["_browse"] then
        cachedPanels["_browse"]:Hide()
        cachedPanels["_browse"] = nil
    end

    if PC.AddonsPanel then
        local panel = PC.AddonsPanel:GetOrCreatePanel(scrollFrame)
        cachedPanels["_browse"] = panel
        currentPanel = panel
        scrollFrame:SetScrollChild(panel)
        scrollFrame:SetVerticalScroll(0)
    end
end

function ContentArea:ShowSupport()
    if cachedPanels["_support"] then
        cachedPanels["_support"]:Hide()
        cachedPanels["_support"] = nil
    end

    if PC.SupportPanel then
        local panel = PC.SupportPanel:GetOrCreatePanel(scrollFrame)
        cachedPanels["_support"] = panel
        currentPanel = panel
        scrollFrame:SetScrollChild(panel)
    end
end

function ContentArea:ShowMessage(text)
    local panel = CreateFrame("Frame", nil, scrollFrame)
    panel:SetWidth(scrollChild:GetWidth())
    panel:SetHeight(200)

    local width = (panel:GetWidth() or 0) - (INSET * 2)
    if width < 100 then width = 360 end

    local msg = Style.Paragraph(panel, text, width, Style.Alpha.secondary)
    msg:SetPoint("TOPLEFT", INSET, -(INSET + Style.Pad.gap))

    currentPanel = panel
    scrollFrame:SetScrollChild(panel)
end

function ContentArea:HideCurrentPanel()
    if currentPanel then
        currentPanel:Hide()
        currentPanel = nil
    end
end

function ContentArea:OnResize()
    if scrollChild then
        scrollChild:SetWidth(scrollFrame:GetWidth())
    end
    if currentPanel then
        currentPanel:SetWidth(scrollFrame:GetWidth())
    end

    -- Debounced rebuild: invalidate cache and rebuild current page after resize settles
    if resizeTimer then resizeTimer:Cancel() end
    resizeTimer = C_Timer.NewTimer(0.15, function()
        resizeTimer = nil
        if not currentAddonName then return end
        self:InvalidateCache(currentAddonName)
        self:ShowAddon(currentAddonName)
    end)
end

function ContentArea:GetFrame()
    return contentFrame
end

function ContentArea:InvalidateCache(addonName)
    if addonName then
        if cachedPanels[addonName] then
            cachedPanels[addonName]:Hide()
            cachedPanels[addonName] = nil
        end
        if cachedTabData[addonName] then
            for _, panel in pairs(cachedTabData[addonName].pages) do
                panel:Hide()
            end
            cachedTabData[addonName] = nil
        end
    else
        for key, panel in pairs(cachedPanels) do
            panel:Hide()
        end
        cachedPanels = {}
        for key, data in pairs(cachedTabData) do
            for _, panel in pairs(data.pages) do
                panel:Hide()
            end
        end
        cachedTabData = {}
    end
end

return ContentArea
