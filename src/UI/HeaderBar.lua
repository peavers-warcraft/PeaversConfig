local _, PC = ...

PC.HeaderBar = {}
local HeaderBar = PC.HeaderBar

local PeaversCommons = _G.PeaversCommons
local Theme = PeaversCommons.Theme

local HEADER_HEIGHT = 40

function HeaderBar:Create(parent)
    local W = PC.Widgets
    local C = W.Colors
    local Style = PC.Style

    local header = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 2, -2)
    header:SetPoint("TOPRIGHT", -2, -2)
    header:SetHeight(HEADER_HEIGHT)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    header:SetBackdropColor(C.bgNested[1], C.bgNested[2], C.bgNested[3], 1)

    self.frame = header

    -- Title, in one colour.
    --
    -- The wordmark used to tint "Peavers" with the accent, which is the accent
    -- doing decoration. It belongs to selection and to the primary action, and
    -- spending it on a heading that is the same on every screen is what makes it
    -- stop meaning anything where it matters.
    local title = Style.Label(header, "Peavers Config", Style.Size.hero, Style.Alpha.primary)
    title:SetPoint("LEFT", 16, 0)

    local version = Style.Label(header, "v" .. (PC.version or "1.0.0"),
        Style.Size.meta, Style.Alpha.muted)
    version:SetPoint("LEFT", title, "RIGHT", 8, -1)

    -- A text glyph rather than a bordered button: a boxed X competes with the
    -- real actions on whichever panel is open. ASCII, not a typographic
    -- multiplication sign - the game's fonts carry almost nothing outside basic
    -- Latin and the nicer glyph draws as blank space.
    local closeBtn = Style.Button(header, "X", {
        variant = "link",
        width = 28,
        height = 28,
        onClick = function()
            PC.MainFrame:Hide()
        end,
    })
    closeBtn:SetPoint("TOPRIGHT", -6, -6)

    -- Bottom border, at the chrome weight: this is the window's own structure
    -- rather than a divider inside a panel.
    local borderLine = Style.Hairline(header, Style.Rule.chrome)
    borderLine:SetPoint("BOTTOMLEFT", 0, 0)
    borderLine:SetPoint("BOTTOMRIGHT", 0, 0)

    return header
end

function HeaderBar:GetFrame()
    return self.frame
end

return HeaderBar
