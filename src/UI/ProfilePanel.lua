local _, PC = ...

PC.ProfilePanel = {}
local ProfilePanel = PC.ProfilePanel


local panel = nil
local elements = {}

function ProfilePanel:GetOrCreatePanel(parent)
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

function ProfilePanel:RegisterPopups()
    StaticPopupDialogs["PEAVERSCONFIG_DELETE_PROFILE"] = {
        text = "Delete profile '%s'?\n\nThis will remove it from all Peavers addons. This cannot be undone.",
        button1 = "Delete",
        button2 = "Cancel",
        OnAccept = function(_, data)
            PC.EcosystemProfiles:DeleteProfile(data)
            ProfilePanel:Refresh()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        showAlert = true,
    }

    StaticPopupDialogs["PEAVERSCONFIG_RESET_PROFILE"] = {
        text = "Reset current profile to defaults?\n\nThis will reset settings in all Peavers addons for this profile.",
        button1 = "Reset",
        button2 = "Cancel",
        OnAccept = function()
            local current = PC.EcosystemProfiles:GetActiveProfile()
                or (UnitName("player") .. " - " .. GetRealmName())
            PC.EcosystemProfiles:ResetProfile(current)
            ProfilePanel:Refresh()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        showAlert = true,
    }
end

function ProfilePanel.Refresh(_)
    if not panel then return end

    for _, el in ipairs(elements) do
        if el.Hide then el:Hide() end
        if el.SetParent then el:SetParent(nil) end
    end
    elements = {}

    local W = PC.Widgets
    local C = W.Colors

    local activeProfile = PC.EcosystemProfiles:GetActiveProfile()
        or (UnitName("player") .. " - " .. GetRealmName())
    local allProfiles = PC.EcosystemProfiles:GetAllProfileNames()

    local yPos = -20
    local leftX = 25
    local rightX = 300

    -- ========================================
    -- Current Profile indicator
    -- ========================================

    local currentPanel = W:CreatePanel(panel, { bg = C.bgNested })
    currentPanel:SetPoint("TOPLEFT", leftX, yPos)
    currentPanel:SetPoint("TOPRIGHT", -25, yPos)
    currentPanel:SetHeight(50)
    table.insert(elements, currentPanel)

    local activeLabel = W:CreateLabel(currentPanel, "Active Profile", { color = C.textMuted, size = 10 })
    activeLabel:SetPoint("TOPLEFT", 12, -10)

    local activeName = W:CreateLabel(currentPanel, activeProfile, { color = C.success, size = 14 })
    activeName:SetPoint("TOPLEFT", 12, -28)

    yPos = yPos - 65

    -- ========================================
    -- COLUMN 1: Profile List (left side)
    -- ========================================

    local _, headerY = W:CreateSectionHeader(panel, "AVAILABLE PROFILES", leftX, yPos)
    yPos = headerY - 5
    -- Store in elements for cleanup
    table.insert(elements, _)

    -- Profile list container
    local listHeight = math.max(#allProfiles * 30 + 8, 50)
    listHeight = math.min(listHeight, 220)

    local listContainer = W:CreatePanel(panel, { bg = C.bgInput })
    listContainer:SetPoint("TOPLEFT", leftX, yPos)
    listContainer:SetSize(240, listHeight)
    listContainer:SetClipsChildren(true)
    table.insert(elements, listContainer)

    -- Scroll frame inside
    local scrollFrame = CreateFrame("ScrollFrame", nil, listContainer, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 2, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", -22, 2)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(210, #allProfiles * 30 + 8)
    scrollFrame:SetScrollChild(scrollChild)

    local contentHeight = #allProfiles * 30 + 8
    if contentHeight <= listHeight and scrollFrame.ScrollBar then
        scrollFrame.ScrollBar:Hide()
        scrollFrame:SetPoint("BOTTOMRIGHT", -4, 2)
    end

    -- Profile buttons
    local py = -4
    for _, profileName in ipairs(allProfiles) do
        local isActive = (profileName == activeProfile)

        local btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
        btn:SetSize(206, 26)
        btn:SetPoint("TOPLEFT", 2, py)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })

        if isActive then
            btn:SetBackdropColor(C.accent[1] * 0.2, C.accent[2] * 0.2, C.accent[3] * 0.2, 0.8)
            btn:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.8)
        else
            btn:SetBackdropColor(C.bgPanel[1], C.bgPanel[2], C.bgPanel[3], 1)
            btn:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
        end

        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", 10, 0)
        text:SetText(profileName)
        if isActive then
            text:SetTextColor(C.accentLight[1], C.accentLight[2], C.accentLight[3])
        else
            text:SetTextColor(C.text[1], C.text[2], C.text[3])
        end

        btn:SetScript("OnEnter", function(self)
            if not isActive then
                self:SetBackdropColor(C.highlight[1], C.highlight[2], C.highlight[3], 0.08)
                self:SetBackdropBorderColor(C.borderHover[1], C.borderHover[2], C.borderHover[3], 1)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if not isActive then
                self:SetBackdropColor(C.bgPanel[1], C.bgPanel[2], C.bgPanel[3], 1)
                self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
            end
        end)
        btn:SetScript("OnClick", function()
            PC.EcosystemProfiles:SwitchProfile(profileName)
            ProfilePanel:Refresh()
        end)

        py = py - 30
    end

    if #allProfiles == 0 then
        local emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyText:SetPoint("CENTER")
        emptyText:SetText("No profiles yet")
        emptyText:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    end

    yPos = yPos - listHeight - 20

    -- ========================================
    -- Create New Profile
    -- ========================================

    local _, createHeaderY = W:CreateSectionHeader(panel, "CREATE NEW PROFILE", leftX, yPos)
    yPos = createHeaderY - 5
    table.insert(elements, _)

    local inputWidget = W:CreateInput(panel, nil, {
        width = 240,
        placeholder = "Enter profile name...",
        maxLetters = 50,
    })
    inputWidget:SetPoint("TOPLEFT", leftX, yPos)
    table.insert(elements, inputWidget)
    yPos = yPos - 34

    -- Buttons row
    local createEmptyBtn = W:CreateButton(panel, "Create Empty", {
        variant = "secondary",
        width = 115,
        height = 26,
        onClick = function()
            local name = inputWidget:GetText():trim()
            if name == "" then
                print("|cffff6666PeaversConfig:|r Please enter a profile name.")
                return
            end
            PC.EcosystemProfiles:CreateEmptyProfile(name)
            inputWidget:SetText("")
            inputWidget:ClearFocus()
            ProfilePanel:Refresh()
        end,
    })
    createEmptyBtn:SetPoint("TOPLEFT", leftX, yPos)
    table.insert(elements, createEmptyBtn)

    local dupeBtn = W:CreateButton(panel, "Duplicate Current", {
        variant = "primary",
        width = 115,
        height = 26,
        onClick = function()
            local name = inputWidget:GetText():trim()
            if name == "" then
                print("|cffff6666PeaversConfig:|r Please enter a name for the duplicated profile.")
                return
            end
            PC.EcosystemProfiles:DuplicateProfile(name)
            inputWidget:SetText("")
            inputWidget:ClearFocus()
            ProfilePanel:Refresh()
        end,
    })
    dupeBtn:SetPoint("LEFT", createEmptyBtn, "RIGHT", 10, 0)
    table.insert(elements, dupeBtn)

    -- ========================================
    -- COLUMN 2: Actions (right side)
    -- ========================================

    local actionY = -85 -- Offset below the current profile panel

    local _, actHeaderY = W:CreateSectionHeader(panel, "PROFILE ACTIONS", rightX, actionY)
    actionY = actHeaderY - 8
    table.insert(elements, _)

    local deleteBtn = W:CreateButton(panel, "Delete Current Profile", {
        variant = "danger",
        width = 180,
        height = 26,
        onClick = function()
            local p = activeProfile
            local charDefault = UnitName("player") .. " - " .. GetRealmName()
            if p == charDefault then
                print("|cffff6666PeaversConfig:|r Cannot delete your character's default profile.")
                return
            end
            local dialog = StaticPopup_Show("PEAVERSCONFIG_DELETE_PROFILE", p)
            if dialog then
                dialog.data = p
            end
        end,
    })
    deleteBtn:SetPoint("TOPLEFT", rightX, actionY)
    table.insert(elements, deleteBtn)
    actionY = actionY - 35

    local resetBtn = W:CreateButton(panel, "Reset to Defaults", {
        variant = "secondary",
        width = 180,
        height = 26,
        onClick = function()
            StaticPopup_Show("PEAVERSCONFIG_RESET_PROFILE")
        end,
    })
    resetBtn:SetPoint("TOPLEFT", rightX, actionY)
    table.insert(elements, resetBtn)
    actionY = actionY - 50

    -- ========================================
    -- Auto-Switch by Spec
    -- ========================================

    local _, specHeaderY = W:CreateSectionHeader(panel, "AUTO-SWITCH BY SPEC", rightX, actionY)
    actionY = specHeaderY - 5
    table.insert(elements, _)

    local specDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    specDesc:SetPoint("TOPLEFT", rightX, actionY)
    specDesc:SetText("Automatically switch profile when\nyou change specialization.")
    specDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    table.insert(elements, specDesc)
    actionY = actionY - 35

    -- Enable toggle
    if not _G.PeaversConfigDB then _G.PeaversConfigDB = {} end
    if not _G.PeaversConfigDB.specAutoSwitch then
        _G.PeaversConfigDB.specAutoSwitch = { enabled = false, specProfiles = {} }
    end
    local specConfig = _G.PeaversConfigDB.specAutoSwitch

    local specToggle = W:CreateToggle(panel, "Enable Spec Auto-Switch", {
        checked = specConfig.enabled,
        width = 240,
        onChange = function(checked)
            specConfig.enabled = checked
        end,
    })
    specToggle:SetPoint("TOPLEFT", rightX, actionY)
    table.insert(elements, specToggle)
    actionY = actionY - 32

    -- Per-spec assignment
    local numSpecs = GetNumSpecializations and GetNumSpecializations() or 0
    if numSpecs > 0 then
        for i = 1, numSpecs do
            local _, specName, _, specIcon = GetSpecializationInfo(i)
            if specName then
                local assignedProfile = specConfig.specProfiles and specConfig.specProfiles[i]
                local specIndex = i

                local row = CreateFrame("Frame", nil, panel)
                row:SetPoint("TOPLEFT", rightX, actionY)
                row:SetSize(280, 28)
                table.insert(elements, row)

                local specLabel = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                specLabel:SetPoint("LEFT", 0, 0)
                specLabel:SetText("|T" .. specIcon .. ":16:16|t " .. specName)
                specLabel:SetTextColor(C.text[1], C.text[2], C.text[3])

                local assignedText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                assignedText:SetPoint("LEFT", specLabel, "RIGHT", 8, 0)
                if assignedProfile then
                    assignedText:SetText(assignedProfile)
                    assignedText:SetTextColor(C.success[1], C.success[2], C.success[3])
                else
                    assignedText:SetText("None")
                    assignedText:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
                end

                local assignBtn = W:CreateButton(row, "Assign", {
                    variant = "secondary",
                    width = 55,
                    height = 20,
                    onClick = function()
                        if not specConfig.specProfiles then specConfig.specProfiles = {} end
                        specConfig.specProfiles[specIndex] = activeProfile
                        ProfilePanel:Refresh()
                    end,
                })
                assignBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)

                local clearBtn = W:CreateButton(row, "Clear", {
                    variant = "ghost",
                    width = 45,
                    height = 20,
                    onClick = function()
                        if not specConfig.specProfiles then specConfig.specProfiles = {} end
                        specConfig.specProfiles[specIndex] = nil
                        ProfilePanel:Refresh()
                    end,
                })
                clearBtn:SetPoint("RIGHT", assignBtn, "LEFT", -4, 0)

                actionY = actionY - 32
            end
        end
    else
        local noSpec = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        noSpec:SetPoint("TOPLEFT", rightX, actionY)
        noSpec:SetText("Specialization data not available.")
        noSpec:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
        table.insert(elements, noSpec)
        actionY = actionY - 20
    end

    -- ========================================
    -- Bottom info
    -- ========================================

    local bottomY = math.min(yPos - 50, actionY - 30)

    local _, sepY = W:CreateSeparator(panel, leftX, bottomY, 500)
    bottomY = sepY
    table.insert(elements, _)

    local infoText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    infoText:SetPoint("TOPLEFT", leftX, bottomY)
    infoText:SetPoint("TOPRIGHT", -25, bottomY)
    infoText:SetJustifyH("LEFT")
    infoText:SetText(
        "Profiles save automatically. Switching a profile changes settings in all Peavers addons at once.\n" ..
        "Each character starts with their own default profile. Named profiles are shared across characters."
    )
    infoText:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    table.insert(elements, infoText)
    bottomY = bottomY - 40

    panel:SetHeight(math.abs(bottomY) + 50)
end

return ProfilePanel
