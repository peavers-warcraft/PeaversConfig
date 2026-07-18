local _, PC = ...

PC.SupportPanel = {}
local SupportPanel = PC.SupportPanel

local PeaversCommons = _G.PeaversCommons
local Theme = PeaversCommons.Theme

local panel = nil
local elements = {}

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

    for _, el in ipairs(elements) do
        if el.Hide then el:Hide() end
        if el.SetParent then el:SetParent(nil) end
    end
    elements = {}

    local W = PC.Widgets
    local C = W.Colors
    local leftX = 25
    local yPos = -20
    local accentHex = Theme.Hex(C.accent)

    local title = W:CreateLabel(panel, "Support Peavers", { color = C.text, size = 20 })
    title:SetPoint("TOPLEFT", leftX, yPos)
    table.insert(elements, title)
    yPos = yPos - 28

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    desc:SetPoint("TOPLEFT", leftX, yPos)
    desc:SetPoint("TOPRIGHT", -25, yPos)
    desc:SetJustifyH("LEFT")
    desc:SetSpacing(2)
    desc:SetText("|cff" .. accentHex .. "wowcompare.io|r is a free tool for comparing your character's gear, stats, talents, and raid/Mythic+ performance against top players across the world. Help spread the word by opting in to a small promotional message in party or raid chat.")
    desc:SetTextColor(C.textSec[1], C.textSec[2], C.textSec[3])
    table.insert(elements, desc)
    yPos = yPos - (desc:GetStringHeight() + 35)

    local _, headerY = W:CreateSectionHeader(panel, "CHAT PROMOTION", leftX, yPos)
    yPos = headerY - 8
    table.insert(elements, _)

    local width = panel:GetWidth() - (leftX * 2) - 10
    if width < 100 then width = 360 end

    local config = PeaversCommonsDB and PeaversCommonsDB.config or {}
    local toggle = W:CreateToggle(panel, "Promote wowcompare.io in party/raid chat", {
        checked = config.promoteInChat == true,
        width = width,
        onChange = function(checked)
            PeaversCommonsDB = PeaversCommonsDB or {}
            PeaversCommonsDB.config = PeaversCommonsDB.config or {}
            PeaversCommonsDB.config.promoteInChat = checked
            if PeaversCommons.Config and PeaversCommons.Config.Save then
                PeaversCommons.Config:Save()
            end
        end,
    })
    toggle:SetPoint("TOPLEFT", leftX, yPos)
    table.insert(elements, toggle)
    yPos = yPos - 35

    local detailLines = {
        "A short message is posted after a Mythic+ completion or a raid boss kill",
        "Sent to party chat in dungeons, raid chat in raids",
        "Maximum once every 10 minutes to avoid spam",
        "Only you can enable or disable this — it is never turned on automatically",
    }

    for _, line in ipairs(detailLines) do
        local bullet = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        bullet:SetPoint("TOPLEFT", leftX + 10, yPos)
        bullet:SetPoint("TOPRIGHT", -25, yPos)
        bullet:SetJustifyH("LEFT")
        bullet:SetText("|cff" .. accentHex .. "•|r  " .. line)
        bullet:SetTextColor(C.textSec[1], C.textSec[2], C.textSec[3])
        table.insert(elements, bullet)
        yPos = yPos - 18
    end

    yPos = yPos - 15

    local _, sepY = W:CreateSeparator(panel, leftX, yPos)
    yPos = sepY - 8

    local thanks = W:CreateLabel(panel, "Thank you for supporting Peavers addons!", { color = C.textMuted })
    thanks:SetPoint("TOPLEFT", leftX, yPos)
    table.insert(elements, thanks)
    yPos = yPos - 30

    panel:SetHeight(math.abs(yPos) + 20)
end

return SupportPanel
