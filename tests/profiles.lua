--------------------------------------------------------------------------------
-- Profiles belong to the character that picked them.
--
--   Run: lua tests/profiles.lua        (from the addon root, Lua 5.1)
--
-- Needs PeaversCommons checked out beside this repo (../PeaversCommons). Its
-- real AceDB and ConfigManager are loaded, because the per-character half of
-- this lives in AceDB's profileKeys and stand-ins would only agree with
-- themselves.
--
-- Two characters share one account's saved variables and take turns logging
-- in. Picking a profile, or a profile for a spec, on one must leave the other
-- where it was.
--
-- Not addon code, and not packaged.
--------------------------------------------------------------------------------

local COMMONS = os.getenv("PEAVERS_COMMONS_DIR") or "../PeaversCommons"

local failures, checks = 0, 0
local say = print

local function check(label, got, want)
    checks = checks + 1
    if got ~= want then
        failures = failures + 1
        say(("  FAIL %s: got %s, want %s"):format(label, tostring(got), tostring(want)))
    end
end

local function load(path, ...)
    local chunk, err = loadfile(path)
    if not chunk then error("cannot load " .. path .. ": " .. tostring(err) ..
        "\n(is PeaversCommons checked out at " .. COMMONS .. "?)") end
    return chunk(...)
end

local REALM = "Dreamscythe"
local SAVED = { "PeaversConfigDB", "PeaversDynamicStatsDB", "PeaversCombatResDB", "PeaversCastBarDB" }

-- The account's saved variables, carried from one login to the next.
local account = {
    -- What 1.0.38 left behind: one choice for the whole account, already
    -- forced onto Main, and one list of spec choices.
    PeaversConfigDB = {
        ecosystemProfiles = { Raid = true },
        activeEcosystemProfile = "Raid",
        specAutoSwitch = { enabled = true, specProfiles = { [1] = "Raid" } },
    },
    PeaversDynamicStatsDB = {
        profileKeys = { ["Main - " .. REALM] = "Raid", ["Alt - " .. REALM] = "Alt - " .. REALM },
        profiles = { Raid = { barWidth = 300 } },
    },
    PeaversCombatResDB = {
        profileKeys = { ["Main - " .. REALM] = "Raid", ["Alt - " .. REALM] = "Alt - " .. REALM },
        profiles = { Raid = {} },
    },
}

-- One login: fresh libraries and addons, this account's saved variables.
local function Login(character, opts)
    opts = opts or {}
    for _, name in ipairs({ "LibStub", "PeaversCommons", "PeaversCommonsDB", "PeaversCastBarDB" }) do
        _G[name] = nil
    end
    for _, name in ipairs(SAVED) do _G[name] = account[name] end

    _G.print = function() end
    _G.strmatch = string.match
    _G.GetLocale = function() return "enUS" end
    _G.UnitName = function() return character end
    _G.GetRealmName = function() return REALM end
    _G.UnitClass = function() return "Mage", "MAGE" end
    _G.UnitRace = function() return "Human", "Human" end
    _G.UnitFactionGroup = function() return "Alliance" end
    _G.GetCurrentRegion = function() return 1 end
    _G.InCombatLockdown = function() return false end
    _G.time = os.time
    _G.date = os.date
    _G.securecallfunction = function(f, ...) return f(...) end
    _G.geterrorhandler = function() return function(e) error(e) end end
    local specHandler
    _G.CreateFrame = function()
        return {
            RegisterEvent = function() end,
            UnregisterEvent = function() end,
            SetScript = function(_, _, fn) specHandler = fn end,
        }
    end
    local spec = opts.spec or 1
    _G.GetSpecialization = function() return spec end
    _G.GetSpecializationInfo = function(i) return i, "Spec " .. i end

    load(COMMONS .. "/Libs/LibStub/LibStub.lua")
    load(COMMONS .. "/Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
    load(COMMONS .. "/Libs/AceDB-3.0/AceDB-3.0.lua")

    ---@diagnostic disable-next-line: missing-fields
    _G.PeaversCommons = { Utils = {} }
    load(COMMONS .. "/src/Utils/Utils.lua")
    load(COMMONS .. "/src/Core/ConfigManager.lua")
    load(COMMONS .. "/src/Core/ConfigRegistry.lua")

    local CM = _G.PeaversCommons.ConfigManager
    local registry = _G.PeaversCommons.ConfigRegistry

    local addons = {}
    local function AceAddon(name)
        local config = CM:NewWithAceDB(name, { barWidth = 250 }, { savedVariablesName = name .. "DB" })
        config:Initialize()
        account[name .. "DB"] = _G[name .. "DB"]
        registry:Register({ name = name, displayName = name, config = config })
        addons[name] = config
    end
    AceAddon("PeaversDynamicStats")
    AceAddon("PeaversCombatRes")
    if opts.newAddon then AceAddon(opts.newAddon) end

    -- A flat one, which has no profiles, and one with no config at all.
    local cast = CM:New({ name = "PeaversCastBar" }, { showLatency = true },
        { savedVariablesName = "PeaversCastBarDB" })
    cast:Initialize()
    registry:Register({ name = "PeaversCastBar", displayName = "Cast Bar", config = cast })
    registry:Register({ name = "PeaversCVars", displayName = "CVars" })

    local PC = {}
    load("src/Core/EcosystemProfiles.lua", "PeaversConfig", PC)
    local profiles = PC.EcosystemProfiles
    profiles:Initialize()
    profiles:ApplyActiveProfileOnLogin()
    account.PeaversConfigDB = _G.PeaversConfigDB

    return {
        profiles = profiles,
        addons = addons,
        ChangeSpec = function(to) spec = to specHandler(nil, "PLAYER_SPECIALIZATION_CHANGED", "player") end,
    }
end

local function On(session, name)
    return session.addons[name]:GetCurrentProfile()
end

--------------------------------------------------------------------------------
-- Upgrading: nothing moves
--------------------------------------------------------------------------------

local main = Login("Main")
check("the account-wide choice is dropped", account.PeaversConfigDB.activeEcosystemProfile, nil)
check("Main stays on the profile its addons remember", main.profiles:GetActiveProfile(), "Raid")
check("Main keeps its spec choices", main.profiles:GetSpecConfig().specProfiles[1], "Raid")

local alt = Login("Alt")
check("Alt is not pulled onto Main's profile", On(alt, "PeaversDynamicStats"), "Alt - " .. REALM)
check("Alt reports its own profile", alt.profiles:GetActiveProfile(), "Alt - " .. REALM)
check("Alt keeps the spec choices it had", alt.profiles:GetSpecConfig().specProfiles[1], "Raid")

--------------------------------------------------------------------------------
-- The report: picking a profile on one character
--------------------------------------------------------------------------------

main = Login("Main")
main.profiles:CreateEmptyProfile("Solo")
check("Main is on Solo", On(main, "PeaversCombatRes"), "Solo")

alt = Login("Alt")
check("Alt is still on its own profile", On(alt, "PeaversDynamicStats"), "Alt - " .. REALM)
check("Alt is still on its own profile (second addon)", On(alt, "PeaversCombatRes"), "Alt - " .. REALM)
check("Alt reports its own profile after Main switched", alt.profiles:GetActiveProfile(), "Alt - " .. REALM)
alt.profiles:SwitchProfile("Raid")
alt.profiles:GetSpecConfig().specProfiles[2] = "Raid"

main = Login("Main")
check("Main is still on Solo after Alt switched", On(main, "PeaversDynamicStats"), "Solo")
check("Main reports Solo", main.profiles:GetActiveProfile(), "Solo")
check("Alt's spec choice is not Main's", main.profiles:GetSpecConfig().specProfiles[2], nil)

-- An addon installed since: it joins the profile this character picked.
main = Login("Main", { newAddon = "PeaversCastBarPlus" })
check("a new addon joins Main's profile", On(main, "PeaversCastBarPlus"), "Solo")

--------------------------------------------------------------------------------
-- Spec switching uses this character's list
--------------------------------------------------------------------------------

alt = Login("Alt")
alt.profiles:SwitchProfile("Alt - " .. REALM)
alt.ChangeSpec(2)
check("Alt's spec 2 switches Alt to Raid", On(alt, "PeaversDynamicStats"), "Raid")

main = Login("Main")
main.ChangeSpec(2)
check("Main has nothing on spec 2, so stays on Solo", On(main, "PeaversDynamicStats"), "Solo")

--------------------------------------------------------------------------------
-- Deleting a profile one character picked, from another
--------------------------------------------------------------------------------

alt = Login("Alt")
alt.profiles:DeleteProfile("Solo")
check("no character still asks for a deleted profile",
    account.PeaversConfigDB.characters["Main - " .. REALM].activeProfile, nil)

say(("%d checks, %d failed"):format(checks, failures))
if failures > 0 then os.exit(1) end
