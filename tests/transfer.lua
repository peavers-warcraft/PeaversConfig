--------------------------------------------------------------------------------
-- Import / Export, end to end, without a game client.
--
--   Run: lua tests/transfer.lua        (from the addon root, Lua 5.1)
--
-- Needs PeaversCommons checked out beside this repo (../PeaversCommons), the
-- same way the lint config needs ../wow-api. Its real AceDB, ConfigManager and
-- GlobalAppearance are loaded rather than imitated, because what this has to
-- prove is that a string made by one client's configs lands correctly in
-- another client's configs - and stand-ins would only prove the stand-ins
-- agree with each other.
--
-- Each "client" is a fresh load of everything with its own saved variables:
-- one plays retail and exports, the other plays WoW Forever and imports.
--
-- Not addon code, and not packaged.
--------------------------------------------------------------------------------

local COMMONS = os.getenv("PEAVERS_COMMONS_DIR") or "../PeaversCommons"

local failures, checks = 0, 0

-- The game stand-in captures print, so the results go out through this.
local say = print

local function check(label, got, want)
    checks = checks + 1
    if got ~= want then
        failures = failures + 1
        say(("  FAIL %s: got %s, want %s"):format(label, tostring(got), tostring(want)))
    end
end

local function truthy(label, v) check(label, not not v, true) end

local function load(path, ...)
    local chunk, err = loadfile(path)
    if not chunk then error("cannot load " .. path .. ": " .. tostring(err) ..
        "\n(is PeaversCommons checked out at " .. COMMONS .. "?)") end
    return chunk(...)
end

local function DeepEqual(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do if not DeepEqual(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

--------------------------------------------------------------------------------
-- The game, as little of it as these files touch
--------------------------------------------------------------------------------

local inCombat = false
local printed = {}

local function StubGame()
    _G.print = function(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring(select(i, ...)) end printed[#printed + 1] = table.concat(t, " ") end
    _G.strmatch = string.match
    _G.GetLocale = function() return "enUS" end
    _G.UnitName = function() return "Peavers" end
    _G.GetRealmName = function() return "Dreamscythe" end
    _G.UnitClass = function() return "Mage", "MAGE" end
    _G.UnitRace = function() return "Human", "Human" end
    _G.UnitFactionGroup = function() return "Alliance" end
    _G.GetCurrentRegion = function() return 1 end
    _G.InCombatLockdown = function() return inCombat end
    _G.time = os.time
    _G.date = os.date
    _G.securecallfunction = function(f, ...) return f(...) end
    _G.geterrorhandler = function() return function(e) error(e) end end
    _G.CreateFrame = function()
        return { RegisterEvent = function() end, SetScript = function() end, UnregisterEvent = function() end }
    end
    _G.C_AddOns = { GetAddOnMetadata = function(name, field)
        if field == "Version" then return name == "PeaversDynamicStats" and "1.0.120" or "1.0.0" end
    end }
end

-- One client: fresh libraries, fresh saved variables, and three addons the way
-- the collection builds them - two on AceDB and one flat.
local function NewClient(clientKey, clientLabel, opts)
    opts = opts or {}

    for _, name in ipairs({ "LibStub", "PeaversCommons", "PeaversCommonsDB", "PeaversConfigDB",
        "PeaversDynamicStatsDB", "PeaversCombatResDB", "PeaversCastBarDB", "C_EncodingUtil", "Enum" }) do
        _G[name] = nil
    end
    StubGame()

    load(COMMONS .. "/Libs/LibStub/LibStub.lua")
    load(COMMONS .. "/Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
    load(COMMONS .. "/Libs/AceDB-3.0/AceDB-3.0.lua")

    ---@diagnostic disable-next-line: missing-fields
    _G.PeaversCommons = { Utils = {}, Client = { key = clientKey, label = clientLabel } }
    load(COMMONS .. "/src/Utils/Utils.lua")
    load(COMMONS .. "/src/Core/ConfigManager.lua")
    load(COMMONS .. "/src/Core/ConfigRegistry.lua")
    load(COMMONS .. "/src/Core/GlobalAppearance.lua")

    local PC = {}
    load("src/Core/Codec.lua", "PeaversConfig", PC)
    load("src/Core/SettingsTransfer.lua", "PeaversConfig", PC)

    local CM = _G.PeaversCommons.ConfigManager
    local registry = _G.PeaversCommons.ConfigRegistry
    local GA = _G.PeaversCommons.GlobalAppearance
    GA:Initialize()

    local stats = CM:NewWithAceDB("PeaversDynamicStats", {
        showStats = { HASTE = true, MASTERY = true },
        statOrder = { "HASTE", "MASTERY" },
        barWidth = 250,
        lockPosition = false,
        lastAppliedTemplate = nil,
    }, { savedVariablesName = "PeaversDynamicStatsDB" })
    stats:Initialize()

    local cres = CM:NewWithAceDB("PeaversCombatRes", {
        iconSize = 36,
        showText = true,
    }, { savedVariablesName = "PeaversCombatResDB" })
    cres:Initialize()

    local cast = CM:New({ name = "PeaversCastBar" }, {
        units = { player = { enabled = true, width = 220 } },
        showLatency = true,
    }, { savedVariablesName = "PeaversCastBarDB" })
    cast:Initialize()

    registry:Register({ name = "PeaversDynamicStats", displayName = "Dynamic Stats", config = stats })
    registry:Register({ name = "PeaversCombatRes", displayName = "Combat Res", config = cres })
    if not opts.withoutCastBar then
        registry:Register({ name = "PeaversCastBar", displayName = "Cast Bar", config = cast })
    end
    -- Registered with no config at all, the way PeaversCVars is.
    registry:Register({ name = "PeaversCVars", displayName = "CVars" })

    return {
        PC = PC, T = PC.SettingsTransfer, Codec = PC.Codec,
        stats = stats, cres = cres, cast = cast, GA = GA,
    }
end

--------------------------------------------------------------------------------
-- Codec
--------------------------------------------------------------------------------

say("codec")
do
    local c = NewClient("retail", "World of Warcraft")
    local Codec = c.Codec

    local bytes = {}
    for i = 0, 255 do bytes[#bytes + 1] = string.char(i) end
    local every = table.concat(bytes)

    local value = {
        int = 42, neg = -7, zero = 0, big = 2^40, huge = -2^52,
        third = 1 / 3, tenth = 0.1, tiny = 1e-300, large = 1.5e300,
        yes = true, no = false,
        text = "s5:{}T;F", empty = "", bytes = every,
        list = { "a", "b", { nested = { deeper = { 1, 2, 3 } } } },
        [1] = "one", [2.5] = "two and a half",
        none = {},
    }
    local back = Codec.Deserialize(Codec.Serialize(value))
    truthy("everything round-trips", DeepEqual(back, value))
    check("floats keep full precision", back.third, 1 / 3)
    check("integers past 32 bits survive", back.big, 2^40)
    check("every byte survives in a string", back.bytes, every)

    check("the same settings make the same string",
        Codec.Serialize({ b = 1, a = 2, [3] = true }), Codec.Serialize({ [3] = true, a = 2, b = 1 }))

    local skipped = Codec.Deserialize(Codec.Serialize({ f = print, nan = 0 / 0, inf = math.huge,
        frame = { [0] = newproxy() }, keep = 1 }))
    check("functions are left out", skipped.f, nil)
    check("NaN is left out", skipped.nan, nil)
    check("infinity is left out", skipped.inf, nil)
    check("frames are left out", skipped.frame, nil)
    check("the rest stays", skipped.keep, 1)

    -- Known vectors, and every length's padding.
    check("base64 Man", Codec.ToBase64("Man"), "TWFu")
    check("base64 Ma", Codec.ToBase64("Ma"), "TWE=")
    check("base64 M", Codec.ToBase64("M"), "TQ==")
    for n = 0, 9 do
        local s = every:sub(200, 199 + n)
        check("base64 round trip length " .. n, Codec.FromBase64(Codec.ToBase64(s)), s)
    end
    check("base64 of every byte", Codec.FromBase64(Codec.ToBase64(every)), every)

    -- Hostile input is refused, never run and never thrown.
    local bad = {
        "s99999:abc", "{s1:a", "{{}i1;}", "i1.5;", "nnan;", "ninf;", "n-inf;", "x",
        "i1;i2;", "", string.rep("{", 100) .. string.rep("}", 100),
    }
    for _, s in ipairs(bad) do
        local ok, v = pcall(Codec.Deserialize, s)
        truthy("refuses " .. s:sub(1, 20) .. " without throwing", ok)
        check("refuses " .. s:sub(1, 20), v, nil)
    end

    -- No C_EncodingUtil: plain base64, still readable.
    local plain = Codec.Encode({ a = 1 })
    check("falls back to base64 without the client's encoder", plain:sub(1, 6), "!PV1b!")
    check("and reads it back", Codec.Decode(plain).a, 1)

    -- Chat clients wrap long lines and add spaces; none of it is the string.
    local wrapped = plain:sub(1, 5) .. "\n  " .. plain:sub(6, 9) .. " \r\n" .. plain:sub(10)
    check("whitespace from a chat paste is ignored", Codec.Decode(wrapped).a, 1)

    local _, err1 = Codec.Decode("hello")
    truthy("not ours says so", err1 and err1:find("not a Peavers"))
    local _, err2 = Codec.Decode("!PV2b!abcd")
    truthy("newer format says to update", err2 and err2:find("newer"))
    local _, err3 = Codec.Decode(plain:sub(1, #plain - 6))
    truthy("cut short says it is damaged", err3 and err3:find("damaged"))

    -- With the client's encoder: deflate path. A stand-in that is honest about
    -- the contract - bytes in, different bytes out, and back again.
    _G.Enum = { CompressionMethod = { Deflate = 0 } }
    _G.C_EncodingUtil = {
        CompressString = function(s, method) assert(method == 0) return "Z" .. s:reverse() end,
        DecompressString = function(s, method)
            assert(method == 0)
            if s:sub(1, 1) ~= "Z" then error("bad stream") end
            return s:sub(2):reverse()
        end,
        EncodeBase64 = Codec.ToBase64,
        DecodeBase64 = Codec.FromBase64,
    }
    local packed = Codec.Encode({ a = 2 })
    check("uses the client's encoder when it has one", packed:sub(1, 6), "!PV1z!")
    check("and reads it back", Codec.Decode(packed).a, 2)
    local _, err4 = Codec.Decode("!PV1z!" .. Codec.ToBase64("garbage"))
    truthy("a broken compressed string is refused, not thrown", err4 and err4:find("damaged"))

    -- A compressed string on a client with no encoder says why.
    _G.C_EncodingUtil = nil
    local _, err5 = Codec.Decode(packed)
    truthy("no encoder says so", err5 and err5:find("cannot unpack"))
end

--------------------------------------------------------------------------------
-- Retail exports
--------------------------------------------------------------------------------

say("export")
local retail = NewClient("retail", "World of Warcraft")
retail.stats.showStats = { HASTE = true, MASTERY = false, VERSATILITY = true }
retail.stats.statOrder = { "VERSATILITY", "HASTE" }
retail.stats.barWidth = 310
retail.stats.fontFace = "Fonts\\MORPHEUS.TTF"
retail.stats.barTexture = "Interface\\AddOns\\SharedMedia\\statusbar\\Fancy.tga" -- retail-only LSM
retail.stats.installedVersion = "retail-install"
retail.stats.lastAppliedTemplate = "Raid"
retail.cast.showLatency = false
retail.cast.units.player.width = 300
retail.cast.frameX = 120
retail.cast:Save()
retail.GA:Set("fontSize", 14)

local entries = retail.T:GetEntries()
local keys = {}
for _, e in ipairs(entries) do keys[#keys + 1] = e.key end
check("every addon with a config, then Global Appearance", table.concat(keys, ","),
    "PeaversCastBar,PeaversCombatRes,PeaversDynamicStats,GlobalAppearance")

local statsEntry = retail.T:GetEntry("PeaversDynamicStats")
check("counts what was changed, and not the install record", retail.T:CountChanged(statsEntry), 6)
check("an untouched addon has nothing changed", retail.T:CountChanged(retail.T:GetEntry("PeaversCombatRes")), 0)

local text, n = retail.T:Export()
check("exports every addon", n, 4)
truthy("the string is framed", text:find("^!PV1[bz]!"))

local onlyStats = retail.T:Export({ PeaversDynamicStats = true })
local onlyPayload = retail.T:Read(onlyStats)
check("an export can be narrowed to one addon", onlyPayload.addons.PeaversCastBar, nil)
truthy("and keeps that one", onlyPayload.addons.PeaversDynamicStats)

local payload = retail.T:Read(text)
check("records where it came from", payload.clientLabel, "World of Warcraft")
check("the install record stays home", payload.addons.PeaversDynamicStats.settings.installedVersion, nil)
check("the addon's version travels", payload.addons.PeaversDynamicStats.version, "1.0.120")

--------------------------------------------------------------------------------
-- Forever imports
--------------------------------------------------------------------------------

say("import")
local forever = NewClient("forever", "WoW Forever", { withoutCastBar = true })
forever.stats.installedVersion = "forever-install"
forever.stats.barWidth = 999
forever.stats.lockPosition = true          -- changed here, not on retail
forever.cres.iconSize = 50                 -- an addon the import will leave alone
forever.GA:Set("fontSize", 20)

local incoming, readErr = forever.T:Read(text)
truthy("reads a retail string on Forever", incoming)
check("reading does not complain", readErr, nil)

local rows = forever.T:Preview(incoming)
local byKey = {}
for _, r in ipairs(rows) do byKey[r.key] = r end
check("an installed addon is offered", byKey.PeaversDynamicStats.installed, true)
check("its settings are counted", byKey.PeaversDynamicStats.count, 6)
check("an addon not installed here is shown as such", byKey.PeaversCastBar.installed, false)
check("installed ones come first", rows[#rows].key, "PeaversCastBar")

-- Nothing has changed yet.
check("reading changes nothing", forever.stats.barWidth, 999)

inCombat = true
local blocked, combatErr = forever.T:Apply(incoming, { PeaversDynamicStats = true })
check("refuses in combat", blocked, nil)
truthy("and says why", combatErr and combatErr:find("combat"))
check("and changed nothing", forever.stats.barWidth, 999)
inCombat = false

local report = forever.T:Apply(incoming, { PeaversDynamicStats = true, GlobalAppearance = true })
truthy("applies", report)

check("settings arrive", forever.stats.barWidth, 310)
truthy("tables arrive whole", DeepEqual(forever.stats.showStats,
    { HASTE = true, MASTERY = false, VERSATILITY = true }))
truthy("lists arrive in order", DeepEqual(forever.stats.statOrder, { "VERSATILITY", "HASTE" }))
check("a font both clients have arrives", forever.stats.fontFace, "Fonts\\MORPHEUS.TTF")
check("a texture this client lacks stays at the default", forever.stats.barTexture,
    forever.stats.defaults.barTexture)
check("replace, not merge: a setting only Forever had goes back to default", forever.stats.lockPosition, false)
check("the install record here is kept", forever.stats.installedVersion, "forever-install")
check("a nil-default setting arrives", forever.stats.lastAppliedTemplate, "Raid")
check("an unticked addon is left alone", forever.cres.iconSize, 50)
check("Global Appearance arrives", forever.GA:Get("fontSize"), 14)

local statsLine
for _, line in ipairs(report.applied) do if line.label == "Dynamic Stats" then statsLine = line end end
truthy("the report names what stayed at its default",
    statsLine and #statsLine.dropped == 1 and statsLine.dropped[1]:find("barTexture"))

-- The profile on disk is what AceDB will hand the addon after the reload.
local key = "Peavers - Dreamscythe"
local onDisk = _G.PeaversDynamicStatsDB.profiles[_G.PeaversDynamicStatsDB.profileKeys[key]]
check("it is in the saved profile, ready for the reload", onDisk.barWidth, 310)

-- After the reload, the chat says what happened.
printed = {}
forever.T:AnnounceLastImport()
truthy("says what was imported after the reload", printed[1] and printed[1]:find("Imported settings for 2"))
truthy("and from where", printed[1] and printed[1]:find("World of Warcraft"))
truthy("and what stayed at its default", printed[2] and printed[2]:find("barTexture"))
printed = {}
forever.T:AnnounceLastImport()
check("only once", #printed, 0)

--------------------------------------------------------------------------------
-- Undo
--------------------------------------------------------------------------------

say("undo")
truthy("there is something to undo", forever.T:GetUndo())
forever.T:Undo()
check("undo puts the settings back", forever.stats.barWidth, 999)
check("including ones the import reset", forever.stats.lockPosition, true)
check("and Global Appearance", forever.GA:Get("fontSize"), 20)
check("and keeps the install record", forever.stats.installedVersion, "forever-install")
check("the undo is used up", forever.T:GetUndo(), nil)

--------------------------------------------------------------------------------
-- A flat config, imported
--------------------------------------------------------------------------------

say("flat config")
local pc2 = NewClient("era", "Classic Era")
pc2.cast.showLatency = true
pc2.cast.strayKey = "left over from an old version"
pc2.cast:Save()
local castReport = pc2.T:Apply(pc2.T:Read(text), { PeaversCastBar = true })
truthy("applies to a flat config", castReport)
check("flat settings arrive", pc2.cast.showLatency, false)
check("nested flat settings arrive", pc2.cast.units.player.width, 300)
check("and are saved", _G.PeaversCastBarDB.showLatency, false)
check("a key the string does not have is gone from disk", _G.PeaversCastBarDB.strayKey, nil)
check("positions travel", _G.PeaversCastBarDB.frameX, 120)

-- A wrong-kind value from a hand-edited string is refused, not written.
local tampered = pc2.T:Read(text)
tampered.addons.PeaversCastBar.settings.showLatency = "yes"
local tamperedReport = pc2.T:Apply(tampered, { PeaversCastBar = true })
check("a wrong-kind value keeps the default", pc2.cast.showLatency, true)
truthy("and is reported", tamperedReport.applied[1].dropped[1]:find("showLatency"))

--------------------------------------------------------------------------------

say(("%d checks, %d failed"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
