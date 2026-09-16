local _, PC = ...

PC.SupportPanel = {}
local SupportPanel = PC.SupportPanel

local PeaversCommons = _G.PeaversCommons
local Style = PC.Style

local panel = nil
local content = nil

local INSET = Style.Pad.content

function SupportPanel:GetOrCreatePanel(parent)
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

function SupportPanel:Refresh()
    if not panel then return end

    -- One container per build, dropped whole rather than walked.
    --
    -- WoW cannot destroy a frame, so this used to keep a table of every label
    -- and texture it made and hide them one at a time on refresh. Drawing into a
    -- single child and dropping that child does the same job in one move with no
    -- chance of leaving a stray region behind, and it gives the row banding a
    -- parent of its own to count against.
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

    local y = 0

    local title = Style.Label(content, "Support Peavers", Style.Size.hero, Style.Alpha.primary)
    title:SetPoint("TOPLEFT", 0, y)
    y = y - Style.Size.hero - Style.Pad.gap

    -- parses.gg is named at the brighter alpha rather than in the accent. It is
    -- a place you can go, which is worth marking, but the accent belongs to
    -- state and spending it on prose is what stops it meaning anything on the
    -- row you have actually selected.
    local desc, descHeight = Style.Paragraph(content,
        "parses.gg is a free and open combat-logging platform for World of Warcraft - " ..
        "every fight is public by default, every read needs no API key, and the whole " ..
        "dataset can be downloaded by anyone. Help spread the word by opting in to a " ..
        "small promotional message in party or raid chat.", width)
    desc:SetPoint("TOPLEFT", 0, y)
    y = y - descHeight - Style.Pad.gap

    y = Style.Section(content, "Chat promotion", y, width)

    local config = PeaversCommonsDB and PeaversCommonsDB.config or {}
    local _, afterToggle = Style.Checkbox(content, y, width, {
        label = "Promote parses.gg in party/raid chat",
        checked = config.promoteInChat == true,
        onChange = function(checked)
            PeaversCommonsDB = PeaversCommonsDB or {}
            PeaversCommonsDB.config = PeaversCommonsDB.config or {}
            PeaversCommonsDB.config.promoteInChat = checked
            if PeaversCommons.Config and PeaversCommons.Config.Save then
                PeaversCommons.Config:Save()
            end
        end,
    })
    y = afterToggle

    -- What the setting actually does, as banded rows rather than a column of
    -- accent-coloured bullets. Four short facts are a table, and the banding is
    -- what makes them read as one.
    local detailLines = {
        "A short message is posted after a Mythic+ completion or a raid boss kill",
        "Sent to party chat in dungeons, raid chat in raids",
        "At most once every ten minutes, so it cannot become spam",
        "Only you can turn this on - it is never enabled for you",
    }

    for _, line in ipairs(detailLines) do
        local row, nextY = Style.MakeRow(content, y, width)
        local label = Style.Label(row, line, Style.Size.value, Style.Alpha.secondary)
        label:SetPoint("LEFT", Style.Row.inset, 0)
        y = nextY
    end

    y = y - Style.Pad.section

    local thanks = Style.Label(content, "Thank you for supporting Peavers addons.",
        Style.Size.value, Style.Alpha.muted)
    thanks:SetPoint("TOPLEFT", 0, y)
    y = y - Style.Size.value - Style.Pad.gap

    -- Re-derived from the container's own running offset, which is what the
    -- scroll thumb sizes against. Both insets count: the container starts one
    -- down from the top and the last row wants the same air beneath it.
    panel:SetHeight(INSET + math.abs(y) + INSET)
end

return SupportPanel
