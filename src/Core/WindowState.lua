local _, PC = ...

PC.WindowState = {}
local WindowState = PC.WindowState

local DEFAULTS = {
    width = 800,
    height = 600,
    point = "CENTER",
    x = 0,
    y = 0,
    lastAddon = nil,
}

function WindowState:Initialize()
    if not _G.PeaversConfigDB then
        _G.PeaversConfigDB = {}
    end
    if not _G.PeaversConfigDB.windowState then
        _G.PeaversConfigDB.windowState = {}
        for k, v in pairs(DEFAULTS) do
            _G.PeaversConfigDB.windowState[k] = v
        end
    end
end

function WindowState:Get(key)
    if _G.PeaversConfigDB and _G.PeaversConfigDB.windowState then
        local val = _G.PeaversConfigDB.windowState[key]
        if val ~= nil then return val end
    end
    return DEFAULTS[key]
end

function WindowState:Set(key, value)
    if not _G.PeaversConfigDB then _G.PeaversConfigDB = {} end
    if not _G.PeaversConfigDB.windowState then _G.PeaversConfigDB.windowState = {} end
    _G.PeaversConfigDB.windowState[key] = value
end

function WindowState:SaveFramePosition(frame)
    if not frame then return end
    local point, _, _, x, y = frame:GetPoint()
    self:Set("point", point)
    self:Set("x", x)
    self:Set("y", y)
    self:Set("width", frame:GetWidth())
    self:Set("height", frame:GetHeight())
end

function WindowState:RestoreFramePosition(frame)
    if not frame then return end
    frame:ClearAllPoints()
    frame:SetPoint(
        self:Get("point"),
        UIParent,
        self:Get("point"),
        self:Get("x"),
        self:Get("y")
    )
    frame:SetSize(self:Get("width"), self:Get("height"))
end

return WindowState
