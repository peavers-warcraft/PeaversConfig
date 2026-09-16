local _, PC = ...

PC.AddonsPanel = {}
local AddonsPanel = PC.AddonsPanel

local Style = PC.Style
local C = PC.Widgets.Colors

local panel = nil
local content = nil

local INSET = Style.Pad.content
-- Where the description starts and how much room the status word keeps. Two
-- numbers for the whole table, so every row lines up with the one above it.
local NAME_COL = 170
local STATUS_COL = 104

-- Folder names of every addon physically present, loaded or not. Installation
-- can't change mid-session, but enable state can, so this stays a function.
local function GetInstalledFolders()
    local installed = {}
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        if name then
            installed[name] = true
        end
    end
    return installed
end

function AddonsPanel:GetOrCreatePanel(parent)
    if panel then
        panel:Show()
        self:Refresh()
        return panel
    end

    panel = CreateFrame("Frame", nil, parent)
    panel:SetWidth(parent:GetWidth())
    panel:SetHeight(400)

    self:Refresh()

    return panel
end

function AddonsPanel:Refresh()
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

    local catalog = (PC.AddonCatalog and PC.AddonCatalog.addons) or {}
    local installed = GetInstalledFolders()

    local missing, have = {}, {}
    for _, addon in ipairs(catalog) do
        if installed[addon.folder] then
            table.insert(have, addon)
        else
            table.insert(missing, addon)
        end
    end
    local byName = function(a, b) return a.name < b.name end
    table.sort(missing, byName)
    table.sort(have, byName)

    local y = 0

    local title = Style.Label(content, "All Peavers Addons", Style.Size.hero, Style.Alpha.primary)
    title:SetPoint("TOPLEFT", 0, y)
    y = y - Style.Size.hero - Style.Pad.gap

    local summaryText
    if #catalog == 0 then
        summaryText = "No catalog data available. This build is missing its bundled addon catalog."
    elseif #missing == 0 then
        summaryText = "You have all " .. #catalog .. " Peavers addons installed. Thank you."
    else
        summaryText = "You have " .. #have .. " of " .. #catalog .. " Peavers addons installed."
    end

    local summary, summaryHeight = Style.Paragraph(content, summaryText, width)
    summary:SetPoint("TOPLEFT", 0, y)
    y = y - summaryHeight - Style.Pad.gap

    -- A row per addon: name, what it does, and whether you have it.
    --
    -- This was a dot, a name, and the description wrapped underneath on its own
    -- line - two lines and a floating marker for every entry, which at twenty
    -- addons is a wall rather than a list. Name and description in fixed columns
    -- with the state as a word on the right is the same information as a table
    -- you can scan, and it retires the dot: a colour that has to be decoded
    -- says less than the word it stood for.
    local function AddRow(addon, isInstalled)
        local row, nextY = Style.MakeRow(content, y, width)

        local name = Style.Label(row, addon.name, Style.Size.label, Style.Alpha.primary)
        name:SetPoint("LEFT", Style.Row.inset, 0)
        name:SetWidth(NAME_COL - Style.Row.inset - 8)
        name:SetWordWrap(false)
        name:SetJustifyH("LEFT")

        local desc = Style.Label(row, addon.description or "", Style.Size.value, Style.Alpha.muted)
        desc:SetPoint("LEFT", NAME_COL, 0)
        desc:SetWidth(width - NAME_COL - STATUS_COL)
        desc:SetWordWrap(false)
        desc:SetJustifyH("LEFT")

        local status = Style.Label(row, isInstalled and "installed" or "not installed",
            Style.Size.value,
            isInstalled and Style.Alpha.muted or Style.Alpha.primary,
            { color = (not isInstalled) and C.amber or nil })
        status:SetPoint("RIGHT", -Style.Row.inset, 0)
        status:SetJustifyH("RIGHT")

        y = nextY
    end

    if #missing > 0 then
        y = Style.Section(content, "Not installed (" .. #missing .. ")", y, width)
        for _, addon in ipairs(missing) do
            AddRow(addon, false)
        end

        y = y - Style.Pad.gap
        local hint, hintHeight = Style.Paragraph(content,
            "Get these with the Peavers Updater app, or from CurseForge - addons.peavers.io",
            width, Style.Alpha.muted)
        hint:SetPoint("TOPLEFT", 0, y)
        y = y - hintHeight
    end

    if #have > 0 then
        y = Style.Section(content, "Installed (" .. #have .. ")", y, width)
        for _, addon in ipairs(have) do
            AddRow(addon, true)
        end
    end

    panel:SetHeight(INSET + math.abs(y) + INSET)
end

return AddonsPanel
