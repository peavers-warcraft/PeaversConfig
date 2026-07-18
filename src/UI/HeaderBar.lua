local _, PC = ...

PC.HeaderBar = {}
local HeaderBar = PC.HeaderBar

local PeaversCommons = _G.PeaversCommons
local Theme = PeaversCommons.Theme

local HEADER_HEIGHT = 40

function HeaderBar:Create(parent)
    local W = PC.Widgets
    local C = W.Colors

    local header = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 2, -2)
    header:SetPoint("TOPRIGHT", -2, -2)
    header:SetHeight(HEADER_HEIGHT)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    header:SetBackdropColor(C.bgNested[1], C.bgNested[2], C.bgNested[3], 1)

    self.frame = header

    -- Title
    local title = header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("LEFT", 16, 0)
    title:SetText(Theme.Colorize(C.accent, "Peavers") .. " Config")
    -- GameFontNormalLarge is gold by default, so the uncoloured half of the
    -- wordmark inherits gold unless the base colour is set explicitly.
    title:SetTextColor(unpack(C.text))
    title:SetFont(title:GetFont() --[[@as string]], 16)

    -- Version
    local version = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    version:SetPoint("LEFT", title, "RIGHT", 8, 0)
    version:SetText("v" .. (PC.version or "1.0.0"))
    version:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

    -- Close button (custom styled)
    local closeBtn = W:CreateButton(header, "x", {
        variant = "ghost",
        width = 28,
        height = 28,
        onClick = function()
            PC.MainFrame:Hide()
        end,
    })
    closeBtn:SetPoint("TOPRIGHT", -4, -6)
    closeBtn.label:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])

    -- Bottom border
    local borderLine = header:CreateTexture(nil, "ARTWORK")
    borderLine:SetPoint("BOTTOMLEFT", 0, 0)
    borderLine:SetPoint("BOTTOMRIGHT", 0, 0)
    borderLine:SetHeight(1)
    borderLine:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

    return header
end

function HeaderBar:GetFrame()
    return self.frame
end

return HeaderBar
