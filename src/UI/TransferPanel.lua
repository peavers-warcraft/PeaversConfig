--------------------------------------------------------------------------------
-- TransferPanel
--
-- Import / Export: every Peavers addon's settings as one string, for moving to
-- WoW Forever, a Classic client, another PC, or a friend.
--
-- Reading a string and applying it are two steps on purpose. A pasted string
-- shows what is in it - which addons, from which client, how much each one
-- carries - and nothing changes until "Import and reload". Anything not ticked,
-- and anything not in the string, is left exactly as it is.
--------------------------------------------------------------------------------

local _, PC = ...

PC.TransferPanel = {}
local TransferPanel = PC.TransferPanel

local Style = PC.Style

local panel = nil
local content = nil

local INSET = Style.Pad.content

-- What the export will include. Absent means ticked: a new addon shows up
-- ready to go rather than silently left out.
local exportOff = {}

-- A string that has been read and is waiting to be applied, and which of its
-- addons are ticked.
local pending = nil
local importOn = {}

local function Transfer() return PC.SettingsTransfer end

local function When(stamp)
    if type(stamp) ~= "number" or stamp <= 0 or not date then return nil end
    return date("%d %b %Y, %H:%M", stamp)
end

local function SettingsCount(n)
    if n == 0 then return "defaults" end
    return n == 1 and "1 setting" or (n .. " settings")
end

function TransferPanel:GetOrCreatePanel(parent)
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

function TransferPanel:RegisterPopups()
    StaticPopupDialogs["PEAVERSCONFIG_IMPORT_SETTINGS"] = {
        text = "Import settings for %s?\n\nEach one is set exactly as it is in the string, " ..
            "and the UI reloads. You can undo this afterwards.",
        button1 = "Import and reload",
        button2 = "Cancel",
        OnAccept = function()
            TransferPanel:ApplyPending()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        showAlert = true,
    }

    StaticPopupDialogs["PEAVERSCONFIG_UNDO_IMPORT"] = {
        text = "Put back the settings the last import replaced?\n\nThe UI reloads.",
        button1 = "Undo and reload",
        button2 = "Cancel",
        OnAccept = function()
            local report, err = Transfer():Undo()
            if not report then
                print("|cffff6666PeaversConfig:|r " .. tostring(err))
                return
            end
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

function TransferPanel.Export(_)
    local selected = {}
    for _, entry in ipairs(Transfer():GetEntries()) do
        if not exportOff[entry.key] then selected[entry.key] = true end
    end
    if next(selected) == nil then
        print("|cffff6666PeaversConfig:|r Tick at least one addon to export.")
        return
    end

    local text, n = Transfer():Export(selected)
    PC.TextWindow:ShowCopy("Export",
        text,
        "Settings for " .. n .. " addon(s). Ctrl+C to copy, then paste it into " ..
        "/peavers import on the other client.")
end

function TransferPanel:OpenPaste()
    PC.TextWindow:ShowPaste("Import",
        "Paste a settings string (Ctrl+V). Nothing changes yet - you will see what is " ..
        "in it first.",
        function(text)
            local payload, err = Transfer():Read(text)
            if not payload then return false, err end

            pending = payload
            importOn = {}
            for _, row in ipairs(Transfer():Preview(payload)) do
                if row.installed then importOn[row.key] = true end
            end
            self:Refresh()
            return true
        end)
end

function TransferPanel:ApplyPending()
    if not pending then return end

    local report, err = Transfer():Apply(pending, importOn)
    if not report then
        print("|cffff6666PeaversConfig:|r " .. tostring(err))
        return
    end

    pending = nil
    importOn = {}
    ReloadUI()
end

function TransferPanel:ConfirmImport()
    local n = 0
    for _, on in pairs(importOn) do
        if on then n = n + 1 end
    end
    if n == 0 then
        print("|cffff6666PeaversConfig:|r Tick at least one addon to import.")
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        print("|cffff6666PeaversConfig:|r Leave combat first. Importing reloads the UI.")
        return
    end
    StaticPopup_Show("PEAVERSCONFIG_IMPORT_SETTINGS", n == 1 and "1 addon" or (n .. " addons"))
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

local function CountLabel(row, text, alpha)
    local value = Style.Label(row, text, Style.Size.value, alpha or Style.Alpha.secondary)
    value:SetPoint("TOPRIGHT", -Style.Row.inset, -9)
    return value
end

function TransferPanel.Refresh(self)
    if not panel then return end

    if content then
        content:Hide()
        content:SetParent(nil)
    end

    content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", INSET, -INSET)
    content:SetPoint("TOPRIGHT", -INSET, -INSET)
    content:SetHeight(1)

    local width = (panel:GetWidth() or 0) - (INSET * 2)
    if width < 100 then width = 360 end

    local entries = Transfer():GetEntries()
    local y = 0

    local title = Style.Label(content, "Import / Export", Style.Size.hero, Style.Alpha.primary)
    title:SetPoint("TOPLEFT", 0, y)
    y = y - Style.Size.hero - Style.Pad.gap

    local desc, descHeight = Style.Paragraph(content,
        "Move your Peavers settings to WoW Forever, a Classic client, another PC, or a " ..
        "friend. Export gives you a string; paste it into Import on the other side. A " ..
        "string from any client works on every other.", width)
    desc:SetPoint("TOPLEFT", 0, y)
    y = y - descHeight - Style.Pad.gap

    ----------------------------------------------------------------------------
    -- Export
    ----------------------------------------------------------------------------
    y = Style.Section(content, "Export", y, width)

    if #entries == 0 then
        local row = Style.MakeRow(content, y, width)
        local empty = Style.Label(row, "No Peavers addons with settings are loaded.",
            Style.Size.value, Style.Alpha.muted)
        empty:SetPoint("LEFT", Style.Row.inset, 0)
        y = y - Style.Row.height
    else
        for _, entry in ipairs(entries) do
            local key = entry.key
            local row, nextY = Style.Checkbox(content, y, width, {
                label = entry.label,
                checked = not exportOff[key],
                onChange = function(checked)
                    exportOff[key] = not checked or nil
                end,
            })
            CountLabel(row, SettingsCount(Transfer():CountChanged(entry)), Style.Alpha.muted)
            y = nextY
        end

        y = y - Style.Pad.gap

        local exportBtn = Style.Button(content, "Export", {
            variant = "primary",
            width = 130,
            onClick = function() self:Export() end,
        })
        exportBtn:SetPoint("TOPLEFT", 0, y)

        local allBtn = Style.Button(content, "All", {
            variant = "link",
            width = 50,
            onClick = function()
                exportOff = {}
                self:Refresh()
            end,
        })
        allBtn:SetPoint("LEFT", exportBtn, "RIGHT", Style.Pad.gap, 0)

        local noneBtn = Style.Button(content, "None", {
            variant = "link",
            width = 50,
            onClick = function()
                for _, entry in ipairs(entries) do exportOff[entry.key] = true end
                self:Refresh()
            end,
        })
        noneBtn:SetPoint("LEFT", allBtn, "RIGHT", 0, 0)

        y = y - 32 - Style.Pad.gap
    end

    ----------------------------------------------------------------------------
    -- Import
    ----------------------------------------------------------------------------
    y = Style.Section(content, "Import", y, width)

    if not pending then
        local text, height = Style.Paragraph(content,
            "Paste a string from another client. You see what is in it before anything " ..
            "changes.", width)
        text:SetPoint("TOPLEFT", 0, y)
        y = y - height - Style.Pad.gap

        local pasteBtn = Style.Button(content, "Paste a string", {
            variant = "primary",
            width = 150,
            onClick = function() self:OpenPaste() end,
        })
        pasteBtn:SetPoint("TOPLEFT", 0, y)
        y = y - 32 - Style.Pad.gap
    else
        local from = type(pending.clientLabel) == "string" and pending.clientLabel or "another client"
        local made = When(pending.made)
        local text, height = Style.Paragraph(content,
            "From " .. from .. (made and (", made " .. made) or "") .. ". Ticked addons are " ..
            "set exactly as they are in the string - anything else stays as it is.", width)
        text:SetPoint("TOPLEFT", 0, y)
        y = y - height - Style.Pad.gap

        for _, row in ipairs(Transfer():Preview(pending)) do
            if row.installed then
                local key = row.key
                local box, nextY = Style.Checkbox(content, y, width, {
                    label = row.label,
                    checked = importOn[key],
                    onChange = function(checked)
                        importOn[key] = checked or nil
                    end,
                })
                CountLabel(box, SettingsCount(row.count))
                y = nextY
            else
                local line, nextY = Style.MakeRow(content, y, width)
                Style.RowText(line, row.label, "not installed", { valueAlpha = Style.Alpha.disabled })
                line.styleLabel:SetAlpha(Style.Alpha.disabled / Style.Alpha.primary)
                y = nextY
            end
        end

        y = y - Style.Pad.gap

        local importBtn = Style.Button(content, "Import and reload", {
            variant = "primary",
            width = 170,
            onClick = function() self:ConfirmImport() end,
        })
        importBtn:SetPoint("TOPLEFT", 0, y)

        local discardBtn = Style.Button(content, "Discard", {
            variant = "link",
            width = 80,
            onClick = function()
                pending = nil
                importOn = {}
                self:Refresh()
            end,
        })
        discardBtn:SetPoint("LEFT", importBtn, "RIGHT", Style.Pad.gap, 0)

        y = y - 32 - Style.Pad.gap
    end

    ----------------------------------------------------------------------------
    -- Undo
    ----------------------------------------------------------------------------
    local undo = Transfer():GetUndo()
    if undo then
        y = Style.Section(content, "Undo", y, width)

        local count = 0
        for _ in pairs(undo.addons) do count = count + 1 end
        local made = When(undo.made)

        local text, height = Style.Paragraph(content,
            "The last import" .. (made and (" (" .. made .. ")") or "") .. " replaced " ..
            (count == 1 and "1 addon's" or (count .. " addons'")) .. " settings. Undo puts " ..
            "them back the way they were.", width)
        text:SetPoint("TOPLEFT", 0, y)
        y = y - height - Style.Pad.gap

        local undoBtn = Style.Button(content, "Undo and reload", {
            variant = "secondary",
            width = 160,
            onClick = function()
                if InCombatLockdown and InCombatLockdown() then
                    print("|cffff6666PeaversConfig:|r Leave combat first. Undoing reloads the UI.")
                    return
                end
                StaticPopup_Show("PEAVERSCONFIG_UNDO_IMPORT")
            end,
        })
        undoBtn:SetPoint("TOPLEFT", 0, y)
        y = y - 32 - Style.Pad.gap
    end

    ----------------------------------------------------------------------------
    -- Footer
    ----------------------------------------------------------------------------
    y = y - Style.Pad.section

    local info, infoHeight = Style.Paragraph(content,
        "Settings go into the profile you are on now. Fonts and bar textures that are " ..
        "not installed on this client stay at their defaults.", width, Style.Alpha.muted)
    info:SetPoint("TOPLEFT", 0, y)
    y = y - infoHeight

    panel:SetHeight(INSET + math.abs(y) + INSET)
end

return TransferPanel
