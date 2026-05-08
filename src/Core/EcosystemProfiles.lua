local _, PC = ...

PC.EcosystemProfiles = {}
local EcosystemProfiles = PC.EcosystemProfiles

function EcosystemProfiles:Initialize()
    if not _G.PeaversConfigDB then _G.PeaversConfigDB = {} end
    if not _G.PeaversConfigDB.ecosystemProfiles then
        _G.PeaversConfigDB.ecosystemProfiles = {}
    end
    if not _G.PeaversConfigDB.activeEcosystemProfile then
        _G.PeaversConfigDB.activeEcosystemProfile = nil
    end
    if not _G.PeaversConfigDB.specAutoSwitch then
        _G.PeaversConfigDB.specAutoSwitch = { enabled = false, specProfiles = {} }
    end

    self:SetupSpecAutoSwitch()
end

function EcosystemProfiles:GetProfiles()
    return _G.PeaversConfigDB.ecosystemProfiles or {}
end

function EcosystemProfiles:GetActiveProfile()
    return _G.PeaversConfigDB.activeEcosystemProfile
end

function EcosystemProfiles:GetAllProfileNames()
    local names = {}
    local seen = {}

    -- Gather from ecosystem profiles
    for name, _ in pairs(self:GetProfiles()) do
        if not seen[name] then
            table.insert(names, name)
            seen[name] = true
        end
    end

    -- Also gather from individual addon AceDB profiles
    local registry = _G.PeaversCommons and _G.PeaversCommons.ConfigRegistry
    if registry then
        for _, info in pairs(registry:GetRegisteredAddons()) do
            if info.config and info.config.GetProfiles then
                local addonProfiles = info.config:GetProfiles()
                for _, p in ipairs(addonProfiles) do
                    if not seen[p] then
                        table.insert(names, p)
                        seen[p] = true
                    end
                end
            end
        end
    end

    table.sort(names)
    return names
end

-- Create a new empty profile (defaults) across all addons
function EcosystemProfiles:CreateEmptyProfile(name)
    if not name or name == "" then return false end
    if not _G.PeaversConfigDB.ecosystemProfiles then
        _G.PeaversConfigDB.ecosystemProfiles = {}
    end

    local existing = _G.PeaversConfigDB.ecosystemProfiles[name]
    if existing then
        print("|cffff6666PeaversConfig:|r Profile '" .. name .. "' already exists.")
        return false
    end

    local registry = _G.PeaversCommons and _G.PeaversCommons.ConfigRegistry
    if registry then
        for _, info in pairs(registry:GetRegisteredAddons()) do
            if info.config and info.config.db then
                -- Switch to new profile (AceDB creates it with defaults)
                info.config.db:SetProfile(name)
            end
        end
    end

    _G.PeaversConfigDB.ecosystemProfiles[name] = true
    _G.PeaversConfigDB.activeEcosystemProfile = name
    print("|cff00ff00PeaversConfig:|r Created new profile: " .. name)
    return true
end

-- Duplicate the current profile to a new name across all addons
function EcosystemProfiles:DuplicateProfile(name)
    if not name or name == "" then return false end
    if not _G.PeaversConfigDB.ecosystemProfiles then
        _G.PeaversConfigDB.ecosystemProfiles = {}
    end

    if _G.PeaversConfigDB.ecosystemProfiles[name] then
        print("|cffff6666PeaversConfig:|r Profile '" .. name .. "' already exists.")
        return false
    end

    local registry = _G.PeaversCommons and _G.PeaversCommons.ConfigRegistry
    if registry then
        for _, info in pairs(registry:GetRegisteredAddons()) do
            if info.config and info.config.db then
                local currentProfile = info.config:GetCurrentProfile()
                -- Switch to new profile, then copy from current
                info.config.db:SetProfile(name)
                info.config.db:CopyProfile(currentProfile, true)
            end
        end
    end

    _G.PeaversConfigDB.ecosystemProfiles[name] = true
    _G.PeaversConfigDB.activeEcosystemProfile = name
    print("|cff00ff00PeaversConfig:|r Duplicated current profile to: " .. name)
    return true
end

function EcosystemProfiles:DeleteProfile(name)
    if not name or not _G.PeaversConfigDB.ecosystemProfiles then return false end

    local charDefault = UnitName("player") .. " - " .. GetRealmName()

    local registry = _G.PeaversCommons and _G.PeaversCommons.ConfigRegistry
    if registry then
        for _, info in pairs(registry:GetRegisteredAddons()) do
            if info.config and info.config.db then
                local currentProfile = info.config:GetCurrentProfile()
                if currentProfile == name then
                    info.config.db:SetProfile(charDefault)
                end
                info.config:DeleteProfile(name)
            end
        end
    end

    _G.PeaversConfigDB.ecosystemProfiles[name] = nil
    if _G.PeaversConfigDB.activeEcosystemProfile == name then
        _G.PeaversConfigDB.activeEcosystemProfile = nil
    end
    print("|cff00ff00PeaversConfig:|r Deleted profile: " .. name)
    return true
end

function EcosystemProfiles:ResetProfile(name)
    if not name then return false end

    local registry = _G.PeaversCommons and _G.PeaversCommons.ConfigRegistry
    if not registry then return false end

    for _, info in pairs(registry:GetRegisteredAddons()) do
        if info.config and info.config.db then
            local currentProfile = info.config:GetCurrentProfile()
            if currentProfile == name then
                info.config.db:ResetProfile()
            else
                info.config.db:SetProfile(name)
                info.config.db:ResetProfile()
                info.config.db:SetProfile(currentProfile)
            end
        end
    end

    print("|cff00ff00PeaversConfig:|r Reset profile to defaults: " .. name)
    return true
end

function EcosystemProfiles:SwitchProfile(name)
    if not name then return false end

    local registry = _G.PeaversCommons and _G.PeaversCommons.ConfigRegistry
    if not registry then return false end

    for _, info in pairs(registry:GetRegisteredAddons()) do
        if info.config and info.config.SetProfile then
            info.config:SetProfile(name)
        end
    end

    -- Track as ecosystem profile if not already
    if not _G.PeaversConfigDB.ecosystemProfiles then
        _G.PeaversConfigDB.ecosystemProfiles = {}
    end

    _G.PeaversConfigDB.activeEcosystemProfile = name
    print("|cff00ff00PeaversConfig:|r Switched to profile: " .. name)
    return true
end

-- ============================================================
-- SPEC AUTO-SWITCH
-- ============================================================

function EcosystemProfiles:SetupSpecAutoSwitch()
    if self.specFrame then return end

    self.specFrame = CreateFrame("Frame")
    self.specFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self.specFrame:SetScript("OnEvent", function(_, _, unit)
        if unit == "player" or not unit then
            self:CheckSpecAutoSwitch()
        end
    end)
end

function EcosystemProfiles:CheckSpecAutoSwitch()
    local specConfig = _G.PeaversConfigDB and _G.PeaversConfigDB.specAutoSwitch
    if not specConfig or not specConfig.enabled then return end

    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex then return end

    local profileName = specConfig.specProfiles and specConfig.specProfiles[specIndex]
    if not profileName or profileName == "" then return end

    local current = self:GetActiveProfile() or (UnitName("player") .. " - " .. GetRealmName())
    if profileName == current then return end

    -- Verify profile exists
    local allProfiles = self:GetAllProfileNames()
    local exists = false
    for _, p in ipairs(allProfiles) do
        if p == profileName then
            exists = true
            break
        end
    end

    if exists then
        self:SwitchProfile(profileName)
        print("|cff00ff00PeaversConfig:|r Auto-switched to profile: " .. profileName)
    end
end

return EcosystemProfiles
