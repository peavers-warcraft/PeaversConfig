local _, PC = ...

PC.ContentArea = {}
local ContentArea = PC.ContentArea

local PeaversCommons = _G.PeaversCommons

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
    contentFrame:SetBackdropColor(C.bgBase[1], C.bgBase[2], C.bgBase[3], 0.6)

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
    scrollTrack:SetBackdropColor(0.1, 0.1, 0.12, 1)

    -- Custom scroll thumb
    scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
    scrollThumb:SetWidth(SCROLL_WIDTH)
    scrollThumb:SetHeight(40)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    })
    scrollThumb:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], C.accent[4])
    scrollThumb:EnableMouse(true)

    scrollThumb:SetScript("OnEnter", function(thumb)
        thumb:SetBackdropColor(C.accentHover[1], C.accentHover[2], C.accentHover[3], C.accentHover[4])
    end)
    scrollThumb:SetScript("OnLeave", function(thumb)
        thumb:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], C.accent[4])
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
    local W = PC.Widgets
    local C = W.Colors

    if cachedPanels["_changelog"] then
        cachedPanels["_changelog"]:Show()
        currentPanel = cachedPanels["_changelog"]
        scrollFrame:SetScrollChild(currentPanel)
        return
    end

    local featureHex = string.format("%02x%02x%02x", C.accent[1] * 255, C.accent[2] * 255, C.accent[3] * 255)
    local fixHex = "aaaaaa"
    local leftX = 25
    local yPos = -20

    local panel = CreateFrame("Frame", nil, scrollFrame)
    panel:SetWidth(scrollChild:GetWidth())
    panel:SetHeight(600)

    local title = W:CreateLabel(panel, "What's New", {
        size = 20,
        outline = "OUTLINE",
        color = C.gold,
    })
    title:SetPoint("TOPLEFT", leftX, yPos)
    yPos = yPos - 10

    local changelogs = _G.PeaversChangelogs
    if not changelogs or not next(changelogs) then
        yPos = yPos - 20
        local noData = W:CreateLabel(panel, "No changelog data available yet. Changelogs will appear here after your next addon update.", { color = C.textMuted })
        noData:SetPoint("TOPLEFT", leftX, yPos)
        noData:SetPoint("TOPRIGHT", -leftX, yPos)
        yPos = yPos - 40
    else
        local sortedAddons = {}
        for name, data in pairs(changelogs) do
            if data.entries and #data.entries > 0 then
                table.insert(sortedAddons, { name = name, data = data })
            end
        end
        table.sort(sortedAddons, function(a, b) return a.name < b.name end)

        if #sortedAddons == 0 then
            yPos = yPos - 20
            local noEntries = W:CreateLabel(panel, "All addons are up to date — no recent changes to show.", { color = C.textMuted })
            noEntries:SetPoint("TOPLEFT", leftX, yPos)
            noEntries:SetPoint("TOPRIGHT", -leftX, yPos)
            yPos = yPos - 40
        else
            for _, addon in ipairs(sortedAddons) do
                yPos = yPos - 18
                _, yPos = W:CreateSectionHeader(panel, addon.name:gsub("^Peavers", "") .. "  v" .. (addon.data.version or ""), leftX, yPos)
                yPos = yPos - 6

                for _, entry in ipairs(addon.data.entries) do
                    local prefix, color
                    if entry.type == "feature" then
                        prefix = "|cff" .. featureHex .. "NEW|r  "
                        color = C.text
                    else
                        prefix = "|cff" .. fixHex .. "FIX|r  "
                        color = C.textSec
                    end

                    local entryLabel = W:CreateLabel(panel, prefix .. entry.text, { color = color })
                    entryLabel:SetPoint("TOPLEFT", leftX + 8, yPos)
                    entryLabel:SetPoint("TOPRIGHT", -leftX, yPos)
                    yPos = yPos - 18
                end

                yPos = yPos - 4
            end
        end
    end

    yPos = yPos - 10
    panel:SetHeight(math.abs(yPos))

    cachedPanels["_changelog"] = panel
    currentPanel = panel
    scrollFrame:SetScrollChild(panel)
end

function ContentArea:ShowAbout()
    local W = PC.Widgets
    local C = W.Colors

    if cachedPanels["_about"] then
        cachedPanels["_about"]:Show()
        currentPanel = cachedPanels["_about"]
        scrollFrame:SetScrollChild(currentPanel)
        return
    end

    local accentHex = string.format("%02x%02x%02x", C.accent[1] * 255, C.accent[2] * 255, C.accent[3] * 255)
    local leftX = 25
    local yPos = -20

    local panel = CreateFrame("Frame", nil, scrollFrame)
    panel:SetWidth(scrollChild:GetWidth())
    panel:SetHeight(600)

    -- Title
    local title = W:CreateLabel(panel, "|cff" .. accentHex .. "Peavers|r Addons", {
        size = 20,
        outline = "OUTLINE",
        color = C.gold,
    })
    title:SetPoint("TOPLEFT", leftX, yPos)
    yPos = yPos - 28

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    desc:SetPoint("TOPLEFT", leftX, yPos)
    desc:SetPoint("TOPRIGHT", -leftX, yPos)
    desc:SetJustifyH("LEFT")
    desc:SetText("Centralized configuration for all Peavers addons. If you enjoy these addons and would like to support their development, or if you need help, stop by the website.")
    desc:SetTextColor(C.textSec[1], C.textSec[2], C.textSec[3])
    desc:SetSpacing(2)
    yPos = yPos - (desc:GetStringHeight() + 20)

    -- Info section
    _, yPos = W:CreateSectionHeader(panel, "INFO", leftX, yPos)

    yPos = yPos - 8
    local version = W:CreateLabel(panel, "Version:  |cffffffff" .. (PC.version or "1.0.0") .. "|r", { color = C.textSec })
    version:SetPoint("TOPLEFT", leftX, yPos)
    yPos = yPos - 18

    local website = W:CreateLabel(panel, "Website:  |cff" .. accentHex .. "peavers.io|r", { color = C.textSec })
    website:SetPoint("TOPLEFT", leftX, yPos)
    yPos = yPos - 18

    local addonCount = PeaversCommons.ConfigRegistry:GetAddonCount()
    local countLabel = W:CreateLabel(panel, "Registered addons:  |cffffffff" .. addonCount .. "|r", { color = C.textSec })
    countLabel:SetPoint("TOPLEFT", leftX, yPos)
    yPos = yPos - 30

    -- WoWCompare section
    _, yPos = W:CreateSectionHeader(panel, "WOWCOMPARE", leftX, yPos)

    yPos = yPos - 8
    local compareDesc = W:CreateLabel(panel, "Compare your raid and Mythic+ performance using real-world data", { color = C.text })
    compareDesc:SetPoint("TOPLEFT", leftX, yPos)
    yPos = yPos - 18

    local compareUrl = W:CreateLabel(panel, "Try it at |cff" .. accentHex .. "wowcompare.io|r", { color = C.textSec })
    compareUrl:SetPoint("TOPLEFT", leftX, yPos)
    yPos = yPos - 30

    -- UI Vault section
    _, yPos = W:CreateSectionHeader(panel, "UI VAULT", leftX, yPos)

    yPos = yPos - 8
    local vaultTitle = W:CreateLabel(panel, "One-click backup and restore of all WoW addons", { color = C.text })
    vaultTitle:SetPoint("TOPLEFT", leftX, yPos)
    yPos = yPos - 18

    local vaultUrl = W:CreateLabel(panel, "Get it at |cff" .. accentHex .. "vault.peavers.io|r", { color = C.textSec })
    vaultUrl:SetPoint("TOPLEFT", leftX, yPos)
    yPos = yPos - 30

    -- Patrons section
    local Patrons = PeaversCommons.Patrons
    if Patrons and Patrons.GetSorted then
        local allPatrons = Patrons:GetSorted()
        if #allPatrons > 0 then
            _, yPos = W:CreateSectionHeader(panel, "PATRONS", leftX, yPos)

            yPos = yPos - 8
            local patronLines = {}
            for _, patron in ipairs(allPatrons) do
                table.insert(patronLines, Patrons:GetColoredName(patron))
            end

            local patronList = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            patronList:SetPoint("TOPLEFT", leftX, yPos)
            patronList:SetPoint("TOPRIGHT", -leftX, yPos)
            patronList:SetJustifyH("LEFT")
            patronList:SetSpacing(4)
            patronList:SetText(table.concat(patronLines, "\n"))
            yPos = yPos - (patronList:GetStringHeight() + 20)
        end
    end

    -- Footer
    local _, sepY = W:CreateSeparator(panel, leftX, yPos)
    yPos = sepY - 4

    local thanks = W:CreateLabel(panel, "Thank you for using Peavers Addons!", { color = C.textMuted })
    thanks:SetPoint("TOPLEFT", leftX, yPos)
    yPos = yPos - 30

    panel:SetHeight(math.abs(yPos))

    cachedPanels["_about"] = panel
    currentPanel = panel
    scrollFrame:SetScrollChild(panel)
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
    local W = PC.Widgets
    local C = W.Colors

    local panel = CreateFrame("Frame", nil, scrollFrame)
    panel:SetWidth(scrollChild:GetWidth())
    panel:SetHeight(200)

    local msg = W:CreateLabel(panel, text, { color = C.textSec })
    msg:SetPoint("TOPLEFT", 25, -40)
    msg:SetPoint("TOPRIGHT", -25, -40)

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
