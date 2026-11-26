local _, PC = ...

PC.EcosystemProfiles = {}
local EcosystemProfiles = PC.EcosystemProfiles

local function CharacterKey()
    return UnitName("player") .. " - " .. GetRealmName()
end

local function CopySpecConfig(from)
    local copy = { enabled = from and from.enabled or false, specProfiles = {} }
    if from and type(from.specProfiles) == "table" then
        for index, name in pairs(from.specProfiles) do copy.specProfiles[index] = name end
    end
    return copy
end

-- Which profile a character uses, and which profile each of its specs switches
-- to, belong to that character. Both used to sit at the top of the account's
-- saved variables, so picking a profile on one character moved every other
-- character onto it at their next login.
function EcosystemProfiles:GetCharacterState()
    local db = _G.PeaversConfigDB
    if not db.characters then db.characters = {} end
    local key = CharacterKey()
    local state = db.characters[key]
    if not state then
        -- Spec choices were one account-wide list. Each character starts from
        -- a copy of it, so nobody's setup vanishes, and goes its own way after.
        state = { specAutoSwitch = CopySpecConfig(db.specAutoSwitch) }
        db.characters[key] = state
    end
    return state
end

function EcosystemProfiles:Initialize()
    if not _G.PeaversConfigDB then _G.PeaversConfigDB = {} end
    if not _G.PeaversConfigDB.ecosystemProfiles then
        _G.PeaversConfigDB.ecosystemProfiles = {}
    end
    -- The old account-wide choice is not carried over: the profile each addon
    -- remembers for this character is already the right answer, and copying
    -- the shared one would repeat the bug once more for every character.
    _G.PeaversConfigDB.activeEcosystemProfile = nil

    self:SetupSpecAutoSwitch()
end

function EcosystemProfiles:GetSpecConfig()
    return self:GetCharacterState().specAutoSwitch
end

function EcosystemProfiles:GetProfiles()
    return _G.PeaversConfigDB.ecosystemProfiles or {}
end

-- The profile this character's addons are on, when it has not picked one here
-- yet: whichever most of them use, as each addon keeps its own per character.
local function ProfileInUse()
    local registry = _G.PeaversCommons and _G.PeaversCommons.ConfigRegistry
    if not registry then return nil end
    local counts, best = {}, nil
    for _, info in pairs(registry:GetRegisteredAddons()) do
        local name = info.config and info.config.GetCurrentProfile and info.config:GetCurrentProfile()
        if name then
            counts[name] = (counts[name] or 0) + 1
            if not best or counts[name] > counts[best] or (counts[name] == counts[best] and name < best) then
                best = name
            end
        end
    end
    return best
end

function EcosystemProfiles:GetActiveProfile()
    return self:GetCharacterState().activeProfile or ProfileInUse()
end

local function SetActiveProfile(name)
    EcosystemProfiles:GetCharacterState().activeProfile = name
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
    SetActiveProfile(name)
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
    SetActiveProfile(name)
    print("|cff00ff00PeaversConfig:|r Duplicated current profile to: " .. name)
    return true
end

function EcosystemProfiles:DeleteProfile(name)
    if not name or not _G.PeaversConfigDB.ecosystemProfiles then return false end

    local charDefault = CharacterKey()

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
    -- Gone for every character, so no character may still ask for it at login.
    for _, state in pairs(_G.PeaversConfigDB.characters or {}) do
        if state.activeProfile == name then state.activeProfile = nil end
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

    SetActiveProfile(name)
    print("|cff00ff00PeaversConfig:|r Switched to profile: " .. name)
    return true
end

-- Brings an addon installed since this character last picked a profile onto
-- that profile. Only this character's own pick counts.
function EcosystemProfiles:ApplyActiveProfileOnLogin()
    local activeProfile = self:GetCharacterState().activeProfile
    if not activeProfile then return end

    local registry = _G.PeaversCommons and _G.PeaversCommons.ConfigRegistry
    if not registry then return end

    local needsSwitch = false
    for _, info in pairs(registry:GetRegisteredAddons()) do
        if info.config and info.config.GetCurrentProfile then
            if info.config:GetCurrentProfile() ~= activeProfile then
                needsSwitch = true
                break
            end
        end
    end

    if needsSwitch then
        self:SwitchProfile(activeProfile)
    end
end

-- ============================================================
-- SPEC AUTO-SWITCH
-- ============================================================

function EcosystemProfiles:SetupSpecAutoSwitch()
    if self.specFrame then return end

    -- Nothing to switch on a client without specializations - and registering
    -- their event there is a hard error that would stop PeaversConfig loading.
    local Compat = _G.PeaversCommons and _G.PeaversCommons.Compat
    if not (GetSpecialization and GetSpecializationInfo) then return end

    self.specFrame = CreateFrame("Frame")
    if not Compat or Compat.IsEventValid("PLAYER_SPECIALIZATION_CHANGED") then
        self.specFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    end
    self.specFrame:SetScript("OnEvent", function(_, _, unit)
        if unit == "player" or not unit then
            self:CheckSpecAutoSwitch()
        end
    end)
end

function EcosystemProfiles:CheckSpecAutoSwitch()
    local specConfig = _G.PeaversConfigDB and self:GetSpecConfig()
    if not specConfig or not specConfig.enabled then return end

    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex then return end

    local profileName = specConfig.specProfiles and specConfig.specProfiles[specIndex]
    if not profileName or profileName == "" then return end

    local current = self:GetActiveProfile() or CharacterKey()
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
