local _, PC = ...

PC.ProfilePanel = {}
local ProfilePanel = PC.ProfilePanel

local Style = PC.Style

local panel = nil
local content = nil

local INSET = Style.Pad.content

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

-- One column, not two.
--
-- This was laid out as a left column at x=25 and a right column at a hardcoded
-- x=300, on a window that resizes from 650 to 1200 wide. The right column never
-- moved, so the gap between them grew with the window and the two halves drifted
-- apart. Sections stacked down one column reflow for free and read in the order
-- you actually use them: which profile you are on, which exist, make a new one,
-- act on the current one, and automate the switching.
function ProfilePanel.Refresh(_)
    if not panel then return end

    if content then
        content:Hide()
        content:SetParent(nil)
    end

    local W = PC.Widgets

    content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", INSET, -INSET)
    content:SetPoint("TOPRIGHT", -INSET, -INSET)
    content:SetHeight(1)

    local width = (panel:GetWidth() or 0) - (INSET * 2)
    if width < 100 then width = 360 end

    local activeProfile = PC.EcosystemProfiles:GetActiveProfile()
        or (UnitName("player") .. " - " .. GetRealmName())
    local allProfiles = PC.EcosystemProfiles:GetAllProfileNames()

    local y = 0

    local title = Style.Label(content, "Profiles", Style.Size.hero, Style.Alpha.primary)
    title:SetPoint("TOPLEFT", 0, y)
    y = y - Style.Size.hero - Style.Pad.gap

    local desc, descHeight = Style.Paragraph(content,
        "A profile is one set of settings across every Peavers addon. Switching " ..
        "changes them all at once.", width)
    desc:SetPoint("TOPLEFT", 0, y)
    y = y - descHeight - Style.Pad.gap

    ----------------------------------------------------------------------------
    -- The profiles themselves
    --
    -- A flat list of rows, in the window's own scroll, rather than a fixed-height
    -- box with a scroll frame of its own. A list inside a list is two thumbs to
    -- find and two places to lose your position, and the box was capped at 220
    -- pixels whether you had three profiles or thirty.
    ----------------------------------------------------------------------------
    y = Style.Section(content, "Available profiles", y, width)

    if #allProfiles == 0 then
        local row = Style.MakeRow(content, y, width)
        local empty = Style.Label(row, "No profiles yet", Style.Size.value, Style.Alpha.muted)
        empty:SetPoint("LEFT", Style.Row.inset, 0)
        y = y - Style.Row.height
    else
        for _, profileName in ipairs(allProfiles) do
            local isActive = (profileName == activeProfile)

            local row, nextY = Style.MakeRow(content, y, width, {
                onClick = function()
                    PC.EcosystemProfiles:SwitchProfile(profileName)
                    ProfilePanel:Refresh()
                end,
            })

            Style.RowText(row, profileName, isActive and "active" or nil, {
                valueAlpha = Style.Alpha.primary,
            })
            row:SetSelected(isActive)

            y = nextY
        end
    end

    ----------------------------------------------------------------------------
    -- Making one
    ----------------------------------------------------------------------------
    y = Style.Section(content, "Create a profile", y, width)

    -- W:CreateInput, not a Style one: the system has no text field yet, and
    -- inventing a second input idiom for a single call site would be worse than
    -- using the one the rest of the collection already uses.
    local inputWidget = W:CreateInput(content, nil, {
        width = 240,
        placeholder = "Enter profile name...",
        maxLetters = 50,
    })
    inputWidget:SetPoint("TOPLEFT", 0, y)
    y = y - 34 - Style.Pad.gap

    local createEmptyBtn = Style.Button(content, "Create Empty", {
        variant = "secondary",
        width = 130,
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
    createEmptyBtn:SetPoint("TOPLEFT", 0, y)

    local dupeBtn = Style.Button(content, "Duplicate Current", {
        variant = "primary",
        width = 150,
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
    dupeBtn:SetPoint("LEFT", createEmptyBtn, "RIGHT", Style.Pad.gap, 0)
    y = y - 32 - Style.Pad.gap

    ----------------------------------------------------------------------------
    -- Acting on the current one
    ----------------------------------------------------------------------------
    y = Style.Section(content, "Profile actions", y, width)

    local deleteBtn = Style.Button(content, "Delete Current Profile", {
        variant = "danger",
        width = 190,
        onClick = function()
            local charDefault = UnitName("player") .. " - " .. GetRealmName()
            if activeProfile == charDefault then
                print("|cffff6666PeaversConfig:|r Cannot delete your character's default profile.")
                return
            end
            local dialog = StaticPopup_Show("PEAVERSCONFIG_DELETE_PROFILE", activeProfile)
            if dialog then
                dialog.data = activeProfile
            end
        end,
    })
    deleteBtn:SetPoint("TOPLEFT", 0, y)

    local resetBtn = Style.Button(content, "Reset to Defaults", {
        variant = "secondary",
        width = 160,
        onClick = function()
            StaticPopup_Show("PEAVERSCONFIG_RESET_PROFILE")
        end,
    })
    resetBtn:SetPoint("LEFT", deleteBtn, "RIGHT", Style.Pad.gap, 0)
    y = y - 32 - Style.Pad.gap

    ----------------------------------------------------------------------------
    -- Switching by specialisation
    ----------------------------------------------------------------------------
    y = Style.Section(content, "Auto-switch by spec", y, width)

    if not _G.PeaversConfigDB then _G.PeaversConfigDB = {} end
    if not _G.PeaversConfigDB.specAutoSwitch then
        _G.PeaversConfigDB.specAutoSwitch = { enabled = false, specProfiles = {} }
    end
    local specConfig = _G.PeaversConfigDB.specAutoSwitch

    local _, afterToggle = Style.Checkbox(content, y, width, {
        label = "Switch profile when I change specialization",
        checked = specConfig.enabled,
        onChange = function(checked)
            specConfig.enabled = checked
        end,
    })
    y = afterToggle

    -- Guarded, and deliberately so: GetNumSpecializations and
    -- GetSpecializationInfo do not exist on Classic Era, Anniversary or Mists.
    -- The fallback branch is the only thing those clients ever see here.
    local numSpecs = GetNumSpecializations and GetNumSpecializations() or 0
    if numSpecs > 0 then
        for i = 1, numSpecs do
            local _, specName, _, specIcon = GetSpecializationInfo(i)
            if specName then
                local assignedProfile = specConfig.specProfiles and specConfig.specProfiles[i]
                local specIndex = i

                local row, nextY = Style.MakeRow(content, y, width, { height = Style.Row.tall })

                local specLabel = Style.Label(row, "|T" .. specIcon .. ":16:16|t  " .. specName,
                    Style.Size.label, Style.Alpha.primary)
                specLabel:SetPoint("LEFT", Style.Row.inset, 0)

                local assignedText = Style.Label(row, assignedProfile or "none",
                    Style.Size.value,
                    assignedProfile and Style.Alpha.secondary or Style.Alpha.muted)
                assignedText:SetPoint("LEFT", specLabel, "RIGHT", 12, 0)

                local clearBtn = Style.Button(row, "Clear", {
                    variant = "link",
                    width = 52,
                    height = 22,
                    size = Style.Size.value,
                    onClick = function()
                        if not specConfig.specProfiles then specConfig.specProfiles = {} end
                        specConfig.specProfiles[specIndex] = nil
                        ProfilePanel:Refresh()
                    end,
                })
                clearBtn:SetPoint("RIGHT", -Style.Row.inset, 0)

                local assignBtn = Style.Button(row, "Assign", {
                    variant = "secondary",
                    width = 68,
                    height = 22,
                    size = Style.Size.value,
                    onClick = function()
                        if not specConfig.specProfiles then specConfig.specProfiles = {} end
                        specConfig.specProfiles[specIndex] = activeProfile
                        ProfilePanel:Refresh()
                    end,
                })
                assignBtn:SetPoint("RIGHT", clearBtn, "LEFT", -6, 0)

                y = nextY
            end
        end
    else
        local row = Style.MakeRow(content, y, width)
        local noSpec = Style.Label(row, "Specialization data is not available on this client.",
            Style.Size.value, Style.Alpha.muted)
        noSpec:SetPoint("LEFT", Style.Row.inset, 0)
        y = y - Style.Row.height
    end

    ----------------------------------------------------------------------------
    -- Footer
    ----------------------------------------------------------------------------
    y = y - Style.Pad.section

    local info, infoHeight = Style.Paragraph(content,
        "Profiles save automatically. Each character starts with a default profile of " ..
        "its own; named profiles are shared across every character.", width, Style.Alpha.muted)
    info:SetPoint("TOPLEFT", 0, y)
    y = y - infoHeight

    panel:SetHeight(INSET + math.abs(y) + INSET)
end

return ProfilePanel
