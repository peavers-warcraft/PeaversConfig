local _, PC = ...

PC.MainFrame = {}
local MainFrame = PC.MainFrame

local PeaversCommons = _G.PeaversCommons

local SIDEBAR_WIDTH = 180
local MIN_WIDTH = 650
local MIN_HEIGHT = 450
local HEADER_HEIGHT = 40

local mainFrame = nil

function MainFrame:Initialize()
    if mainFrame then return end
    self:CreateFrame()
end

function MainFrame:CreateFrame()
    local W = PC.Widgets
    local C = W.Colors

    mainFrame = CreateFrame("Frame", "PeaversConfigFrame", UIParent, "BackdropTemplate")
    mainFrame:SetFrameStrata("DIALOG")
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMovable(true)
    mainFrame:SetResizable(true)
    mainFrame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, 1200, 900)

    PC.WindowState:RestoreFramePosition(mainFrame)

    mainFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    mainFrame:SetBackdropColor(C.bgBase[1], C.bgBase[2], C.bgBase[3], C.bgBase[4])
    mainFrame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)

    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        PC.WindowState:SaveFramePosition(self)
    end)

    mainFrame:SetScript("OnSizeChanged", function(self)
        PC.WindowState:SaveFramePosition(self)
        if PC.ContentArea and PC.ContentArea.OnResize then
            PC.ContentArea:OnResize()
        end
    end)

    -- Escape to close
    table.insert(UISpecialFrames, "PeaversConfigFrame")

    -- Resize handle — 6 dots in a triangle pattern
    local resizeButton = CreateFrame("Frame", nil, mainFrame)
    resizeButton:SetSize(14, 14)
    resizeButton:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeButton:EnableMouse(true)

    local dots = {}
    local dotPositions = {
        {-2, 2},
        {-6, 2}, {-2, 6},
        {-10, 2}, {-6, 6}, {-2, 10},
    }
    for _, pos in ipairs(dotPositions) do
        local dot = resizeButton:CreateTexture(nil, "OVERLAY")
        dot:SetSize(2, 2)
        dot:SetPoint("BOTTOMRIGHT", pos[1], pos[2])
        dot:SetColorTexture(C.textMuted[1], C.textMuted[2], C.textMuted[3], 0.6)
        dots[#dots + 1] = dot
    end

    resizeButton:SetScript("OnMouseDown", function() mainFrame:StartSizing("BOTTOMRIGHT") end)
    resizeButton:SetScript("OnMouseUp", function()
        mainFrame:StopMovingOrSizing()
        PC.WindowState:SaveFramePosition(mainFrame)
    end)
    resizeButton:SetScript("OnEnter", function()
        for _, dot in ipairs(dots) do
            dot:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.8)
        end
    end)
    resizeButton:SetScript("OnLeave", function()
        for _, dot in ipairs(dots) do
            dot:SetColorTexture(C.textMuted[1], C.textMuted[2], C.textMuted[3], 0.6)
        end
    end)

    PC.HeaderBar:Create(mainFrame)
    PC.Sidebar:Create(mainFrame)
    PC.ContentArea:Create(mainFrame)

    mainFrame:Hide()
end

function MainFrame:GetFrame()
    return mainFrame
end

function MainFrame:Show()
    if not mainFrame then self:Initialize() end

    if PC.Sidebar then
        PC.Sidebar:Refresh()
    end

    mainFrame:Show()

    if PC.Sidebar and not PC.Sidebar:GetSelected() then
        local sorted = PeaversCommons.ConfigRegistry:GetSortedAddons()
        if sorted and sorted[1] then
            PC.Sidebar:Select(sorted[1].name)
        end
    end
end

function MainFrame:Hide()
    if mainFrame then
        mainFrame:Hide()
    end
end

function MainFrame:Toggle()
    if not mainFrame then
        self:Show()
        return
    end
    if mainFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function MainFrame:SelectAddon(addonName)
    if PC.Sidebar then
        PC.Sidebar:Select(addonName)
    end
end

function MainFrame:SelectSection(section)
    if PC.Sidebar then
        PC.Sidebar:SelectSection(section)
    end
end

return MainFrame
